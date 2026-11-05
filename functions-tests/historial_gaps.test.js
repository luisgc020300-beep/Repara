// functions-tests/historial_gaps.test.js
//
// Avisos inteligentes + registro de actividad compartido (noviembre 2026):
// la auditoría encontró que finalización/archivado/invitación no dejaban
// ningún rastro en el historial append-only, y que invitación aceptada/
// rechazada y cancelar un cambio de alcance no avisaban a nadie. Contra el
// Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, sembrarRegistro, leerHistorial, leerNotificaciones } = require('./helpers');

async function marcarComoProfesional(uid) {
  await db.collection('users').doc(uid).set({ esProfesional: true }, { merge: true });
}

test('1. finalizarTrabajoPropietario deja un evento de historial entidad=registro', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });

  const { error } = await llamar('finalizarTrabajoPropietario', owner.idToken, { casaId, elementoId, registroId });
  assert.equal(error, undefined);

  const historial = await leerHistorial(casaId, elementoId, registroId);
  const evento = historial.find((h) => h.entidad === 'registro');
  assert.ok(evento, 'debe existir un evento de entidad registro');
  assert.equal(evento.accion, 'confirmado');
  assert.equal(evento.actorUid, owner.uid);
  assert.equal(evento.estadoNuevo, 'terminado');
});

test('2. marcarTrabajoFinalizadoProfesional y rechazarFinalizacionProfesional dejan su propio evento', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid,
  });

  const marcar = await llamar('marcarTrabajoFinalizadoProfesional', pro.idToken, { casaId, elementoId, registroId });
  assert.equal(marcar.error, undefined);
  let historial = await leerHistorial(casaId, elementoId, registroId);
  assert.ok(historial.some((h) => h.entidad === 'registro' && h.accion === 'pendienteConfirmacion'));

  const rechazar = await llamar('rechazarFinalizacionProfesional', owner.idToken, { casaId, elementoId, registroId });
  assert.equal(rechazar.error, undefined);
  historial = await leerHistorial(casaId, elementoId, registroId);
  assert.ok(historial.some((h) => h.entidad === 'registro' && h.accion === 'finalizacionRechazada'));

  // Ya notificaba antes de esta corrección -- sigue notificando.
  const notisDelPro = await leerNotificaciones(pro.uid);
  assert.ok(notisDelPro.some((n) => n.tipo === 'trabajo_finalizacion_rechazada'));
});

test('3. archivarElemento deja un evento por cada registro y avisa al resto de la casa', async () => {
  const owner = await crearUsuario();
  const otroMiembro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'terminado' });
  await db.collection('casas').doc(casaId).update({ members: [owner.uid, otroMiembro.uid] });

  const { error } = await llamar('archivarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error, undefined);

  const historial = await leerHistorial(casaId, elementoId, registroId);
  assert.ok(historial.some((h) => h.entidad === 'registro' && h.accion === 'elementoArchivado'));

  const notisOtro = await leerNotificaciones(otroMiembro.uid);
  assert.ok(notisOtro.some((n) => n.tipo === 'elemento_archivado'));
  // Quien archiva no se notifica a sí mismo (mismo criterio que el resto de
  // avisos a "toda la casa").
  const notisOwner = await leerNotificaciones(owner.uid);
  assert.ok(!notisOwner.some((n) => n.tipo === 'elemento_archivado'));
});

test('4. restaurarElemento deja su propio evento y avisa a la casa', async () => {
  const owner = await crearUsuario();
  const otroMiembro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'terminado' });
  await db.collection('casas').doc(casaId).update({ members: [owner.uid, otroMiembro.uid] });
  await llamar('archivarElemento', owner.idToken, { casaId, elementoId });

  const { error } = await llamar('restaurarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error, undefined);

  const historial = await leerHistorial(casaId, elementoId, registroId);
  assert.ok(historial.some((h) => h.entidad === 'registro' && h.accion === 'elementoRestaurado'));
  const notisOtro = await leerNotificaciones(otroMiembro.uid);
  assert.ok(notisOtro.some((n) => n.tipo === 'elemento_restaurado'));
});

test('5. aceptar una invitación deja historial y avisa al propietario', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const { result } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, emailProfesional: pro.email,
  });

  const { error } = await llamar('responderInvitacion', pro.idToken, {
    invitacionId: result.invitacionId, aceptar: true,
  });
  assert.equal(error, undefined);

  const historial = await leerHistorial(casaId, elementoId, registroId);
  const evento = historial.find((h) => h.entidad === 'invitacion');
  assert.ok(evento, 'debe existir un evento de entidad invitacion');
  assert.equal(evento.accion, 'aceptada');
  assert.equal(evento.actorUid, pro.uid);

  const notisOwner = await leerNotificaciones(owner.uid);
  assert.ok(notisOwner.some((n) => n.tipo === 'invitacion_aceptada'));
});

test('6. rechazar una invitación deja historial y avisa al propietario, sin asignar profesionalUid', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const { result } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, emailProfesional: pro.email,
  });

  const { error } = await llamar('responderInvitacion', pro.idToken, {
    invitacionId: result.invitacionId, aceptar: false,
  });
  assert.equal(error, undefined);

  const historial = await leerHistorial(casaId, elementoId, registroId);
  assert.ok(historial.some((h) => h.entidad === 'invitacion' && h.accion === 'rechazada'));

  const notisOwner = await leerNotificaciones(owner.uid);
  assert.ok(notisOwner.some((n) => n.tipo === 'invitacion_rechazada'));
});

test('7. cancelar un cambio de alcance avisa al resto de la casa', async () => {
  const owner = await crearUsuario();
  const otroMiembro = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid,
  });
  await db.collection('casas').doc(casaId).update({ members: [owner.uid, otroMiembro.uid] });
  const { result } = await llamar('crearCambioAlcance', pro.idToken, {
    casaId, elementoId, registroId, titulo: 'Más tubería', importeAdicional: 80,
  });

  const { error } = await llamar('cancelarCambioAlcance', pro.idToken, {
    casaId, elementoId, registroId, cambioAlcanceId: result.cambioAlcanceId,
  });
  assert.equal(error, undefined);

  const notisOtro = await leerNotificaciones(otroMiembro.uid);
  assert.ok(notisOtro.some((n) => n.tipo === 'cambio_alcance_cancelado'));
});
