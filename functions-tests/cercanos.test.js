// functions-tests/cercanos.test.js
//
// Profesionales cercanos (noviembre 2026, decisión explícita y posterior del
// CEO -- ver el comentario de buscarProfesionalesCercanos en
// functions/index.js para el porqué de cada decisión de privacidad de
// abajo). Contra el Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, sembrarRegistro } = require('./helpers');

// Puntos de referencia muy separados entre sí (bastante más que el radio
// máximo de 50 km) -- cada test usa el suyo propio. Esta colección no se
// limpia entre tests (mismo criterio que el resto de functions-tests, ver
// helpers.js), así que sin esto los profesionales creados por un test se
// colarían en la búsqueda del siguiente si compartieran zona.
const MADRID = { lat: 40.4168, lng: -3.7038 };
const TOKIO = { lat: 35.6762, lng: 139.6503 };
const SIDNEY = { lat: -33.8688, lng: 151.2093 };
const EL_CAIRO = { lat: 30.0444, lng: 31.2357 };
const RIO = { lat: -22.9068, lng: -43.1729 };
const CIUDAD_DEL_CABO = { lat: -33.9249, lng: 18.4241 };
const BUENOS_AIRES = { lat: -34.6037, lng: -58.3816 };
const MOSCU = { lat: 55.7558, lng: 37.6173 };

async function crearProfesionalVisible(uid, { lat, lng, visible = true, nombreComercial, especialidad } = {}) {
  await db.collection('profesionales').doc(uid).set({
    visibleCercano: visible,
    ...(lat != null ? { lat } : {}),
    ...(lng != null ? { lng } : {}),
  }, { merge: true });
  if (nombreComercial || especialidad) {
    await db.collection('profesionalesPublico').doc(uid).set({
      ...(nombreComercial ? { nombreComercial } : {}),
      ...(especialidad ? { especialidad } : {}),
    }, { merge: true });
  }
}

async function marcarComoProfesional(uid) {
  await db.collection('users').doc(uid).set({ esProfesional: true }, { merge: true });
}

test('1. devuelve profesionales visibles ordenados de más a menos cerca', async () => {
  const owner = await crearUsuario();
  const cerca = await crearUsuario(); // ~1 km al norte
  const lejos = await crearUsuario(); // ~5 km al norte
  await crearProfesionalVisible(cerca.uid, { lat: MADRID.lat + 0.009, lng: MADRID.lng, nombreComercial: 'Fontanero Cerca' });
  await crearProfesionalVisible(lejos.uid, { lat: MADRID.lat + 0.045, lng: MADRID.lng, nombreComercial: 'Fontanero Lejos' });

  const { error, result } = await llamar('buscarProfesionalesCercanos', owner.idToken, { lat: MADRID.lat, lng: MADRID.lng });
  assert.equal(error, undefined);
  assert.equal(result.resultados.length, 2);
  assert.equal(result.resultados[0].uid, cerca.uid);
  assert.equal(result.resultados[1].uid, lejos.uid);
  assert.ok(result.resultados[0].distanciaAproxKm < result.resultados[1].distanciaAproxKm);
});

test('2. ignora profesionales con visibleCercano en false', async () => {
  const owner = await crearUsuario();
  const noVisible = await crearUsuario();
  await crearProfesionalVisible(noVisible.uid, { lat: TOKIO.lat, lng: TOKIO.lng, visible: false });

  const { result } = await llamar('buscarProfesionalesCercanos', owner.idToken, { lat: TOKIO.lat, lng: TOKIO.lng });
  assert.equal(result.resultados.length, 0);
});

test('3. ignora profesionales visibles sin lat/lng guardadas', async () => {
  const owner = await crearUsuario();
  const sinUbicacion = await crearUsuario();
  await crearProfesionalVisible(sinUbicacion.uid, { visible: true });

  const { result } = await llamar('buscarProfesionalesCercanos', owner.idToken, { lat: SIDNEY.lat, lng: SIDNEY.lng });
  assert.equal(result.resultados.length, 0);
});

test('4. respeta el radio máximo de 50 km', async () => {
  const owner = await crearUsuario();
  const muyLejos = await crearUsuario(); // ~111 km al norte (1 grado de latitud)
  await crearProfesionalVisible(muyLejos.uid, { lat: EL_CAIRO.lat + 1, lng: EL_CAIRO.lng });

  const { result } = await llamar('buscarProfesionalesCercanos', owner.idToken, { lat: EL_CAIRO.lat, lng: EL_CAIRO.lng });
  assert.equal(result.resultados.length, 0);
});

test('5. un profesional no se encuentra a sí mismo si él mismo busca', async () => {
  const propio = await crearUsuario();
  await crearProfesionalVisible(propio.uid, { lat: RIO.lat, lng: RIO.lng });

  const { result } = await llamar('buscarProfesionalesCercanos', propio.idToken, { lat: RIO.lat, lng: RIO.lng });
  assert.equal(result.resultados.length, 0);
});

test('6. requiere autenticación', async () => {
  const { error } = await llamar('buscarProfesionalesCercanos', null, { lat: MADRID.lat, lng: MADRID.lng });
  assert.equal(error?.status, 'UNAUTHENTICATED');
});

test('7. rechaza coordenadas inválidas', async () => {
  const owner = await crearUsuario();
  const { error: e1 } = await llamar('buscarProfesionalesCercanos', owner.idToken, { lat: 999, lng: MADRID.lng });
  assert.equal(e1?.status, 'INVALID_ARGUMENT');
  const { error: e2 } = await llamar('buscarProfesionalesCercanos', owner.idToken, { lat: MADRID.lat, lng: 'no es un número' });
  assert.equal(e2?.status, 'INVALID_ARGUMENT');
});

test('8. la respuesta nunca incluye coordenadas, solo distancia aproximada', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await crearProfesionalVisible(pro.uid, { lat: CIUDAD_DEL_CABO.lat + 0.01, lng: CIUDAD_DEL_CABO.lng, nombreComercial: 'Electricista' });

  const { result } = await llamar('buscarProfesionalesCercanos', owner.idToken, { lat: CIUDAD_DEL_CABO.lat, lng: CIUDAD_DEL_CABO.lng });
  assert.equal(result.resultados.length, 1);
  const r = result.resultados[0];
  assert.equal('lat' in r, false);
  assert.equal('lng' in r, false);
  assert.equal(typeof r.distanciaAproxKm, 'number');
});

test('9. la distancia nunca es más precisa que el suelo de 2 km (defensa contra triangulación)', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  // A unos 30 metros -- si no hubiera suelo mínimo, esto se vería como
  // "0.0 km" o similar, precisión suficiente para triangular una vivienda.
  await crearProfesionalVisible(pro.uid, { lat: BUENOS_AIRES.lat + 0.0003, lng: BUENOS_AIRES.lng });

  const { result } = await llamar('buscarProfesionalesCercanos', owner.idToken, { lat: BUENOS_AIRES.lat, lng: BUENOS_AIRES.lng });
  assert.equal(result.resultados.length, 1);
  assert.equal(result.resultados[0].distanciaAproxKm, 2);
});

test('10. el desplazamiento de privacidad es fijo, no aleatorio por consulta (la media de muchas consultas no revela la posición real)', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await crearProfesionalVisible(pro.uid, { lat: MOSCU.lat + 0.03, lng: MOSCU.lng }); // ~3.3 km

  const distancias = [];
  for (let i = 0; i < 3; i++) {
    const { result } = await llamar('buscarProfesionalesCercanos', owner.idToken, { lat: MOSCU.lat, lng: MOSCU.lng });
    distancias.push(result.resultados[0].distanciaAproxKm);
  }
  assert.equal(distancias[0], distancias[1]);
  assert.equal(distancias[1], distancias[2]);
});

test('11. límite diario de búsquedas: la 21ª del día se rechaza', async () => {
  const owner = await crearUsuario();
  const hoy = new Date().toISOString().slice(0, 10);
  await db.collection('intentosCodigo').doc(`${owner.uid}_buscarProfesionalesCercanos_${hoy}`)
    .set({ uid: owner.uid, accion: 'buscarProfesionalesCercanos', fecha: hoy, intentos: 20 });

  const { error } = await llamar('buscarProfesionalesCercanos', owner.idToken, { lat: MADRID.lat, lng: MADRID.lng });
  assert.equal(error?.status, 'RESOURCE_EXHAUSTED');
});

test('12. invitarProfesional con profesionalUidDirecto invita sin email ni teléfono', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });

  const { error, result } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, profesionalUidDirecto: pro.uid,
  });
  assert.equal(error, undefined);
  assert.equal(result.tipo, 'directa');

  const invSnap = await db.collection('invitaciones').doc(result.invitacionId).get();
  assert.equal(invSnap.data().profesionalUid, pro.uid);
});

test('13. invitarProfesional rechaza un profesionalUidDirecto que no es una cuenta profesional', async () => {
  const owner = await crearUsuario();
  const noProfesional = await crearUsuario(); // nunca marcado esProfesional
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });

  const { error } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, profesionalUidDirecto: noProfesional.uid,
  });
  assert.equal(error?.status, 'NOT_FOUND');
});

test('14. invitarProfesional rechaza invitarse a uno mismo vía profesionalUidDirecto', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });

  const { error } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, profesionalUidDirecto: owner.uid,
  });
  assert.equal(error?.status, 'INVALID_ARGUMENT');
});
