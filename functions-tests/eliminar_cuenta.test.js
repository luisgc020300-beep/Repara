// functions-tests/eliminar_cuenta.test.js
//
// eliminarCuenta (auditoría R9-H1, cerrado en R10, octubre 2026): la versión
// anterior comprobaba "¿eres propietario único?" casa por casa, DENTRO del
// mismo bucle que ya borraba -- si el usuario era propietario único de la
// primera casa de la lista (que se borraba sin problema, de forma
// irreversible) y propietario compartido de la segunda, la función lanzaba
// el error al llegar a la segunda, dejando la cuenta a medias: una casa ya
// borrada para siempre, la cuenta de Authentication todavía viva. Contra el
// Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, admin, crearUsuario, llamar, crearCasa, fijarCasaIds, subirArchivoStorage, existeArchivoStorage } = require('./helpers');

async function existeCasa(casaId) {
  const snap = await db.collection('casas').doc(casaId).get();
  return snap.exists;
}

async function existeJoinCode(joinCode) {
  const snap = await db.collection('joinCodes').doc(joinCode).get();
  return snap.exists;
}

async function existeUsuarioAuth(uid) {
  try {
    await admin.auth().getUser(uid);
    return true;
  } catch (e) {
    if (e.code === 'auth/user-not-found') return false;
    throw e;
  }
}

test('1. propietario único de una sola casa: se borra la casa, el perfil, la cuenta, el joinCode y los archivos reales de Storage', async () => {
  const owner = await crearUsuario();
  const casaId = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });
  const joinCode = `TEST-${casaId}`;
  await db.collection('casas').doc(casaId).update({ joinCode });
  await db.collection('joinCodes').doc(joinCode).set({ casaId });
  await fijarCasaIds(owner.uid, [casaId]);

  // Archivo real en el emulador de Storage (no un mock) -- auditoría R11:
  // antes de R11 esta prueba solo comprobaba que la llamada no lanzaba
  // error, nunca que Storage se hubiera limpiado de verdad.
  const rutaArchivo = `casas/${casaId}/documento-prueba.txt`;
  await subirArchivoStorage(rutaArchivo);
  assert.equal(await existeArchivoStorage(rutaArchivo), true, 'el archivo de prueba debe existir antes de borrar la cuenta');

  const { error } = await llamar('eliminarCuenta', owner.idToken, {});
  assert.equal(error, undefined, JSON.stringify(error));

  assert.equal(await existeCasa(casaId), false);
  assert.equal(await existeJoinCode(joinCode), false, 'el joinCode también debe limpiarse');
  assert.equal(await existeArchivoStorage(rutaArchivo), false, 'el archivo real de Storage debe haberse borrado de verdad');
  assert.equal((await db.collection('users').doc(owner.uid).get()).exists, false);
  assert.equal(await existeUsuarioAuth(owner.uid), false);
});

test('2. propietario único de varias casas: se borran todas', async () => {
  const owner = await crearUsuario();
  const casaA = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });
  const casaB = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });
  await fijarCasaIds(owner.uid, [casaA, casaB]);

  const { error } = await llamar('eliminarCuenta', owner.idToken, {});
  assert.equal(error, undefined, JSON.stringify(error));

  assert.equal(await existeCasa(casaA), false);
  assert.equal(await existeCasa(casaB), false);
  assert.equal(await existeUsuarioAuth(owner.uid), false);
});

// Este es el escenario exacto de R9-H1: la casa eliminable va PRIMERO en la
// lista -- con el código anterior, se borraba sin problema antes de que la
// función lanzara el error al llegar a la segunda (compartida).
test('3. una casa compartida bloquea TODO el proceso, incluida una casa eliminable que iba antes en la lista', async () => {
  const owner = await crearUsuario();
  const otroMiembro = await crearUsuario();
  const casaEliminable = await crearCasa({ ownerUid: owner.uid, members: [owner.uid], nombre: 'Eliminable' });
  const casaCompartida = await crearCasa({ ownerUid: owner.uid, members: [owner.uid, otroMiembro.uid], nombre: 'Compartida' });
  await fijarCasaIds(owner.uid, [casaEliminable, casaCompartida]);

  const { error } = await llamar('eliminarCuenta', owner.idToken, {});
  assert.equal(error?.status, 'FAILED_PRECONDITION');

  // La aserción real de esta prueba: NINGUNA de las dos casas se tocó,
  // tampoco la que sí era eliminable por su cuenta sola.
  assert.equal(await existeCasa(casaEliminable), true, 'la casa eliminable NUNCA debió borrarse si otra casa bloquea el proceso completo');
  assert.equal(await existeCasa(casaCompartida), true);
  assert.equal(await existeUsuarioAuth(owner.uid), true, 'la cuenta tampoco debe tocarse si el proceso se bloquea de antemano');
});

test('4. reintento después de una interrupción a mitad de camino: lo ya borrado se salta, lo que falta se completa', async () => {
  const owner = await crearUsuario();
  const casaA = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });
  const casaB = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });
  await fijarCasaIds(owner.uid, [casaA, casaB]);

  // Se construye a mano el estado exacto en el que una ejecución anterior
  // se habría interrumpido justo después de borrar la primera casa -- no se
  // inyecta un fallo real a mitad de la función (no es reproducible sin
  // añadir un gancho de prueba al propio código de producción, algo que no
  // se ha hecho). Esto comprueba el mismo punto que importa: que retomar
  // después de una interrupción a mitad es seguro.
  await db.recursiveDelete(db.collection('casas').doc(casaA));

  const { error } = await llamar('eliminarCuenta', owner.idToken, {});
  assert.equal(error, undefined, 'retomar tras una interrupción a mitad debe completarse con éxito');

  assert.equal(await existeCasa(casaB), false, 'la casa que faltaba debe completarse en el reintento');
  assert.equal(await existeUsuarioAuth(owner.uid), false);
});

// Simula que un intento anterior llegó hasta el último paso y SOLO ese paso
// (borrar la cuenta de Authentication) tuvo éxito -- lo hace directamente,
// sin pasar por eliminarCuenta, dejando el resto (casa, perfil) intacto
// para que el reintento lo encuentre así.
test('5. si la cuenta de Authentication ya se había borrado en un intento anterior, el reintento no falla', async () => {
  const owner = await crearUsuario();
  const casaId = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });
  await fijarCasaIds(owner.uid, [casaId]);

  await admin.auth().deleteUser(owner.uid);

  const { error } = await llamar('eliminarCuenta', owner.idToken, {});
  assert.equal(error, undefined, JSON.stringify(error));

  assert.equal(await existeCasa(casaId), false, 'el resto de la limpieza debe completarse aunque la cuenta de Auth ya no exista');
  assert.equal((await db.collection('users').doc(owner.uid).get()).exists, false);
});

test('6. un usuario no autenticado no puede invocar la eliminación de ninguna cuenta', async () => {
  const { error } = await llamar('eliminarCuenta', null, {});
  assert.equal(error?.status, 'UNAUTHENTICATED');
});

// No existe ningún parámetro que acepte un uid distinto del propio -- uid
// viene siempre de request.auth.uid (el token verificado por el propio
// emulador de Functions), nunca de request.data. No hay ninguna llamada que
// pueda construirse para borrar la cuenta de otra persona.
test('7. no existe ninguna forma de pedir la eliminación de la cuenta de otro usuario', async () => {
  const owner = await crearUsuario();
  const victima = await crearUsuario();
  const casaId = await crearCasa({ ownerUid: victima.uid, members: [victima.uid] });
  await fijarCasaIds(victima.uid, [casaId]);

  // Intenta pasar el uid de la víctima como si fuera un parámetro -- la
  // función lo ignora por completo y actúa sobre quien de verdad llamó.
  const { error } = await llamar('eliminarCuenta', owner.idToken, { uid: victima.uid });
  assert.equal(error, undefined);

  assert.equal(await existeCasa(casaId), true, 'la casa de la víctima nunca debió tocarse');
  assert.equal(await existeUsuarioAuth(victima.uid), true, 'la cuenta de la víctima nunca debió tocarse');
});

// Auditoría R11 -- carrera real (sin ningún gancho de prueba en producción)
// entre eliminarCuenta y joinCasa, mismo patrón que la prueba de
// concurrencia H5-1 de payments.test.js: Promise.all no garantiza el orden,
// así que esto comprueba el INVARIANTE (nunca se borra una casa que al
// final tiene más de un miembro), no un orden concreto -- documentado, no
// disimulado como "determinista".
test('8. concurrencia: unirse a la casa justo cuando se está eliminando la cuenta del propietario nunca deja la casa borrada con otro miembro dentro', async () => {
  const owner = await crearUsuario();
  const nuevoMiembro = await crearUsuario();
  const casaId = await crearCasa({ ownerUid: owner.uid, members: [owner.uid], nombre: 'Casa en disputa' });
  // joinCasa hace .toUpperCase() sobre el código recibido -- tiene que
  // coincidir ya en mayúsculas con lo que se guarda aquí, o toda búsqueda
  // falla con NOT_FOUND antes de llegar a la transacción (bug de esta
  // prueba detectado y corregido en la auditoría R12, no de producción).
  const joinCode = `RACE-${casaId}`.toUpperCase();
  await db.collection('casas').doc(casaId).update({ joinCode });
  await db.collection('joinCodes').doc(joinCode).set({ casaId });
  await fijarCasaIds(owner.uid, [casaId]);

  const [elimResultado, joinResultado] = await Promise.all([
    llamar('eliminarCuenta', owner.idToken, {}),
    llamar('joinCasa', nuevoMiembro.idToken, { joinCode }),
  ]);

  const casaFinal = (await db.collection('casas').doc(casaId).get()).data();
  console.log(`[concurrencia R11-H1] eliminarCuenta.error=${elimResultado.error?.status}, joinCasa.error=${joinResultado.error?.status}, casa existe=${!!casaFinal}, members=${JSON.stringify(casaFinal?.members)}`);

  if (!casaFinal) {
    // eliminarCuenta ganó la carrera y la casa se borró -- correcto SOLO si
    // joinCasa no llegó a añadir al nuevo miembro antes de que se leyera.
    assert.notEqual(joinResultado.error, undefined, 'si la casa se borró, joinCasa no debió poder completarse como si la casa siguiera ahí');
  } else {
    // joinCasa ganó la carrera -- la casa sigue existiendo y DEBE reflejar
    // al nuevo miembro; eliminarCuenta debe haber detectado el cambio
    // (bloqueo de última hora) en vez de borrar una casa ya compartida.
    assert.ok(casaFinal.members.includes(nuevoMiembro.uid), 'si la casa sigue existiendo, debe incluir al nuevo miembro');
    assert.ok(casaFinal.members.includes(owner.uid), 'el propietario original tampoco debe haber desaparecido de una casa que no se borró');
  }
});

// Auditoría R11 -- idempotencia total: si TODAS las casas de un intento
// anterior ya se completaron (recursiveDelete + Storage + joinCode, los
// tres), un reintento no debe fallar ni repetir ningún trabajo, solo
// completar lo que queda (perfil, notificaciones, cuenta).
test('9. repetición total sobre recursos ya eliminados: ambas casas ya estaban borradas, el reintento solo limpia el resto de la cuenta', async () => {
  const owner = await crearUsuario();
  const casaA = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });
  const casaB = await crearCasa({ ownerUid: owner.uid, members: [owner.uid] });
  await fijarCasaIds(owner.uid, [casaA, casaB]);

  await db.recursiveDelete(db.collection('casas').doc(casaA));
  await db.recursiveDelete(db.collection('casas').doc(casaB));

  const { error } = await llamar('eliminarCuenta', owner.idToken, {});
  assert.equal(error, undefined, 'repetir sobre dos casas ya borradas no debe fallar');

  assert.equal((await db.collection('users').doc(owner.uid).get()).exists, false);
  assert.equal(await existeUsuarioAuth(owner.uid), false);
});
