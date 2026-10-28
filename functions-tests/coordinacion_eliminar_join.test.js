// functions-tests/coordinacion_eliminar_join.test.js
//
// Auditoría R12 (octubre 2026): cierre del riesgo residual documentado en
// R10/R11 -- entre la relectura de members.length de la Fase 1 de
// eliminarCuenta y sus tres llamadas de red (Storage, joinCode,
// recursiveDelete) no había NINGUNA protección real. Si joinCasa añadía un
// miembro justo en esa ventana, recursiveDelete borraba la casa igual.
//
// La solución (marcarCasaParaEliminarSiEsSeguro en functions/index.js) es
// una transacción que lee el mismo documento que lee la transacción de
// joinCasa -- Firestore sirve de árbitro real entre las dos, no un lock
// nuevo. El campo eliminandoDesde que esa transacción escribe caduca solo
// (TTL_BLOQUEO_ELIMINACION_MS) para que un intento abandonado nunca
// bloquee la casa de forma permanente.
//
// Estas pruebas comprueban el estado FINAL en Firestore, no solo códigos
// de error, y evitan depender de temporizaciones arbitrarias: el flag y su
// caducidad se construyen escribiendo el documento directamente (Admin
// SDK, salta las reglas), no esperando minutos reales.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, admin, crearUsuario, llamar, crearCasa, fijarCasaIds } = require('./helpers');

const TTL_BLOQUEO_ELIMINACION_MS = 2 * 60 * 1000; // debe coincidir con functions/index.js

async function crearCasaConJoinCode(ownerUid, nombre) {
  const casaId = await crearCasa({ ownerUid, members: [ownerUid], nombre });
  // joinCasa hace .toUpperCase() sobre el código que recibe antes de
  // buscarlo -- el código guardado tiene que coincidir YA en mayúsculas,
  // o la búsqueda falla con NOT_FOUND sin que sea la carrera la causa.
  const joinCode = `COORD-${casaId}`.toUpperCase();
  await db.collection('casas').doc(casaId).update({ joinCode });
  await db.collection('joinCodes').doc(joinCode).set({ casaId });
  return { casaId, joinCode };
}

test('1. secuencial (sin carrera): si alguien se une antes de llamar a eliminarCuenta, la cuenta no se borra y la casa queda intacta', async () => {
  const owner = await crearUsuario();
  const nuevoMiembro = await crearUsuario();
  const { casaId, joinCode } = await crearCasaConJoinCode(owner.uid, 'Casa unida antes');
  await fijarCasaIds(owner.uid, [casaId]);

  const { error: errorJoin } = await llamar('joinCasa', nuevoMiembro.idToken, { joinCode });
  assert.equal(errorJoin, undefined, JSON.stringify(errorJoin));

  const { error: errorEliminar } = await llamar('eliminarCuenta', owner.idToken, {});
  assert.equal(errorEliminar?.status, 'FAILED_PRECONDITION');

  const casaFinal = (await db.collection('casas').doc(casaId).get()).data();
  assert.ok(casaFinal, 'la casa no debió borrarse');
  assert.ok(casaFinal.members.includes(nuevoMiembro.uid) && casaFinal.members.includes(owner.uid));
});

// Construye DIRECTAMENTE el estado exacto que dejaría marcarCasaParaEliminarSiEsSeguro
// a mitad de su trabajo (flag puesto, casa todavía sin borrar) -- sin
// depender de ganar ninguna carrera real. Esto prueba el mecanismo en sí,
// no una coincidencia de tiempos.
test('2. un flag de eliminación en curso (recién puesto) bloquea joinCasa -- sin necesidad de ninguna carrera real', async () => {
  const owner = await crearUsuario();
  const nuevoMiembro = await crearUsuario();
  const { casaId, joinCode } = await crearCasaConJoinCode(owner.uid, 'Casa en eliminación');

  await db.collection('casas').doc(casaId).update({ eliminandoDesde: admin.firestore.Timestamp.now() });

  const { error } = await llamar('joinCasa', nuevoMiembro.idToken, { joinCode });
  assert.equal(error?.status, 'FAILED_PRECONDITION', JSON.stringify(error));

  const casaFinal = (await db.collection('casas').doc(casaId).get()).data();
  assert.deepEqual(casaFinal.members, [owner.uid], 'el nuevo miembro NO debió incorporarse mientras el flag está activo');
});

// El TTL se construye escribiendo un timestamp ya viejo -- no esperando el
// tiempo real. Esto prueba que un intento de eliminarCuenta abandonado
// (por ejemplo, el usuario cerró la app tras un fallo de Storage) nunca
// deja la casa bloqueada para siempre.
test('3. un flag de eliminación caducado (más viejo que el TTL) ya NO bloquea joinCasa, y se limpia al incorporar al nuevo miembro', async () => {
  const owner = await crearUsuario();
  const nuevoMiembro = await crearUsuario();
  const { casaId, joinCode } = await crearCasaConJoinCode(owner.uid, 'Casa con flag caducado');

  const timestampViejo = admin.firestore.Timestamp.fromMillis(Date.now() - TTL_BLOQUEO_ELIMINACION_MS - 5000);
  await db.collection('casas').doc(casaId).update({ eliminandoDesde: timestampViejo });

  const { error } = await llamar('joinCasa', nuevoMiembro.idToken, { joinCode });
  assert.equal(error, undefined, JSON.stringify(error));

  const casaFinal = (await db.collection('casas').doc(casaId).get()).data();
  assert.ok(casaFinal.members.includes(nuevoMiembro.uid), 'un flag caducado no debió bloquear la incorporación');
  assert.equal(casaFinal.eliminandoDesde, undefined, 'el flag caducado debió limpiarse al incorporar a alguien, no quedar colgando');
});

// Dos miembros NUEVOS distintos uniéndose a la misma casa a la vez -- la
// propia petición R12 de probar "dos operaciones concurrentes que
// intentan modificar la membresía". No implica a eliminarCuenta, pero
// confirma que añadir la comprobación del flag dentro de la transacción de
// joinCasa no rompió la concurrencia normal entre dos altas simultáneas.
test('4. concurrencia: dos miembros distintos uniéndose a la misma casa a la vez no se pisan -- ambos quedan en members', async () => {
  const owner = await crearUsuario();
  const miembroA = await crearUsuario();
  const miembroB = await crearUsuario();
  const { casaId, joinCode } = await crearCasaConJoinCode(owner.uid, 'Casa con alta doble');

  const [resultadoA, resultadoB] = await Promise.all([
    llamar('joinCasa', miembroA.idToken, { joinCode }),
    llamar('joinCasa', miembroB.idToken, { joinCode }),
  ]);
  assert.equal(resultadoA.error, undefined, JSON.stringify(resultadoA.error));
  assert.equal(resultadoB.error, undefined, JSON.stringify(resultadoB.error));

  const casaFinal = (await db.collection('casas').doc(casaId).get()).data();
  assert.ok(casaFinal.members.includes(miembroA.uid), 'el miembro A no debió perderse en la concurrencia');
  assert.ok(casaFinal.members.includes(miembroB.uid), 'el miembro B no debió perderse en la concurrencia');
  assert.equal(casaFinal.members.length, 3, 'propietario + dos miembros nuevos, ninguno perdido por una actualización pisada');
});

// Carrera real (sin ningún gancho de prueba en producción) repetida varias
// veces para aumentar la confianza empírica de que el invariante se
// cumple sea cual sea el orden real que ejecute el emulador -- Promise.all
// no garantiza el orden, así que esto NO se declara "determinista": es un
// refuerzo empírico de los tests 2 y 3, que sí lo son.
test('5. concurrencia real repetida: ninguna carrera entre eliminarCuenta y joinCasa deja la casa borrada con dos miembros ni pierde al nuevo miembro', async () => {
  const resultados = [];
  for (let intento = 0; intento < 6; intento++) {
    const owner = await crearUsuario();
    const nuevoMiembro = await crearUsuario();
    const { casaId, joinCode } = await crearCasaConJoinCode(owner.uid, `Casa en disputa ${intento}`);
    await fijarCasaIds(owner.uid, [casaId]);

    const [elimResultado, joinResultado] = await Promise.all([
      llamar('eliminarCuenta', owner.idToken, {}),
      llamar('joinCasa', nuevoMiembro.idToken, { joinCode }),
    ]);

    const casaFinal = (await db.collection('casas').doc(casaId).get()).data();
    resultados.push({
      intento,
      elimError: elimResultado.error?.status,
      joinError: joinResultado.error?.status,
      casaExiste: !!casaFinal,
      members: casaFinal?.members,
    });

    if (!casaFinal) {
      // eliminarCuenta ganó -- la casa se borró. Esto SOLO es correcto si
      // joinCasa no llegó a incorporar al nuevo miembro antes de que
      // desapareciera (si lo hubiera incorporado y la casa se borró
      // igual, el nuevo miembro quedaría huérfano -- justo lo que R12
      // cierra).
      assert.notEqual(joinResultado.error, undefined, `intento ${intento}: si la casa se borró, joinCasa no debió completarse como si la casa siguiera ahí`);
    } else {
      // joinCasa ganó -- la casa sigue existiendo y debe reflejar al nuevo
      // miembro sin haber perdido al propietario.
      assert.ok(casaFinal.members.includes(nuevoMiembro.uid), `intento ${intento}: si la casa sigue existiendo, debe incluir al nuevo miembro`);
      assert.ok(casaFinal.members.includes(owner.uid), `intento ${intento}: el propietario no debió desaparecer de una casa que no se borró`);
    }
  }
  console.log('[concurrencia R12] resultados de los 6 intentos:', JSON.stringify(resultados));
});
