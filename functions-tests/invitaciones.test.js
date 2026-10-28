// functions-tests/invitaciones.test.js
//
// Invitar a un profesional y aceptar la invitación (auditoría R7, octubre
// 2026): hallazgo real de la auditoría -- ni invitarProfesional ni
// responderInvitacion comprobaban el estado del registro, así que se podía
// vincular (o aceptar) un profesional sobre un trabajo ya cerrado, dándole
// acceso de lectura permanente a un registro que ya no debería poder
// vincular a nadie nuevo. Mismo criterio que crearCambioAlcance. Contra el
// Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, sembrarRegistro, leerRegistro } = require('./helpers');

async function marcarComoProfesional(uid) {
  await db.collection('users').doc(uid).set({ esProfesional: true }, { merge: true });
}

test('1. se puede invitar a un profesional sobre un registro abierto (nuevo)', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });

  const { error, result } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, emailProfesional: pro.email,
  });
  assert.equal(error, undefined);
  assert.equal(result.tipo, 'directa');
});

test('2. se bloquea invitar a un profesional sobre un registro ya terminado', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'terminado' });

  const { error } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, emailProfesional: pro.email,
  });
  assert.equal(error?.status, 'FAILED_PRECONDITION');
});

test('3. aceptar una invitación válida asigna profesionalUid al registro', async () => {
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

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.profesionalUid, pro.uid);
});

// Este es el caso real que motivó la corrección: la invitación se crea con
// el registro todavía abierto, pero se cierra ANTES de que el profesional
// llegue a aceptarla.
test('4. se bloquea aceptar una invitación si el registro se cerró entre invitar y aceptar', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const { result } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, emailProfesional: pro.email,
  });

  // El registro se cierra por otra vía ajena a este test (p.ej.
  // finalizarTrabajoPropietario) -- se simula el estado resultante
  // directamente, Admin SDK, sin pasar por esa función.
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).update({ estado: 'terminado' });

  const { error } = await llamar('responderInvitacion', pro.idToken, {
    invitacionId: result.invitacionId, aceptar: true,
  });
  assert.equal(error?.status, 'FAILED_PRECONDITION');

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.profesionalUid, undefined, 'el registro cerrado nunca debe acabar con un profesionalUid colado');
});

test('5. rechazar una invitación siempre funciona, incluso si el registro ya se cerró', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const { result } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, emailProfesional: pro.email,
  });

  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).update({ estado: 'terminado' });

  const { error } = await llamar('responderInvitacion', pro.idToken, {
    invitacionId: result.invitacionId, aceptar: false,
  });
  assert.equal(error, undefined, 'rechazar no escribe en el registro, así que no hay nada que bloquear');
});
