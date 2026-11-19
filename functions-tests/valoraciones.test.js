// functions-tests/valoraciones.test.js
//
// Perfil público del profesional (mejora de perfiles profesionales,
// noviembre 2026): crearValoracion solo admite valorar trabajos reales ya
// terminados, con profesional vinculado, y nunca dos veces por la misma
// persona; los dos triggers mantienen profesionalesPublico/{uid} (nº de
// trabajos terminados, nombre/especialidad) sin que el cliente escriba ahí
// directamente. Contra el Emulator Suite real -- ver helpers.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, sembrarRegistro, esperarA, PROJECT_ID } = require('./helpers');

// Mismo bucket por defecto que usa getStorage().bucket() sin argumento en
// este proyecto de pruebas -- ver el comentario de BUCKET_POR_DEFECTO en
// helpers.js. Hace falta una URL de descarga con esta forma exacta para
// que urlFotoProfesionalEsValida() (functions/index.js) la acepte.
function urlFotoValida(uid) {
  return `https://firebasestorage.googleapis.com/v0/b/${PROJECT_ID}.appspot.com/o/profesionales%2F${uid}%2Ffoto?alt=media&token=test-token`;
}

test('1. el propietario valora un trabajo terminado con profesional vinculado', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'terminado', profesionalUid: pro.uid,
  });

  const { error } = await llamar('crearValoracion', owner.idToken, {
    casaId, elementoId, registroId, puntuacion: 5, comentario: 'Genial, muy puntual.',
  });
  assert.equal(error, undefined);

  const valSnap = await db.collection('valoraciones').doc(`${registroId}_${owner.uid}`).get();
  assert.equal(valSnap.data().puntuacion, 5);
  assert.equal(valSnap.data().profesionalUid, pro.uid);
  assert.equal(valSnap.data().comentario, 'Genial, muy puntual.');

  const pubSnap = await db.collection('profesionalesPublico').doc(pro.uid).get();
  assert.equal(pubSnap.data().sumaPuntuaciones, 5);
  assert.equal(pubSnap.data().numValoraciones, 1);
});

test('2. no se puede valorar el mismo trabajo dos veces', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'terminado', profesionalUid: pro.uid,
  });
  await llamar('crearValoracion', owner.idToken, { casaId, elementoId, registroId, puntuacion: 4 });

  const { error } = await llamar('crearValoracion', owner.idToken, { casaId, elementoId, registroId, puntuacion: 2 });
  assert.equal(error?.status, 'ALREADY_EXISTS');

  const pubSnap = await db.collection('profesionalesPublico').doc(pro.uid).get();
  assert.equal(pubSnap.data().numValoraciones, 1);
});

test('3. no se puede valorar un trabajo que todavía no está terminado', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'enCurso', profesionalUid: pro.uid,
  });

  const { error } = await llamar('crearValoracion', owner.idToken, { casaId, elementoId, registroId, puntuacion: 5 });
  assert.equal(error?.status, 'FAILED_PRECONDITION');
});

test('4. no se puede valorar un trabajo sin ningún profesional vinculado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({ ownerUid: owner.uid, estado: 'terminado' });

  const { error } = await llamar('crearValoracion', owner.idToken, { casaId, elementoId, registroId, puntuacion: 5 });
  assert.equal(error?.status, 'FAILED_PRECONDITION');
});

test('5. un usuario que no pertenece a la casa no puede valorar', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const extrano = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'terminado', profesionalUid: pro.uid,
  });

  const { error } = await llamar('crearValoracion', extrano.idToken, { casaId, elementoId, registroId, puntuacion: 5 });
  assert.equal(error?.status, 'PERMISSION_DENIED');
});

test('6. una puntuación fuera de 1-5 se rechaza', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'terminado', profesionalUid: pro.uid,
  });

  const { error: e1 } = await llamar('crearValoracion', owner.idToken, { casaId, elementoId, registroId, puntuacion: 0 });
  assert.equal(e1?.status, 'INVALID_ARGUMENT');
  const { error: e2 } = await llamar('crearValoracion', owner.idToken, { casaId, elementoId, registroId, puntuacion: 6 });
  assert.equal(e2?.status, 'INVALID_ARGUMENT');
});

test('7. dos propietarios de la misma casa pueden valorar el mismo trabajo cada uno la suya', async () => {
  const ownerA = await crearUsuario();
  const ownerB = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: ownerA.uid, estado: 'terminado', profesionalUid: pro.uid,
  });
  await db.collection('casas').doc(casaId).update({ members: [ownerA.uid, ownerB.uid] });

  const r1 = await llamar('crearValoracion', ownerA.idToken, { casaId, elementoId, registroId, puntuacion: 5 });
  assert.equal(r1.error, undefined);
  const r2 = await llamar('crearValoracion', ownerB.idToken, { casaId, elementoId, registroId, puntuacion: 3 });
  assert.equal(r2.error, undefined);

  const pubSnap = await db.collection('profesionalesPublico').doc(pro.uid).get();
  assert.equal(pubSnap.data().numValoraciones, 2);
  assert.equal(pubSnap.data().sumaPuntuaciones, 8);
});

test('8. un profesional que también es miembro de la casa no puede valorarse a sí mismo', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'terminado', profesionalUid: pro.uid,
  });
  // El profesional también es miembro de esta misma casa (p.ej. comparte
  // vivienda con el propietario) -- esMiembroCasa por sí sola no basta.
  await db.collection('casas').doc(casaId).update({ members: [owner.uid, pro.uid] });

  const { error } = await llamar('crearValoracion', pro.idToken, { casaId, elementoId, registroId, puntuacion: 5 });
  assert.equal(error?.status, 'PERMISSION_DENIED');

  const pubSnap = await db.collection('profesionalesPublico').doc(pro.uid).get();
  assert.ok(!pubSnap.exists || !pubSnap.data().numValoraciones);
});

test('9. (trigger) un registro que pasa a terminado con profesional incrementa trabajosTerminados', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'enCurso', profesionalUid: pro.uid,
  });

  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).update({ estado: 'terminado' });

  const pub = await esperarA(async () => {
    const snap = await db.collection('profesionalesPublico').doc(pro.uid).get();
    return snap.exists && snap.data().trabajosTerminados === 1 ? snap.data() : null;
  });
  assert.equal(pub.trabajosTerminados, 1);
});

test('10. (trigger) el perfil público sincroniza nombreComercial/especialidad del profesional', async () => {
  const pro = await crearUsuario();
  await db.collection('profesionales').doc(pro.uid).set({
    nombreComercial: 'Fontanería Ejemplo', especialidad: 'Fontanería',
  });

  const pub = await esperarA(async () => {
    const snap = await db.collection('profesionalesPublico').doc(pro.uid).get();
    return snap.exists && snap.data().nombreComercial ? snap.data() : null;
  });
  assert.equal(pub.nombreComercial, 'Fontanería Ejemplo');
  assert.equal(pub.especialidad, 'Fontanería');
});

// Mejora de perfiles profesionales (noviembre 2026): mismo trigger que el
// test anterior, ahora también con fotoUrl/descripcion -- lo que el cliente
// guarda via ProfesionalService.actualizarPerfil/actualizarFoto.
test('11. (trigger) el perfil público sincroniza fotoUrl/descripcion del profesional', async () => {
  const pro = await crearUsuario();
  const url = urlFotoValida(pro.uid);
  await db.collection('profesionales').doc(pro.uid).set({
    nombreComercial: 'Electricidad Ejemplo',
    fotoUrl: url,
    descripcion: 'Más de 10 años de experiencia en instalaciones eléctricas.',
  });

  const pub = await esperarA(async () => {
    const snap = await db.collection('profesionalesPublico').doc(pro.uid).get();
    return snap.exists && snap.data().fotoUrl ? snap.data() : null;
  });
  assert.equal(pub.fotoUrl, url);
  assert.equal(pub.descripcion, 'Más de 10 años de experiencia en instalaciones eléctricas.');
});

// Corrección de revisión automática de seguridad (noviembre 2026):
// profesionales/{uid}.fotoUrl ya está validada en firestore.rules (ver
// rules.test.js), pero este trigger es la última línea de defensa real
// contra lo que de verdad llega a profesionalesPublico/{uid} -- se
// escribe directamente con el Admin SDK (se salta las reglas, como
// cualquier dato que llegara por otro camino) para probar el trigger en
// sí, no solo la regla de arriba.
test('12. (trigger) una fotoUrl que no es la URL de descarga real de ESE profesional nunca llega a profesionalesPublico', async () => {
  const pro = await crearUsuario();
  await db.collection('profesionales').doc(pro.uid).set({
    nombreComercial: 'Fontanería Maliciosa',
    fotoUrl: 'https://evil.example.com/track.png?uid=' + pro.uid,
  });

  const pub = await esperarA(async () => {
    const snap = await db.collection('profesionalesPublico').doc(pro.uid).get();
    return snap.exists && snap.data().nombreComercial ? snap.data() : null;
  });
  assert.equal(pub.fotoUrl, null);
});

test('13. (trigger) una descripcion de más de 500 caracteres se recorta antes de llegar a profesionalesPublico', async () => {
  const pro = await crearUsuario();
  await db.collection('profesionales').doc(pro.uid).set({
    nombreComercial: 'Pintor',
    descripcion: 'x'.repeat(600),
  });

  const pub = await esperarA(async () => {
    const snap = await db.collection('profesionalesPublico').doc(pro.uid).get();
    return snap.exists && snap.data().nombreComercial ? snap.data() : null;
  });
  assert.equal(pub.descripcion.length, 500);
});

// Historial profesional visible antes de contactar (punto 7, noviembre
// 2026): el desglose por tipo complementa trabajosTerminados sin exponer
// nunca el título del trabajo ni el nombre del elemento.
test('14. (trigger) un registro que pasa a terminado con profesional incrementa trabajosPorTipo según su categoría', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'enCurso', profesionalUid: pro.uid, tipo: 'reparacion',
  });

  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).update({ estado: 'terminado' });

  const pub = await esperarA(async () => {
    const snap = await db.collection('profesionalesPublico').doc(pro.uid).get();
    return snap.exists && snap.data().trabajosTerminados === 1 ? snap.data() : null;
  });
  assert.equal(pub.trabajosPorTipo.reparacion, 1);
});

test('15. (trigger) volver a abrir un trabajo terminado decrementa su categoría en trabajosPorTipo', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'terminado', profesionalUid: pro.uid, tipo: 'mantenimiento',
  });
  await esperarA(async () => {
    const snap = await db.collection('profesionalesPublico').doc(pro.uid).get();
    return snap.exists && snap.data().trabajosTerminados === 1 ? snap.data() : null;
  });

  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).update({ estado: 'enCurso' });

  const pub = await esperarA(async () => {
    const snap = await db.collection('profesionalesPublico').doc(pro.uid).get();
    return snap.exists && snap.data().trabajosTerminados === 0 ? snap.data() : null;
  });
  assert.equal(pub.trabajosPorTipo.mantenimiento, 0);
});

// Corrección de revisión automática de seguridad (igual criterio que el
// test 12 de fotoUrl): 'tipo' lo escribe el propio propietario sin que
// firestore.rules valide su contenido -- un valor fuera de la lista cerrada
// de TipoRegistro nunca debe llegar como clave de trabajosPorTipo.
test('16. (trigger) un tipo fuera de la lista cerrada nunca llega a trabajosPorTipo', async () => {
  const owner = await crearUsuario();
  const pro = await crearUsuario();
  const { casaId, elementoId, registroId } = await sembrarRegistro({
    ownerUid: owner.uid, estado: 'enCurso', profesionalUid: pro.uid, tipo: '__proto__',
  });

  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId).update({ estado: 'terminado' });

  const pub = await esperarA(async () => {
    const snap = await db.collection('profesionalesPublico').doc(pro.uid).get();
    return snap.exists && snap.data().trabajosTerminados === 1 ? snap.data() : null;
  });
  assert.equal(pub.trabajosPorTipo, undefined);
});

test('17. (trigger) el perfil público sincroniza la fecha de alta (desde) del profesional', async () => {
  const pro = await crearUsuario();
  await db.collection('profesionales').doc(pro.uid).set({
    nombreComercial: 'Carpintería Ejemplo',
    createdAt: new Date('2026-03-01T00:00:00Z'),
  });

  const pub = await esperarA(async () => {
    const snap = await db.collection('profesionalesPublico').doc(pro.uid).get();
    return snap.exists && snap.data().nombreComercial ? snap.data() : null;
  });
  assert.ok(pub.desde);
  assert.equal(pub.desde.toDate().toISOString(), '2026-03-01T00:00:00.000Z');
});
