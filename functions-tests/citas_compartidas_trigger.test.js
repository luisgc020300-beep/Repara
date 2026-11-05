// functions-tests/citas_compartidas_trigger.test.js
//
// onCitaEscrita (noviembre 2026): crear/modificar/cancelar una cita
// compartida=true que enlaza un trabajo debe avisar a la casa y dejar un
// evento de historial bajo ESE registro -- una cita privada (compartida
// false en los dos lados) nunca debe generar nada. El permiso de lectura en
// sí (firestore.rules) se prueba en firestore-tests/rules.test.js; aquí solo
// se prueba el trigger. Escribe directo con Admin SDK (como haría
// CitaService desde el cliente) y sondea con esperarA() porque el trigger
// corre después de que la escritura ya se confirmó.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, sembrarRegistro, leerHistorial, leerNotificaciones, esperarA } = require('./helpers');

function citaRef(profesionalUid, citaId) {
  return db.collection('profesionales').doc(profesionalUid).collection('citas').doc(citaId);
}

test('1. crear una cita compartida avisa a la casa y deja un evento de historial', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });

  await citaRef(pro.uid, 'cita-1').set({
    titulo: 'Visita', fecha: new Date(Date.now() + 3600_000), compartida: true,
    casaId, elementoId, registroId, todoElDia: false, completada: false,
  });

  await esperarA(async () => {
    const historial = await leerHistorial(casaId, elementoId, registroId);
    return historial.find((h) => h.entidad === 'cita');
  });
  const notis = await esperarA(async () => {
    const n = await leerNotificaciones(owner.uid);
    return n.some((x) => x.tipo === 'cita_creada') ? n : null;
  });
  assert.ok(notis.some((n) => n.tipo === 'cita_creada'));
});

test('2. una cita privada (nunca compartida) no genera historial ni notificación', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });

  await citaRef(pro.uid, 'cita-privada').set({
    titulo: 'Nota personal', fecha: new Date(Date.now() + 3600_000), compartida: false,
    casaId, elementoId, registroId, todoElDia: false, completada: false,
  });

  // Da tiempo de sobra a que el trigger, si fuera a disparar algo, lo haga.
  await new Promise((r) => setTimeout(r, 3000));
  const historial = await leerHistorial(casaId, elementoId, registroId);
  assert.equal(historial.some((h) => h.entidad === 'cita'), false);
  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo === 'cita_creada'), false);
});

test('3. modificar la fecha de una cita ya compartida avisa de nuevo (modificada)', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });

  await citaRef(pro.uid, 'cita-1').set({
    titulo: 'Visita', fecha: new Date(Date.now() + 3600_000), compartida: true,
    casaId, elementoId, registroId, todoElDia: false, completada: false,
  });
  await esperarA(async () => {
    const historial = await leerHistorial(casaId, elementoId, registroId);
    return historial.find((h) => h.entidad === 'cita' && h.accion === 'creada');
  });

  await citaRef(pro.uid, 'cita-1').update({ fecha: new Date(Date.now() + 7200_000) });

  await esperarA(async () => {
    const historial = await leerHistorial(casaId, elementoId, registroId);
    return historial.find((h) => h.entidad === 'cita' && h.accion === 'modificada');
  });
  const notis = await esperarA(async () => {
    const n = await leerNotificaciones(owner.uid);
    return n.filter((x) => x.tipo === 'cita_modificada').length > 0 ? n : null;
  });
  assert.ok(notis.some((n) => n.tipo === 'cita_modificada'));
});

test('4. marcar completada (sin cambiar fecha/hora/título) no genera un evento nuevo', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });

  await citaRef(pro.uid, 'cita-1').set({
    titulo: 'Visita', fecha: new Date(Date.now() + 3600_000), compartida: true,
    casaId, elementoId, registroId, todoElDia: false, completada: false,
  });
  await esperarA(async () => {
    const historial = await leerHistorial(casaId, elementoId, registroId);
    return historial.find((h) => h.entidad === 'cita');
  });

  await citaRef(pro.uid, 'cita-1').update({ completada: true });
  await new Promise((r) => setTimeout(r, 3000));

  const historial = await leerHistorial(casaId, elementoId, registroId);
  const eventosCita = historial.filter((h) => h.entidad === 'cita');
  assert.equal(eventosCita.length, 1, 'solo el de creación -- completar no debe añadir uno nuevo');
});

test('5. cancelar (borrar) una cita compartida avisa de que se canceló', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });

  await citaRef(pro.uid, 'cita-1').set({
    titulo: 'Visita', fecha: new Date(Date.now() + 3600_000), compartida: true,
    casaId, elementoId, registroId, todoElDia: false, completada: false,
  });
  await esperarA(async () => {
    const historial = await leerHistorial(casaId, elementoId, registroId);
    return historial.find((h) => h.entidad === 'cita');
  });

  await citaRef(pro.uid, 'cita-1').delete();

  await esperarA(async () => {
    const historial = await leerHistorial(casaId, elementoId, registroId);
    return historial.find((h) => h.entidad === 'cita' && h.accion === 'cancelada');
  });
  const notis = await esperarA(async () => {
    const n = await leerNotificaciones(owner.uid);
    return n.some((x) => x.tipo === 'cita_cancelada') ? n : null;
  });
  assert.ok(notis.some((n) => n.tipo === 'cita_cancelada'));
});
