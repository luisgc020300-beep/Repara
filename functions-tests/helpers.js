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
const FIRESTORE_HOST = '127.0.0.1:8080';
const AUTH_HOST = '127.0.0.1:9099';
const FUNCTIONS_HOST = '127.0.0.1:5001';

process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

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
  return { uid: data.localId, idToken: data.idToken };
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

module.exports = { db, PROJECT_ID, REGION, crearUsuario, llamar, idUnico, sembrarRegistro, leerRegistro, leerPagos };
