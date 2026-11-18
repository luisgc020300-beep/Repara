// functions-tests/sincronizar_claims_seguridad.test.js
//
// Auditoría de seguridad P0 (noviembre 2026): sincronizarClaimsUid y
// cambiarCasaActiva comprobaban la pertenencia a una casa leyendo
// users/{uid}.casaIds -- un campo que, antes de esta corrección,
// firestore.rules dejaba escribir libremente al propio dueño. Como
// storage.rules usa el custom claim "casaIds" como ÚNICA fuente de verdad
// de membresía (no puede leer Firestore por la diferencia de región, ver
// storage.rules), un cliente podía escribirse a mano el id de una casa
// ajena ahí y, llamando a sincronizarClaims, conseguir acceso real a los
// documentos/fotos de esa casa en Storage.
//
// Estos tests reproducen el escenario con dos usuarios (OWNER_A, OWNER_B) y
// dos viviendas de prueba (casaA, casaB), escribiendo el campo envenenado
// directamente con Admin SDK -- exactamente lo que firestore-tests/
// rules.test.js demuestra que un cliente real ya NO puede hacer tras la
// corrección de las reglas, pero que esta prueba verifica en una segunda
// capa (defensa en profundidad): aunque ese dato envenenado existiera
// (p.ej. un documento antiguo, o si las reglas se relajaran por error en el
// futuro), la propia función ya no se fía de él. Contra el Emulator Suite
// real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { admin, db, crearUsuario, llamar, crearCasa, fijarCasaIds } = require('./helpers');

test('1. (legítimo) un miembro real de su casa obtiene casaIds correcto al sincronizar', async () => {
  const owner = await crearUsuario();
  const casaPropia = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });

  const { error } = await llamar('sincronizarClaims', owner.idToken, {});
  assert.equal(error, undefined);

  const user = await admin.auth().getUser(owner.uid);
  assert.deepEqual(user.customClaims?.casaIds, [casaPropia]);
});

test('2. (IDOR) un casaId ajeno escrito a mano en users/{uid}.casaIds no llega al custom claim', async () => {
  const ownerA = await crearUsuario();
  const ownerB = await crearUsuario();
  await crearCasa({ ownerUid: ownerA.uid, members: [ownerA.uid] });
  const casaAjena = await crearCasa({ ownerUid: ownerB.uid, members: [ownerB.uid] });

  // Simula exactamente lo que un cliente malicioso intentaría escribir --
  // Admin SDK salta las reglas a propósito, para probar que la FUNCIÓN (no
  // solo la regla) resiste un dato ya envenenado.
  await db.collection('users').doc(ownerA.uid).set({ casaIds: [casaAjena] }, { merge: true });

  const { error } = await llamar('sincronizarClaims', ownerA.idToken, {});
  assert.equal(error, undefined);

  const user = await admin.auth().getUser(ownerA.uid);
  assert.equal(user.customClaims?.casaIds?.includes(casaAjena), false);
});

test('3. (legítimo) un profesional realmente asignado obtiene registrosProId correcto', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const casaId = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });
  const elementoId = 'elemento-1';
  const registroId = 'registro-1';
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).set({ profesionalUid: pro.uid, titulo: 'Avería' });

  const { error } = await llamar('sincronizarClaims', pro.idToken, {});
  assert.equal(error, undefined);

  const user = await admin.auth().getUser(pro.uid);
  assert.deepEqual(user.customClaims?.registrosProId, [registroId]);
});

test('4. (IDOR) un registroId ajeno colado en users/{uid}.registrosProRefs no llega al custom claim', async () => {
  const ownerB = await crearUsuario();
  const proAjeno = await crearUsuario();
  const casaB = await crearCasa({ ownerUid: ownerB.uid, members: [ownerB.uid] });
  const registroAjenoId = 'registro-ajeno';
  await db.collection('casas').doc(casaB).collection('elementos').doc('elemento-ajeno')
    .collection('registros').doc(registroAjenoId).set({ profesionalUid: ownerB.uid, titulo: 'No es de proAjeno' });

  await db.collection('users').doc(proAjeno.uid).set({
    registrosProRefs: [{ casaId: casaB, elementoId: 'elemento-ajeno', registroId: registroAjenoId }],
  }, { merge: true });

  const { error } = await llamar('sincronizarClaims', proAjeno.idToken, {});
  assert.equal(error, undefined);

  const user = await admin.auth().getUser(proAjeno.uid);
  assert.equal((user.customClaims?.registrosProId || []).includes(registroAjenoId), false);
});

test('5. (legítimo) cambiarCasaActiva funciona para una casa a la que el usuario pertenece de verdad', async () => {
  const owner = await crearUsuario();
  const casaId = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });
  // En producción, createCasa/joinCasa ya crean users/{uid} (set con merge)
  // antes de que tenga sentido llamar a cambiarCasaActiva (elegir entre
  // varias casas) -- crearCasa() aquí es un fixture más ligero que no
  // replica ese efecto, así que se deja igual de explícito.
  await fijarCasaIds(owner.uid, [casaId]);

  const { error } = await llamar('cambiarCasaActiva', owner.idToken, { casaId });
  assert.equal(error, undefined);

  const userSnap = await db.collection('users').doc(owner.uid).get();
  assert.equal(userSnap.data().activeCasaId, casaId);
});

test('6. (IDOR) cambiarCasaActiva rechaza una casa ajena aunque users/{uid}.casaIds diga lo contrario', async () => {
  const ownerA = await crearUsuario();
  const ownerB = await crearUsuario();
  const casaAjena = await crearCasa({ ownerUid: ownerB.uid, members: [ownerB.uid] });
  await db.collection('users').doc(ownerA.uid).set({ casaIds: [casaAjena] }, { merge: true });

  const { error } = await llamar('cambiarCasaActiva', ownerA.idToken, { casaId: casaAjena });
  assert.equal(error?.status, 'PERMISSION_DENIED');

  const userSnap = await db.collection('users').doc(ownerA.uid).get();
  assert.notEqual(userSnap.data().activeCasaId, casaAjena);
});

test('7. cambiarCasaActiva rechaza una casa que no existe', async () => {
  const owner = await crearUsuario();
  const { error } = await llamar('cambiarCasaActiva', owner.idToken, { casaId: 'no-existe' });
  assert.equal(error?.status, 'PERMISSION_DENIED');
});
