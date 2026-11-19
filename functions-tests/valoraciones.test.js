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
const { db, crearUsuario, llamar, sembrarRegistro, esperarA } = require('./helpers');

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
  await db.collection('profesionales').doc(pro.uid).set({
    nombreComercial: 'Electricidad Ejemplo',
    fotoUrl: 'https://ejemplo.com/foto.jpg',
    descripcion: 'Más de 10 años de experiencia en instalaciones eléctricas.',
  });

  const pub = await esperarA(async () => {
    const snap = await db.collection('profesionalesPublico').doc(pro.uid).get();
    return snap.exists && snap.data().fotoUrl ? snap.data() : null;
  });
  assert.equal(pub.fotoUrl, 'https://ejemplo.com/foto.jpg');
  assert.equal(pub.descripcion, 'Más de 10 años de experiencia en instalaciones eléctricas.');
});
