// functions-tests/invitacion_hogar.test.js
//
// Fase 2 (noviembre 2026): un profesional invita a un propietario a
// vincular un TrabajoProfesional privado suyo con la cuenta real de ese
// propietario. Espejo de invitacion.test.js (si existe) / el flujo que ya
// prueban otros archivos para invitarProfesional, en la dirección inversa.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, idUnico, leerRegistro, leerNotificaciones, esperarA } = require('./helpers');

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

async function leerTrabajoPrivado(profesionalUid, trabajoId) {
  const snap = await db.collection('profesionales').doc(profesionalUid).collection('trabajosPro').doc(trabajoId).get();
  return snap.data();
}

test('1. invitación directa: el email ya tiene cuenta -- crea invitacionesHogar pendiente y notifica al propietario', async () => {
  const pro = await crearUsuario();
  const propietario = await crearUsuario();
  const trabajoId = await sembrarTrabajoPrivado(pro.uid);

  const { error, result } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: propietario.email,
  });
  assert.equal(error, undefined);
  assert.equal(result.tipo, 'directa');

  const invSnap = await db.collection('invitacionesHogar').doc(result.invitacionId).get();
  assert.ok(invSnap.exists);
  assert.equal(invSnap.data().propietarioUid, propietario.uid);
  assert.equal(invSnap.data().profesionalUid, pro.uid);
  assert.equal(invSnap.data().estado, 'pendiente');
  assert.equal(invSnap.data().titulo, 'Caldera no calienta');

  const notis = await esperarA(async () => {
    const lista = await leerNotificaciones(propietario.uid);
    return lista.filter((n) => n.tipo === 'invitacion_hogar_recibida').length > 0 ? lista : null;
  });
  assert.ok(notis.some((n) => n.tipo === 'invitacion_hogar_recibida'));
});

test('2. sin cuenta con ese email -- genera código abierto, no invitacionesHogar todavía', async () => {
  const pro = await crearUsuario();
  const trabajoId = await sembrarTrabajoPrivado(pro.uid);

  const { error, result } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: 'nadie-con-esta-cuenta@test.local',
  });
  assert.equal(error, undefined);
  assert.equal(result.tipo, 'abierta');
  assert.ok(result.codigo);

  const abiertaSnap = await db.collection('invitacionesHogarAbiertas').doc(result.codigo).get();
  assert.ok(abiertaSnap.exists);
  assert.equal(abiertaSnap.data().estado, 'pendiente_registro');
});

test('3. canjear el código abierto crea la invitación pendiente con el propietario real', async () => {
  const pro = await crearUsuario();
  const propietario = await crearUsuario();
  const trabajoId = await sembrarTrabajoPrivado(pro.uid);
  const { result: invResult } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: 'nadie-con-esta-cuenta2@test.local',
  });

  const { error, result } = await llamar('canjearCodigoInvitacionHogar', propietario.idToken, { codigo: invResult.codigo });
  assert.equal(error, undefined);
  assert.equal(result.titulo, 'Caldera no calienta');

  const pendientes = await db.collection('invitacionesHogar').where('propietarioUid', '==', propietario.uid).where('estado', '==', 'pendiente').get();
  assert.equal(pendientes.size, 1);
});

test('4. aceptar crea Elemento+Registro reales en la casa elegida, marca el trabajo privado como vinculado y notifica al profesional', async () => {
  const pro = await crearUsuario();
  const propietario = await crearUsuario();
  const casaId = idUnico('casa');
  await db.collection('casas').doc(casaId).set({ nombre: 'Piso de Luis', ownerUid: propietario.uid, members: [propietario.uid] });
  const trabajoId = await sembrarTrabajoPrivado(pro.uid, { presupuestoEstimado: 220 });

  const { result: invResult } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: propietario.email,
  });

  const { error, result } = await llamar('responderInvitacionHogar', propietario.idToken, {
    invitacionId: invResult.invitacionId, aceptar: true, casaId,
  });
  assert.equal(error, undefined);
  assert.ok(result.vinculo);
  assert.equal(result.vinculo.casaId, casaId);

  const registro = await leerRegistro(casaId, result.vinculo.elementoId, result.vinculo.registroId);
  assert.equal(registro.titulo, 'Caldera no calienta');
  assert.equal(registro.esConProfesional, true);
  assert.equal(registro.profesionalUid, pro.uid);
  assert.equal(registro.presupuesto, 220);
  assert.equal(registro.estado, 'presupuestado');

  const elementoSnap = await db.collection('casas').doc(casaId).collection('elementos').doc(result.vinculo.elementoId).get();
  assert.ok(elementoSnap.exists);
  assert.equal(elementoSnap.data().nombre, 'Caldera no calienta');

  const trabajoPrivado = await leerTrabajoPrivado(pro.uid, trabajoId);
  assert.ok(trabajoPrivado.vinculo);
  assert.equal(trabajoPrivado.vinculo.casaId, casaId);
  assert.equal(trabajoPrivado.vinculo.registroId, result.vinculo.registroId);

  const userSnap = await db.collection('users').doc(pro.uid).get();
  const refs = userSnap.data()?.registrosProRefs || [];
  assert.ok(refs.some((r) => r.registroId === result.vinculo.registroId), 'registrosProRefs debe incluir el nuevo registro');

  const notis = await leerNotificaciones(pro.uid);
  assert.ok(notis.some((n) => n.tipo === 'invitacion_hogar_aceptada'));
});

test('5. rechazar no crea ningún registro y notifica al profesional', async () => {
  const pro = await crearUsuario();
  const propietario = await crearUsuario();
  const trabajoId = await sembrarTrabajoPrivado(pro.uid);
  const { result: invResult } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: propietario.email,
  });

  const { error, result } = await llamar('responderInvitacionHogar', propietario.idToken, {
    invitacionId: invResult.invitacionId, aceptar: false,
  });
  assert.equal(error, undefined);
  assert.equal(result.vinculo, null);

  const trabajoPrivado = await leerTrabajoPrivado(pro.uid, trabajoId);
  assert.equal(trabajoPrivado.vinculo, undefined);

  const notis = await leerNotificaciones(pro.uid);
  assert.ok(notis.some((n) => n.tipo === 'invitacion_hogar_rechazada'));
});

test('6. el profesional puede cancelar su propia invitación pendiente', async () => {
  const pro = await crearUsuario();
  const propietario = await crearUsuario();
  const trabajoId = await sembrarTrabajoPrivado(pro.uid);
  const { result: invResult } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: propietario.email,
  });

  const { error } = await llamar('cancelarInvitacionHogar', pro.idToken, { invitacionId: invResult.invitacionId });
  assert.equal(error, undefined);

  const invSnap = await db.collection('invitacionesHogar').doc(invResult.invitacionId).get();
  assert.equal(invSnap.data().estado, 'cancelada');
});

test('7. un propietario ajeno no puede responder a la invitación de otro', async () => {
  const pro = await crearUsuario();
  const propietario = await crearUsuario();
  const intruso = await crearUsuario();
  const casaId = idUnico('casa');
  await db.collection('casas').doc(casaId).set({ nombre: 'Casa del intruso', ownerUid: intruso.uid, members: [intruso.uid] });
  const trabajoId = await sembrarTrabajoPrivado(pro.uid);
  const { result: invResult } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: propietario.email,
  });

  const { error } = await llamar('responderInvitacionHogar', intruso.idToken, {
    invitacionId: invResult.invitacionId, aceptar: true, casaId,
  });
  assert.equal(error?.status, 'PERMISSION_DENIED');
});

test('8. no se puede invitar dos veces sobre un trabajo ya vinculado', async () => {
  const pro = await crearUsuario();
  const propietario = await crearUsuario();
  const casaId = idUnico('casa');
  await db.collection('casas').doc(casaId).set({ nombre: 'Casa', ownerUid: propietario.uid, members: [propietario.uid] });
  const trabajoId = await sembrarTrabajoPrivado(pro.uid);
  const { result: invResult } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: propietario.email,
  });
  await llamar('responderInvitacionHogar', propietario.idToken, { invitacionId: invResult.invitacionId, aceptar: true, casaId });

  const { error } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: propietario.email,
  });
  assert.equal(error?.status, 'FAILED_PRECONDITION');
});

// Hallazgo de uso real (noviembre 2026): aceptar creaba SIEMPRE un Elemento
// nuevo con el título del trabajo, aunque el propietario ya tuviera un
// Elemento al que de verdad pertenecía (p.ej. "Pérgolas") -- duplicaba
// Elementos sin necesidad. [elementoId] deja elegir uno ya existente.
test('9. aceptar con un elementoId ya existente reutiliza ese Elemento en vez de crear uno nuevo', async () => {
  const pro = await crearUsuario();
  const propietario = await crearUsuario();
  const casaId = idUnico('casa');
  const elementoExistenteId = idUnico('elemento');
  await db.collection('casas').doc(casaId).set({ nombre: 'Piso de Luis', ownerUid: propietario.uid, members: [propietario.uid] });
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoExistenteId).set({ nombre: 'Pérgolas' });
  const trabajoId = await sembrarTrabajoPrivado(pro.uid, { titulo: 'Reparación pérgola' });

  const { result: invResult } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: propietario.email,
  });
  const { error, result } = await llamar('responderInvitacionHogar', propietario.idToken, {
    invitacionId: invResult.invitacionId, aceptar: true, casaId, elementoId: elementoExistenteId,
  });
  assert.equal(error, undefined);
  assert.equal(result.vinculo.elementoId, elementoExistenteId, 'debe usar el Elemento existente, no crear uno nuevo');
  assert.equal(result.vinculo.elementoNombre, 'Pérgolas');

  const elementosSnap = await db.collection('casas').doc(casaId).collection('elementos').get();
  assert.equal(elementosSnap.size, 1, 'no debe haber creado ningún Elemento nuevo');

  const registro = await leerRegistro(casaId, elementoExistenteId, result.vinculo.registroId);
  assert.equal(registro.titulo, 'Reparación pérgola');
  assert.equal(registro.elementoNombre, 'Pérgolas');
});

test('10. aceptar con un elementoId que no existe falla con not-found', async () => {
  const pro = await crearUsuario();
  const propietario = await crearUsuario();
  const casaId = idUnico('casa');
  await db.collection('casas').doc(casaId).set({ nombre: 'Casa', ownerUid: propietario.uid, members: [propietario.uid] });
  const trabajoId = await sembrarTrabajoPrivado(pro.uid);
  const { result: invResult } = await llamar('invitarClienteAHogar', pro.idToken, {
    trabajoProfesionalId: trabajoId, emailCliente: propietario.email,
  });

  const { error } = await llamar('responderInvitacionHogar', propietario.idToken, {
    invitacionId: invResult.invitacionId, aceptar: true, casaId, elementoId: 'elemento-fantasma',
  });
  assert.equal(error?.status, 'NOT_FOUND');
});
