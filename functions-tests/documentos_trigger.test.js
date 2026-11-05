// functions-tests/documentos_trigger.test.js
//
// onDocumentoCreado (noviembre 2026): añadir un documento/foto ligado a un
// registro con profesional vinculado debe avisar al lado que NO lo subió y
// dejar un evento de historial -- antes era una escritura silenciosa, sin
// rastro ni aviso para nadie. Un documento sin registroId/elementoId (suelto
// de la casa) o sobre un registro sin profesional no genera nada, porque no
// hay "otro lado" a quien avisar.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, sembrarRegistro, leerHistorial, leerNotificaciones, esperarA } = require('./helpers');

test('1. el profesional sube un documento -- avisa a los miembros de la casa', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });

  await db.collection('casas').doc(casaId).collection('documentos').add({
    url: 'https://x/factura.pdf', nombreArchivo: 'factura.pdf', tipo: 'factura',
    elementoId, registroId, estadoIA: 'manual', creadoPorIA: false, createdBy: pro.uid,
  });

  const notis = await esperarA(async () => {
    const n = await leerNotificaciones(owner.uid);
    return n.some((x) => x.tipo === 'documento_anadido_cliente') ? n : null;
  });
  assert.ok(notis.some((n) => n.tipo === 'documento_anadido_cliente'));
  const historial = await leerHistorial(casaId, elementoId, registroId);
  assert.ok(historial.some((h) => h.entidad === 'documento' && h.actorUid === pro.uid));
});

test('2. el propietario sube un documento -- avisa al profesional vinculado', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo', profesionalUid: pro.uid });

  await db.collection('casas').doc(casaId).collection('documentos').add({
    url: 'https://x/garantia.pdf', nombreArchivo: 'garantia.pdf', tipo: 'garantia',
    elementoId, registroId, estadoIA: 'manual', creadoPorIA: false, createdBy: owner.uid,
  });

  const notis = await esperarA(async () => {
    const n = await leerNotificaciones(pro.uid);
    return n.some((x) => x.tipo === 'documento_anadido_profesional') ? n : null;
  });
  assert.ok(notis.some((n) => n.tipo === 'documento_anadido_profesional'));
});

test('3. un documento sobre un registro SIN profesional no genera ningún aviso', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });

  await db.collection('casas').doc(casaId).collection('documentos').add({
    url: 'https://x/nota.pdf', nombreArchivo: 'nota.pdf', tipo: 'otro',
    elementoId, registroId, estadoIA: 'manual', creadoPorIA: false, createdBy: owner.uid,
  });

  await new Promise((r) => setTimeout(r, 3000));
  const historial = await leerHistorial(casaId, elementoId, registroId);
  assert.equal(historial.some((h) => h.entidad === 'documento'), false);
});

test('4. un documento suelto de la casa (sin registroId) no genera ningún aviso', async () => {
  const owner = await crearUsuario();
  const { casaId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'nuevo' });

  const ref = await db.collection('casas').doc(casaId).collection('documentos').add({
    url: 'https://x/manual.pdf', nombreArchivo: 'manual.pdf', tipo: 'manual',
    estadoIA: 'manual', creadoPorIA: false, createdBy: owner.uid,
  });

  await new Promise((r) => setTimeout(r, 3000));
  const notis = await leerNotificaciones(owner.uid);
  assert.equal(notis.some((n) => n.tipo?.startsWith('documento_anadido')), false);
  assert.ok(ref.id);
});
