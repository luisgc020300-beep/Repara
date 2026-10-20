// functions-tests/presupuestos.test.js
//
// DATA-3 (auditoría de integridad económica, octubre 2026): aceptar un
// presupuesto ya no debe ser posible si el registro ya tiene OTRO
// presupuesto aceptado -- antes solo se bloqueaba crear uno nuevo en ese
// caso, nunca aceptar un segundo que ya existía (dos presupuestos en
// estado 'enviado' a la vez). Contra el Emulator Suite real -- ver
// helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, idUnico, sembrarRegistro, leerRegistro } = require('./helpers');

// Siembra un presupuesto directamente (Admin SDK, salta firestore.rules) --
// el test ejercita responderPresupuesto de verdad, no crearPresupuesto.
async function sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid, total, estado = 'enviado' }) {
  const ref = db
    .collection('casas').doc(casaId)
    .collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId)
    .collection('presupuestos').doc(idUnico('presupuesto'));
  await ref.set({ numero: 1, version: 1, estado, total, creadoPorUid, lineas: [] });
  return ref.id;
}

test('1. se puede aceptar un presupuesto válido cuando no existe otro aceptado', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const presupuestoId = await sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid: pro.uid, total: 500 });

  const { error } = await llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId, aceptar: true });
  assert.equal(error, undefined);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.estado, 'presupuestado');
  assert.equal(registro.presupuesto, 500);
});

test('2. no se puede aceptar un segundo presupuesto cuando ya hay uno aceptado para el mismo registro', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const presA = await sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid: pro.uid, total: 500 });
  const presB = await sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid: pro.uid, total: 800 });

  const primero = await llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId: presA, aceptar: true });
  assert.equal(primero.error, undefined);

  const segundo = await llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId: presB, aceptar: true });
  assert.equal(segundo.error?.status, 'FAILED_PRECONDITION');

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.presupuesto, 500, 'el total aceptado primero no debe quedar sobrescrito por el segundo');
});

test('3. dos aceptaciones concurrentes de dos presupuestos distintos del mismo registro no dejan dos aceptados', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const presA = await sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid: pro.uid, total: 500 });
  const presB = await sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid: pro.uid, total: 800 });

  const [a, b] = await Promise.all([
    llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId: presA, aceptar: true }),
    llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId: presB, aceptar: true }),
  ]);

  const exitos = [a, b].filter((r) => !r.error);
  assert.equal(exitos.length, 1, `exactamente una aceptación debe triunfar (a=${JSON.stringify(a)}, b=${JSON.stringify(b)})`);

  const [snapA, snapB] = await Promise.all([
    db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).collection('registros').doc(registroId).collection('presupuestos').doc(presA).get(),
    db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).collection('registros').doc(registroId).collection('presupuestos').doc(presB).get(),
  ]);
  const aceptados = [snapA, snapB].filter((s) => s.data().estado === 'aceptado');
  assert.equal(aceptados.length, 1, 'nunca deben quedar dos presupuestos en estado aceptado para el mismo registro');
});

test('4. un reintento de la misma aceptación no duplica el efecto (el presupuesto ya no está en estado enviado)', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const presupuestoId = await sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid: pro.uid, total: 500 });

  const primero = await llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId, aceptar: true });
  assert.equal(primero.error, undefined);
  const reintento = await llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId, aceptar: true });
  assert.equal(reintento.error?.status, 'FAILED_PRECONDITION');
});

test('5. un presupuesto rechazado no puede aceptarse después', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const presupuestoId = await sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid: pro.uid, total: 500 });

  const rechazo = await llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId, aceptar: false });
  assert.equal(rechazo.error, undefined);
  const intentoTardio = await llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId, aceptar: true });
  assert.equal(intentoTardio.error?.status, 'FAILED_PRECONDITION');
});

test('6. un usuario que no pertenece a la casa no puede aceptar presupuestos ajenos', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const extrano = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const presupuestoId = await sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid: pro.uid, total: 500 });

  const { error } = await llamar('responderPresupuesto', extrano.idToken, { casaId, elementoId, registroId, presupuestoId, aceptar: true });
  assert.equal(error?.status, 'PERMISSION_DENIED');
});

test('quien creó el presupuesto no puede autoaprobárselo', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const presupuestoId = await sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid: owner.uid, total: 500 });

  const { error } = await llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId, aceptar: true });
  assert.equal(error?.status, 'PERMISSION_DENIED');
});

// Segunda auditoría de integridad económica (octubre 2026): reproduce el
// escenario EXACTO que describió la auditoría -- 1) aceptar A, 2) resetear
// "estado" a mano (firestore.rules SÍ permite esto -- es el picker
// legítimo de "_estadosEditables"), 3) intentar aceptar B. Antes de este
// fix, el paso 3 funcionaba porque responderPresupuesto solo miraba
// "estado". Ahora debe seguir bloqueado porque "presupuestoAceptadoId" no
// se resetea con ese tercer paso -- se escribe directo con el Admin SDK
// (en vez de una llamada de cliente autenticado) porque las reglas no son
// lo que se está probando aquí, es la resiliencia de la Cloud Function.
test('8. resetear "estado" a mano tras aceptar A no reabre el hueco para aceptar B', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });
  const presA = await sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid: pro.uid, total: 500 });
  const presB = await sembrarPresupuesto(casaId, elementoId, registroId, { creadoPorUid: pro.uid, total: 800 });

  const aceptarA = await llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId: presA, aceptar: true });
  assert.equal(aceptarA.error, undefined);

  // Paso 2 del escenario de la auditoría: reset directo de "estado",
  // exactamente lo que firestore.rules permite hoy a un miembro.
  const regRef = db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).collection('registros').doc(registroId);
  await regRef.update({ estado: 'nuevo' });
  const tras_reset = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(tras_reset.estado, 'nuevo', 'el reset de estado debe haberse aplicado de verdad para que el test reproduzca el escenario real');
  assert.equal(tras_reset.presupuestoAceptadoId, presA, 'presupuestoAceptadoId no debe moverse por resetear "estado"');

  const aceptarB = await llamar('responderPresupuesto', owner.idToken, { casaId, elementoId, registroId, presupuestoId: presB, aceptar: true });
  assert.equal(aceptarB.error?.status, 'FAILED_PRECONDITION', 'aceptar B debe seguir bloqueado aunque "estado" ya no diga presupuestado');

  const final = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(final.presupuesto, 500, 'el total no debe haber cambiado a pesar del reset y el segundo intento');
  assert.equal(final.presupuestoAceptadoId, presA);
});
