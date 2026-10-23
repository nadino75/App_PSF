'use strict';
// This utility intentionally refuses to write to a real Firebase project.
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('Se requieren los emuladores de Firestore y Authentication.');
}
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp({ projectId: 'demo-vitrina-local' });
async function seed() {
  const auth = getAuth(), db = getFirestore();
  for (const [uid, email, nombre, admin] of [
    ['demo-owner','dueno@vitrina.local','Emprendedor local',false],
    ['demo-admin','admin@vitrina.local','Administración',true],
    ['otro','otro@vitrina.local','Otra cuenta',false],
  ]) {
    try { await auth.createUser({uid,email,password:'Demo123!',displayName:nombre}); }
    catch (e) { if (!['auth/uid-already-exists', 'auth/email-already-exists'].includes(e.code)) throw e; }
    await auth.setCustomUserClaims(uid, {admin});
    await db.collection('usuarios').doc(uid).set({nombre}, {merge:true});
  }
  for (const [id,nombre] of [['gastronomia','Gastronomía'],['artesania','Artesanía'],['servicios','Servicios']]) {
    await db.collection('categorias').doc(id).set({nombre,activa:true});
  }
  if (!(await db.doc('catalogo/cafe-demo').get()).exists) {
    const content = {nombre:'Café de la esquina',descripcion:'Café de altura y pan recién horneado. Un espacio para conversar y descubrir sabores locales. Datos ficticios de demostración.',categoria:'gastronomia',direccion:'Av. del Prado 120',zona:'Centro',telefono:'+59170000001',horarios:'Lunes a sábado · 08:00 a 20:00',imagenes:[],publicado:true};
    await db.doc('catalogo/cafe-demo').set(content);
    await db.doc('negocios/cafe-demo').set({duenoId:'demo-owner',publicado:true,versionId:'inicial'});
    await db.doc('negocios/cafe-demo/versiones/inicial').set(content);
    await db.doc('boletines/bienvenida-demo').set({titulo:'Tu barrio tiene mucho por descubrir',descripcion:'Vitrina Local conecta a nuestra comunidad con sus negocios. Explora el catálogo, guarda tus favoritos y encuentra nuevas propuestas cerca de ti. Estos son datos ficticios para demostrar el proyecto.',publicado:true});
  }
  console.log('Emuladores preparados. Cuentas: dueno@vitrina.local, admin@vitrina.local, otro@vitrina.local. Contraseña: Demo123!');
}
seed().catch(e => { console.error(e); process.exitCode=1; });
