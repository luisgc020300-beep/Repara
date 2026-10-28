// functions-tests/elementos.test.js
//
// Archivar/restaurar un elemento (auditoría R5, octubre 2026): archivar NO
// es eliminar -- estas pruebas solo comprueban que archivarElemento/
// restaurarElemento (Cloud Functions reales, contra el emulador) autorizan
// o bloquean el cambio correctamente, nunca que borran nada. Contra el
// Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, idUnico } = require('./helpers');

async function crearCasaConElemento(ownerUid) {
  const casaId = idUnico('casa');
  const elementoId = idUnico('elemento');
  await db.collection('casas').doc(casaId).set({ nombre: 'Casa de prueba', ownerUid, members: [ownerUid] });
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).set({ nombre: 'Elemento de prueba' });
  return { casaId, elementoId };
}

async function anadirRegistro(casaId, elementoId, { esConProfesional = false, estado = 'nuevo', profesionalUid = null, presupuesto = null } = {}) {
  const registroId = idUnico('registro');
  await db
    .collection('casas').doc(casaId)
    .collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId)
    .set({
      titulo: 'Registro de prueba', estado, esConProfesional,
      ...(profesionalUid ? { profesionalUid } : {}),
      ...(presupuesto != null ? { presupuesto } : {}),
    });
  return registroId;
}

async function anadirPago(casaId, elementoId, registroId, importe) {
  await db
    .collection('casas').doc(casaId)
    .collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId)
    .collection('pagos').add({ importe, fecha: new Date(), createdBy: 'test' });
}

async function leerElemento(casaId, elementoId) {
  const snap = await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).get();
  return snap.data();
}

test('1. se puede archivar un elemento cuyo único registro ya está terminado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  await anadirRegistro(casaId, elementoId, { estado: 'terminado', esConProfesional: true });

  const { error } = await llamar('archivarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error, undefined);

  const elemento = await leerElemento(casaId, elementoId);
  assert.equal(elemento.archivado, true);
  assert.ok(elemento.archivadoAt);
  assert.equal(elemento.archivadoPorUid, owner.uid);
});

test('2. se bloquea archivar un elemento con trabajo profesional activo', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  await anadirRegistro(casaId, elementoId, { estado: 'enCurso', esConProfesional: true, profesionalUid: pro.uid });

  const { error } = await llamar('archivarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error?.status, 'FAILED_PRECONDITION');

  const elemento = await leerElemento(casaId, elementoId);
  assert.equal(elemento.archivado ?? false, false);
});

test('3. un elemento sin ningún registro también se puede archivar', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);

  const { error } = await llamar('archivarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error, undefined);
});

test('4. un usuario que no pertenece a la casa no puede archivar su elemento', async () => {
  const owner = await crearUsuario();
  const extrano = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);

  const { error } = await llamar('archivarElemento', extrano.idToken, { casaId, elementoId });
  assert.equal(error?.status, 'PERMISSION_DENIED');
});

test('5. no se puede archivar un elemento que ya está archivado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  const primero = await llamar('archivarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(primero.error, undefined);

  const segundo = await llamar('archivarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(segundo.error?.status, 'FAILED_PRECONDITION');
});

test('6. se puede restaurar un elemento archivado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  await llamar('archivarElemento', owner.idToken, { casaId, elementoId });

  const { error } = await llamar('restaurarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error, undefined);

  const elemento = await leerElemento(casaId, elementoId);
  assert.equal(elemento.archivado, false);
  assert.equal(elemento.archivadoAt, undefined);
  assert.equal(elemento.archivadoPorUid, undefined);
});

test('7. no se puede restaurar un elemento que no está archivado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);

  const { error } = await llamar('restaurarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error?.status, 'FAILED_PRECONDITION');
});

test('8. un usuario que no pertenece a la casa no puede restaurar su elemento', async () => {
  const owner = await crearUsuario();
  const extrano = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  await llamar('archivarElemento', owner.idToken, { casaId, elementoId });

  const { error } = await llamar('restaurarElemento', extrano.idToken, { casaId, elementoId });
  assert.equal(error?.status, 'PERMISSION_DENIED');
});

// Ejercita la transacción real de archivarElemento (tx.get() sobre la
// subcolección de registros) -- igual que el test 12 de cambios_alcance.
// test.js, no afirma quién "gana" la carrera entre archivar y que nazca un
// trabajo nuevo, solo que el resultado final nunca deja un elemento
// archivado con trabajo activo colgando debajo.
test('9. concurrencia: archivar a la vez que se crea un trabajo con profesional nunca deja el elemento archivado con trabajo activo', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);

  await Promise.all([
    llamar('archivarElemento', owner.idToken, { casaId, elementoId }),
    anadirRegistro(casaId, elementoId, { estado: 'nuevo', esConProfesional: true, profesionalUid: pro.uid }),
  ]);

  const elemento = await leerElemento(casaId, elementoId);
  const registrosSnap = await db
    .collection('casas').doc(casaId)
    .collection('elementos').doc(elementoId)
    .collection('registros').get();
  const hayTrabajoActivo = registrosSnap.docs.some((d) => {
    const r = d.data();
    return r.esConProfesional === true && r.estado !== 'terminado' && r.estado !== 'archivado';
  });
  if (elemento.archivado === true) {
    assert.equal(hayTrabajoActivo, false, 'si quedó archivado, no debe haber trabajo activo colgando debajo');
  }
});

// ── Saldo pendiente (auditoría R6, octubre 2026) ────────────────────────────

test('10. se bloquea archivar un elemento con saldo pendiente de pago (presupuesto sin ningún pago)', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  await anadirRegistro(casaId, elementoId, { estado: 'terminado', esConProfesional: true, presupuesto: 100 });

  const { error } = await llamar('archivarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error?.status, 'FAILED_PRECONDITION');

  const elemento = await leerElemento(casaId, elementoId);
  assert.equal(elemento.archivado ?? false, false);
});

test('11. se bloquea archivar un elemento con un pago parcial que no cubre el presupuesto', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  const registroId = await anadirRegistro(casaId, elementoId, { estado: 'terminado', esConProfesional: true, presupuesto: 100 });
  await anadirPago(casaId, elementoId, registroId, 60);

  const { error } = await llamar('archivarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error?.status, 'FAILED_PRECONDITION');
});

test('12. un registro con el presupuesto completamente cubierto por los pagos permite archivar', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  const registroId = await anadirRegistro(casaId, elementoId, { estado: 'terminado', esConProfesional: true, presupuesto: 100 });
  await anadirPago(casaId, elementoId, registroId, 60);
  await anadirPago(casaId, elementoId, registroId, 40);

  const { error } = await llamar('archivarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error, undefined);

  const elemento = await leerElemento(casaId, elementoId);
  assert.equal(elemento.archivado, true);
});

test('13. un registro sin presupuesto fijado (null) nunca bloquea el archivado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  await anadirRegistro(casaId, elementoId, { estado: 'terminado', esConProfesional: false });

  const { error } = await llamar('archivarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error, undefined);
});

// Ejercita la transacción real: igual que el test 9, no afirma quién "gana"
// la carrera entre archivar y registrar un pago, solo que el resultado
// final nunca deja un elemento archivado con un saldo real sin cubrir.
test('14. concurrencia: archivar a la vez que se registra un pago nunca deja el elemento archivado con saldo pendiente', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  const registroId = await anadirRegistro(casaId, elementoId, { estado: 'terminado', esConProfesional: true, presupuesto: 100 });

  await Promise.all([
    llamar('archivarElemento', owner.idToken, { casaId, elementoId }),
    llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() }),
  ]);

  const elemento = await leerElemento(casaId, elementoId);
  if (elemento.archivado === true) {
    const pagosSnap = await db
      .collection('casas').doc(casaId)
      .collection('elementos').doc(elementoId)
      .collection('registros').doc(registroId)
      .collection('pagos').get();
    const totalPagado = pagosSnap.docs.reduce((acc, d) => acc + (Number(d.data().importe) || 0), 0);
    assert.ok(totalPagado >= 100 - 0.01, 'si quedó archivado, el saldo debe estar realmente cubierto, no solo "ganada la carrera"');
  }
});
