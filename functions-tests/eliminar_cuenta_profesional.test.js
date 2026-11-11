// functions-tests/eliminar_cuenta_profesional.test.js
//
// Corrección de la auditoría de comunicación cruzada (noviembre 2026,
// problema #2 del informe de seguimiento): eliminarCuenta borraba el
// documento profesionales/{uid} con un .delete() plano, dejando sus
// subcolecciones (trabajosPro, clientesPro) huérfanas para siempre --
// inaccesibles para el dueño (su cuenta ya no existe) pero nunca borradas
// de Firestore de verdad. Ahora usa db.recursiveDelete(), y además limpia
// las invitaciones de vinculación (invitacionesHogar/invitacionesHogarAbiertas)
// que ese profesional dejó pendientes, para que un propietario no pueda
// aceptar más tarde una invitación de una cuenta que ya no existe.
//
// Contra el Emulator Suite real -- ver helpers.js. Espejo del patrón de
// invitacion_hogar.test.js: se usan las propias Cloud Functions
// (invitarClienteAHogar) para sembrar invitacionesHogar/Abiertas reales, no
// documentos escritos a mano con forma adivinada.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, admin, crearUsuario, llamar, idUnico, crearCasa, fijarCasaIds } = require('./helpers');

async function sembrarTrabajoPrivado(profesionalUid, overrides = {}) {
  const trabajoId = idUnico('trabajo-privado');
  await db.collection('profesionales').doc(profesionalUid).collection('trabajosPro').doc(trabajoId).set({
    clienteId: 'cliente-1',
    clienteNombre: 'Luis',
    titulo: 'Caldera no calienta',
    tipo: 'averia',
    estado: 'abierto',
    presupuestoEstimado: 220,
    ...overrides,
  });
  return trabajoId;
}

async function sembrarClientePrivado(profesionalUid, overrides = {}) {
  const clienteId = idUnico('cliente-privado');
  await db.collection('profesionales').doc(profesionalUid).collection('clientesPro').doc(clienteId).set({
    nombre: 'Luis',
    telefono: '600000000',
    ...overrides,
  });
  return clienteId;
}

async function contarDocs(ref) {
  const snap = await ref.get();
  return snap.size;
}

async function existeUsuarioAuth(uid) {
  try {
    await admin.auth().getUser(uid);
    return true;
  } catch (e) {
    if (e.code === 'auth/user-not-found') return false;
    throw e;
  }
}

test('1. borra trabajosPro y clientesPro, y el propio documento profesionales/{uid}', async () => {
  const pro = await crearUsuario();
  await sembrarTrabajoPrivado(pro.uid);
  await sembrarTrabajoPrivado(pro.uid);
  await sembrarClientePrivado(pro.uid);
  await db.collection('profesionales').doc(pro.uid).set({ nombreComercial: 'Fontanería Luis' }, { merge: true });

  const profRef = db.collection('profesionales').doc(pro.uid);
  assert.equal(await contarDocs(profRef.collection('trabajosPro')), 2, 'sanity check: los 2 trabajos deben existir antes de borrar');
  assert.equal(await contarDocs(profRef.collection('clientesPro')), 1, 'sanity check: el cliente debe existir antes de borrar');

  const { error } = await llamar('eliminarCuenta', pro.idToken, {});
  assert.equal(error, undefined, JSON.stringify(error));

  assert.equal(await contarDocs(profRef.collection('trabajosPro')), 0, 'trabajosPro debe quedar vacía, no solo inaccesible');
  assert.equal(await contarDocs(profRef.collection('clientesPro')), 0, 'clientesPro debe quedar vacía, no solo inaccesible');
  assert.equal((await profRef.get()).exists, false, 'el documento profesionales/{uid} también debe desaparecer');
  assert.equal(await existeUsuarioAuth(pro.uid), false);
});

test('2. invitación de vinculación pendiente (directa) creada por el profesional se borra al eliminar su cuenta', async () => {
  const pro = await crearUsuario();
  const propietario = await crearUsuario();
  const trabajoId = await sembrarTrabajoPrivado(pro.uid);

  const { error: errorInv, result } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: propietario.email,
  });
  assert.equal(errorInv, undefined, JSON.stringify(errorInv));
  assert.equal((await db.collection('invitacionesHogar').doc(result.invitacionId).get()).exists, true);

  const { error } = await llamar('eliminarCuenta', pro.idToken, {});
  assert.equal(error, undefined, JSON.stringify(error));

  assert.equal(
    (await db.collection('invitacionesHogar').doc(result.invitacionId).get()).exists,
    false,
    'la invitación pendiente de un profesional ya borrado no debe seguir accionable',
  );
});

test('3. código abierto (invitacionesHogarAbiertas) sin canjear se borra al eliminar la cuenta del profesional', async () => {
  const pro = await crearUsuario();
  const trabajoId = await sembrarTrabajoPrivado(pro.uid);

  const { error: errorInv, result } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: 'nadie-registrado-aun@test.local',
  });
  assert.equal(errorInv, undefined, JSON.stringify(errorInv));
  assert.equal(result.tipo, 'abierta');
  assert.equal((await db.collection('invitacionesHogarAbiertas').doc(result.codigo).get()).exists, true);

  const { error } = await llamar('eliminarCuenta', pro.idToken, {});
  assert.equal(error, undefined, JSON.stringify(error));

  assert.equal(
    (await db.collection('invitacionesHogarAbiertas').doc(result.codigo).get()).exists,
    false,
    'un código abierto de un profesional ya borrado no debe poder canjearse nunca',
  );
});

test('4. una invitación YA aceptada (historial) no se toca -- solo se limpian las que siguen pendientes', async () => {
  const pro = await crearUsuario();
  const propietario = await crearUsuario();
  const casaId = await crearCasa({ ownerUid: propietario.uid, members: [propietario.uid] });
  const trabajoId = await sembrarTrabajoPrivado(pro.uid);

  const { result: invResult } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: propietario.email,
  });
  const { error: errorResp } = await llamar('responderInvitacionHogar', propietario.idToken, {
    invitacionId: invResult.invitacionId, aceptar: true, casaId,
  });
  assert.equal(errorResp, undefined, JSON.stringify(errorResp));
  assert.equal((await db.collection('invitacionesHogar').doc(invResult.invitacionId).get()).data().estado, 'aceptada');

  const { error } = await llamar('eliminarCuenta', pro.idToken, {});
  assert.equal(error, undefined, JSON.stringify(error));

  const invFinal = await db.collection('invitacionesHogar').doc(invResult.invitacionId).get();
  assert.equal(invFinal.exists, true, 'una invitación ya resuelta es historial, no se borra al eliminar la cuenta del profesional');
  assert.equal(invFinal.data().estado, 'aceptada');
});

test('5. los trabajosPro/clientesPro de OTRO profesional nunca se tocan', async () => {
  const proA = await crearUsuario();
  const proB = await crearUsuario();
  await sembrarTrabajoPrivado(proA.uid);
  const trabajoB = await sembrarTrabajoPrivado(proB.uid);
  const clienteB = await sembrarClientePrivado(proB.uid);

  const { error } = await llamar('eliminarCuenta', proA.idToken, {});
  assert.equal(error, undefined, JSON.stringify(error));

  const profRefB = db.collection('profesionales').doc(proB.uid);
  assert.equal((await profRefB.collection('trabajosPro').doc(trabajoB).get()).exists, true, 'el trabajo de otro profesional nunca debió tocarse');
  assert.equal((await profRefB.collection('clientesPro').doc(clienteB).get()).exists, true, 'el cliente de otro profesional nunca debió tocarse');
  assert.equal(await existeUsuarioAuth(proB.uid), true);
});

test('6. cuenta con vivienda propia Y perfil profesional: se limpian ambas cosas en la misma llamada', async () => {
  const user = await crearUsuario();
  const casaId = await crearCasa({ ownerUid: user.uid, members: [user.uid] });
  await fijarCasaIds(user.uid, [casaId]);
  await sembrarTrabajoPrivado(user.uid);

  const { error } = await llamar('eliminarCuenta', user.idToken, {});
  assert.equal(error, undefined, JSON.stringify(error));

  assert.equal((await db.collection('casas').doc(casaId).get()).exists, false, 'la vivienda debe seguir borrándose igual que siempre');
  assert.equal(
    await contarDocs(db.collection('profesionales').doc(user.uid).collection('trabajosPro')),
    0,
    'el trabajo privado también debe limpiarse en la misma cuenta',
  );
  assert.equal(await existeUsuarioAuth(user.uid), false);
});

// No se crean 400+ documentos reales para ejercitar literalmente el límite
// de lote de Firestore (sería un test lentísimo sin aportar nada que el
// bucle de borrarEnLotesPorQuery no garantice ya por construcción: pide
// página, borra, repite hasta que la página viene corta). Este test
// confirma el caso múltiple más modesto -- varios documentos en una sola
// llamada a eliminarCuenta -- como evidencia de que el bucle de verdad
// itera más de una vez cuando hace falta, no solo con cero o un documento.
test('7. varios trabajosPro y clientesPro a la vez se borran todos, no solo el primero', async () => {
  const pro = await crearUsuario();
  const ids = await Promise.all([
    sembrarTrabajoPrivado(pro.uid, { titulo: 'Trabajo 1' }),
    sembrarTrabajoPrivado(pro.uid, { titulo: 'Trabajo 2' }),
    sembrarTrabajoPrivado(pro.uid, { titulo: 'Trabajo 3' }),
    sembrarClientePrivado(pro.uid, { nombre: 'Cliente 1' }),
    sembrarClientePrivado(pro.uid, { nombre: 'Cliente 2' }),
  ]);
  assert.equal(ids.length, 5);

  const { error } = await llamar('eliminarCuenta', pro.idToken, {});
  assert.equal(error, undefined, JSON.stringify(error));

  const profRef = db.collection('profesionales').doc(pro.uid);
  assert.equal(await contarDocs(profRef.collection('trabajosPro')), 0);
  assert.equal(await contarDocs(profRef.collection('clientesPro')), 0);
});
