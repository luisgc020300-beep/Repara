// functions-tests/recordatorios.test.js
//
// enviarRecordatorios (noviembre 2026) -- primera Cloud Function de este
// proyecto disparada por reloj en vez de por una acción de usuario. Esta
// sesión no despliega Cloud Functions, así que no hay scheduler real que
// invocar: se llama directamente a _enviarRecordatoriosParaTests(ahoraMs),
// el punto de entrada de solo test que expone functions/index.js, con una
// fecha fija inyectada -- nunca se depende del paso real del tiempo. Ver la
// limitación declarada en la cabecera de ese bloque en functions/index.js:
// esto prueba la LÓGICA (selección, deduplicación, auto-sanado), nunca la
// fiabilidad real de Cloud Scheduler en producción.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, sembrarRegistro, leerNotificaciones } = require('./helpers');
const { _enviarRecordatoriosParaTests } = require('../functions/index.js');

function citaRef(profesionalUid, citaId) {
  return db.collection('profesionales').doc(profesionalUid).collection('citas').doc(citaId);
}

test('1. una cita compartida dentro de la ventana de antelación avisa a cliente y profesional', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const ahoraMs = Date.now();
  await citaRef(pro.uid, 'cita-1').set({
    titulo: 'Visita', fecha: new Date(ahoraMs + 60 * 60 * 1000), compartida: true,
    casaId, elementoId, registroId, todoElDia: false, completada: false,
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notisCliente = await leerNotificaciones(owner.uid);
  assert.ok(notisCliente.some((n) => n.tipo === 'recordatorio_cita_cliente'));
  const notisPro = await leerNotificaciones(pro.uid);
  assert.ok(notisPro.some((n) => n.tipo === 'recordatorio_cita_profesional'));
});

test('2. ejecutar enviarRecordatorios dos veces para la misma cita no duplica el aviso', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const ahoraMs = Date.now();
  await citaRef(pro.uid, 'cita-1').set({
    titulo: 'Visita', fecha: new Date(ahoraMs + 60 * 60 * 1000), compartida: true,
    casaId, elementoId, registroId, todoElDia: false, completada: false,
  });

  await _enviarRecordatoriosParaTests(ahoraMs);
  await _enviarRecordatoriosParaTests(ahoraMs + 60_000);

  const notis = await leerNotificaciones(owner.uid);
  const avisos = notis.filter((n) => n.tipo === 'recordatorio_cita_cliente');
  assert.equal(avisos.length, 1, 'no debe repetirse el mismo recordatorio');
});

test('3. cambiar la fecha de la cita después de avisar permite un nuevo recordatorio', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const ahoraMs = Date.now();
  await citaRef(pro.uid, 'cita-1').set({
    titulo: 'Visita', fecha: new Date(ahoraMs + 60 * 60 * 1000), compartida: true,
    casaId, elementoId, registroId, todoElDia: false, completada: false,
  });
  await _enviarRecordatoriosParaTests(ahoraMs);

  // La visita se retrasa, pero sigue dentro de la ventana de 120 min.
  await citaRef(pro.uid, 'cita-1').update({ fecha: new Date(ahoraMs + 90 * 60 * 1000) });
  await _enviarRecordatoriosParaTests(ahoraMs + 60_000);

  const notis = await leerNotificaciones(owner.uid);
  const avisos = notis.filter((n) => n.tipo === 'recordatorio_cita_cliente');
  assert.equal(avisos.length, 2, 'la nueva fecha debe generar un recordatorio nuevo');
});

test('4. una cita compartida demasiado lejana todavía no genera recordatorio', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const ahoraMs = Date.now();
  await citaRef(pro.uid, 'cita-lejana').set({
    titulo: 'Visita', fecha: new Date(ahoraMs + 5 * 60 * 60 * 1000), compartida: true,
    casaId, elementoId, registroId, todoElDia: false, completada: false,
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo === 'recordatorio_cita_cliente'), false);
});

test('5. una cita NO compartida dentro de la ventana no genera recordatorio', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const ahoraMs = Date.now();
  await citaRef(pro.uid, 'cita-privada').set({
    titulo: 'Nota', fecha: new Date(ahoraMs + 60 * 60 * 1000), compartida: false,
    casaId, elementoId, registroId, todoElDia: false, completada: false,
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo === 'recordatorio_cita_cliente'), false);
});

test('6. un presupuesto enviado hace más de 3 días sin respuesta avisa a la casa', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const ahoraMs = Date.now();
  const hace4Dias = new Date(ahoraMs - 4 * 24 * 60 * 60 * 1000);
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).collection('presupuestos').add({
      estado: 'enviado', creadoPorUid: pro.uid, total: 150, fechaEnvio: hace4Dias, titulo: 'Presupuesto',
    });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  assert.ok(notis.some((n) => n.tipo === 'presupuesto_sin_respuesta'));
});

test('7. un presupuesto enviado hace 1 día todavía no avisa', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const ahoraMs = Date.now();
  const hace1Dia = new Date(ahoraMs - 1 * 24 * 60 * 60 * 1000);
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).collection('presupuestos').add({
      estado: 'enviado', creadoPorUid: pro.uid, total: 150, fechaEnvio: hace1Dia, titulo: 'Presupuesto',
    });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo === 'presupuesto_sin_respuesta'), false);
});

test('8. un presupuesto ya aceptado, aunque sea antiguo, nunca avisa', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const ahoraMs = Date.now();
  const hace10Dias = new Date(ahoraMs - 10 * 24 * 60 * 60 * 1000);
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).collection('presupuestos').add({
      estado: 'aceptado', creadoPorUid: pro.uid, total: 150, fechaEnvio: hace10Dias, titulo: 'Presupuesto',
    });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo === 'presupuesto_sin_respuesta'), false);
});

test('9. repetir enviarRecordatorios no duplica el aviso de presupuesto sin respuesta', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });
  const ahoraMs = Date.now();
  const hace4Dias = new Date(ahoraMs - 4 * 24 * 60 * 60 * 1000);
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).collection('presupuestos').add({
      estado: 'enviado', creadoPorUid: pro.uid, total: 150, fechaEnvio: hace4Dias, titulo: 'Presupuesto',
    });

  await _enviarRecordatoriosParaTests(ahoraMs);
  await _enviarRecordatoriosParaTests(ahoraMs + 60_000);

  const notis = await leerNotificaciones(owner.uid);
  const avisos = notis.filter((n) => n.tipo === 'presupuesto_sin_respuesta');
  assert.equal(avisos.length, 1);
});
