// functions-tests/payments.test.js
//
// DATA-1 (auditoría de integridad económica, octubre 2026): los pagos
// (registrarPago/actualizarPago) deben validar el total acumulado contra el
// presupuesto DENTRO de una transacción en servidor, no en el cliente antes
// de escribir. Contra el Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { crearUsuario, llamar, sembrarRegistro, leerRegistro, leerPagos } = require('./helpers');

test('1. un pago válido dentro del presupuesto se acepta', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });

  const { status, result, error } = await llamar('registrarPago', owner.idToken, {
    casaId, elementoId, registroId, importe: 40, fecha: Date.now(),
  });
  assert.equal(error, undefined, JSON.stringify(error));
  assert.equal(status, 200);
  assert.ok(result.pagoId);

  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos.length, 1);
  assert.equal(pagos[0].importe, 40);
  assert.equal(pagos[0].createdBy, owner.uid);
});

test('2. un pago que supera el importe restante se rechaza', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });

  await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 70, fecha: Date.now() });
  const { error } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 40, fecha: Date.now() });

  assert.equal(error?.status, 'FAILED_PRECONDITION');
  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos.length, 1, 'el segundo pago rechazado no debe dejar ningún documento parcial');
});

test('3. dos solicitudes concurrentes cuyos importes sumados superan el presupuesto no pueden aceptarse ambas', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });

  const [a, b] = await Promise.all([
    llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 70, fecha: Date.now() }),
    llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 70, fecha: Date.now() }),
  ]);

  const exitos = [a, b].filter((r) => !r.error);
  const fallos = [a, b].filter((r) => r.error);
  assert.equal(exitos.length, 1, `exactamente una de las dos debe triunfar (a=${JSON.stringify(a)}, b=${JSON.stringify(b)})`);
  assert.equal(fallos.length, 1);
  assert.equal(fallos[0].error.status, 'FAILED_PRECONDITION');

  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos.length, 1);
  assert.equal(pagos[0].importe, 70);
});

test('4. repetir la misma solicitud (mismo clientRequestId, mismo contenido) por un reintento no duplica el pago', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });
  const clientRequestId = 'intento-logico-fijo-1';
  // Un reintento real del cliente reenvía exactamente la misma petición --
  // por eso se fija `fecha` una sola vez, no Date.now() en cada llamada
  // (dos timestamps "iguales en la práctica" pero distintos en
  // milisegundos harían que datosCoinciden() los tratara como una
  // petición DISTINTA, ver test 7).
  const fecha = Date.now();

  const primero = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 40, fecha, clientRequestId });
  const reintento = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 40, fecha, clientRequestId });

  assert.equal(primero.error, undefined);
  assert.equal(reintento.error, undefined);
  assert.equal(primero.result.pagoId, reintento.result.pagoId, 'el reintento debe devolver el mismo id, no crear uno nuevo');
  assert.equal(reintento.result.yaExistia, true);

  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos.length, 1, 'el reintento no debe duplicar el documento de pago');
});

test('5. un usuario que no pertenece a la casa no puede registrar un pago para un registro ajeno', async () => {
  const owner = await crearUsuario();
  const extrano = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });

  const { error } = await llamar('registrarPago', extrano.idToken, { casaId, elementoId, registroId, importe: 10, fecha: Date.now() });
  assert.equal(error?.status, 'PERMISSION_DENIED');

  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos.length, 0);
});

test('6. sin presupuesto fijado (null), se deja pagar libremente -- mismo criterio que el cliente', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: null });

  const { error } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 99999, fecha: Date.now() });
  assert.equal(error, undefined);
});

// Segunda auditoría (octubre 2026): el escenario exacto que describió --
// pago de 40€, el usuario corrige a 45€ y reintenta reutilizando el mismo
// clientRequestId. Antes de este fix la función respondía éxito sin más
// (tratando "already-exists" como si fuera siempre el mismo intento);
// ahora debe rechazar explícitamente, nunca devolver "ok" para datos que no
// coinciden con lo guardado.
test('7. reutilizar el mismo clientRequestId con un importe distinto se rechaza explícitamente', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });
  const clientRequestId = 'intento-logico-fijo-reusado';

  const primero = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 40, fecha: Date.now(), clientRequestId });
  assert.equal(primero.error, undefined);

  const reintentoConOtroImporte = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 45, fecha: Date.now(), clientRequestId });
  assert.equal(reintentoConOtroImporte.error?.status, 'ALREADY_EXISTS', 'debe rechazar, nunca devolver éxito silencioso con datos distintos');

  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos.length, 1);
  assert.equal(pagos[0].importe, 40, 'el pago guardado debe seguir siendo el original, no el del reintento rechazado');
});

test('actualizarPago: solo quien creó el pago puede editarlo, y la edición también respeta el presupuesto', async () => {
  const owner = await crearUsuario();
  const otroMiembro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });
  // otroMiembro se añade como miembro directamente en el fixture (dos
  // propietarios de la misma casa es un caso real: pareja conviviendo).
  const { db } = require('./helpers');
  await db.collection('casas').doc(casaId).update({ members: [owner.uid, otroMiembro.uid] });

  const creado = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 40, fecha: Date.now() });
  const pagoId = creado.result.pagoId;

  const edicionAjena = await llamar('actualizarPago', otroMiembro.idToken, { casaId, elementoId, registroId, pagoId, importe: 50, fecha: Date.now() });
  assert.equal(edicionAjena.error?.status, 'PERMISSION_DENIED');

  const subidaExcesiva = await llamar('actualizarPago', owner.idToken, { casaId, elementoId, registroId, pagoId, importe: 150, fecha: Date.now() });
  assert.equal(subidaExcesiva.error?.status, 'FAILED_PRECONDITION');

  const edicionValida = await llamar('actualizarPago', owner.idToken, { casaId, elementoId, registroId, pagoId, importe: 80, fecha: Date.now() });
  assert.equal(edicionValida.error, undefined);

  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos.length, 1);
  assert.equal(pagos[0].importe, 80);
});
