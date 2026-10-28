'use strict';
// Uso: node seed-prod.js <correo-del-admin>
// Requiere credenciales: GOOGLE_APPLICATION_CREDENTIALS=<clave.json> o `gcloud auth application-default login`.
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID = 'app-movil-psf';
const adminEmail = process.argv[2];
if (!adminEmail) {
  console.error('Falta el correo. Uso: node seed-prod.js correo@ejemplo.com');
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });

async function main() {
  const db = getFirestore();
  const auth = getAuth();

  const categorias = [
    ['gastronomia', 'Gastronomía'],
    ['artesania', 'Artesanía'],
    ['servicios', 'Servicios'],
    ['comercio', 'Comercio'],
    ['salud', 'Salud y bienestar'],
    ['educacion', 'Educación'],
  ];
  for (const [id, nombre] of categorias) {
    await db.collection('categorias').doc(id).set({ nombre, activa: true }, { merge: true });
  }
  console.log(`Categorías creadas: ${categorias.length}`);

  const user = await auth.getUserByEmail(adminEmail);
  await auth.setCustomUserClaims(user.uid, { ...(user.customClaims || {}), admin: true });
  console.log(`Rol admin asignado a ${adminEmail} (uid ${user.uid}). Debe cerrar sesión y volver a ingresar.`);
}

main().catch((e) => {
  console.error(e.message);
  process.exitCode = 1;
});
