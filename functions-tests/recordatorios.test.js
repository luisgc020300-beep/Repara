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

function elementoRef(casaId, elementoId) {
  return db.collection('casas').doc(casaId).collection('elementos').doc(elementoId);
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

// =============================================================================
// GARANTÍAS Y MANTENIMIENTO (sistema de notificaciones activas, noviembre
// 2026) -- mismo patrón de deduplicación por marcador en el propio
// documento que citas/presupuestos arriba, aplicado a elementos.
// =============================================================================

test('10. una garantía que caduca en 5 días avisa con el umbral de 7 días', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await elementoRef(casaId, elementoId).update({
    nombre: 'Caldera', garantiaHasta: new Date(ahoraMs + 5 * 24 * 60 * 60 * 1000),
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  const aviso = notis.find((n) => n.tipo === 'garantia_proxima_vencer');
  assert.ok(aviso, 'debe avisar de la garantía próxima');
  assert.match(aviso.cuerpo, /7 días/);
});

test('11. una garantía que caduca hoy avisa con el umbral 0', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await elementoRef(casaId, elementoId).update({
    nombre: 'Caldera', garantiaHasta: new Date(ahoraMs),
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  const aviso = notis.find((n) => n.tipo === 'garantia_proxima_vencer');
  assert.ok(aviso);
  assert.match(aviso.cuerpo, /caduca hoy/);
});

test('12. repetir enviarRecordatorios para la misma garantía no duplica el aviso', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await elementoRef(casaId, elementoId).update({
    nombre: 'Caldera', garantiaHasta: new Date(ahoraMs + 5 * 24 * 60 * 60 * 1000),
  });

  await _enviarRecordatoriosParaTests(ahoraMs);
  await _enviarRecordatoriosParaTests(ahoraMs + 60_000);

  const notis = await leerNotificaciones(owner.uid);
  const avisos = notis.filter((n) => n.tipo === 'garantia_proxima_vencer');
  assert.equal(avisos.length, 1);
});

test('13. tras avisar del umbral de 7 días, entrar en el umbral de 0 días genera un segundo aviso', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await elementoRef(casaId, elementoId).update({
    nombre: 'Caldera', garantiaHasta: new Date(ahoraMs + 5 * 24 * 60 * 60 * 1000),
  });
  await _enviarRecordatoriosParaTests(ahoraMs);

  // Pasan los días -- misma fecha de garantía, ahora el umbral es 0.
  const cincoDiasDespues = ahoraMs + 5 * 24 * 60 * 60 * 1000;
  await _enviarRecordatoriosParaTests(cincoDiasDespues);

  const notis = await leerNotificaciones(owner.uid);
  const avisos = notis.filter((n) => n.tipo === 'garantia_proxima_vencer');
  assert.equal(avisos.length, 2, 'un umbral más cercano al vencimiento debe generar un aviso nuevo');
});

test('14. cambiar la fecha de garantía después de avisar permite un nuevo aviso con el mismo umbral', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await elementoRef(casaId, elementoId).update({
    nombre: 'Caldera', garantiaHasta: new Date(ahoraMs + 5 * 24 * 60 * 60 * 1000),
  });
  await _enviarRecordatoriosParaTests(ahoraMs);

  // Se edita el elemento con una garantía nueva, de otro producto -- vuelve
  // a caer en el mismo umbral de 7, pero es un dato distinto.
  await elementoRef(casaId, elementoId).update({ garantiaHasta: new Date(ahoraMs + 6 * 24 * 60 * 60 * 1000) });
  await _enviarRecordatoriosParaTests(ahoraMs + 60_000);

  const notis = await leerNotificaciones(owner.uid);
  const avisos = notis.filter((n) => n.tipo === 'garantia_proxima_vencer');
  assert.equal(avisos.length, 2, 'una fecha de garantía distinta debe reabrir el aviso');
});

test('15. un elemento archivado con garantía próxima nunca avisa', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await elementoRef(casaId, elementoId).update({
    nombre: 'Caldera', garantiaHasta: new Date(ahoraMs + 5 * 24 * 60 * 60 * 1000), archivado: true,
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo === 'garantia_proxima_vencer'), false);
});

test('16. una garantía caducada desde hace meses (ya así antes del despliegue) no avisa retroactivamente', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await elementoRef(casaId, elementoId).update({
    nombre: 'Caldera vieja', garantiaHasta: new Date(ahoraMs - 90 * 24 * 60 * 60 * 1000),
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo === 'garantia_proxima_vencer'), false);
});

test('17. un mantenimiento próximo en 3 días avisa con el umbral de 7 días', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await elementoRef(casaId, elementoId).update({
    nombre: 'Caldera', proximoMantenimiento: new Date(ahoraMs + 3 * 24 * 60 * 60 * 1000),
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  const aviso = notis.find((n) => n.tipo === 'mantenimiento_pendiente');
  assert.ok(aviso);
  assert.match(aviso.cuerpo, /próximo/);
});

test('18. un mantenimiento vencido desde hace 2 días avisa como pendiente atrasado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await elementoRef(casaId, elementoId).update({
    nombre: 'Caldera', proximoMantenimiento: new Date(ahoraMs - 2 * 24 * 60 * 60 * 1000),
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  const aviso = notis.find((n) => n.tipo === 'mantenimiento_pendiente');
  assert.ok(aviso);
  assert.match(aviso.cuerpo, /pendiente desde hace días/);
});

test('19. marcar la revisión como hecha (nueva fecha) reabre el aviso de mantenimiento', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await elementoRef(casaId, elementoId).update({
    nombre: 'Caldera', proximoMantenimiento: new Date(ahoraMs),
  });
  await _enviarRecordatoriosParaTests(ahoraMs);

  // Equivalente a ElementoService.marcarRevisionHecha: avanza la próxima
  // revisión -- mismo campo que ya escribe el cliente directamente.
  await elementoRef(casaId, elementoId).update({ proximoMantenimiento: new Date(ahoraMs + 3 * 24 * 60 * 60 * 1000) });
  await _enviarRecordatoriosParaTests(ahoraMs + 60_000);

  const notis = await leerNotificaciones(owner.uid);
  const avisos = notis.filter((n) => n.tipo === 'mantenimiento_pendiente');
  assert.equal(avisos.length, 2, 'la nueva fecha de revisión debe generar un aviso propio');
});

test('20. un elemento archivado con mantenimiento vencido nunca avisa', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await sembrarRegistro({ ownerUid: owner.uid });
  const ahoraMs = Date.now();
  await elementoRef(casaId, elementoId).update({
    nombre: 'Caldera', proximoMantenimiento: new Date(ahoraMs - 2 * 24 * 60 * 60 * 1000), archivado: true,
  });

  await _enviarRecordatoriosParaTests(ahoraMs);

  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo === 'mantenimiento_pendiente'), false);
});
