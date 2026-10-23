'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs } = require('firebase/firestore');
const { initializeApp: adminApp } = require('firebase-admin/app');
const { getAuth: adminAuth } = require('firebase-admin/auth');
const { getFirestore: adminDb } = require('firebase-admin/firestore');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInWithCustomToken } = require('firebase/auth');
const { ref, uploadBytes, getBytes } = require('firebase/storage');
const projectId = 'demo-vitrina-local';
let env, db, accounts = {}, apps = [];
const proposal = {nombre: 'Negocio de prueba', categoria: 'prueba', descripcion: 'Descripción local', zona: 'Centro', direccion: 'Calle 1', telefono: '+59170000000', horarios: '09:00 a 18:00', imagenes: []};

before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Solo se permite ejecutar contra emuladores.');
  env = await initializeTestEnvironment({projectId,
    firestore: {rules: fs.readFileSync(path.join(__dirname,'../../firestore.rules'),'utf8')},
    storage: {host:'127.0.0.1',port:9199,rules:fs.readFileSync(path.join(__dirname,'../../storage.rules'),'utf8')}
  });
  adminApp({projectId}); db = adminDb();
  for (const uid of ['test-owner', 'test-other', 'test-admin', 'test-admin2']) {
    try { await adminAuth().createUser({uid}); } catch(e) { if (e.code !== 'auth/uid-already-exists') throw e; }
    await adminAuth().setCustomUserClaims(uid, {admin: uid.startsWith('test-admin')});
    const app = initializeApp({apiKey:'demo-key', projectId},uid); apps.push(app);
    const auth = getAuth(app); connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});
    const credential = await signInWithCustomToken(auth, await adminAuth().createCustomToken(uid));
    accounts[uid] = await credential.user.getIdToken();
  }
  await db.collection('categorias').doc('prueba').set({nombre:'Prueba',activa:true});
});
after(async () => {
  // Only records created by this suite in the explicitly required demo emulator.
  if (db) {
    for (const name of ['catalogo','negocios','solicitudes','pendientes','historial','novedades','usuarios','anuncios','boletines']) {
      const docs = await db.collection(name).get();
      for (const item of docs.docs.filter(x=>x.id.startsWith('test-'))) await db.recursiveDelete(item.ref);
    }
    await db.doc('categorias/prueba').delete();
  }
  await Promise.all(apps.map(deleteApp)); await env?.cleanup();
});
async function invoke(name, uid, data) {
  const res = await fetch(`http://127.0.0.1:5001/${projectId}/us-central1/${name}`, {
    method:'POST', headers:{'Content-Type':'application/json', Authorization:`Bearer ${accounts[uid]}`}, body:JSON.stringify({data}), signal:AbortSignal.timeout(60000),
  });
  const body = await res.json();
  if (body.error) throw Object.assign(new Error(body.error.message), {code:body.error.status});
  return body.result;
}
const userDb = uid => env.authenticatedContext(uid, {firebase:{sign_in_provider:'password'}}).firestore();

test('public reads are filtered; clients cannot self-promote or publish directly', async () => {
  await db.collection('catalogo').doc('test-public').set({...proposal,publicado:true});
  await db.collection('catalogo').doc('test-hidden').set({...proposal,publicado:false});
  const visitor = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(visitor,'catalogo/test-public')));
  await assertFails(getDoc(doc(visitor,'catalogo/test-hidden')));
  await assertFails(getDocs(collection(visitor,'catalogo')));
  await assertSucceeds(getDocs(query(collection(visitor,'catalogo'),where('publicado','==',true))));
  const user = userDb('test-other');
  await assertFails(setDoc(doc(user,'usuarios/test-other'), {nombre:'Test', admin:true}));
  await assertSucceeds(setDoc(doc(user,'usuarios/test-other'), {nombre:'Test'}));
  await assertFails(updateDoc(doc(user,'usuarios/test-other'), {dueno:true}));
  await assertFails(setDoc(doc(user,'catalogo/injection'), {...proposal,publicado:true}));
  await assertFails(setDoc(doc(user,'solicitudes/injection'), {estado:'aprobada'}));
});

test('approval, concurrent decisions, privacy, version preservation, withdrawal and correction', async () => {
  const id = `test-${Date.now()}`;
  const data = {id,tipo:'negocio',propuesta:proposal};
  await invoke('enviarSolicitud','test-owner',data);
  await invoke('enviarSolicitud','test-owner',data); // lost response retry
  assert.equal((await db.collection('catalogo').doc(id).get()).exists,false);
  await assertFails(getDoc(doc(userDb('test-other'),`solicitudes/${id}`)));
  await assert.rejects(invoke('resolverSolicitud','test-owner',{id,aprobar:true}), {code:'PERMISSION_DENIED'});
  const result = await Promise.allSettled([
    invoke('resolverSolicitud','test-admin',{id,aprobar:true}),
    invoke('resolverSolicitud','test-admin2',{id,aprobar:true}),
  ]);
  assert.equal(result.filter(x=>x.status==='fulfilled').length,1);
  assert.equal((await db.collection('catalogo').doc(id).get()).data().nombre,proposal.nombre);
  assert.equal((await db.doc(`usuarios/test-owner/notificaciones/${id}`).get()).exists,true);
  assert.equal((await db.doc(`historial/${id}`).get()).exists,true);
  assert.equal((await db.doc('usuarios/test-owner').get()).data().dueno,true);
  await assert.rejects(invoke('enviarSolicitud','test-other',{id:`${id}-attack`,tipo:'cambio',negocioId:id,propuesta:proposal}),{code:'PERMISSION_DENIED'});
  const change = {id:`${id}-change`,tipo:'cambio',negocioId:id,propuesta:{...proposal,nombre:'Nuevo nombre'}};
  await invoke('enviarSolicitud','test-owner',change);
  assert.equal((await db.doc(`catalogo/${id}`).get()).data().nombre,proposal.nombre);
  await assert.rejects(invoke('enviarSolicitud','test-owner',{...change,id:`${id}-duplicate`}),{code:'ALREADY_EXISTS'});
  await assert.rejects(invoke('resolverSolicitud','test-admin',{id:change.id,aprobar:false,motivo:' '}),{code:'INVALID_ARGUMENT'});
  await invoke('resolverSolicitud','test-admin',{id:change.id,aprobar:false,motivo:'Corrige el nombre'});
  await invoke('enviarSolicitud','test-owner',{...change,id:`${id}-retry`,anteriorId:change.id});
  await invoke('retirarSolicitud','test-owner',{id:`${id}-retry`});
  await assert.rejects(invoke('resolverSolicitud','test-admin',{id:`${id}-retry`,aprobar:true}),{code:'FAILED_PRECONDITION'});
  await invoke('enviarSolicitud','test-owner',{...change,id:`${id}-final`,anteriorId:`${id}-retry`});
  await invoke('resolverSolicitud','test-admin',{id:`${id}-final`,aprobar:true});
  assert.equal((await db.doc(`catalogo/${id}`).get()).data().nombre,'Nuevo nombre');
  assert.equal((await db.doc(`negocios/${id}/versiones/${id}`).get()).data().nombre,proposal.nombre);
  await assertFails(updateDoc(doc(userDb('test-other'),`usuarios/test-owner/notificaciones/${id}`),{leida:true}));
  await assertFails(updateDoc(doc(userDb('test-owner'),`usuarios/test-owner/notificaciones/${id}`),{mensaje:'Alterado'}));
  await assertSucceeds(updateDoc(doc(userDb('test-owner'),`usuarios/test-owner/notificaciones/${id}`),{leida:true}));
});

test('advertisements and editorial publication respect ownership and unpublishing', async () => {
  const id = `test-ad-business-${Date.now()}`;
  await invoke('enviarSolicitud','test-owner',{id,tipo:'negocio',propuesta:proposal});
  await invoke('resolverSolicitud','test-admin',{id,aprobar:true});
  const ad = {id:`${id}-ad`,tipo:'anuncio',negocioId:id,propuesta:{titulo:'Oferta local',descripcion:'Detalle de la oferta',negocioId:id,vence:new Date(Date.now()+86400000).toISOString()}};
  await assert.rejects(invoke('enviarSolicitud','test-other',ad),{code:'PERMISSION_DENIED'});
  await invoke('enviarSolicitud','test-owner',ad);
  await invoke('resolverSolicitud','test-admin',{id:ad.id,aprobar:true});
  assert.equal((await db.doc(`anuncios/${ad.id}`).get()).data().publicado,true);
  await invoke('gestionEditorial','test-admin',{id,tipo:'negocio',publicado:false});
  assert.equal((await db.doc(`anuncios/${ad.id}`).get()).data().publicado,false);
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),`catalogo/${id}`)));
  await assert.rejects(invoke('gestionEditorial','test-owner',{id:'test-boletin',tipo:'boletin',titulo:'Test',descripcion:'Texto',publicado:true}),{code:'PERMISSION_DENIED'});
  await invoke('gestionEditorial','test-admin',{id:'test-boletin',tipo:'boletin',titulo:'Test',descripcion:'Texto',publicado:true});
  assert.equal((await db.doc('novedades/boletin_test-boletin').get()).exists,true);
  await db.doc('novedades/boletin_test-boletin').delete();
});

test('storage enforces owner, media type and immutable uploads', async () => {
  const storage = env.authenticatedContext('test-owner',{firebase:{sign_in_provider:'password'}}).storage();
  const imagePath = `usuarios/test-owner/test-${Date.now()}`;
  const image = ref(storage,imagePath);
  await assertSucceeds(uploadBytes(image,new Uint8Array([137,80,78,71]),{contentType:'image/png'}));
  await assertFails(uploadBytes(image,new Uint8Array([137,80]),{contentType:'image/png'}));
  await assertFails(uploadBytes(ref(storage,'usuarios/test-other/no'),new Uint8Array([1]),{contentType:'image/png'}));
  await assertFails(uploadBytes(ref(storage,`${imagePath}-text`),new Uint8Array([1]),{contentType:'text/plain'}));
  await assertFails(uploadBytes(ref(storage,`${imagePath}-large`),new Uint8Array(5*1024*1024),{contentType:'image/png'}));
  const other = env.authenticatedContext('test-other',{firebase:{sign_in_provider:'password'}}).storage();
  await assertFails(getBytes(ref(other,imagePath)));
});
