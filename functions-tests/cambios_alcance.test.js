// functions-tests/cambios_alcance.test.js
//
// DATA-6 (auditoría de integridad económica, octubre 2026): un reintento de
// red al crear un cambio de alcance no debe duplicar la solicitud (y por
// tanto no debe poder incrementar el presupuesto dos veces si ambas copias
// llegaran a aprobarse). Contra el Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, sembrarRegistro, leerRegistro } = require('./helpers');

async function leerCambios(casaId, elementoId, registroId) {
  const snap = await db
    .collection('casas').doc(casaId)
    .collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId)
    .collection('cambiosAlcance').get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

test('1. el profesional asignado puede crear una solicitud válida', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });

  const { error, result } = await llamar('crearCambioAlcance', pro.idToken, {
    casaId, elementoId, registroId, titulo: 'Más tubería', importeAdicional: 80,
  });
  assert.equal(error, undefined);
  assert.ok(result.cambioAlcanceId);
});

test('2. un reintento de creación (mismo clientRequestId) no genera un duplicado', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const clientRequestId = 'intento-logico-fijo-cambio-1';

  const primero = await llamar('crearCambioAlcance', pro.idToken, { casaId, elementoId, registroId, titulo: 'Más tubería', importeAdicional: 80, clientRequestId });
  const reintento = await llamar('crearCambioAlcance', pro.idToken, { casaId, elementoId, registroId, titulo: 'Más tubería', importeAdicional: 80, clientRequestId });

  assert.equal(primero.error, undefined);
  assert.equal(reintento.error, undefined);
  assert.equal(primero.result.cambioAlcanceId, reintento.result.cambioAlcanceId);

  const cambios = await leerCambios(casaId, elementoId, registroId);
  assert.equal(cambios.length, 1, 'el reintento no debe duplicar la solicitud');
});

// Segunda auditoría (octubre 2026): mismo defecto que en pagos -- reutilizar
// el identificador con un importe/título distinto nunca debe devolver éxito
// silencioso.
test('2b. reutilizar el mismo clientRequestId con un importe adicional distinto se rechaza explícitamente', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const clientRequestId = 'intento-logico-fijo-cambio-reusado';

  const primero = await llamar('crearCambioAlcance', pro.idToken, { casaId, elementoId, registroId, titulo: 'Más tubería', importeAdicional: 80, clientRequestId });
  assert.equal(primero.error, undefined);

  const reintentoConOtroImporte = await llamar('crearCambioAlcance', pro.idToken, { casaId, elementoId, registroId, titulo: 'Más tubería', importeAdicional: 150, clientRequestId });
  assert.equal(reintentoConOtroImporte.error?.status, 'ALREADY_EXISTS', 'debe rechazar, nunca devolver éxito silencioso con datos distintos');

  const cambios = await leerCambios(casaId, elementoId, registroId);
  assert.equal(cambios.length, 1);
  assert.equal(cambios[0].importeAdicional, 80, 'la solicitud guardada debe seguir siendo la original, no la del reintento rechazado');
});

test('3. una solicitud pendiente puede aprobarse y suma al presupuesto del registro', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', presupuesto: 100, profesionalUid: pro.uid });
  const { result } = await llamar('crearCambioAlcance', pro.idToken, { casaId, elementoId, registroId, titulo: 'Más tubería', importeAdicional: 80 });

  const { error } = await llamar('responderCambioAlcance', owner.idToken, { casaId, elementoId, registroId, cambioAlcanceId: result.cambioAlcanceId, aprobar: true });
  assert.equal(error, undefined);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.presupuesto, 180);
});

test('4. una solicitud ya aprobada no vuelve a incrementar el presupuesto si se reintenta la aprobación', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', presupuesto: 100, profesionalUid: pro.uid });
  const { result } = await llamar('crearCambioAlcance', pro.idToken, { casaId, elementoId, registroId, titulo: 'Más tubería', importeAdicional: 80 });

  const primero = await llamar('responderCambioAlcance', owner.idToken, { casaId, elementoId, registroId, cambioAlcanceId: result.cambioAlcanceId, aprobar: true });
  assert.equal(primero.error, undefined);
  const reintento = await llamar('responderCambioAlcance', owner.idToken, { casaId, elementoId, registroId, cambioAlcanceId: result.cambioAlcanceId, aprobar: true });
  assert.equal(reintento.error?.status, 'FAILED_PRECONDITION');

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.presupuesto, 180, 'el incremento no debe aplicarse dos veces');
});

test('5. dos aprobaciones concurrentes de la misma solicitud producen un único efecto económico', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', presupuesto: 100, profesionalUid: pro.uid });
  const { result } = await llamar('crearCambioAlcance', pro.idToken, { casaId, elementoId, registroId, titulo: 'Más tubería', importeAdicional: 80 });

  const [a, b] = await Promise.all([
    llamar('responderCambioAlcance', owner.idToken, { casaId, elementoId, registroId, cambioAlcanceId: result.cambioAlcanceId, aprobar: true }),
    llamar('responderCambioAlcance', owner.idToken, { casaId, elementoId, registroId, cambioAlcanceId: result.cambioAlcanceId, aprobar: true }),
  ]);
  const exitos = [a, b].filter((r) => !r.error);
  assert.equal(exitos.length, 1, `exactamente una aprobación debe triunfar (a=${JSON.stringify(a)}, b=${JSON.stringify(b)})`);

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.presupuesto, 180, 'el incremento solo debe aplicarse una vez pase lo que pase con la concurrencia');
});

test('6. una solicitud rechazada no puede aprobarse después', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', presupuesto: 100, profesionalUid: pro.uid });
  const { result } = await llamar('crearCambioAlcance', pro.idToken, { casaId, elementoId, registroId, titulo: 'Más tubería', importeAdicional: 80 });

  const rechazo = await llamar('responderCambioAlcance', owner.idToken, { casaId, elementoId, registroId, cambioAlcanceId: result.cambioAlcanceId, aprobar: false });
  assert.equal(rechazo.error, undefined);
  const intentoTardio = await llamar('responderCambioAlcance', owner.idToken, { casaId, elementoId, registroId, cambioAlcanceId: result.cambioAlcanceId, aprobar: true });
  assert.equal(intentoTardio.error?.status, 'FAILED_PRECONDITION');

  const registro = await leerRegistro(casaId, elementoId, registroId);
  assert.equal(registro.presupuesto ?? 100, 100);
});

test('7. un usuario que no pertenece a la casa no puede aprobar cambios ajenos', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const extrano = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', presupuesto: 100, profesionalUid: pro.uid });
  const { result } = await llamar('crearCambioAlcance', pro.idToken, { casaId, elementoId, registroId, titulo: 'Más tubería', importeAdicional: 80 });

  const { error } = await llamar('responderCambioAlcance', extrano.idToken, { casaId, elementoId, registroId, cambioAlcanceId: result.cambioAlcanceId, aprobar: true });
  assert.equal(error?.status, 'PERMISSION_DENIED');
});
