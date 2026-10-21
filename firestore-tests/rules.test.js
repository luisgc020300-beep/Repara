// firestore-tests/rules.test.js
//
// Tests de seguridad de firestore.rules contra el Firebase Emulator Suite
// (auditoría de seguridad, octubre 2026). Cubre explícitamente los
// escenarios de ataque pedidos: usuario A contra vivienda de B, profesional
// contra registro/vivienda ajenos, manipulación de profesionalUid/ownerUid/
// estado/presupuesto, y aislamiento de invitaciones/pagos/documentos.
//
// Octubre 2026 -- reestructurado para la fusión Elemento/Trabajo/Evento en
// Elemento→Registro: lo que antes era casas/{cid}/trabajos/{tid} es ahora
// casas/{cid}/elementos/{eid}/registros/{rid}.
//
// Ejecutar: npm run test:emulator (desde esta carpeta) -- arranca el
// emulador de Firestore, corre los tests y lo para solo. Nunca toca el
// proyecto real: initializeTestEnvironment apunta siempre al emulador
// local (127.0.0.1:8080), nunca a repara-hogar-app.
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, addDoc } = require('firebase/firestore');

const { describe, it, before, after, beforeEach } = test;

let testEnv;

// IDs reutilizados en todo el fichero -- dos casas distintas (A y B), con
// un propietario cada una, un profesional asignado a un registro de la
// casa A, y un usuario externo sin relación con ninguna de las dos.
const OWNER_A = 'owner-a';
const OWNER_B = 'owner-b';
const MIEMBRO_A2 = 'miembro-a2'; // segundo miembro de la casa A, no la creó
const PRO = 'profesional-x';
const PRO_AJENO = 'profesional-y';
const EXTRANO = 'usuario-externo';

const CASA_A = 'casa-a';
const CASA_B = 'casa-b';
const ELEMENTO_A1 = 'elemento-a1';
const ELEMENTO_B1 = 'elemento-b1';
const REGISTRO_A1 = 'registro-a1'; // asignado a PRO
const REGISTRO_A2 = 'registro-a2'; // sin profesional asignado, solo de OWNER_A
const REGISTRO_B1 = 'registro-b1'; // de la casa B, sin relación con PRO

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
      nombre: 'Casa A', ownerUid: OWNER_A, members: [OWNER_A, MIEMBRO_A2], memberProfiles: {}, joinCode: 'AAAAAA',
    });
    await setDoc(doc(db, 'casas', CASA_B), {
      nombre: 'Casa B', ownerUid: OWNER_B, members: [OWNER_B], memberProfiles: {}, joinCode: 'BBBBBB',
    });
    await setDoc(doc(db, `casas/${CASA_A}/elementos`, ELEMENTO_A1), { nombre: 'Elemento A1' });
    await setDoc(doc(db, `casas/${CASA_B}/elementos`, ELEMENTO_B1), { nombre: 'Elemento B1' });
    await setDoc(doc(db, `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), {
      casaId: CASA_A, titulo: 'Registro A1', tipo: 'averia', esConProfesional: true, estado: 'nuevo', profesionalUid: PRO, presupuesto: 100,
    });
    await setDoc(doc(db, `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A2), {
      casaId: CASA_A, titulo: 'Registro A2', tipo: 'averia', esConProfesional: false, estado: 'nuevo', profesionalUid: null,
    });
    await setDoc(doc(db, `casas/${CASA_B}/elementos/${ELEMENTO_B1}/registros`, REGISTRO_B1), {
      casaId: CASA_B, titulo: 'Registro B1', tipo: 'averia', esConProfesional: false, estado: 'nuevo', profesionalUid: null,
    });
    await setDoc(doc(db, `casas/${CASA_A}/documentos`, 'doc-a1'), { elementoId: ELEMENTO_A1, registroId: REGISTRO_A1, nombreArchivo: 'factura.pdf' });
    await setDoc(doc(db, `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/presupuestos`, 'pres-a1'), { estado: 'enviado', creadoPorUid: PRO, total: 100 });
    await setDoc(doc(db, `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/pagos`, 'pago-a1'), { importe: 50, fecha: new Date(), createdBy: OWNER_A });
    await setDoc(doc(db, `casas/${CASA_A}/resumen`, 'pendientes'), { registros: [], actualizadoEn: new Date() });
    await setDoc(doc(db, 'notificaciones', 'notif-owner-a'), { uid: OWNER_A, tipo: 'presupuesto_enviado', titulo: 't', cuerpo: 'c', leida: false });
    await setDoc(doc(db, 'users', OWNER_A), { activeCasaId: CASA_A, casaIds: [CASA_A] });
    await setDoc(doc(db, 'profesionales', PRO), { nombreComercial: 'Fontanería X' });
    await setDoc(doc(db, 'invitaciones', 'inv-a1'), {
      propietarioUid: OWNER_A, profesionalUid: PRO, casaId: CASA_A, elementoId: ELEMENTO_A1, elementoNombre: 'Elemento A1',
      registroId: REGISTRO_A1, registroTitulo: 'Registro A1', casaNombre: 'Casa A', profesionalEmail: 'pro@x.com', estado: 'pendiente',
    });
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

  it('DENY: un profesional asignado a un registro NO obtiene acceso a la vivienda completa', async () => {
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

describe('registros -- acceso del propietario y del profesional asignado', () => {
  it('ALLOW: el propietario lee los registros de su elemento', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1)));
  });

  it('ALLOW: el profesional asignado lee SU registro', async () => {
    await assertSucceeds(getDoc(doc(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1)));
  });

  it('DENY: el profesional NO puede leer otro registro del MISMO elemento al que no está asignado', async () => {
    await assertFails(getDoc(doc(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A2)));
  });

  it('DENY: el profesional no puede leer un registro de OTRA casa manipulando el id', async () => {
    await assertFails(getDoc(doc(as(PRO), `casas/${CASA_B}/elementos/${ELEMENTO_B1}/registros`, REGISTRO_B1)));
  });

  it('DENY: un usuario externo no puede leer ningún registro de la casa A', async () => {
    await assertFails(getDoc(doc(as(EXTRANO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1)));
  });

  it('DENY: un usuario (incluso miembro) no puede escribir profesionalUid directamente', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A2), { profesionalUid: PRO_AJENO }));
  });

  it('DENY: el propio profesional no puede reasignarse otro registro escribiendo profesionalUid', async () => {
    await assertFails(updateDoc(doc(as(PRO_AJENO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A2), { profesionalUid: PRO_AJENO }));
  });

  it('DENY: un miembro no puede marcar un registro como "terminado" con una escritura directa', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A2), { estado: 'terminado' }));
  });

  it('DENY: el profesional tampoco puede marcar su propio registro como "terminado" directamente', async () => {
    await assertFails(updateDoc(doc(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { estado: 'terminado' }));
  });

  it('DENY: el profesional no puede escribir "presupuesto" directamente en el registro', async () => {
    await assertFails(updateDoc(doc(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { presupuesto: 999999 }));
  });

  // Segunda auditoría de integridad económica (octubre 2026) -- DATA-3: el
  // miembro de la casa SÍ podía escribir "presupuesto" directo (el
  // profesional no, por el hasOnly(['estado']) de su rama, pero el
  // propietario/miembro no tenía esa restricción). Es el campo que usan
  // registrarPago/actualizarPago como techo económico -- si un miembro
  // puede inflarlo a mano, el límite deja de significar nada.
  it('DENY: un miembro (el propietario) tampoco puede escribir "presupuesto" directamente', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { presupuesto: 999999 }));
  });

  // DATA-3: "presupuestoAceptadoId" es la señal real (inmune a que se
  // resetee "estado" a mano) de que ya hay un presupuesto aceptado -- si
  // un miembro pudiera tocarlo, podría tanto borrarla (reabriendo el hueco)
  // como falsificarla.
  it('DENY: un miembro no puede escribir "presupuestoAceptadoId" directamente', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { presupuestoAceptadoId: 'pres-falso' }));
  });

  // "estado" SIGUE siendo editable a mano a propósito (ver
  // _estadosEditables en registro_detail_screen.dart/
  // registro_pro_detail_screen.dart -- un picker real para marcar
  // progreso), incluso para sacar un registro de 'presupuestado'. La
  // protección de DATA-3 no vive aquí: vive en que "presupuesto"/
  // "presupuestoAceptadoId" sean intocables (ver los dos tests de arriba)
  // y en que responderPresupuesto compruebe "presupuestoAceptadoId", no
  // "estado" (ver functions-tests/presupuestos.test.js, test 8, que
  // reproduce el escenario completo de la auditoría: aceptar A, resetear
  // estado a mano, intentar aceptar B).
  it('ALLOW: el propietario SÍ puede sacar un registro de "presupuestado" a mano (picker legítimo)', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { estado: 'presupuestado' }, { merge: true });
    });
    await assertSucceeds(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { estado: 'nuevo' }));
  });

  it('ALLOW: el profesional SÍ puede mover su registro a un estado no terminal (p.ej. "enCurso")', async () => {
    await assertSucceeds(updateDoc(doc(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { estado: 'enCurso' }));
  });

  it('DENY: un profesional ajeno (sin asignar) no puede tocar el registro de otro profesional', async () => {
    await assertFails(updateDoc(doc(as(PRO_AJENO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { estado: 'enCurso' }));
  });

  // Modelo de dos pasos (auditoría de producto, octubre 2026): el profesional
  // no puede fingir que el propietario ya confirmó, y el propietario no
  // puede "deshacer" una confirmación pendiente sin pasar por
  // rechazarFinalizacionProfesional (que es quien avisa al profesional).
  it('DENY: el profesional no puede escribir "pendienteConfirmacion" directamente', async () => {
    await assertFails(updateDoc(doc(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { estado: 'pendienteConfirmacion' }));
  });

  it('DENY: el propietario tampoco puede escribir "pendienteConfirmacion" directamente', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { estado: 'pendienteConfirmacion' }));
  });

  it('DENY: el propietario no puede sacar un registro de "pendienteConfirmacion" con una escritura directa', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { estado: 'pendienteConfirmacion' }, { merge: true });
    });
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { estado: 'enCurso' }));
  });

  it('DENY: el propietario no puede escribir "estadoPrevioAPendiente" directamente', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`, REGISTRO_A1), { estadoPrevioAPendiente: 'enCurso' }));
  });

  // Auditoría de seguridad, octubre 2026: profesionalUid solo estaba
  // protegido en `update`, nunca en `create` -- un miembro podía crear el
  // registro YA con ese campo puesto, saltándose por completo el apretón
  // de manos de invitar/aceptar. (El bloqueo de "estado controlado" en
  // create que esta misma auditoría añadió se revirtió después -- ver el
  // test más abajo -- por romper la creación legítima de compras/notas
  // simples sin profesional.)
  it('ALLOW: un miembro crea un registro normal, sin profesionalUid ni estado controlado', async () => {
    await assertSucceeds(addDoc(collection(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`), { titulo: 'Nuevo', tipo: 'averia', esConProfesional: false, estado: 'nuevo' }));
  });

  it('DENY: un miembro no puede crear un registro con profesionalUid ya puesto', async () => {
    await assertFails(addDoc(collection(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`), { titulo: 'Colado', tipo: 'averia', esConProfesional: true, estado: 'nuevo', profesionalUid: PRO_AJENO }));
  });

  // Corregido (octubre 2026): una compra o nota simple sin profesional
  // (nuevo_elemento_screen.dart) crea su registro fundacional directamente
  // como "terminado" -- no hay profesional ni flujo de finalización que
  // saltarse, el registro nace y muere en el mismo estado. Bloquear esto
  // en "create" rompía esa alta legítima sin cerrar ningún hueco real: la
  // combinación peligrosa (estado cerrado + profesionalUid) ya está
  // cubierta por el test de arriba, que bloquea profesionalUid en create
  // sin importar el estado.
  it('ALLOW: un miembro crea un registro sin profesional ya "terminado" (compra/nota simple)', async () => {
    await assertSucceeds(addDoc(collection(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`), { titulo: 'Freidora nueva', tipo: 'compra', esConProfesional: false, estado: 'terminado' }));
  });

  // DATA-3 (segunda auditoría, octubre 2026): mismo criterio que
  // profesionalUid -- sin esto, un miembro podría crear el registro ya con
  // un "presupuesto"/"presupuestoAceptadoId" inventados, sin que ninguna
  // Cloud Function los haya puesto nunca.
  it('DENY: un miembro no puede crear un registro con "presupuesto" ya puesto', async () => {
    await assertFails(addDoc(collection(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`), { titulo: 'Colado', tipo: 'averia', esConProfesional: false, estado: 'nuevo', presupuesto: 500 }));
  });

  it('DENY: un miembro no puede crear un registro con "presupuestoAceptadoId" ya puesto', async () => {
    await assertFails(addDoc(collection(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros`), { titulo: 'Colado', tipo: 'averia', esConProfesional: false, estado: 'nuevo', presupuestoAceptadoId: 'pres-falso' }));
  });
});

describe('resumen -- banner de "pendientes" en Inicio (mantenido por Cloud Function)', () => {
  // Reemplaza la consulta collectionGroup('registros') descartada tras
  // validarla contra el emulador (ver firestore.rules) -- un único
  // documento de solo lectura, mantenido por onRegistroEstadoCambiado.
  it('ALLOW: un miembro lee el resumen de pendientes de su casa', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER_A), `casas/${CASA_A}/resumen`, 'pendientes')));
  });

  it('DENY: un usuario externo no puede leer el resumen de pendientes de una casa ajena', async () => {
    await assertFails(getDoc(doc(as(EXTRANO), `casas/${CASA_A}/resumen`, 'pendientes')));
  });

  it('DENY: nadie escribe el resumen directamente, ni el propietario (solo la Cloud Function)', async () => {
    await assertFails(setDoc(doc(as(OWNER_A), `casas/${CASA_A}/resumen`, 'pendientes'), { registros: [] }));
  });
});

describe('presupuestos y cambios de alcance -- siempre de solo lectura para el cliente', () => {
  it('ALLOW: el propietario lee los presupuestos de su registro', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/presupuestos`, 'pres-a1')));
  });

  it('ALLOW: el profesional asignado lee los presupuestos de SU registro', async () => {
    await assertSucceeds(getDoc(doc(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/presupuestos`, 'pres-a1')));
  });

  it('DENY: un profesional ajeno no puede leer presupuestos de un registro que no es suyo', async () => {
    await assertFails(getDoc(doc(as(PRO_AJENO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/presupuestos`, 'pres-a1')));
  });

  it('DENY: nadie puede escribir un presupuesto directamente, ni el propietario', async () => {
    await assertFails(setDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/presupuestos`, 'falso'), { total: 1 }));
  });

  it('DENY: el profesional no puede auto-aprobarse un presupuesto con una escritura directa', async () => {
    await assertFails(updateDoc(doc(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/presupuestos`, 'pres-a1'), { estado: 'aceptado' }));
  });

  it('DENY: nadie puede escribir un cambio de alcance directamente', async () => {
    await assertFails(addDoc(collection(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/cambiosAlcance`), { titulo: 'x', estado: 'pendiente' }));
  });
});

describe('historial -- append-only, mismo criterio de lectura que presupuestos/cambiosAlcance', () => {
  it('ALLOW: el propietario lee el historial de su registro', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/historial`, 'h1'), {
        actorUid: PRO, entidad: 'presupuesto', entidadId: 'pres-a1', accion: 'creado',
      });
    });
    await assertSucceeds(getDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/historial`, 'h1')));
  });

  it('ALLOW: el profesional asignado lee el historial de SU registro', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/historial`, 'h1'), { accion: 'creado' });
    });
    await assertSucceeds(getDoc(doc(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/historial`, 'h1')));
  });

  it('DENY: un profesional ajeno no puede leer el historial de un registro que no es suyo', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/historial`, 'h1'), { accion: 'creado' });
    });
    await assertFails(getDoc(doc(as(PRO_AJENO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/historial`, 'h1')));
  });

  it('DENY: nadie puede escribir en el historial directamente, ni el propietario', async () => {
    await assertFails(setDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/historial`, 'falso'), { accion: 'manipulado' }));
  });

  it('DENY: un usuario externo no puede leer el historial de una casa ajena', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/historial`, 'h1'), { accion: 'creado' });
    });
    await assertFails(getDoc(doc(as(EXTRANO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/historial`, 'h1')));
  });
});

describe('pagos -- create/update solo vía Cloud Function, delete directo restringido a quien lo creó', () => {
  // DATA-1 (auditoría de integridad económica, octubre 2026): create/update
  // pasaron de ser escritura directa del cliente a exigir Cloud Function
  // (registrarPago/actualizarPago), que valida el total acumulado contra el
  // presupuesto dentro de una transacción -- algo que estas reglas, al
  // evaluarse documento a documento, no pueden comprobar. Por eso ahora son
  // `if false` sin excepción, pase lo que pase en los datos; la lógica de
  // "importe válido"/"quien creó puede editar" vive en las propias Cloud
  // Functions (ver functions-tests/payments.test.js para esos casos).
  it('DENY: ni siquiera el propietario puede crear un pago directo desde el cliente', async () => {
    await assertFails(addDoc(collection(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/pagos`), { importe: 10, fecha: new Date() }));
  });

  it('ALLOW: el profesional asignado lee los pagos de SU registro', async () => {
    await assertSucceeds(getDoc(doc(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/pagos`, 'pago-a1')));
  });

  it('DENY: el profesional no puede crear pagos', async () => {
    await assertFails(addDoc(collection(as(PRO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/pagos`), { importe: 10, fecha: new Date() }));
  });

  it('DENY: un profesional ajeno no puede leer pagos de un registro que no es suyo', async () => {
    await assertFails(getDoc(doc(as(PRO_AJENO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/pagos`, 'pago-a1')));
  });

  it('DENY: un usuario externo no puede escribir pagos en una casa ajena', async () => {
    await assertFails(addDoc(collection(as(EXTRANO), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/pagos`), { importe: 10, fecha: new Date() }));
  });

  it('DENY: ni siquiera quien creó el pago puede editarlo directo desde el cliente', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/pagos`, 'pago-a1'), { concepto: 'Primera parte' }));
  });

  it('DENY: otro miembro de la misma casa tampoco puede editar un pago que no creó él', async () => {
    await assertFails(deleteDoc(doc(as(MIEMBRO_A2), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/pagos`, 'pago-a1')));
  });

  it('ALLOW: quien creó el pago sí puede borrarlo', async () => {
    await assertSucceeds(deleteDoc(doc(as(OWNER_A), `casas/${CASA_A}/elementos/${ELEMENTO_A1}/registros/${REGISTRO_A1}/pagos`, 'pago-a1')));
  });
});

describe('documentos -- acceso acotado al registro concreto del profesional', () => {
  it('ALLOW: el propietario lee los documentos de su casa', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER_A), `casas/${CASA_A}/documentos`, 'doc-a1')));
  });

  it('ALLOW: el profesional asignado lee un documento ligado a SU registro', async () => {
    await assertSucceeds(getDoc(doc(as(PRO), `casas/${CASA_A}/documentos`, 'doc-a1')));
  });

  it('DENY: un profesional ajeno no puede leer un documento ligado a un registro que no es suyo', async () => {
    await assertFails(getDoc(doc(as(PRO_AJENO), `casas/${CASA_A}/documentos`, 'doc-a1')));
  });

  it('DENY: un usuario externo no puede leer documentos de una casa ajena', async () => {
    await assertFails(getDoc(doc(as(EXTRANO), `casas/${CASA_A}/documentos`, 'doc-a1')));
  });

  it('DENY: el profesional no puede modificar/borrar un documento, solo crear/leer', async () => {
    await assertFails(deleteDoc(doc(as(PRO), `casas/${CASA_A}/documentos`, 'doc-a1')));
  });
});

describe('users -- cada usuario solo ve/edita su propio perfil', () => {
  it('ALLOW: el dueño lee su propio documento de usuario', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER_A), 'users', OWNER_A)));
  });

  it('DENY: otro usuario no puede leer el documento de usuario ajeno (activeCasaId/casaIds)', async () => {
    await assertFails(getDoc(doc(as(EXTRANO), 'users', OWNER_A)));
  });

  it('DENY: otro usuario no puede escribir en el documento de usuario ajeno', async () => {
    await assertFails(updateDoc(doc(as(EXTRANO), 'users', OWNER_A), { activeCasaId: CASA_B }));
  });
});

describe('profesionales -- cada profesional solo ve/edita su propia ficha', () => {
  it('ALLOW: el propio profesional lee su ficha', async () => {
    await assertSucceeds(getDoc(doc(as(PRO), 'profesionales', PRO)));
  });

  it('DENY: otro profesional no puede leer la ficha de un profesional ajeno', async () => {
    await assertFails(getDoc(doc(as(PRO_AJENO), 'profesionales', PRO)));
  });

  it('DENY: un propietario no puede leer directamente la ficha de un profesional (solo vía invitarProfesional)', async () => {
    await assertFails(getDoc(doc(as(OWNER_A), 'profesionales', PRO)));
  });
});

describe('invitaciones -- solo las dos partes implicadas, y el profesional solo cambia "estado"', () => {
  it('ALLOW: el propietario que invitó lee la invitación', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER_A), 'invitaciones', 'inv-a1')));
  });

  it('ALLOW: el profesional invitado lee la invitación', async () => {
    await assertSucceeds(getDoc(doc(as(PRO), 'invitaciones', 'inv-a1')));
  });

  it('DENY: un tercero sin relación no puede leer la invitación', async () => {
    await assertFails(getDoc(doc(as(EXTRANO), 'invitaciones', 'inv-a1')));
  });

  it('DENY: un profesional ajeno (no invitado) no puede leer la invitación', async () => {
    await assertFails(getDoc(doc(as(PRO_AJENO), 'invitaciones', 'inv-a1')));
  });

  it('ALLOW: el profesional invitado puede aceptarla (cambiar solo "estado")', async () => {
    await assertSucceeds(updateDoc(doc(as(PRO), 'invitaciones', 'inv-a1'), { estado: 'aceptada' }));
  });

  it('DENY: el propietario que invitó no puede cambiar el estado de la invitación (solo responde el profesional)', async () => {
    await assertFails(updateDoc(doc(as(OWNER_A), 'invitaciones', 'inv-a1'), { estado: 'aceptada' }));
  });

  it('DENY: un profesional ajeno no puede responder una invitación que no es suya', async () => {
    await assertFails(updateDoc(doc(as(PRO_AJENO), 'invitaciones', 'inv-a1'), { estado: 'aceptada' }));
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

  it('DENY: un profesional asignado a un registro no puede crear elementos en la casa (solo documentos de su registro)', async () => {
    await assertFails(addDoc(collection(as(PRO), `casas/${CASA_A}/elementos`), { nombre: 'Intento de profesional' }));
  });

  it('DENY: un profesional asignado a un registro no puede leer el elemento padre', async () => {
    await assertFails(getDoc(doc(as(PRO), `casas/${CASA_A}/elementos`, ELEMENTO_A1)));
  });

  it('DENY: un usuario externo no puede leer la libreta de contactos de otra casa', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `casas/${CASA_A}/contactos`, 'c1'), { nombre: 'Fontanero', telefono: '600' });
    });
    await assertFails(getDoc(doc(as(EXTRANO), `casas/${CASA_A}/contactos`, 'c1')));
  });
});
