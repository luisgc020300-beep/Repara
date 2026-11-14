// functions-tests/citas_respuesta_propietario.test.js
//
// CEO, noviembre 2026: "que el propietario pueda responder de verdad, no
// solo aceptar la fecha que ponga el profesional". responderCitaPropietario/
// proponerOtraFechaCita son las únicas vías por las que el propietario puede
// tocar un documento de profesionales/{uid}/citas -- la regla base de
// `citas` en firestore.rules no le da ningún `allow write` (ver
// rules.test.js, "el propietario no puede escribir ni editar la cita", que
// sigue pasando sin cambios). CitaService.responderContrapropuesta (la
// respuesta del profesional a la contrapropuesta) es escritura directa, sin
// Cloud Function -- aquí se simula con Admin SDK, igual que
// citas_compartidas_trigger.test.js simula CitaService.crear/actualizar.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, sembrarRegistro, leerHistorial, leerNotificaciones, esperarA } = require('./helpers');

function citaRef(profesionalUid, citaId) {
  return db.collection('profesionales').doc(profesionalUid).collection('citas').doc(citaId);
}

async function leerCita(profesionalUid, citaId) {
  const snap = await citaRef(profesionalUid, citaId).get();
  return snap.data();
}

async function sembrarCitaPendiente({ pro, casaId, elementoId, registroId }) {
  await citaRef(pro.uid, 'cita-1').set({
    titulo: 'Visita', fecha: new Date(Date.now() + 3600_000), compartida: true,
    casaId, elementoId, registroId, todoElDia: false, completada: false,
    estado: 'pendienteConfirmacion',
  });
  return 'cita-1';
}

test('1. el propietario confirma una cita pendiente', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const citaId = await sembrarCitaPendiente({ pro, casaId, elementoId, registroId });

  const { error } = await llamar('responderCitaPropietario', owner.idToken, { profesionalUid: pro.uid, citaId, respuesta: 'confirmar' });
  assert.equal(error, undefined);

  const cita = await leerCita(pro.uid, citaId);
  assert.equal(cita.estado, 'confirmada');

  const historial = await esperarA(async () => {
    const h = await leerHistorial(casaId, elementoId, registroId);
    return h.find((x) => x.entidad === 'cita' && x.accion === 'confirmada') ? h : null;
  });
  assert.ok(historial.some((h) => h.accion === 'confirmada'));
  const notis = await esperarA(async () => {
    const n = await leerNotificaciones(pro.uid);
    return n.some((x) => x.tipo === 'cita_confirmada') ? n : null;
  });
  assert.ok(notis.some((n) => n.tipo === 'cita_confirmada'));
});

test('2. el propietario rechaza una cita pendiente', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const citaId = await sembrarCitaPendiente({ pro, casaId, elementoId, registroId });

  const { error } = await llamar('responderCitaPropietario', owner.idToken, { profesionalUid: pro.uid, citaId, respuesta: 'rechazar' });
  assert.equal(error, undefined);

  const cita = await leerCita(pro.uid, citaId);
  assert.equal(cita.estado, 'rechazada');
  const notis = await esperarA(async () => {
    const n = await leerNotificaciones(pro.uid);
    return n.some((x) => x.tipo === 'cita_rechazada') ? n : null;
  });
  assert.ok(notis.some((n) => n.tipo === 'cita_rechazada'));
});

test('3. un usuario que no pertenece a la casa no puede responder', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const ajeno = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const citaId = await sembrarCitaPendiente({ pro, casaId, elementoId, registroId });

  const { error } = await llamar('responderCitaPropietario', ajeno.idToken, { profesionalUid: pro.uid, citaId, respuesta: 'confirmar' });
  assert.equal(error?.status, 'PERMISSION_DENIED');

  const cita = await leerCita(pro.uid, citaId);
  assert.equal(cita.estado, 'pendienteConfirmacion', 'no debe haber cambiado');
});

test('4. una cita ya respondida no puede volver a responderse', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const citaId = await sembrarCitaPendiente({ pro, casaId, elementoId, registroId });

  const primera = await llamar('responderCitaPropietario', owner.idToken, { profesionalUid: pro.uid, citaId, respuesta: 'confirmar' });
  assert.equal(primera.error, undefined);

  const segunda = await llamar('responderCitaPropietario', owner.idToken, { profesionalUid: pro.uid, citaId, respuesta: 'rechazar' });
  assert.equal(segunda.error?.status, 'FAILED_PRECONDITION');

  const cita = await leerCita(pro.uid, citaId);
  assert.equal(cita.estado, 'confirmada', 'el segundo intento no debe sobrescribir la respuesta ya dada');
});

test('5. una cita no compartida no se puede responder, aunque el uid sea miembro de la casa', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  await citaRef(pro.uid, 'cita-privada').set({
    titulo: 'Nota personal', fecha: new Date(Date.now() + 3600_000), compartida: false,
    casaId, elementoId, registroId, todoElDia: false, completada: false, estado: 'pendienteConfirmacion',
  });

  const { error } = await llamar('responderCitaPropietario', owner.idToken, { profesionalUid: pro.uid, citaId: 'cita-privada', respuesta: 'confirmar' });
  assert.equal(error?.status, 'PERMISSION_DENIED');
});

test('6. el propietario propone otra fecha', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const citaId = await sembrarCitaPendiente({ pro, casaId, elementoId, registroId });
  const nuevaFecha = new Date(Date.now() + 86_400_000);

  const { error } = await llamar('proponerOtraFechaCita', owner.idToken, {
    profesionalUid: pro.uid, citaId, fecha: nuevaFecha.toISOString(),
  });
  assert.equal(error, undefined);

  const cita = await leerCita(pro.uid, citaId);
  assert.equal(cita.estado, 'contrapropuestaPropietario');
  assert.equal(cita.fechaPropuesta.toDate().getTime(), nuevaFecha.getTime());

  const notis = await esperarA(async () => {
    const n = await leerNotificaciones(pro.uid);
    return n.some((x) => x.tipo === 'cita_contrapropuesta') ? n : null;
  });
  assert.ok(notis.some((n) => n.tipo === 'cita_contrapropuesta'));
});

test('7. proponerOtraFechaCita sin fecha falla con invalid-argument', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const citaId = await sembrarCitaPendiente({ pro, casaId, elementoId, registroId });

  const { error } = await llamar('proponerOtraFechaCita', owner.idToken, { profesionalUid: pro.uid, citaId });
  assert.equal(error?.status, 'INVALID_ARGUMENT');
});

test('8. no se puede contraproponer dos veces seguidas sin que el profesional responda', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const citaId = await sembrarCitaPendiente({ pro, casaId, elementoId, registroId });

  const primera = await llamar('proponerOtraFechaCita', owner.idToken, {
    profesionalUid: pro.uid, citaId, fecha: new Date(Date.now() + 86_400_000).toISOString(),
  });
  assert.equal(primera.error, undefined);

  const segunda = await llamar('proponerOtraFechaCita', owner.idToken, {
    profesionalUid: pro.uid, citaId, fecha: new Date(Date.now() + 172_800_000).toISOString(),
  });
  assert.equal(segunda.error?.status, 'FAILED_PRECONDITION');
});

test('9. el profesional acepta la contrapropuesta -- un único evento "confirmada", nunca también "modificada"', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const citaId = await sembrarCitaPendiente({ pro, casaId, elementoId, registroId });
  const nuevaFecha = new Date(Date.now() + 86_400_000);

  await llamar('proponerOtraFechaCita', owner.idToken, { profesionalUid: pro.uid, citaId, fecha: nuevaFecha.toISOString() });
  await esperarA(async () => {
    const h = await leerHistorial(casaId, elementoId, registroId);
    return h.find((x) => x.entidad === 'cita' && x.accion === 'contrapropuesta') ? h : null;
  });

  // CitaService.responderContrapropuesta(aceptar: true) es escritura
  // directa del profesional sobre su propio documento -- se simula aquí
  // con Admin SDK, igual que el resto de este archivo simula al cliente.
  await citaRef(pro.uid, citaId).update({
    fecha: nuevaFecha,
    estado: 'confirmada',
    fechaPropuesta: require('firebase-admin/firestore').FieldValue.delete(),
  });

  const historial = await esperarA(async () => {
    const h = await leerHistorial(casaId, elementoId, registroId);
    return h.filter((x) => x.entidad === 'cita' && x.accion === 'confirmada').length > 0 ? h : null;
  });
  const eventosCita = historial.filter((h) => h.entidad === 'cita');
  // creada (al sembrar la cita) + contrapropuesta + confirmada -- nunca un
  // cuarto evento 'modificada' por el mismo cambio de fecha que ya queda
  // reflejado en 'confirmada'.
  assert.equal(eventosCita.length, 3, `eventos inesperados: ${JSON.stringify(eventosCita.map((e) => e.accion))}`);
  assert.equal(eventosCita.filter((e) => e.accion === 'modificada').length, 0);
});

test('10. el profesional declina la contrapropuesta -- vuelve a pendienteConfirmacion', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const citaId = await sembrarCitaPendiente({ pro, casaId, elementoId, registroId });

  await llamar('proponerOtraFechaCita', owner.idToken, {
    profesionalUid: pro.uid, citaId, fecha: new Date(Date.now() + 86_400_000).toISOString(),
  });
  await esperarA(async () => {
    const h = await leerHistorial(casaId, elementoId, registroId);
    return h.find((x) => x.entidad === 'cita' && x.accion === 'contrapropuesta') ? h : null;
  });

  const { FieldValue } = require('firebase-admin/firestore');
  await citaRef(pro.uid, citaId).update({
    estado: 'pendienteConfirmacion',
    fechaPropuesta: FieldValue.delete(),
  });

  const cita = await leerCita(pro.uid, citaId);
  assert.equal(cita.estado, 'pendienteConfirmacion');
  assert.equal(cita.fechaPropuesta, undefined);

  const historial = await esperarA(async () => {
    const h = await leerHistorial(casaId, elementoId, registroId);
    return h.find((x) => x.entidad === 'cita' && x.accion === 'contrapropuestaRechazada') ? h : null;
  });
  assert.ok(historial.some((h) => h.accion === 'contrapropuestaRechazada'));
});
