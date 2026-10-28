// functions-tests/payments.test.js
//
// DATA-1 (auditoría de integridad económica, octubre 2026): los pagos
// (registrarPago/actualizarPago) deben validar el total acumulado contra el
// presupuesto DENTRO de una transacción en servidor, no en el cliente antes
// de escribir. Contra el Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, sembrarRegistro, leerRegistro, leerPagos } = require('./helpers');

async function archivar(casaId, elementoId) {
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).set({ archivado: true }, { merge: true });
}

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

// ── Coherencia económica de elementos archivados (auditoría R8, H4) ────────

test('H4-1. se bloquea reducir un pago si eso dejaría un saldo pendiente en un elemento archivado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() });
  await archivar(casaId, elementoId);

  const { error } = await llamar('actualizarPago', owner.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId, importe: 50, fecha: Date.now() });
  assert.equal(error?.status, 'FAILED_PRECONDITION');

  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos[0].importe, 100, 'el pago no debe haberse modificado');
});

test('H4-2. se puede editar un pago de un elemento archivado si sigue cubriendo el presupuesto', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() });
  await archivar(casaId, elementoId);

  // Mismo importe, solo cambia el concepto -- sigue cubriendo el presupuesto.
  const { error } = await llamar('actualizarPago', owner.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId, importe: 100, fecha: Date.now(), concepto: 'Pago final' });
  assert.equal(error, undefined);
});

test('H4-3. se bloquea borrar un pago si eso dejaría un saldo pendiente en un elemento archivado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() });
  await archivar(casaId, elementoId);

  const { error } = await llamar('eliminarPago', owner.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId });
  assert.equal(error?.status, 'FAILED_PRECONDITION');

  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos.length, 1, 'el pago no debe haberse borrado');
});

// Nota de diseño: no existe ningún estado real alcanzable donde la suma de
// pagos supere el presupuesto (registrarPago ya lo impide siempre, ver test
// 2 de este mismo fichero), así que "borrar un pago sobrante y seguir
// cubierto" no es un escenario reproducible con datos legítimos -- en vez
// de forzar un estado artificial, este test cubre el camino permitido real:
// un registro SIN presupuesto fijado nunca tiene saldo que proteger.
test('H4-4. eliminarPago nunca bloquea un pago de un registro sin presupuesto fijado, aunque el elemento esté archivado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 40, fecha: Date.now() });
  await archivar(casaId, elementoId);

  const { error } = await llamar('eliminarPago', owner.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId });
  assert.equal(error, undefined);

  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos.length, 0);
});

test('H4-5. un elemento activo (no archivado) sigue permitiendo reducir o borrar un pago libremente, igual que antes', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() });

  const reducir = await llamar('actualizarPago', owner.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId, importe: 10, fecha: Date.now() });
  assert.equal(reducir.error, undefined);

  const borrar = await llamar('eliminarPago', owner.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId });
  assert.equal(borrar.error, undefined);

  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos.length, 0);
});

test('H4-6. eliminarPago rechaza a quien no sea el que registró el pago', async () => {
  const owner = await crearUsuario();
  const otroMiembro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });
  await db.collection('casas').doc(casaId).update({ members: [owner.uid, otroMiembro.uid] });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 40, fecha: Date.now() });

  const { error } = await llamar('eliminarPago', otroMiembro.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId });
  assert.equal(error?.status, 'PERMISSION_DENIED');

  const pagos = await leerPagos(casaId, elementoId, registroId);
  assert.equal(pagos.length, 1, 'el rechazo no debe haber borrado el pago');
});

test('H4-7. eliminarPago rechaza una llamada sin autenticar', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, presupuesto: 100 });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 40, fecha: Date.now() });

  const { error } = await llamar('eliminarPago', null, { casaId, elementoId, registroId, pagoId: result.pagoId });
  assert.equal(error?.status, 'UNAUTHENTICATED');
});

// No afirma quién "gana" la carrera entre archivar y borrar el pago que
// cubre el presupuesto -- solo que el resultado final nunca deja el
// elemento archivado con un saldo real sin cubrir (mismo criterio que los
// tests de concurrencia de elementos.test.js).
test('H4-8. concurrencia: archivar a la vez que se borra el pago que cubre el presupuesto nunca deja el elemento archivado con saldo pendiente', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'terminado', presupuesto: 100 });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() });

  await Promise.all([
    llamar('archivarElemento', owner.idToken, { casaId, elementoId }),
    llamar('eliminarPago', owner.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId }),
  ]);

  const elemento = await (await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).get()).data();
  if (elemento.archivado === true) {
    const pagos = await leerPagos(casaId, elementoId, registroId);
    const totalPagado = pagos.reduce((acc, p) => acc + (Number(p.importe) || 0), 0);
    assert.ok(totalPagado >= 100 - 0.01, 'si quedó archivado, el saldo debe seguir realmente cubierto');
  }
});

// R9-H5 (auditoría R9, cerrado en R10, octubre 2026): existía ya un test de
// concurrencia archivarElemento-vs-eliminarPago (H4-8, arriba), pero ninguno
// equivalente para archivarElemento-vs-actualizarPago, pese a que el
// mecanismo transaccional es idéntico. Mismo criterio que H4-8 y que los
// tests de elementos.test.js: Promise.all no garantiza qué llamada "gana" --
// el emulador decide la intercalación real de E/S, y no existe en este
// repositorio (ni se añade aquí) ningún gancho de prueba que fuerce un
// orden exacto dentro del código de producción. Lo que SÍ se puede, y es lo
// que de verdad importa, es comprobar el INVARIANTE sobre los documentos
// finales reales en Firestore -- no solo el código de error de cada
// llamada -- pase lo que pase con el orden real de esta ejecución.
async function leerElementoArchivado(casaId, elementoId) {
  const snap = await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).get();
  return snap.data()?.archivado === true;
}

test('H5-1. concurrencia: archivar un elemento a la vez que se reduce el pago que lo cubre nunca deja un elemento archivado con saldo pendiente', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'terminado', presupuesto: 100 });
  const { result } = await llamar('registrarPago', owner.idToken, { casaId, elementoId, registroId, importe: 100, fecha: Date.now() });

  const [archivarResultado, actualizarResultado] = await Promise.all([
    llamar('archivarElemento', owner.idToken, { casaId, elementoId }),
    llamar('actualizarPago', owner.idToken, { casaId, elementoId, registroId, pagoId: result.pagoId, importe: 30, fecha: Date.now() }),
  ]);

  // Verificación real: los documentos finales en Firestore, no el mensaje
  // de error de ninguna de las dos llamadas.
  const quedoArchivado = await leerElementoArchivado(casaId, elementoId);
  const pagos = await leerPagos(casaId, elementoId, registroId);
  const totalPagadoFinal = pagos.reduce((acc, p) => acc + (Number(p.importe) || 0), 0);

  if (quedoArchivado) {
    // Si quedó archivado, el saldo tiene que seguir realmente cubierto --
    // eso solo es posible si la reducción del pago NO se aplicó (debió
    // bloquearse) o si se aplicó antes de que el archivado empezara a
    // comprobar (lo que, de nuevo, significaría que no debería haber
    // podido archivarse con un saldo descubierto).
    assert.ok(
      totalPagadoFinal >= 100 - 0.01,
      `quedó archivado pero el saldo pagado real es ${totalPagadoFinal} de 100 -- saldo pendiente en un elemento archivado`,
    );
  } else {
    // Si no quedó archivado, la reducción del pago pudo aplicarse sin
    // ningún problema -- no hay ninguna garantía de archivado que proteger.
    assert.ok(true);
  }

  // Nunca deben haber "ganado" las dos operaciones de forma incoherente: si
  // el pago se redujo A 30 Y el elemento quedó archivado, eso es
  // exactamente el defecto que se está comprobando.
  const pagoFinal = pagos.find((p) => p.id === result.pagoId);
  if (quedoArchivado && pagoFinal) {
    assert.notEqual(pagoFinal.importe, 30, 'el pago no debió poder reducirse a 30 si el elemento terminó archivado con ese saldo');
  }

  console.log(
    `[concurrencia H5] archivado=${quedoArchivado}, importe final del pago=${pagoFinal?.importe}, ` +
    `archivarElemento.error=${archivarResultado.error?.status}, actualizarPago.error=${actualizarResultado.error?.status}`,
  );
});
