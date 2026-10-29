// functions-tests/terminado_requiere_pago.test.js
//
// CEO, octubre 2026: "terminado" tiene que referenciar a todo el proceso --
// el trabajo Y el pago -- si falla una de las dos, el registro no está
// terminado. Antes de esto, finalizarTrabajoPropietario cerraba un registro
// sin mirar nunca si coste/presupuesto estaba cubierto, y
// registrarPago/actualizarPago/eliminarPago nunca tocaban `estado`. Ahora:
// - finalizarTrabajoPropietario deja el registro en 'pendientePago' en vez
//   de 'terminado' si queda saldo sin cubrir.
// - registrarPago/actualizarPago pueden completar un 'pendientePago' y
//   pasarlo a 'terminado' en el mismo movimiento.
// - actualizarPago/eliminarPago pueden REABRIR un 'terminado' a
//   'pendientePago' si la edición/borrado deja un saldo real.
// - nada de esto toca un registro que sigue en su flujo normal (nuevo/
//   presupuestado/enCurso/pendienteConfirmacion) -- ver estadoTrasCambioDePago
//   en functions/index.js.
// Contra el Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { crearUsuario, llamar, sembrarRegistro, leerRegistro } = require('./helpers');

test('finalizarTrabajoPropietario: sin nada que cobrar (sin presupuesto), cierra directo a terminado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'enCurso' });

  const { error } = await llamar('finalizarTrabajoPropietario', owner.idToken, { casaId, elementoId, registroId });
  assert.equal(error, undefined);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.estado, 'terminado');
});

test('finalizarTrabajoPropietario: con presupuesto sin ningún pago, queda en pendientePago, no en terminado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'enCurso', presupuesto: 100 });

  const { error } = await llamar('finalizarTrabajoPropietario', owner.idToken, { casaId, elementoId, registroId });
  assert.equal(error, undefined);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.estado, 'pendientePago');
});

test('finalizarTrabajoPropietario: con el presupuesto ya cubierto por pagos previos, cierra directo a terminado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'enCurso', presupuesto: 100 });
  await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() });

  const { error } = await llamar('finalizarTrabajoPropietario', owner.idToken, { casaId, elementoId, registroId });
  assert.equal(error, undefined);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.estado, 'terminado');
});

test('finalizarTrabajoPropietario: llamarlo de nuevo sobre un registro ya en pendientePago se rechaza, igual que sobre uno terminado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'enCurso', presupuesto: 100 });
  await llamar('finalizarTrabajoPropietario', owner.idToken, { casaId, elementoId, registroId });

  const { error } = await llamar('finalizarTrabajoPropietario', owner.idToken, { casaId, elementoId, registroId });
  assert.equal(error?.status, 'FAILED_PRECONDITION');
});

test('registrarPago: completar el saldo de un registro en pendientePago lo cierra a terminado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'pendientePago', presupuesto: 100 });

  const { error } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() });
  assert.equal(error, undefined);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.estado, 'terminado');
});

test('registrarPago: un pago parcial sobre un registro en pendientePago lo deja igual, no lo cierra', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'pendientePago', presupuesto: 100 });

  const { error } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 60, fecha: Date.now() });
  assert.equal(error, undefined);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.estado, 'pendientePago');
});

test('registrarPago: no toca el estado de un registro que sigue en su flujo normal (nuevo/enCurso/...)', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'enCurso', presupuesto: 100 });

  // Cubre el presupuesto entero, pero el trabajo en sí nunca se confirmó
  // terminado -- pagar no debe "finalizar" nada por su cuenta.
  const { error } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() });
  assert.equal(error, undefined);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.estado, 'enCurso');
});

test('actualizarPago: reducir un pago que dejaba un registro terminado reabre a pendientePago', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'pendientePago', presupuesto: 100 });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() });
  assert.equal((await leerRegistro(casaId, elementoId, registroId)).estado, 'terminado');

  const { error } = await llamar('actualizarPago', owner.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId, importe: 50, fecha: Date.now() });
  assert.equal(error, undefined);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.estado, 'pendientePago');
});

test('actualizarPago: subir un pago hasta cubrir el saldo cierra un pendientePago a terminado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'pendientePago', presupuesto: 100 });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 60, fecha: Date.now() });
  assert.equal((await leerRegistro(casaId, elementoId, registroId)).estado, 'pendientePago');

  const { error } = await llamar('actualizarPago', owner.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId, importe: 100, fecha: Date.now() });
  assert.equal(error, undefined);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.estado, 'terminado');
});

test('eliminarPago: borrar el pago que cubría un registro terminado lo reabre a pendientePago', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'pendientePago', presupuesto: 100 });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() });
  assert.equal((await leerRegistro(casaId, elementoId, registroId)).estado, 'terminado');

  const { error } = await llamar('eliminarPago', owner.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId });
  assert.equal(error, undefined);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.estado, 'pendientePago');
});

test('responderCambioAlcance: se rechaza sobre un registro en pendientePago, igual que sobre uno terminado', async () => {
  const owner = await crearUsuario();
  const profesional = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'pendientePago', presupuesto: 100, profesionalUid: profesional.uid,
  });
  const { db } = require('./helpers');
  const ref = await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).collection('cambiosAlcance')
    .add({ titulo: 'Cambio', estado: 'pendiente', creadoPorUid: profesional.uid, importeAdicional: 10 });

  const { error } = await llamar('responderCambioAlcance', owner.idToken, {
    casaId, elementoId, registroId, cambioAlcanceId: ref.id, aprobar: true,
  });
  assert.equal(error?.status, 'FAILED_PRECONDITION');
});
