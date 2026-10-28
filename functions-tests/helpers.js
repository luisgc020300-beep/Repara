// functions-tests/helpers.js
//
// Helpers compartidos por los tests de integración contra el Emulator
// Suite. Las Cloud Functions callable se llaman por HTTP directo (el
// protocolo "callable" que documenta Firebase:
// https://firebase.google.com/docs/functions/callable-reference) en vez de
// con el SDK cliente -- así cada "usuario" de prueba es independiente
// (su propio idToken) y Promise.all([...]) lanza peticiones realmente
// concurrentes contra el mismo emulador, sin que una única app/sesión del
// SDK cliente sea un cuello de botella artificial.
const admin = require('firebase-admin');

const PROJECT_ID = 'repara-test';
const REGION = 'europe-west1';
// Overridable por variable de entorno (auditoría R4, octubre 2026): un
// proceso del emulador que no termina limpio deja el puerto por defecto
// ocupado para el siguiente intento -- sin esto, no hay forma de reintentar
// en un entorno limpio sin esperar a que ese proceso suelte el puerto.
const FIRESTORE_HOST = process.env.REPARA_TEST_FIRESTORE_HOST || '127.0.0.1:8080';
const AUTH_HOST = process.env.REPARA_TEST_AUTH_HOST || '127.0.0.1:9099';
const FUNCTIONS_HOST = process.env.REPARA_TEST_FUNCTIONS_HOST || '127.0.0.1:5001';
// Solo lo necesitan los tests de eliminarCuenta que suben/comprueban
// archivos reales en Storage (auditoría R11, octubre 2026) -- el resto de
// tests nunca tocan Storage y no necesitan esta variable.
const STORAGE_HOST = process.env.REPARA_TEST_STORAGE_HOST || '';

process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;
if (STORAGE_HOST) process.env.STORAGE_EMULATOR_HOST = `http://${STORAGE_HOST}`;

// Admin SDK contra los emuladores -- salta firestore.rules por completo, lo
// que es exactamente lo que hace falta para sembrar fixtures (casas/
// elementos/registros) sin tener que pasar por las reglas de escritura.
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

let contador = 0;

// Crea un usuario real en el emulador de Auth y devuelve su uid + idToken.
// El uid lo asigna el propio emulador (no es controlable) -- los fixtures
// de Firestore se siembran DESPUÉS, usando el uid que devuelve esto.
async function crearUsuario() {
  contador += 1;
  const email = `user${Date.now()}_${contador}@test.local`;
  const res = await fetch(`http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password: 'Test1234!', returnSecureToken: true }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`crearUsuario: ${JSON.stringify(data)}`);
  // email incluido (auditoría R7, octubre 2026) -- invitarProfesional
  // necesita el email real del profesional invitado, no solo su uid.
  return { uid: data.localId, idToken: data.idToken, email };
}

// Llama a una Cloud Function callable por HTTP directo. Devuelve
// { status, result, error } -- nunca lanza por un error de la función
// (failed-precondition, permission-denied...), para que el propio test
// decida qué hacer con cada código; sí lanza si la petición de red en sí
// falla (emulador caído, etc).
async function llamar(nombreFuncion, idToken, payload) {
  const res = await fetch(`http://${FUNCTIONS_HOST}/${PROJECT_ID}/${REGION}/${nombreFuncion}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(idToken ? { authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data: payload }),
  });
  const texto = await res.text();
  let body;
  try {
    body = JSON.parse(texto);
  } catch (e) {
    throw new Error(`llamar(${nombreFuncion}): respuesta no JSON (status ${res.status}): ${texto.slice(0, 500)}`);
  }
  return { status: res.status, result: body.result, error: body.error };
}

function idUnico(prefijo) {
  contador += 1;
  return `${prefijo}-${Date.now()}-${contador}`;
}

// Siembra una casa + elemento + registro mínimos, con el owner ya como
// miembro -- lo que casi todos los tests necesitan como punto de partida.
async function sembrarRegistro({ ownerUid, presupuesto = null, estado = 'nuevo', profesionalUid = null }) {
  const casaId = idUnico('casa');
  const elementoId = idUnico('elemento');
  const registroId = idUnico('registro');

  await db.collection('casas').doc(casaId).set({ nombre: 'Casa de prueba', ownerUid, members: [ownerUid] });
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).set({ nombre: 'Elemento de prueba' });
  await db
    .collection('casas').doc(casaId)
    .collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId)
    .set({
      titulo: 'Registro de prueba',
      estado,
      ...(presupuesto != null ? { presupuesto } : {}),
      ...(profesionalUid ? { profesionalUid } : {}),
    });

  return { casaId, elementoId, registroId };
}

async function leerRegistro(casaId, elementoId, registroId) {
  const snap = await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).collection('registros').doc(registroId).get();
  return snap.data();
}

async function leerPagos(casaId, elementoId, registroId) {
  const snap = await db
    .collection('casas').doc(casaId)
    .collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId)
    .collection('pagos').get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

// Crea una casa directamente (Admin SDK, salta firestore.rules) con el
// propietario y los miembros exactos que pida el test -- usado por los
// tests de eliminarCuenta (auditoría R10, octubre 2026), que necesitan
// controlar member.length con precisión, a diferencia de sembrarRegistro
// (que siempre crea exactamente un miembro: el propietario).
async function crearCasa({ ownerUid, members, nombre = 'Casa de prueba' }) {
  const casaId = idUnico('casa');
  await db.collection('casas').doc(casaId).set({ nombre, ownerUid, members });
  return casaId;
}

// users/{uid}.casaIds es lo que eliminarCuenta usa para saber qué casas
// recorrer -- sembrarRegistro/crearCasa no tocan la colección users, así
// que los tests de eliminarCuenta tienen que fijarlo a mano.
async function fijarCasaIds(uid, casaIds) {
  await db.collection('users').doc(uid).set({ casaIds }, { merge: true });
}

// Sube un archivo real al emulador de Storage bajo la misma ruta que usa
// eliminarCuenta (casas/{casaId}/...) -- para que el test de R11 compruebe
// un borrado real de Storage, no solo que la llamada no lanzó error.
// Requiere REPARA_TEST_STORAGE_HOST (el emulador de Storage debe estar
// arrancado en esa sesión).
// Mismo nombre de bucket por defecto que usa el propio emulador de
// Functions para getStorage().bucket() sin argumento (<projectId>.appspot.com
// -- lo confirma el log del emulador). Aquí hace falta pasarlo explícito
// porque este admin.initializeApp() (fuera del emulador de Functions) no
// tiene ningún FIREBASE_CONFIG del que adivinarlo.
const BUCKET_POR_DEFECTO = `${PROJECT_ID}.appspot.com`;

async function subirArchivoStorage(ruta, contenido = 'contenido de prueba') {
  if (!STORAGE_HOST) throw new Error('subirArchivoStorage: falta REPARA_TEST_STORAGE_HOST');
  await admin.storage().bucket(BUCKET_POR_DEFECTO).file(ruta).save(Buffer.from(contenido), { contentType: 'text/plain' });
}

async function existeArchivoStorage(ruta) {
  if (!STORAGE_HOST) throw new Error('existeArchivoStorage: falta REPARA_TEST_STORAGE_HOST');
  const [existe] = await admin.storage().bucket(BUCKET_POR_DEFECTO).file(ruta).exists();
  return existe;
}

module.exports = {
  admin,
  db,
  PROJECT_ID,
  REGION,
  crearUsuario,
  llamar,
  idUnico,
  sembrarRegistro,
  leerRegistro,
  leerPagos,
  crearCasa,
  fijarCasaIds,
  subirArchivoStorage,
  existeArchivoStorage,
};
