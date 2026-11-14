// functions-tests/preferencias_notificacion.test.js
//
// Preferencias de notificación (sección 6 del encargo de avisos
// inteligentes, noviembre 2026): apagar una categoría apaga de verdad esa
// notificación (ni interna ni push); los tipos de seguridad/permisos nunca
// se silencian pase lo que pase en users/{uid}.notifPrefs. Contra el
// Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, sembrarRegistro, leerNotificaciones } = require('./helpers');
const { _enviarRecordatoriosParaTests } = require('../functions/index.js');

async function marcarComoProfesional(uid) {
  await db.collection('users').doc(uid).set({ esProfesional: true }, { merge: true });
}

test('1. con la categoría "presupuestos" desactivada, no se crea la notificación interna', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await db.collection('users').doc(owner.uid).set({ notifPrefs: { presupuestos: false } }, { merge: true });
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const { result } = await llamar('crearPresupuesto', pro.idToken, {
    casaId, elementoId, registroId, lineas: [{ descripcion: 'Mano de obra', cantidad: 1, precioUnitario: 100 }],
  });

  const { error } = await llamar('enviarPresupuesto', pro.idToken, {
    casaId, elementoId, registroId, presupuestoId: result.presupuestoId,
  });
  assert.equal(error, undefined);

  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo === 'presupuesto_enviado'), false);
});

test('2. sin tocar preferencias (todo activado por defecto), la notificación se crea igual que siempre', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const { result } = await llamar('crearPresupuesto', pro.idToken, {
    casaId, elementoId, registroId, lineas: [{ descripcion: 'Mano de obra', cantidad: 1, precioUnitario: 100 }],
  });

  await llamar('enviarPresupuesto', pro.idToken, { casaId, elementoId, registroId, presupuestoId: result.presupuestoId });

  const notis = await leerNotificaciones(owner.uid);
  assert.ok(notis.some((n) => n.tipo === 'presupuesto_enviado'));
});

test('3. con "pushHabilitado" desactivado, la notificación interna se sigue creando', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await db.collection('users').doc(owner.uid).set({ notifPrefs: { pushHabilitado: false } }, { merge: true });
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const { result } = await llamar('crearPresupuesto', pro.idToken, {
    casaId, elementoId, registroId, lineas: [{ descripcion: 'Mano de obra', cantidad: 1, precioUnitario: 100 }],
  });

  await llamar('enviarPresupuesto', pro.idToken, { casaId, elementoId, registroId, presupuestoId: result.presupuestoId });

  // Desactivar push nunca debe quitar el acceso a la notificación interna.
  const notis = await leerNotificaciones(owner.uid);
  assert.ok(notis.some((n) => n.tipo === 'presupuesto_enviado'));
});

test('4. un tipo obligatorio (invitación aceptada) se crea aunque su categoría esté desactivada', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  await marcarComoProfesional(pro.uid);
  // "seguridad" no es una categoría que la UI ofrezca desactivar, pero
  // TIPOS_OBLIGATORIOS debe ignorarla aunque alguien la fuerce igual.
  await db.collection('users').doc(owner.uid).set({ notifPrefs: { seguridad: false, pushHabilitado: false } }, { merge: true });
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const { result } = await llamar('invitarProfesional', owner.idToken, {
    casaId, elementoId, registroId, emailProfesional: pro.email,
  });

  await llamar('responderInvitacion', pro.idToken, { invitacionId: result.invitacionId, aceptar: true });

  const notis = await leerNotificaciones(owner.uid);
  assert.ok(notis.some((n) => n.tipo === 'invitacion_aceptada'));
});

test('5. con la categoría "garantias" desactivada, el recordatorio de garantía no se crea', async () => {
  const owner = await crearUsuario();
  await db.collection('users').doc(owner.uid).set({ notifPrefs: { garantias: false } }, { merge: true });
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).update({
    nombre: 'Caldera', garantiaHasta: new Date(ahoraMs + 5 * 24 * 60 * 60 * 1000),
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo === 'garantia_proxima_vencer'), false);
});

test('6. con la categoría "mantenimiento" desactivada, el recordatorio de mantenimiento no se crea', async () => {
  const owner = await crearUsuario();
  await db.collection('users').doc(owner.uid).set({ notifPrefs: { mantenimiento: false } }, { merge: true });
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).update({
    nombre: 'Caldera', proximoMantenimiento: new Date(ahoraMs),
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo === 'mantenimiento_pendiente'), false);
});
