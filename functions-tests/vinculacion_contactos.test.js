// functions-tests/vinculacion_contactos.test.js
//
// Vinculación de contactos (unificación del sistema de valoraciones,
// noviembre 2026): la única forma fiable de saber "este contacto de la
// libreta es esta cuenta profesional real" -- nunca por coincidencia de
// nombre o teléfono. invitarProfesional guarda contactoId en la
// invitación (directa o de código abierto), y responderInvitacion, solo
// al ACEPTAR de verdad, escribe contactos/{ctid}.profesionalUidVinculado
// vía Admin SDK (el cliente nunca puede escribirlo, ver firestore.rules).
// Contra el Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, sembrarRegistro } = require('./helpers');

async function marcarComoProfesional(uid) {
  await db.collection('users').doc(uid).set({ esProfesional: true }, { merge: true });
}

async function crearContacto(casaId, { nombre = 'Fontanero', telefono = '600111222' } = {}) {
  const ref = db.collection('casas').doc(casaId).collection('contactos').doc();
  await ref.set({ nombre, telefono, tipo: 'particular', favorito: false });
  return ref.id;
}

test('1. aceptar una invitación enviada desde un contacto vincula profesionalUidVinculado', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const contactoId = await crearContacto(casaId);

  const { error, result } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, profesionalUidDirecto: pro.uid, contactoId,
  });
  assert.equal(error, undefined);

  await llamar('responderInvitacion', pro.idToken, { invitacionId: result.invitacionId, aceptar: true });

  const contactoSnap = await db.collection('casas').doc(casaId).collection('contactos').doc(contactoId).get();
  assert.equal(contactoSnap.data().profesionalUidVinculado, pro.uid);
});

test('2. rechazar una invitación enviada desde un contacto NO lo vincula', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const contactoId = await crearContacto(casaId);

  const { result } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, profesionalUidDirecto: pro.uid, contactoId,
  });
  await llamar('responderInvitacion', pro.idToken, { invitacionId: result.invitacionId, aceptar: false });

  const contactoSnap = await db.collection('casas').doc(casaId).collection('contactos').doc(contactoId).get();
  assert.equal(contactoSnap.data().profesionalUidVinculado, undefined);
});

test('3. invitar sin contactoId no vincula ningún contacto (comportamiento de siempre, sin cambios)', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const contactoId = await crearContacto(casaId);

  const { result } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, profesionalUidDirecto: pro.uid,
  });
  await llamar('responderInvitacion', pro.idToken, { invitacionId: result.invitacionId, aceptar: true });

  const contactoSnap = await db.collection('casas').doc(casaId).collection('contactos').doc(contactoId).get();
  assert.equal(contactoSnap.data().profesionalUidVinculado, undefined);
});

test('4. invitarProfesional rechaza un contactoId que no existe en esa casa', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });

  const { error } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, profesionalUidDirecto: pro.uid, contactoId: 'no-existe',
  });
  assert.equal(error?.status, 'NOT_FOUND');
});

test('5. invitarProfesional rechaza un contactoId de una casa distinta', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const otraCasa = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const contactoDeOtraCasa = await crearContacto(otraCasa.casaId);

  const { error } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, profesionalUidDirecto: pro.uid, contactoId: contactoDeOtraCasa,
  });
  assert.equal(error?.status, 'NOT_FOUND');
});

test('6. el flujo de código abierto (sin cuenta previa) también vincula el contacto al aceptar', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario(); // todavía no marcado esProfesional -- fuerza el camino de código abierto
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const contactoId = await crearContacto(casaId, { telefono: '600999888' });

  const { result } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, telefonoProfesional: '600999888', contactoId,
  });
  assert.equal(result.tipo, 'abierta');

  const { result: canjeado } = await llamar('canjearCodigoInvitacion', pro.idToken, { codigo: result.codigo });
  assert.ok(canjeado);

  // Buscar la invitación recién creada para este profesional y aceptarla.
  const invSnap = await db.collection('invitaciones').where('profesionalUid', '==', pro.uid).get();
  assert.equal(invSnap.size, 1);
  await llamar('responderInvitacion', pro.idToken, { invitacionId: invSnap.docs[0].id, aceptar: true });

  const contactoSnap = await db.collection('casas').doc(casaId).collection('contactos').doc(contactoId).get();
  assert.equal(contactoSnap.data().profesionalUidVinculado, pro.uid);
});
