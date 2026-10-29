// functions-tests/eliminar_registro_elemento.test.js
//
// eliminarRegistro / eliminarElemento (CEO, octubre 2026, cierre de R7/R8):
// el borrado directo del cliente (desactivado en la app) solo borraba el
// documento de Firestore, nunca la foto en Storage ni los "documentos"
// (facturas/fotos escaneadas) que lo referencian -- quedaban huérfanos para
// siempre. Estas pruebas comprueban la limpieza real contra el emulador de
// Storage (archivos reales, no mocks -- mismo criterio que eliminar_cuenta.
// test.js R11), no solo que la llamada no lanza error. Contra el Emulator
// Suite real -- ver helpers.js. Requiere REPARA_TEST_STORAGE_HOST (el
// emulador de Storage debe estar arrancado en esa sesión).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, llamar, idUnico, subirArchivoStorage, existeArchivoStorage } = require('./helpers');

const BUCKET = 'repara-test.appspot.com';

function urlDeDescarga(ruta) {
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(ruta)}?alt=media&token=fake`;
}

async function crearCasaConElemento(ownerUid) {
  const casaId = idUnico('casa');
  const elementoId = idUnico('elemento');
  await db.collection('casas').doc(casaId).set({ nombre: 'Casa de prueba', ownerUid, members: [ownerUid] });
  await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).set({ nombre: 'Elemento de prueba' });
  return { casaId, elementoId };
}

async function anadirRegistro(casaId, elementoId, { esConProfesional = false, estado = 'terminado' } = {}) {
  const registroId = idUnico('registro');
  await db
    .collection('casas').doc(casaId)
    .collection('elementos').doc(elementoId)
    .collection('registros').doc(registroId)
    .set({ titulo: 'Registro de prueba', estado, esConProfesional });
  return registroId;
}

async function anadirDocumento(casaId, { elementoId, registroId, ruta, archivosAdicionalesRutas = [] }) {
  const documentoId = idUnico('documento');
  await db.collection('casas').doc(casaId).collection('documentos').doc(documentoId).set({
    url: urlDeDescarga(ruta),
    nombreArchivo: 'factura.jpg',
    tipo: 'factura',
    elementoId: elementoId ?? null,
    registroId: registroId ?? null,
    archivosAdicionales: archivosAdicionalesRutas.map(urlDeDescarga),
  });
  return documentoId;
}

async function existeRegistro(casaId, elementoId, registroId) {
  const snap = await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).collection('registros').doc(registroId).get();
  return snap.exists;
}

async function existeElemento(casaId, elementoId) {
  const snap = await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).get();
  return snap.exists;
}

async function existeDocumento(casaId, documentoId) {
  const snap = await db.collection('casas').doc(casaId).collection('documentos').doc(documentoId).get();
  return snap.exists;
}

// ------------------------------------------------------------- eliminarRegistro

test('1. un registro simple se borra junto con su foto y los documentos (con sus archivos) que lo referencian', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  const registroId = await anadirRegistro(casaId, elementoId, { esConProfesional: false });

  const rutaFoto = `casas/${casaId}/elementos/${elementoId}/registros/${registroId}/foto`;
  await subirArchivoStorage(rutaFoto);

  const rutaDoc = `casas/${casaId}/documentos/porRegistro/${elementoId}/${registroId}/1_factura.jpg`;
  const rutaDocExtra = `casas/${casaId}/documentos/porRegistro/${elementoId}/${registroId}/2_factura.jpg`;
  await subirArchivoStorage(rutaDoc);
  await subirArchivoStorage(rutaDocExtra);
  const documentoId = await anadirDocumento(casaId, {
    elementoId,
    registroId,
    ruta: rutaDoc,
    archivosAdicionalesRutas: [rutaDocExtra],
  });

  const { error } = await llamar('eliminarRegistro', owner.idToken, { casaId, elementoId, registroId });
  assert.equal(error, undefined, JSON.stringify(error));

  assert.equal(await existeRegistro(casaId, elementoId, registroId), false);
  assert.equal(await existeDocumento(casaId, documentoId), false);
  assert.equal(await existeArchivoStorage(rutaFoto), false, 'la foto del registro debe borrarse de Storage');
  assert.equal(await existeArchivoStorage(rutaDoc), false, 'el archivo principal del documento debe borrarse de Storage');
  assert.equal(await existeArchivoStorage(rutaDocExtra), false, 'el archivo adicional (multipágina) también debe borrarse');
});

test('2. un registro CON profesional se rechaza, nunca se borra -- aunque ya esté terminado', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  const registroId = await anadirRegistro(casaId, elementoId, { esConProfesional: true, estado: 'terminado' });

  const { error } = await llamar('eliminarRegistro', owner.idToken, { casaId, elementoId, registroId });
  assert.equal(error?.status, 'FAILED_PRECONDITION');
  assert.equal(await existeRegistro(casaId, elementoId, registroId), true);
});

test('3. eliminarRegistro es idempotente -- llamarlo sobre un registro ya borrado no falla', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  const registroId = await anadirRegistro(casaId, elementoId, { esConProfesional: false });

  const primera = await llamar('eliminarRegistro', owner.idToken, { casaId, elementoId, registroId });
  assert.equal(primera.error, undefined);
  const segunda = await llamar('eliminarRegistro', owner.idToken, { casaId, elementoId, registroId });
  assert.equal(segunda.error, undefined);
});

test('4. un usuario que no pertenece a la casa no puede eliminar su registro', async () => {
  const owner = await crearUsuario();
  const extrano = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  const registroId = await anadirRegistro(casaId, elementoId, { esConProfesional: false });

  const { error } = await llamar('eliminarRegistro', extrano.idToken, { casaId, elementoId, registroId });
  assert.equal(error?.status, 'PERMISSION_DENIED');
  assert.equal(await existeRegistro(casaId, elementoId, registroId), true);
});

// ------------------------------------------------------------- eliminarElemento

test('5. un elemento sin ningún registro con profesional se borra entero: su foto, sus registros y los documentos asociados', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  const registroId1 = await anadirRegistro(casaId, elementoId, { esConProfesional: false });
  const registroId2 = await anadirRegistro(casaId, elementoId, { esConProfesional: false });

  const rutaFotoElemento = `casas/${casaId}/elementos/${elementoId}/foto`;
  await subirArchivoStorage(rutaFotoElemento);
  const rutaFotoRegistro1 = `casas/${casaId}/elementos/${elementoId}/registros/${registroId1}/foto`;
  await subirArchivoStorage(rutaFotoRegistro1);

  // Un documento "general" del elemento (sin registroId) y otro ligado a
  // un registro concreto -- los dos deben limpiarse (ver nota en
  // eliminarElemento sobre por qué un único filtro por elementoId basta).
  const rutaDocGeneral = `casas/${casaId}/documentos/generales/1_garantia.jpg`;
  await subirArchivoStorage(rutaDocGeneral);
  const documentoGeneralId = await anadirDocumento(casaId, { elementoId, ruta: rutaDocGeneral });

  const rutaDocRegistro = `casas/${casaId}/documentos/porRegistro/${elementoId}/${registroId2}/1_factura.jpg`;
  await subirArchivoStorage(rutaDocRegistro);
  const documentoRegistroId = await anadirDocumento(casaId, { elementoId, registroId: registroId2, ruta: rutaDocRegistro });

  const { error } = await llamar('eliminarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error, undefined, JSON.stringify(error));

  assert.equal(await existeElemento(casaId, elementoId), false);
  assert.equal(await existeRegistro(casaId, elementoId, registroId1), false);
  assert.equal(await existeRegistro(casaId, elementoId, registroId2), false);
  assert.equal(await existeDocumento(casaId, documentoGeneralId), false);
  assert.equal(await existeDocumento(casaId, documentoRegistroId), false);
  assert.equal(await existeArchivoStorage(rutaFotoElemento), false, 'la foto del elemento debe borrarse');
  assert.equal(await existeArchivoStorage(rutaFotoRegistro1), false, 'la foto de cada registro también debe borrarse');
  assert.equal(await existeArchivoStorage(rutaDocGeneral), false);
  assert.equal(await existeArchivoStorage(rutaDocRegistro), false);
});

test('6. un elemento con algún registro con profesional (aunque esté terminado) se rechaza -- no se borra nada', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);
  const registroSimpleId = await anadirRegistro(casaId, elementoId, { esConProfesional: false });
  const registroProId = await anadirRegistro(casaId, elementoId, { esConProfesional: true, estado: 'terminado' });

  const { error } = await llamar('eliminarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(error?.status, 'FAILED_PRECONDITION');

  assert.equal(await existeElemento(casaId, elementoId), true);
  assert.equal(await existeRegistro(casaId, elementoId, registroSimpleId), true);
  assert.equal(await existeRegistro(casaId, elementoId, registroProId), true);
});

test('7. eliminarElemento es idempotente -- llamarlo sobre un elemento ya borrado no falla', async () => {
  const owner = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);

  const primera = await llamar('eliminarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(primera.error, undefined);
  const segunda = await llamar('eliminarElemento', owner.idToken, { casaId, elementoId });
  assert.equal(segunda.error, undefined);
});

test('8. un usuario que no pertenece a la casa no puede eliminar su elemento', async () => {
  const owner = await crearUsuario();
  const extrano = await crearUsuario();
  const { casaId, elementoId } = await crearCasaConElemento(owner.uid);

  const { error } = await llamar('eliminarElemento', extrano.idToken, { casaId, elementoId });
  assert.equal(error?.status, 'PERMISSION_DENIED');
  assert.equal(await existeElemento(casaId, elementoId), true);
});
