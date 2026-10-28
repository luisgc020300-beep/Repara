// firestore-tests/storage.test.js
//
// Tests de seguridad de storage.rules contra el Firebase Emulator Suite --
// incremento 3 del plan de transformación de producto (Problem 5), octubre
// 2026: antes de esto, storage.rules no tenía NINGÚN test, pese a usar un
// mecanismo de autorización distinto al de firestore.rules -- claims del
// token de Auth (casaIds/registrosProId), no lectura de documentos (ver el
// comentario en storage.rules sobre por qué: Firestore y Storage están en
// regiones distintas). Mismo criterio que rules.test.js: node:test +
// @firebase/rules-unit-testing contra el emulador local, nunca el proyecto
// real.
//
// Ejecutar: npm run test:emulator (desde esta carpeta) -- levanta Firestore
// Y Storage, corre rules.test.js y este fichero, y los para solo.
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');

const { describe, it, before, after } = test;

let testEnv;

const CASA_A = 'casa-a';
const CASA_B = 'casa-b';
const ELEMENTO_A1 = 'elemento-a1';
const REGISTRO_A1 = 'registro-a1'; // asignado a PRO
const REGISTRO_A2 = 'registro-a2'; // sin profesional asignado

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'repara-reglas-test',
    storage: {
      rules: fs.readFileSync(path.resolve(__dirname, '..', 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      // Overridable, mismo motivo que rules.test.js de este mismo directorio.
      port: Number(process.env.REPARA_TEST_STORAGE_PORT || 9199),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

// Cada contexto lleva ya el claim que necesita -- casaIds/registrosProId no
// se leen de Firestore (storage.rules no puede, ver su propio comentario),
// los pone directamente el token de prueba, igual que sincronizarClaimsUid
// los pone en el token real.
function miembro(casaId) {
  return testEnv.authenticatedContext('owner-a', { casaIds: [casaId] }).storage();
}
function profesionalDe(registroId) {
  return testEnv.authenticatedContext('profesional-x', { registrosProId: [registroId] }).storage();
}
function extrano() {
  return testEnv.authenticatedContext('usuario-externo', {}).storage();
}
function sinAutenticar() {
  return testEnv.unauthenticatedContext().storage();
}

describe('documentos generales -- solo miembros de la casa', () => {
  it('ALLOW: un miembro sube un documento general', async () => {
    await assertSucceeds(miembro(CASA_A).ref(`casas/${CASA_A}/documentos/generales/factura.pdf`).putString('contenido', 'raw'));
  });

  it('ALLOW: un miembro lee un documento general ya subido', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage().ref(`casas/${CASA_A}/documentos/generales/factura.pdf`).putString('contenido', 'raw');
    });
    await assertSucceeds(miembro(CASA_A).ref(`casas/${CASA_A}/documentos/generales/factura.pdf`).getDownloadURL());
  });

  it('DENY: un usuario externo no puede subir un documento general', async () => {
    await assertFails(extrano().ref(`casas/${CASA_A}/documentos/generales/intruso.pdf`).putString('x', 'raw'));
  });

  it('DENY: un miembro de OTRA casa no puede subir aquí', async () => {
    await assertFails(miembro(CASA_B).ref(`casas/${CASA_A}/documentos/generales/intruso.pdf`).putString('x', 'raw'));
  });

  it('DENY: un profesional asignado a un registro de la casa no puede subir un documento general (solo el de SU registro)', async () => {
    await assertFails(profesionalDe(REGISTRO_A1).ref(`casas/${CASA_A}/documentos/generales/intento.pdf`).putString('x', 'raw'));
  });

  it('DENY: un usuario no autenticado no puede leer ni escribir', async () => {
    await assertFails(sinAutenticar().ref(`casas/${CASA_A}/documentos/generales/factura.pdf`).putString('x', 'raw'));
  });
});

describe('documentos por registro -- miembros + el profesional de ESE registro', () => {
  it('ALLOW: el profesional asignado sube un documento a SU registro', async () => {
    await assertSucceeds(
      profesionalDe(REGISTRO_A1).ref(`casas/${CASA_A}/documentos/porRegistro/${ELEMENTO_A1}/${REGISTRO_A1}/albaran.pdf`).putString('x', 'raw'),
    );
  });

  it('ALLOW: un miembro sube un documento a cualquier registro de su casa', async () => {
    await assertSucceeds(
      miembro(CASA_A).ref(`casas/${CASA_A}/documentos/porRegistro/${ELEMENTO_A1}/${REGISTRO_A2}/foto.jpg`).putString('x', 'raw'),
    );
  });

  it('DENY: el profesional NO puede subir a un registro al que no está asignado, aunque sea de la misma carpeta de documentos', async () => {
    await assertFails(
      profesionalDe(REGISTRO_A1).ref(`casas/${CASA_A}/documentos/porRegistro/${ELEMENTO_A1}/${REGISTRO_A2}/intento.pdf`).putString('x', 'raw'),
    );
  });

  it('DENY: un profesional ajeno (sin el claim de ESTE registro) no puede leer sus documentos', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage().ref(`casas/${CASA_A}/documentos/porRegistro/${ELEMENTO_A1}/${REGISTRO_A1}/albaran.pdf`).putString('x', 'raw');
    });
    await assertFails(
      profesionalDe(REGISTRO_A2).ref(`casas/${CASA_A}/documentos/porRegistro/${ELEMENTO_A1}/${REGISTRO_A1}/albaran.pdf`).getDownloadURL(),
    );
  });

  it('DENY: un usuario externo no puede subir documentos a ningún registro', async () => {
    await assertFails(extrano().ref(`casas/${CASA_A}/documentos/porRegistro/${ELEMENTO_A1}/${REGISTRO_A1}/intruso.pdf`).putString('x', 'raw'));
  });
});

describe('fotos de ScopeGuard (cambios de alcance) -- mismo criterio que documentos por registro', () => {
  it('ALLOW: el profesional asignado sube una foto de cambio de alcance de SU registro', async () => {
    await assertSucceeds(
      profesionalDe(REGISTRO_A1)
        .ref(`casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/cambiosAlcance/foto.jpg`)
        .putString('x', 'raw'),
    );
  });

  it('ALLOW: un miembro de la casa sube una foto de cambio de alcance', async () => {
    await assertSucceeds(
      miembro(CASA_A).ref(`casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A2}/cambiosAlcance/foto.jpg`).putString('x', 'raw'),
    );
  });

  it('DENY: el profesional no puede subir una foto de cambio de alcance de OTRO registro', async () => {
    await assertFails(
      profesionalDe(REGISTRO_A1)
        .ref(`casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A2}/cambiosAlcance/intento.jpg`)
        .putString('x', 'raw'),
    );
  });
});

describe('resto de rutas de la casa (elementos, contactos...) -- solo miembros, comportamiento original', () => {
  it('ALLOW: un miembro sube la foto de un elemento', async () => {
    await assertSucceeds(miembro(CASA_A).ref(`casas/${CASA_A}/elementos/${ELEMENTO_A1}/foto`).putString('x', 'raw'));
  });

  it('DENY: un profesional asignado a un registro NO puede subir la foto de un elemento (solo documentos de su registro concreto)', async () => {
    await assertFails(profesionalDe(REGISTRO_A1).ref(`casas/${CASA_A}/elementos/${ELEMENTO_A1}/foto`).putString('x', 'raw'));
  });

  it('DENY: un usuario externo no puede leer ni escribir nada de la casa', async () => {
    await assertFails(extrano().ref(`casas/${CASA_A}/elementos/${ELEMENTO_A1}/foto`).putString('x', 'raw'));
  });

  it('DENY: un miembro de la casa A no puede escribir en rutas de la casa B', async () => {
    await assertFails(miembro(CASA_A).ref(`casas/${CASA_B}/elementos/algun-elemento/foto`).putString('x', 'raw'));
  });
});
