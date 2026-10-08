// firestore-tests/rules.test.js
//
// Tests de seguridad de firestore.rules contra el Firebase Emulator Suite
// (auditoría de seguridad, octubre 2026). Cubre explícitamente los
// escenarios de ataque pedidos: usuario A contra vivienda de B, profesional
// contra trabajo/vivienda ajenos, manipulación de profesionalUid/ownerUid/
// estado/presupuesto, y aislamiento de invitaciones/pagos/documentos.
//
// Ejecutar: npm run test:emulator (desde esta carpeta) -- arranca el
// emulador de Firestore, corre los tests y lo para solo. Nunca toca el
// proyecto real: initializeTestEnvironment apunta siempre al emulador
// local (127.0.0.1:8080), nunca a repara-hogar-app.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, addDoc } = require('firebase/firestore');

const { describe, it, before, after, beforeEach } = test;

let testEnv;

// IDs reutilizados en todo el fichero -- dos casas distintas (A y B), con
// un propietario cada una, un profesional asignado a un trabajo de la
// casa A, y un usuario externo sin relación con ninguna de las dos.
const OWNER_A = 'owner-a';
const OWNER_B = 'owner-b';
const PRO = 'profesional-x';
const PRO_AJENO = 'profesional-y';
const EXTRANO = 'usuario-externo';

const CASA_A = 'casa-a';
const CASA_B = 'casa-b';
const TRABAJO_A1 = 'trabajo-a1'; // asignado a PRO
const TRABAJO_A2 = 'trabajo-a2'; // sin profesional asignado, solo de OWNER_A
const TRABAJO_B1 = 'trabajo-b1'; // de la casa B, sin relación con PRO

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'repara-reglas-test',
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Datos base sembrados saltándose las reglas (como lo haría una Cloud
  // Function con Admin SDK) -- los tests comprueban las reglas, no cómo se
  // crean los datos de partida.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'casas', CASA_A), {
      nombre: 'Casa A', ownerUid: OWNER_A, members: [OWNER_A], memberProfiles: {}, joinCode: 'AAAAAA',
    });
    await setDoc(doc(db, 'casas', CASA_B), {
      nombre: 'Casa B', ownerUid: OWNER_B, members: [OWNER_B], memberProfiles: {}, joinCode: 'BBBBBB',
    });
    await setDoc(doc(db, `casas/${CASA_A}/trabajos`, TRABAJO_A1), {
      titulo: 'Trabajo A1', tipo: 'averia', estado: 'nuevo', profesionalUid: PRO, presupuesto: 100,
    });
    await setDoc(doc(db, `casas/${CASA_A}/trabajos`, TRABAJO_A2), {
      titulo: 'Trabajo A2', tipo: 'averia', estado: 'nuevo', profesionalUid: null,
    });
    await setDoc(doc(db, `casas/${CASA_B}/trabajos`, TRABAJO_B1), {
      titulo: 'Trabajo B1', tipo: 'averia', estado: 'nuevo', profesionalUid: null,
    });
    await setDoc(doc(db, `casas/${CASA_A}/documentos`, 'doc-a1'), { trabajoId: TRABAJO_A1, nombreArchivo: 'factura.pdf' });
    await setDoc(doc(db, `casas/${CASA_A}/trabajos/${TRABAJO_A1}/presupuestos`, 'pres-a1'), { estado: 'enviado', creadoPorUid: PRO, total: 100 });
    await setDoc(doc(db, `casas/${CASA_A}/trabajos/${TRABAJO_A1}/pagos`, 'pago-a1'), { importe: 50, fecha: new Date() });
    await setDoc(doc(db, 'notificaciones', 'notif-owner-a'), { uid: OWNER_A, tipo: 'presupuesto_enviado', titulo: 't', cuerpo: 'c', leida: false });
  });
});

function as(uid) {
  return uid ? testEnv.authenticatedContext(uid).firestore() : testEnv.unauthenticatedContext().firestore();
}

describe('casas -- aislamiento entre viviendas', () => {
  it('ALLOW: el propietario lee su propia casa', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER_A), 'casas', CASA_A)));
  });

  it('DENY: usuario A no puede leer la vivienda de usuario B', async () => {
    await assertFails(getDoc(doc(as(OWNER_A), 'casas', CASA_B)));
  });

  it('DENY: un extraño sin ninguna relación no puede leer ninguna casa', async () => {
    await assertFails(getDoc(doc(as(EXTRANO), 'casas', CASA_A)));
  });

  it('DENY: un profesional asignado a un trabajo NO obtiene acceso a la vivienda completa', async () => {
    await assertFails(getDoc(doc(as(PRO), 'casas', CASA_A)));
  });

  it('DENY: un usuario no autenticado no puede leer ninguna casa', async () => {
    await assertFails(getDoc(doc(as(null), 'casas', CASA_A)));
  });

  it('DENY: un miembro no puede escribirse a sí mismo en members de otra casa (solo "nombre" es editable)', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), 'casas', CASA_A), { members: [OWNER_A, EXTRANO] }));
  });

  it('DENY: un miembro no puede cambiar ownerUid', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), 'casas', CASA_A), { ownerUid: EXTRANO }));
  });

  it('ALLOW: un miembro sí puede renombrar su casa', async () => {
    await assertSucceeds(updateDoc(doc(as(OWNER_A), 'casas', CASA_A), { nombre: 'Casa A renombrada' }));
  });

  it('DENY: nadie puede crear una casa directamente (solo createCasa, Cloud Function)', async () => {
    await assertFails(setDoc(doc(as(OWNER_A), 'casas', 'casa-nueva'), { nombre: 'x', members: [OWNER_A] }));
  });
});

describe('trabajos -- acceso del propietario y del profesional asignado', () => {
  it('ALLOW: el propietario lee los trabajos de su casa', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER_A), `casas/${CASA_A}/trabajos`, TRABAJO_A1)));
  });

  it('ALLOW: el profesional asignado lee SU trabajo', async () => {
    await assertSucceeds(getDoc(doc(as(PRO), `casas/${CASA_A}/trabajos`, TRABAJO_A1)));
  });

  it('DENY: el profesional NO puede leer otro trabajo de la MISMA casa al que no está asignado', async () => {
    await assertFails(getDoc(doc(as(PRO), `casas/${CASA_A}/trabajos`, TRABAJO_A2)));
  });

  it('DENY: el profesional no puede leer un trabajo de OTRA casa manipulando el trabajoId', async () => {
    await assertFails(getDoc(doc(as(PRO), `casas/${CASA_B}/trabajos`, TRABAJO_B1)));
  });

  it('DENY: un usuario externo no puede leer ningún trabajo de la casa A', async () => {
    await assertFails(getDoc(doc(as(EXTRANO), `casas/${CASA_A}/trabajos`, TRABAJO_A1)));
  });

  it('DENY: un usuario (incluso miembro) no puede escribir profesionalUid directamente', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/trabajos`, TRABAJO_A2), { profesionalUid: PRO_AJENO }));
  });

  it('DENY: el propio profesional no puede reasignarse otro trabajo escribiendo profesionalUid', async () => {
    await assertFails(updateDoc(doc(as(PRO_AJENO), `casas/${CASA_A}/trabajos`, TRABAJO_A2), { profesionalUid: PRO_AJENO }));
  });

  it('DENY: un miembro no puede marcar un trabajo como "terminado" con una escritura directa', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/trabajos`, TRABAJO_A2), { estado: 'terminado' }));
  });

  it('DENY: el profesional tampoco puede marcar su propio trabajo como "terminado" directamente', async () => {
    await assertFails(updateDoc(doc(as(PRO), `casas/${CASA_A}/trabajos`, TRABAJO_A1), { estado: 'terminado' }));
  });

  it('DENY: el profesional no puede escribir "presupuesto" directamente en el trabajo', async () => {
    await assertFails(updateDoc(doc(as(PRO), `casas/${CASA_A}/trabajos`, TRABAJO_A1), { presupuesto: 999999 }));
  });

  it('ALLOW: el profesional SÍ puede mover su trabajo a un estado no terminal (p.ej. "enCurso")', async () => {
    await assertSucceeds(updateDoc(doc(as(PRO), `casas/${CASA_A}/trabajos`, TRABAJO_A1), { estado: 'enCurso' }));
  });

  it('DENY: un profesional ajeno (sin asignar) no puede tocar el trabajo de otro profesional', async () => {
    await assertFails(updateDoc(doc(as(PRO_AJENO), `casas/${CASA_A}/trabajos`, TRABAJO_A1), { estado: 'enCurso' }));
  });

  // Modelo de dos pasos (auditoría de producto, octubre 2026): el profesional
  // no puede fingir que el propietario ya confirmó, y el propietario no
  // puede "deshacer" una confirmación pendiente sin pasar por
  // rechazarFinalizacionProfesional (que es quien avisa al profesional).
  it('DENY: el profesional no puede escribir "pendienteConfirmacion" directamente', async () => {
    await assertFails(updateDoc(doc(as(PRO), `casas/${CASA_A}/trabajos`, TRABAJO_A1), { estado: 'pendienteConfirmacion' }));
  });

  it('DENY: el propietario tampoco puede escribir "pendienteConfirmacion" directamente', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/trabajos`, TRABAJO_A1), { estado: 'pendienteConfirmacion' }));
  });

  it('DENY: el propietario no puede sacar un trabajo de "pendienteConfirmacion" con una escritura directa', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `casas/${CASA_A}/trabajos`, TRABAJO_A1), { estado: 'pendienteConfirmacion' }, { merge: true });
    });
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/trabajos`, TRABAJO_A1), { estado: 'enCurso' }));
  });

  it('DENY: el propietario no puede escribir "estadoPrevioAPendiente" directamente', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/trabajos`, TRABAJO_A1), { estadoPrevioAPendiente: 'enCurso' }));
  });
});

describe('presupuestos y cambios de alcance -- siempre de solo lectura para el cliente', () => {
  it('ALLOW: el propietario lee los presupuestos de su trabajo', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER_A), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/presupuestos`, 'pres-a1')));
  });

  it('ALLOW: el profesional asignado lee los presupuestos de SU trabajo', async () => {
    await assertSucceeds(getDoc(doc(as(PRO), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/presupuestos`, 'pres-a1')));
  });

  it('DENY: un profesional ajeno no puede leer presupuestos de un trabajo que no es suyo', async () => {
    await assertFails(getDoc(doc(as(PRO_AJENO), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/presupuestos`, 'pres-a1')));
  });

  it('DENY: nadie puede escribir un presupuesto directamente, ni el propietario', async () => {
    await assertFails(setDoc(doc(as(OWNER_A), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/presupuestos`, 'falso'), { total: 1 }));
  });

  it('DENY: el profesional no puede auto-aprobarse un presupuesto con una escritura directa', async () => {
    await assertFails(updateDoc(doc(as(PRO), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/presupuestos`, 'pres-a1'), { estado: 'aceptado' }));
  });

  it('DENY: nadie puede escribir un cambio de alcance directamente', async () => {
    await assertFails(addDoc(collection(as(PRO), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/cambiosAlcance`), { titulo: 'x', estado: 'pendiente' }));
  });
});

describe('pagos -- solo el propietario escribe, el profesional asignado solo lee', () => {
  it('ALLOW: el propietario registra un pago en su trabajo', async () => {
    await assertSucceeds(addDoc(collection(as(OWNER_A), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/pagos`), { importe: 10, fecha: new Date() }));
  });

  it('ALLOW: el profesional asignado lee los pagos de SU trabajo', async () => {
    await assertSucceeds(getDoc(doc(as(PRO), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/pagos`, 'pago-a1')));
  });

  it('DENY: el profesional no puede crear ni editar pagos', async () => {
    await assertFails(addDoc(collection(as(PRO), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/pagos`), { importe: 10, fecha: new Date() }));
  });

  it('DENY: un profesional ajeno no puede leer pagos de un trabajo que no es suyo', async () => {
    await assertFails(getDoc(doc(as(PRO_AJENO), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/pagos`, 'pago-a1')));
  });

  it('DENY: un usuario externo no puede escribir pagos en una casa ajena', async () => {
    await assertFails(addDoc(collection(as(EXTRANO), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/pagos`), { importe: 10, fecha: new Date() }));
  });

  // Auditoría de seguridad, octubre 2026: antes no había ninguna validación
  // server-side de `importe` -- una llamada directa al SDK (fuera de la UI,
  // que sí valida) podía crear un pago negativo, a cero, o absurdamente alto.
  it('DENY: el propietario no puede registrar un pago con importe negativo', async () => {
    await assertFails(addDoc(collection(as(OWNER_A), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/pagos`), { importe: -10, fecha: new Date() }));
  });

  it('DENY: el propietario no puede registrar un pago de importe cero', async () => {
    await assertFails(addDoc(collection(as(OWNER_A), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/pagos`), { importe: 0, fecha: new Date() }));
  });

  it('DENY: el propietario no puede registrar un pago con un importe absurdamente alto', async () => {
    await assertFails(addDoc(collection(as(OWNER_A), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/pagos`), { importe: 50000000, fecha: new Date() }));
  });

  it('DENY: el propietario no puede editar un pago para ponerle un importe negativo', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/trabajos/${TRABAJO_A1}/pagos`, 'pago-a1'), { importe: -5 }));
  });
});

describe('documentos -- acceso acotado al trabajo concreto del profesional', () => {
  it('ALLOW: el propietario lee los documentos de su casa', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER_A), `casas/${CASA_A}/documentos`, 'doc-a1')));
  });

  it('ALLOW: el profesional asignado lee un documento ligado a SU trabajo', async () => {
    await assertSucceeds(getDoc(doc(as(PRO), `casas/${CASA_A}/documentos`, 'doc-a1')));
  });

  it('DENY: un profesional ajeno no puede leer un documento ligado a un trabajo que no es suyo', async () => {
    await assertFails(getDoc(doc(as(PRO_AJENO), `casas/${CASA_A}/documentos`, 'doc-a1')));
  });

  it('DENY: un usuario externo no puede leer documentos de una casa ajena', async () => {
    await assertFails(getDoc(doc(as(EXTRANO), `casas/${CASA_A}/documentos`, 'doc-a1')));
  });

  it('DENY: el profesional no puede modificar/borrar un documento, solo crear/leer', async () => {
    await assertFails(deleteDoc(doc(as(PRO), `casas/${CASA_A}/documentos`, 'doc-a1')));
  });
});

describe('invitaciones, códigos y datos internos -- nunca accesibles directamente', () => {
  it('DENY: nadie lee invitacionesAbiertas directamente (ni intentando adivinar el id)', async () => {
    await assertFails(getDoc(doc(as(OWNER_A), 'invitacionesAbiertas', 'CUALQUIERA')));
  });

  it('DENY: nadie escribe invitacionesAbiertas directamente', async () => {
    await assertFails(setDoc(doc(as(OWNER_A), 'invitacionesAbiertas', 'FALSO1'), { estado: 'pendiente_registro' }));
  });

  it('DENY: nadie crea una invitación directamente (solo invitarProfesional)', async () => {
    await assertFails(addDoc(collection(as(OWNER_A), 'invitaciones'), { propietarioUid: OWNER_A, profesionalUid: PRO, estado: 'pendiente' }));
  });

  it('DENY: nadie lee/escribe su propio contador de uso de IA', async () => {
    await assertFails(getDoc(doc(as(OWNER_A), 'usoIA', `${OWNER_A}_2026-01-01`)));
  });

  it('DENY: nadie lee/escribe su propio contador de intentos de código', async () => {
    await assertFails(getDoc(doc(as(OWNER_A), 'intentosCodigo', `${OWNER_A}_joinCasa_2026-01-01`)));
  });
});

describe('notificaciones -- cada usuario solo ve y marca las suyas', () => {
  it('ALLOW: el dueño de la notificación la lee', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER_A), 'notificaciones', 'notif-owner-a')));
  });

  it('DENY: otro usuario no puede leer una notificación ajena', async () => {
    await assertFails(getDoc(doc(as(EXTRANO), 'notificaciones', 'notif-owner-a')));
  });

  it('ALLOW: el dueño puede marcarla como leída', async () => {
    await assertSucceeds(updateDoc(doc(as(OWNER_A), 'notificaciones', 'notif-owner-a'), { leida: true }));
  });

  it('DENY: otro usuario no puede marcar como leída una notificación ajena', async () => {
    await assertFails(updateDoc(doc(as(EXTRANO), 'notificaciones', 'notif-owner-a'), { leida: true }));
  });

  it('DENY: ni siquiera el dueño puede cambiar el contenido de su notificación, solo "leida"', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), 'notificaciones', 'notif-owner-a'), { titulo: 'manipulado' }));
  });

  it('DENY: nadie crea una notificación directamente', async () => {
    await assertFails(addDoc(collection(as(OWNER_A), 'notificaciones'), { uid: OWNER_A, titulo: 'falsa', cuerpo: 'x', leida: false }));
  });
});

describe('habitaciones, elementos y contactos -- solo miembros de la casa', () => {
  it('ALLOW: un miembro crea un elemento en su casa', async () => {
    await assertSucceeds(addDoc(collection(as(OWNER_A), `casas/${CASA_A}/elementos`), { nombre: 'Caldera' }));
  });

  it('DENY: un usuario externo no puede crear un elemento en una casa ajena', async () => {
    await assertFails(addDoc(collection(as(EXTRANO), `casas/${CASA_A}/elementos`), { nombre: 'Intruso' }));
  });

  it('DENY: un profesional asignado a un trabajo no puede crear elementos en la casa (solo documentos de su trabajo)', async () => {
    await assertFails(addDoc(collection(as(PRO), `casas/${CASA_A}/elementos`), { nombre: 'Intento de profesional' }));
  });

  it('DENY: un usuario externo no puede leer la libreta de contactos de otra casa', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `casas/${CASA_A}/contactos`, 'c1'), { nombre: 'Fontanero', telefono: '600' });
    });
    await assertFails(getDoc(doc(as(EXTRANO), `casas/${CASA_A}/contactos`, 'c1')));
  });
});
