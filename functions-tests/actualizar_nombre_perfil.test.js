// functions-tests/actualizar_nombre_perfil.test.js
//
// actualizarNombrePerfil (rediseño de registro/perfil de Hogar, noviembre
// 2026): cambiar tu nombre debe quedar reflejado tanto en users/{uid} como
// en memberProfiles.{uid} de TODAS las casas a las que perteneces de
// verdad -- no solo la activa, y nunca desincronizado. La pertenencia se
// decide SIEMPRE por casas/{cid}.members (solo lo escriben las Cloud
// Functions), nunca por users/{uid}.casaIds (auditoría de seguridad,
// noviembre 2026: ese campo es escribible por el propio cliente, así que
// confiar en él para decidir qué casas tocar sería un IDOR -- test 2 lo
// comprueba explícitamente). Contra el Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, crearCasa, fijarCasaIds } = require('./helpers');

test('1. actualiza users/{uid}.displayName y propaga el nombre a todas las casas donde es miembro real', async () => {
  const owner = await crearUsuario();
  const casaA = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });
  const casaB = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });

  const { error } = await llamar('actualizarNombrePerfil', owner.idToken, { nombre: 'Ana García' });
  assert.equal(error, undefined);

  const userSnap = await db.collection('users').doc(owner.uid).get();
  assert.equal(userSnap.data().displayName, 'Ana García');

  const casaASnap = await db.collection('casas').doc(casaA).get();
  const casaBSnap = await db.collection('casas').doc(casaB).get();
  assert.equal(casaASnap.data().memberProfiles[owner.uid].displayName, 'Ana García');
  assert.equal(casaBSnap.data().memberProfiles[owner.uid].displayName, 'Ana García');
});

test('2. (IDOR) un casaId ajeno colado a mano en users/{uid}.casaIds no recibe ninguna escritura', async () => {
  const owner = await crearUsuario();
  const otro = await crearUsuario();
  const casaAjena = await crearCasa({ ownerUid: otro.uid, members: [otro.uid] });
  // Simula lo que un cliente malicioso podría escribir directamente --
  // users/{uid} es de escritura libre para su propio dueño.
  await fijarCasaIds(owner.uid, [casaAjena]);

  const { error } = await llamar('actualizarNombrePerfil', owner.idToken, { nombre: 'Ana García' });
  assert.equal(error, undefined);

  const casaAjenaSnap = await db.collection('casas').doc(casaAjena).get();
  assert.equal(casaAjenaSnap.data().memberProfiles?.[owner.uid], undefined);
});

test('3. un nombre vacío o solo espacios se rechaza (invalid-argument)', async () => {
  const owner = await crearUsuario();
  const { error } = await llamar('actualizarNombrePerfil', owner.idToken, { nombre: '   ' });
  assert.equal(error?.status, 'INVALID_ARGUMENT');
});

test('4. un nombre de más de 60 caracteres se rechaza (invalid-argument)', async () => {
  const owner = await crearUsuario();
  const { error } = await llamar('actualizarNombrePerfil', owner.idToken, { nombre: 'x'.repeat(61) });
  assert.equal(error?.status, 'INVALID_ARGUMENT');
});

test('5. sin sesión (sin idToken), se rechaza como no autenticado', async () => {
  const { error } = await llamar('actualizarNombrePerfil', null, { nombre: 'Ana García' });
  assert.equal(error?.status, 'UNAUTHENTICATED');
});
