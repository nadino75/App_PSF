'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const D = require('./domain');
const { logAudit, AuditAction, AuditResult } = require('./audit');
initializeApp();
const db = getFirestore();
const auth = getAuth();
const stamp = () => FieldValue.serverTimestamp();
const call = (handler) => onCall({ region: 'us-central1', maxInstances: 10 }, async request => {
  try {
    D.requireThat(request.auth && request.auth.token.firebase?.sign_in_provider !== 'anonymous',
      'unauthenticated', 'Inicia sesión con tu cuenta.');
    return await handler(request.data ?? {}, request.auth);
  } catch (error) {
    if (error instanceof D.DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof HttpsError) throw error;
    console.error(error);
    throw new HttpsError('internal', 'No se pudo guardar la operación. Vuelve a intentarlo.');
  }
});
const requireAdmin = auth => D.requireThat(D.isAdmin(auth), 'permission-denied', 'Se requiere un administrador.');

exports.registrarComoDueno = onCall({ region: 'us-central1', maxInstances: 10 }, async request => {
  try {
    // Rechazar usuarios ya autenticados
    D.requireThat(!request.auth || request.auth.token.firebase?.sign_in_provider === 'anonymous',
      'already-authenticated', 'Ya estás registrado.');

    const email = D.text(request.data.email, 'email', 254);
    const password = D.text(request.data.password, 'password', 128);
    const nombre = D.text(request.data.nombre, 'nombre', 100);
    const negocioData = D.businessData(request.data.negocio);

    // Validar email único en Firestore
    const existingUser = await db.collection('usuarios')
      .where('email', '==', email)
      .limit(1)
      .get();
    D.requireThat(existingUser.empty, 'already-exists', 'Este correo ya está registrado.');

    // Crear usuario en Firebase Auth
    const userRecord = await auth.createUser({
      email,
      password,
      displayName: nombre,
    });

    // Crear documento de usuario y negocio en transacción
    const negocioId = db.collection('negocios').doc().id;
    await db.runTransaction(async tx => {
      // Usuario
      tx.set(db.collection('usuarios').doc(userRecord.uid), {
        nombre,
        email,
        dueno: true,
        creado: stamp(),
      });

      // Negocio
      tx.set(db.collection('negocios').doc(negocioId), {
        duenoId: userRecord.uid,
        publicado: false,
        versionId: negocioId,
        creado: stamp(),
      });

      // Catálogo
      tx.set(db.collection('catalogo').doc(negocioId), {
        ...negocioData,
        publicado: false,
        creado: stamp(),
      });

      // Versión inicial
      tx.set(db.collection('negocios').doc(negocioId).collection('versiones').doc(negocioId), {
        ...negocioData,
        creado: stamp(),
      });
    });

    return { uid: userRecord.uid, negocioId };
  } catch (error) {
    if (error instanceof D.DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof HttpsError) throw error;
    console.error(error);
    throw new HttpsError('internal', 'No se pudo registrar. Vuelve a intentarlo.');
  }
});

exports.enviarSolicitud = call(async (data, auth) => {
  const id = D.identifier(data.id);
  const tipo = data.tipo;
  // Los usuarios regulares NO pueden crear negocios (solo dueños vía registrarComoDueno)
  D.requireThat(['cambio', 'anuncio'].includes(tipo), 'invalid-argument', 'Tipo inválido. Use registro especial para crear negocio.');
  const propuesta = tipo === 'anuncio' ? D.contentData(data.propuesta, tipo) : D.businessData(data.propuesta);
  const negocioId = tipo === 'negocio' ? id : D.identifier(data.negocioId);
  if (tipo === 'anuncio') D.requireThat(propuesta.negocioId === negocioId, 'invalid-argument', 'Negocio inválido.');
  const ref = db.collection('solicitudes').doc(id);
  const business = db.collection('negocios').doc(negocioId);
  const lock = db.collection('pendientes').doc(`${negocioId}_${tipo}`);
  await db.runTransaction(async tx => {
    const [existing, current, pending] = await Promise.all([tx.get(ref), tx.get(business), tx.get(lock)]);
    if (existing.exists && existing.data().estado !== 'borrador') {
      D.requireThat(existing.data().solicitanteId === auth.uid, 'permission-denied', 'Solicitud ajena.');
      return; // Stable client-generated ID makes retries idempotent.
    }
    if (existing.exists) D.requireThat(existing.data().solicitanteId === auth.uid, 'permission-denied', 'Solicitud ajena.');
    if (tipo !== 'negocio') D.requireThat(current.exists && current.data().duenoId === auth.uid,
      'permission-denied', 'Solo el dueño puede proponer cambios.');
    else D.requireThat(!current.exists, 'already-exists', 'El negocio ya existe.');
    D.requireThat(!pending.exists || pending.data().solicitudId === id, 'already-exists', 'Ya existe una solicitud pendiente para este negocio.');
    if (tipo !== 'anuncio') {
      const category = await tx.get(db.collection('categorias').doc(D.identifier(propuesta.categoria)));
      D.requireThat(category.exists && category.data().activa, 'invalid-argument', 'Selecciona una categoría activa.');
    }
    const anteriorId = data.anteriorId ? D.identifier(data.anteriorId) : '';
    if (anteriorId) {
      const previous = await tx.get(db.collection('solicitudes').doc(anteriorId));
      D.requireThat(previous.exists && previous.data().solicitanteId === auth.uid &&
        ['rechazada', 'retirada'].includes(previous.data().estado) && previous.data().tipo === tipo &&
        (tipo === 'negocio' || previous.data().negocioId === negocioId),
        'failed-precondition', 'El envío anterior no permite esta corrección.');
    }
    const estado = data.borrador === true ? 'borrador' : 'pendiente';
    tx.set(ref, { tipo, negocioId, propuesta, anteriorId, estado, solicitanteId: auth.uid,
      creado: existing.exists ? existing.data().creado : stamp(), actualizado: stamp() });
    if (estado === 'pendiente') tx.set(lock, { solicitudId: id, solicitanteId: auth.uid });
  });
  await logAudit(db, auth.uid, AuditAction.SUBMIT_REQUEST, id, 'request',
    { tipo, negocioId }, AuditResult.SUCCESS);
  return { id };
});

exports.retirarSolicitud = call(async (data, auth) => {
  const ref = db.collection('solicitudes').doc(D.identifier(data.id));
  await db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    D.requireThat(snap.exists && snap.data().solicitanteId === auth.uid, 'permission-denied', 'Solicitud ajena.');
    const request = snap.data();
    D.requireThat(request.estado === 'pendiente', 'failed-precondition', 'La solicitud no está pendiente.');
    tx.update(ref, { estado: 'retirada', actualizado: stamp() });
    tx.delete(db.collection('pendientes').doc(`${request.negocioId}_${request.tipo}`));
  });
  await logAudit(db, auth.uid, AuditAction.WITHDRAW_REQUEST, D.identifier(data.id), 'request', null, AuditResult.SUCCESS);
  return { ok: true };
});

exports.resolverSolicitud = call(async (data, auth) => {
  requireAdmin(auth);
  const id = D.identifier(data.id);
  const ref = db.collection('solicitudes').doc(id);
  await db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    D.requireThat(snap.exists, 'not-found', 'Solicitud inexistente.');
    const request = snap.data();
    const result = D.decision(request, data.aprobar, data.motivo);
    const business = db.collection('negocios').doc(request.negocioId);
    const current = await tx.get(business);
    if (data.aprobar && request.tipo !== 'negocio') {
      D.requireThat(current.exists && current.data().duenoId === request.solicitanteId,
        'failed-precondition', 'El negocio ya no pertenece al solicitante.');
    }
    if (data.aprobar) {
      if (request.tipo === 'anuncio') {
        D.contentData(request.propuesta, 'anuncio');
        D.requireThat(current.data().publicado, 'failed-precondition', 'El negocio no está publicado.');
        tx.set(db.collection('anuncios').doc(id), { ...request.propuesta, publicado: true, creado: stamp() });
      } else {
        const category = await tx.get(db.collection('categorias').doc(request.propuesta.categoria));
        D.requireThat(category.exists && category.data().activa, 'failed-precondition', 'La categoría ya no está activa.');
        tx.set(business, { duenoId: request.solicitanteId, publicado: true, versionId: id, actualizado: stamp() });
        tx.set(db.collection('catalogo').doc(request.negocioId), { ...request.propuesta, publicado: true, actualizado: stamp() });
        tx.set(business.collection('versiones').doc(id), { ...request.propuesta, creado: stamp() });
        tx.set(db.collection('usuarios').doc(request.solicitanteId), { dueno: true }, { merge: true });
      }
    }
    tx.update(ref, { ...result, revisorId: auth.uid, resuelto: stamp(), actualizado: stamp() });
    tx.delete(db.collection('pendientes').doc(`${request.negocioId}_${request.tipo}`));
    tx.set(db.collection('historial').doc(id), { solicitudId: id, solicitanteId: request.solicitanteId,
      revisorId: auth.uid, ...result, creado: stamp() });
    tx.set(db.collection('usuarios').doc(request.solicitanteId).collection('notificaciones').doc(id), {
      titulo: `Solicitud ${result.estado}`, mensaje: result.motivo || 'Tu contenido ya está publicado.',
      solicitudId: id, leida: false, creado: stamp(),
    });
    if (data.aprobar) tx.set(db.collection('novedades').doc(id), {
      titulo: request.propuesta.nombre ?? request.propuesta.titulo,
      mensaje: request.tipo === 'anuncio' ? 'Nuevo anuncio publicado' : 'Novedades en el catálogo', creado: stamp(),
    });
  });
  const resultLog = {
    solicitudId: id,
    aprobada: data.aprobar,
    motivo: data.motivo,
  };
  await logAudit(db, auth.uid, AuditAction.RESOLVE_REQUEST, id, 'request', resultLog, AuditResult.SUCCESS);
  return { ok: true };
});

exports.gestionEditorial = call(async (data, auth) => {
  requireAdmin(auth);
  const id = D.identifier(data.id);
  if (data.tipo === 'categoria') {
    await db.collection('categorias').doc(id).set({ nombre: D.text(data.nombre, 'nombre', 80), activa: data.activa === true });
  } else if (data.tipo === 'boletin') {
    const content = D.contentData(data, 'boletin');
    const batch = db.batch();
    batch.set(db.collection('boletines').doc(id), { ...content, publicado: data.publicado === true, actualizado: stamp() });
    if (data.publicado) batch.set(db.collection('novedades').doc(`boletin_${id}`), {
      titulo: content.titulo, mensaje: 'Nuevo boletín disponible', creado: stamp(),
    });
    await batch.commit();
  } else if (data.tipo === 'negocio') {
    await db.runTransaction(async tx => {
      const ref = db.collection('negocios').doc(id);
      const snap = await tx.get(ref);
      D.requireThat(snap.exists, 'not-found', 'Negocio inexistente.');
      const ads = await tx.get(db.collection('anuncios').where('negocioId', '==', id));
      tx.update(ref, { publicado: data.publicado === true });
      tx.update(db.collection('catalogo').doc(id), { publicado: data.publicado === true });
      if (!data.publicado) for (const ad of ads.docs) tx.update(ad.ref, { publicado: false });
    });
  } else if (data.tipo === 'anuncio') {
    await db.collection('anuncios').doc(id).update({ publicado: false });
  } else throw new D.DomainError('invalid-argument', 'Operación desconocida.');

  const changeLog = { tipo: data.tipo, id };
  if (data.tipo === 'categoria') changeLog.nombre = data.nombre;
  if (data.tipo === 'boletin') changeLog.titulo = data.titulo;
  if (data.tipo === 'negocio') changeLog.publicado = data.publicado;

  const actionType = data.tipo === 'categoria' ? AuditAction.EDITORIAL_CATEGORY :
                     data.tipo === 'boletin' ? AuditAction.EDITORIAL_BULLETIN :
                     data.tipo === 'negocio' ? AuditAction.EDITORIAL_BUSINESS :
                     AuditAction.EDITORIAL_AD;

  await logAudit(db, auth.uid, actionType, id, data.tipo, changeLog, AuditResult.SUCCESS);
  return { ok: true };
});
