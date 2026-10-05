// functions/index.js
// Cloud Functions para Repara — casas, invitación de miembros y clasificación
// de documentos por IA.
// Deploy: firebase deploy --only functions

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

initializeApp();
const db = getFirestore();

const REGION = 'europe-west1';
const MAX_MIEMBROS_CASA = 10;

// Secreto propio de Repara -- nunca se reutiliza el de RiskRunner/Convive,
// aunque los tres proyectos usen el mismo patrón de proxy a Anthropic.
const _anthropicKey = defineSecret('ANTHROPIC_API_KEY');

// Sin 0/O/1/I/L -- se confunden fácil al leer un código en voz alta o a mano.
const JOIN_CODE_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

async function generarCodigoUnico() {
  for (let intento = 0; intento < 10; intento++) {
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += JOIN_CODE_CHARS[Math.floor(Math.random() * JOIN_CODE_CHARS.length)];
    }
    const existe = await db.collection('joinCodes').doc(code).get();
    if (!existe.exists) return code;
  }
  throw new HttpsError('internal', 'No se pudo generar un código de casa único.');
}

// =============================================================================
// 1. CREAR CASA
// =============================================================================
exports.createCasa = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const nombre = typeof request.data?.nombre === 'string' ? request.data.nombre.trim() : '';
  if (!nombre || nombre.length > 60) {
    throw new HttpsError('invalid-argument', 'Nombre de casa inválido.');
  }

  const userSnap = await db.collection('users').doc(uid).get();
  const displayName = userSnap.exists ? (userSnap.data().displayName || 'Propietario') : 'Propietario';

  const joinCode = await generarCodigoUnico();
  const casaRef = db.collection('casas').doc();

  await db.runTransaction(async (tx) => {
    tx.set(casaRef, {
      nombre,
      joinCode,
      ownerUid: uid,
      members: [uid],
      memberProfiles: { [uid]: { displayName } },
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('joinCodes').doc(joinCode), { casaId: casaRef.id });
    tx.set(db.collection('users').doc(uid), {
      activeCasaId: casaRef.id,
      casaIds: FieldValue.arrayUnion(casaRef.id),
    }, { merge: true });
  });

  return { ok: true, casaId: casaRef.id, joinCode };
});

// =============================================================================
// 2. UNIRSE A UNA CASA (para compartir el historial con otro residente)
// =============================================================================
exports.joinCasa = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const raw = typeof request.data?.joinCode === 'string' ? request.data.joinCode : '';
  const joinCode = raw.trim().toUpperCase();
  if (!joinCode) throw new HttpsError('invalid-argument', 'Código inválido.');

  const codeSnap = await db.collection('joinCodes').doc(joinCode).get();
  if (!codeSnap.exists) throw new HttpsError('not-found', 'No existe ninguna casa con ese código.');
  const casaId = codeSnap.data().casaId;
  const casaRef = db.collection('casas').doc(casaId);

  const userSnap = await db.collection('users').doc(uid).get();
  const displayName = userSnap.exists ? (userSnap.data().displayName || 'Residente') : 'Residente';

  await db.runTransaction(async (tx) => {
    const casaSnap = await tx.get(casaRef);
    if (!casaSnap.exists) throw new HttpsError('not-found', 'La casa ya no existe.');
    const data = casaSnap.data();
    if (!(data.members || []).includes(uid)) {
      if ((data.members || []).length >= MAX_MIEMBROS_CASA) {
        throw new HttpsError('failed-precondition', 'Esta casa ya tiene el máximo de miembros.');
      }
      tx.update(casaRef, {
        members: FieldValue.arrayUnion(uid),
        [`memberProfiles.${uid}`]: { displayName },
      });
    }
    tx.set(db.collection('users').doc(uid), {
      activeCasaId: casaId,
      casaIds: FieldValue.arrayUnion(casaId),
    }, { merge: true });
  });

  return { ok: true, casaId };
});

// =============================================================================
// REPARA PRO — rol profesional, invitación a un trabajo y aceptación
// =============================================================================

// -----------------------------------------------------------------------------
// 3a. ACTIVAR MODO PROFESIONAL
// Autoservicio (sección 5 del spec: una persona puede tener varios roles) --
// no requiere aprobación, solo crea el perfil si no existe todavía.
// -----------------------------------------------------------------------------
exports.activarModoProfesional = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;

  await db.collection('users').doc(uid).set({ esProfesional: true }, { merge: true });

  const profRef = db.collection('profesionales').doc(uid);
  const profSnap = await profRef.get();
  if (!profSnap.exists) {
    await profRef.set({ createdAt: FieldValue.serverTimestamp() });
  }
  return { ok: true };
});

// -----------------------------------------------------------------------------
// 3b. INVITAR PROFESIONAL A UN TRABAJO
// Si el email corresponde a una cuenta profesional YA existente, funciona
// como siempre (invitación directa). Si NO existe cuenta, en vez de fallar
// se genera un CÓDIGO DE INVITACIÓN ABIERTA (mismo patrón que el código
// para unirse a una casa) que el propietario comparte por su cuenta
// (WhatsApp/SMS) -- la persona invitada lo canjea desde la app una vez
// tiene cuenta (ver canjearCodigoInvitacion). Esto es lo que permite que el
// crecimiento del lado profesional no dependa de que ya exista gente
// registrada -- sigue siendo una invitación 1 a 1 de alguien que ya
// conoces, no un listado público.
// -----------------------------------------------------------------------------
const CODIGO_INVITACION_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

async function generarCodigoInvitacionUnico() {
  for (let intento = 0; intento < 10; intento++) {
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += CODIGO_INVITACION_CHARS[Math.floor(Math.random() * CODIGO_INVITACION_CHARS.length)];
    }
    const existe = await db.collection('invitacionesAbiertas').doc(code).get();
    if (!existe.exists) return code;
  }
  throw new HttpsError('internal', 'No se pudo generar un código de invitación único.');
}

exports.invitarProfesional = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const propietarioUid = request.auth.uid;
  const { casaId, trabajoId, emailProfesional, telefonoProfesional } = request.data || {};
  const email = typeof emailProfesional === 'string' ? emailProfesional.trim().toLowerCase() : '';
  const telefono = typeof telefonoProfesional === 'string' ? telefonoProfesional.trim() : '';
  if (!casaId || !trabajoId || (!email && !telefono)) {
    throw new HttpsError('invalid-argument', 'Faltan datos para la invitación.');
  }

  const casaRef = db.collection('casas').doc(casaId);
  const trabajoRef = casaRef.collection('trabajos').doc(trabajoId);
  const [casaSnap, trabajoSnap] = await Promise.all([casaRef.get(), trabajoRef.get()]);
  if (!casaSnap.exists || !(casaSnap.data().members || []).includes(propietarioUid)) {
    throw new HttpsError('permission-denied', 'No perteneces a esa casa.');
  }
  if (!trabajoSnap.exists) throw new HttpsError('not-found', 'El trabajo no existe.');

  let profesionalUid = null;
  if (email) {
    try {
      const usuarioAuth = await getAuth().getUserByEmail(email);
      if (usuarioAuth.uid === propietarioUid) {
        throw new HttpsError('invalid-argument', 'No puedes invitarte a ti mismo.');
      }
      const userSnap = await db.collection('users').doc(usuarioAuth.uid).get();
      if (userSnap.exists && userSnap.data().esProfesional === true) {
        profesionalUid = usuarioAuth.uid;
      }
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      // getUserByEmail lanza si no existe cuenta con ese email -- se trata
      // igual que "existe pero no es profesional": cae al código abierto.
    }
  }

  if (profesionalUid) {
    const invitacionRef = db.collection('invitaciones').doc();
    await invitacionRef.set({
      casaId,
      trabajoId,
      trabajoTitulo: trabajoSnap.data().titulo || '',
      casaNombre: casaSnap.data().nombre || 'Una casa',
      propietarioUid,
      profesionalUid,
      profesionalEmail: email,
      estado: 'pendiente',
      createdAt: FieldValue.serverTimestamp(),
    });
    return { ok: true, tipo: 'directa', invitacionId: invitacionRef.id };
  }

  // Sin cuenta profesional encontrada -- código abierto para compartir a
  // mano. Válido 30 días; pasado ese plazo el propietario puede generar
  // otro sin problema (no hay límite de reintentos, es su propio contacto).
  const codigo = await generarCodigoInvitacionUnico();
  await db.collection('invitacionesAbiertas').doc(codigo).set({
    casaId,
    trabajoId,
    trabajoTitulo: trabajoSnap.data().titulo || '',
    casaNombre: casaSnap.data().nombre || 'Una casa',
    propietarioUid,
    contactoEmail: email || null,
    contactoTelefono: telefono || null,
    estado: 'pendiente_registro',
    createdAt: FieldValue.serverTimestamp(),
    expiraEn: Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000),
  });
  return { ok: true, tipo: 'abierta', codigo };
});

// -----------------------------------------------------------------------------
// 3b-bis. CANJEAR UN CÓDIGO DE INVITACIÓN ABIERTA
// Lo llama la persona invitada, ya con su propia cuenta de Repara (nueva o
// existente). Activa el modo profesional si no lo tenía, y crea la
// invitación normal en estado "pendiente" -- sigue exigiendo aceptación
// explícita desde Inicio Pro, canjear el código no vincula nada todavía.
// -----------------------------------------------------------------------------
exports.canjearCodigoInvitacion = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const raw = typeof request.data?.codigo === 'string' ? request.data.codigo : '';
  const codigo = raw.trim().toUpperCase();
  if (!codigo) throw new HttpsError('invalid-argument', 'Código inválido.');

  const abiertaRef = db.collection('invitacionesAbiertas').doc(codigo);

  const resultado = await db.runTransaction(async (tx) => {
    const snap = await tx.get(abiertaRef);
    if (!snap.exists) throw new HttpsError('not-found', 'No existe ninguna invitación con ese código.');
    const inv = snap.data();
    if (inv.estado !== 'pendiente_registro') {
      throw new HttpsError('failed-precondition', 'Este código ya se ha usado.');
    }
    if (inv.expiraEn && inv.expiraEn.toMillis() < Date.now()) {
      throw new HttpsError('failed-precondition', 'Este código ha caducado. Pide uno nuevo.');
    }
    if (inv.propietarioUid === uid) {
      throw new HttpsError('invalid-argument', 'No puedes canjear tu propia invitación.');
    }

    const invitacionRef = db.collection('invitaciones').doc();
    tx.set(invitacionRef, {
      casaId: inv.casaId,
      trabajoId: inv.trabajoId,
      trabajoTitulo: inv.trabajoTitulo,
      casaNombre: inv.casaNombre,
      propietarioUid: inv.propietarioUid,
      profesionalUid: uid,
      profesionalEmail: inv.contactoEmail || '',
      estado: 'pendiente',
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(abiertaRef, { estado: 'canjeado', profesionalUidCanjeo: uid });
    tx.set(db.collection('users').doc(uid), { esProfesional: true }, { merge: true });

    return { casaNombre: inv.casaNombre, trabajoTitulo: inv.trabajoTitulo };
  });

  const profRef = db.collection('profesionales').doc(uid);
  const profSnap = await profRef.get();
  if (!profSnap.exists) await profRef.set({ createdAt: FieldValue.serverTimestamp() });

  return { ok: true, ...resultado };
});

// -----------------------------------------------------------------------------
// 3c. RESPONDER A UNA INVITACIÓN (aceptar/rechazar)
// Al aceptar: vincula profesionalUid en el trabajo y guarda una copia ligera
// en users/{uid}.trabajosProRefs para que "Trabajos"/"Clientes" en REPARA
// Pro no necesiten permiso de lectura sobre la casa entera.
// -----------------------------------------------------------------------------
exports.responderInvitacion = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { invitacionId, aceptar } = request.data || {};
  if (!invitacionId || typeof aceptar !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Faltan datos.');
  }

  const invitacionRef = db.collection('invitaciones').doc(invitacionId);

  await db.runTransaction(async (tx) => {
    const invSnap = await tx.get(invitacionRef);
    if (!invSnap.exists) throw new HttpsError('not-found', 'La invitación ya no existe.');
    const inv = invSnap.data();
    if (inv.profesionalUid !== uid) {
      throw new HttpsError('permission-denied', 'Esta invitación no es tuya.');
    }
    if (inv.estado !== 'pendiente') {
      throw new HttpsError('failed-precondition', 'Esta invitación ya se respondió.');
    }

    let nombreProfesional = null;
    if (aceptar) {
      const userSnap = await tx.get(db.collection('users').doc(uid));
      nombreProfesional = userSnap.exists ? (userSnap.data().displayName || null) : null;
    }

    tx.update(invitacionRef, { estado: aceptar ? 'aceptada' : 'rechazada' });

    if (aceptar) {
      const trabajoRef = db.collection('casas').doc(inv.casaId).collection('trabajos').doc(inv.trabajoId);
      tx.update(trabajoRef, {
        profesionalUid: uid,
        ...(nombreProfesional ? { profesionalNombre: nombreProfesional } : {}),
      });
      tx.set(db.collection('users').doc(uid), {
        trabajosProRefs: FieldValue.arrayUnion({
          casaId: inv.casaId,
          trabajoId: inv.trabajoId,
          trabajoTitulo: inv.trabajoTitulo,
          casaNombre: inv.casaNombre,
        }),
      }, { merge: true });
    }
  });

  return { ok: true };
});

// =============================================================================
// Helpers compartidos — notificaciones internas y eventos de historial
// (sección 22 del spec: nada de esto debe vivir desconectado del historial
// de la vivienda).
// =============================================================================
async function crearNotificacion(uid, tipo, titulo, cuerpo, extra) {
  await db.collection('notificaciones').add({
    uid,
    tipo,
    titulo,
    cuerpo,
    leida: false,
    createdAt: FieldValue.serverTimestamp(),
    ...(extra || {}),
  });
}

async function crearEventoHistorial(casaId, evento) {
  await db.collection('casas').doc(casaId).collection('eventos').add({
    documentoIds: [],
    ...evento,
    fecha: evento.fecha || FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  });
}

function redondear2(n) {
  return Math.round((Number(n) || 0) * 100) / 100;
}

function validarLineas(lineas) {
  if (!Array.isArray(lineas) || lineas.length === 0) {
    throw new HttpsError('invalid-argument', 'El presupuesto necesita al menos una línea.');
  }
  if (lineas.length > 50) {
    throw new HttpsError('invalid-argument', 'Demasiadas líneas en el presupuesto (máximo 50).');
  }
  return lineas.map((l) => {
    const descripcion = typeof l.descripcion === 'string' ? l.descripcion.trim().slice(0, 200) : '';
    const cantidad = Number(l.cantidad);
    const precioUnitario = Number(l.precioUnitario);
    const ivaPorcentaje = l.ivaPorcentaje == null ? 21 : Number(l.ivaPorcentaje);
    if (!descripcion) throw new HttpsError('invalid-argument', 'Cada línea necesita una descripción.');
    if (!Number.isFinite(cantidad) || cantidad <= 0) throw new HttpsError('invalid-argument', 'Cantidad inválida en una línea.');
    if (!Number.isFinite(precioUnitario) || precioUnitario < 0) throw new HttpsError('invalid-argument', 'Precio inválido en una línea.');
    if (!Number.isFinite(ivaPorcentaje) || ivaPorcentaje < 0 || ivaPorcentaje > 100) throw new HttpsError('invalid-argument', 'IVA inválido en una línea.');
    return { descripcion, cantidad, precioUnitario, ivaPorcentaje };
  });
}

// Nunca se confía en subtotal/iva/total que pudiera mandar el cliente
// (sección 16 del spec: "no confiar únicamente en cálculos del cliente") --
// se recalculan siempre aquí a partir de las líneas ya validadas.
function calcularTotales(lineas) {
  let subtotal = 0;
  let iva = 0;
  for (const l of lineas) {
    const importeLinea = l.cantidad * l.precioUnitario;
    subtotal += importeLinea;
    iva += importeLinea * (l.ivaPorcentaje / 100);
  }
  return { subtotal: redondear2(subtotal), iva: redondear2(iva), total: redondear2(subtotal + iva) };
}

async function getTrabajoOThrow(casaId, trabajoId) {
  const ref = db.collection('casas').doc(casaId).collection('trabajos').doc(trabajoId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'El trabajo no existe.');
  return { ref, snap, data: snap.data() };
}

async function esMiembroCasa(casaId, uid) {
  const snap = await db.collection('casas').doc(casaId).get();
  return snap.exists && (snap.data().members || []).includes(uid);
}

// =============================================================================
// PRESUPUESTOS — casas/{cid}/trabajos/{tid}/presupuestos/{pid}
// Todas las escrituras pasan por aquí (las reglas de Firestore deniegan
// escritura directa del cliente) para que subtotal/IVA/total nunca dependan
// de lo que mande la app, y para impedir que el profesional se autoapruebe.
// =============================================================================

exports.crearPresupuesto = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { casaId, trabajoId, notas } = request.data || {};
  if (!casaId || !trabajoId) throw new HttpsError('invalid-argument', 'Faltan datos.');
  const lineas = validarLineas(request.data?.lineas);

  const { ref: trabajoRef, data: trabajo } = await getTrabajoOThrow(casaId, trabajoId);
  const esProfesionalAsignado = trabajo.profesionalUid === uid;
  if (!esProfesionalAsignado && !(await esMiembroCasa(casaId, uid))) {
    throw new HttpsError('permission-denied', 'No tienes acceso a este trabajo.');
  }

  const totales = calcularTotales(lineas);
  const presupuestosCol = trabajoRef.collection('presupuestos');
  const existentesSnap = await presupuestosCol.get();
  const numero = existentesSnap.docs.filter((d) => !d.data().presupuestoAnteriorId).length + 1;

  const ref = await presupuestosCol.add({
    numero,
    version: 1,
    estado: 'borrador',
    lineas,
    notas: typeof notas === 'string' ? notas.trim().slice(0, 1000) : null,
    presupuestoAnteriorId: null,
    ...totales,
    creadoPorUid: uid,
    fechaCreacion: FieldValue.serverTimestamp(),
    fechaEnvio: null,
    fechaRespuesta: null,
  });

  return { ok: true, presupuestoId: ref.id, ...totales };
});

exports.actualizarLineasPresupuesto = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { casaId, trabajoId, presupuestoId, notas } = request.data || {};
  if (!casaId || !trabajoId || !presupuestoId) throw new HttpsError('invalid-argument', 'Faltan datos.');
  const lineas = validarLineas(request.data?.lineas);

  const ref = db.collection('casas').doc(casaId).collection('trabajos').doc(trabajoId).collection('presupuestos').doc(presupuestoId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'El presupuesto no existe.');
  const p = snap.data();
  if (p.creadoPorUid !== uid) throw new HttpsError('permission-denied', 'Solo quien lo creó puede editarlo.');
  if (p.estado !== 'borrador') throw new HttpsError('failed-precondition', 'Solo se puede editar un presupuesto en borrador.');

  const totales = calcularTotales(lineas);
  await ref.update({ lineas, notas: typeof notas === 'string' ? notas.trim().slice(0, 1000) : p.notas, ...totales });
  return { ok: true, ...totales };
});

exports.enviarPresupuesto = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { casaId, trabajoId, presupuestoId } = request.data || {};
  if (!casaId || !trabajoId || !presupuestoId) throw new HttpsError('invalid-argument', 'Faltan datos.');

  const trabajoRef = db.collection('casas').doc(casaId).collection('trabajos').doc(trabajoId);
  const ref = trabajoRef.collection('presupuestos').doc(presupuestoId);
  const [snap, trabajoSnap] = await Promise.all([ref.get(), trabajoRef.get()]);
  if (!snap.exists || !trabajoSnap.exists) throw new HttpsError('not-found', 'No encontrado.');
  const p = snap.data();
  if (p.creadoPorUid !== uid) throw new HttpsError('permission-denied', 'Solo quien lo creó puede enviarlo.');
  if (p.estado !== 'borrador') throw new HttpsError('failed-precondition', 'Este presupuesto ya se envió.');

  await ref.update({ estado: 'enviado', fechaEnvio: FieldValue.serverTimestamp() });

  const trabajo = trabajoSnap.data();
  const casaSnap = await db.collection('casas').doc(casaId).get();
  for (const memberUid of casaSnap.data().members || []) {
    await crearNotificacion(memberUid, 'presupuesto_enviado',
      'Nuevo presupuesto', `Has recibido un presupuesto de ${p.total.toFixed(2)} € para "${trabajo.titulo}".`,
      { casaId, trabajoId, presupuestoId });
  }
  return { ok: true };
});

exports.responderPresupuesto = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { casaId, trabajoId, presupuestoId, aceptar } = request.data || {};
  if (!casaId || !trabajoId || !presupuestoId || typeof aceptar !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Faltan datos.');
  }
  if (!(await esMiembroCasa(casaId, uid))) throw new HttpsError('permission-denied', 'No perteneces a esa casa.');

  const trabajoRef = db.collection('casas').doc(casaId).collection('trabajos').doc(trabajoId);
  const trabajoSnap = await trabajoRef.get();
  if (!trabajoSnap.exists) throw new HttpsError('not-found', 'El trabajo no existe.');
  // Un trabajo ya cerrado no debe poder "reabrirse" en silencio al aceptar
  // un presupuesto -- si no se bloquea aquí, el estado pasa a
  // 'presupuestado', el botón de Finalizar del propietario reaparece y, al
  // volver a pulsarlo, se duplica el evento de historial del mismo trabajo.
  const estadoTrabajo = trabajoSnap.data().estado;
  if (estadoTrabajo === 'terminado' || estadoTrabajo === 'archivado') {
    throw new HttpsError('failed-precondition', 'Este trabajo ya está finalizado, no se pueden responder presupuestos.');
  }

  const ref = trabajoRef.collection('presupuestos').doc(presupuestoId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'El presupuesto no existe.');
  const p = snap.data();
  // Nunca se permite que quien creó el presupuesto sea también quien lo
  // aprueba (sección 18 del spec: "No permitir que el profesional se
  // autoapruebe un presupuesto").
  if (p.creadoPorUid === uid) throw new HttpsError('permission-denied', 'No puedes aprobar tu propio presupuesto.');
  if (p.estado !== 'enviado') throw new HttpsError('failed-precondition', 'Este presupuesto no está pendiente de respuesta.');

  await ref.update({
    estado: aceptar ? 'aceptado' : 'rechazado',
    fechaRespuesta: FieldValue.serverTimestamp(),
    respondidoPorUid: uid,
  });

  if (aceptar) {
    await trabajoRef.update({ presupuesto: p.total, estado: 'presupuestado' });
  }

  await crearEventoHistorial(casaId, {
    tipo: 'nota',
    titulo: aceptar ? `Presupuesto aceptado (${p.total.toFixed(2)} €)` : 'Presupuesto rechazado',
    trabajoId,
    coste: aceptar ? p.total : null,
    createdBy: uid,
  });

  if (p.creadoPorUid) {
    await crearNotificacion(p.creadoPorUid, aceptar ? 'presupuesto_aceptado' : 'presupuesto_rechazado',
      aceptar ? 'Presupuesto aceptado' : 'Presupuesto rechazado',
      aceptar ? `Te han aceptado el presupuesto de ${p.total.toFixed(2)} €.` : 'Te han rechazado un presupuesto.',
      { casaId, trabajoId, presupuestoId });
  }
  return { ok: true };
});

exports.crearNuevaVersionPresupuesto = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { casaId, trabajoId, presupuestoAnteriorId, notas } = request.data || {};
  if (!casaId || !trabajoId || !presupuestoAnteriorId) throw new HttpsError('invalid-argument', 'Faltan datos.');
  const lineas = validarLineas(request.data?.lineas);

  const trabajoRef = db.collection('casas').doc(casaId).collection('trabajos').doc(trabajoId);
  const anteriorRef = trabajoRef.collection('presupuestos').doc(presupuestoAnteriorId);
  const anteriorSnap = await anteriorRef.get();
  if (!anteriorSnap.exists) throw new HttpsError('not-found', 'El presupuesto anterior no existe.');
  const anterior = anteriorSnap.data();
  if (anterior.creadoPorUid !== uid) throw new HttpsError('permission-denied', 'Solo quien creó el presupuesto puede revisarlo.');
  // Solo se versiona un presupuesto ya cerrado (rechazado) -- nunca se
  // reescribe uno enviado o aceptado (sección 17: "no debe sobrescribirse
  // destructivamente después de haber sido enviado").
  if (anterior.estado !== 'rechazado') throw new HttpsError('failed-precondition', 'Solo se puede crear una nueva versión de un presupuesto rechazado.');

  const totales = calcularTotales(lineas);
  const ref = await trabajoRef.collection('presupuestos').add({
    numero: anterior.numero,
    version: anterior.version + 1,
    estado: 'borrador',
    lineas,
    notas: typeof notas === 'string' ? notas.trim().slice(0, 1000) : null,
    presupuestoAnteriorId,
    ...totales,
    creadoPorUid: uid,
    fechaCreacion: FieldValue.serverTimestamp(),
    fechaEnvio: null,
    fechaRespuesta: null,
  });

  return { ok: true, presupuestoId: ref.id, ...totales };
});

// =============================================================================
// SCOPEGUARD — cambios de alcance, casas/{cid}/trabajos/{tid}/cambiosAlcance
// =============================================================================

exports.crearCambioAlcance = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { casaId, trabajoId, titulo, descripcion, motivo, importeAdicional, tiempoAdicionalHoras, fotos, presupuestoId } = request.data || {};
  if (!casaId || !trabajoId || typeof titulo !== 'string' || !titulo.trim()) {
    throw new HttpsError('invalid-argument', 'Faltan datos.');
  }
  const { ref: trabajoRef, data: trabajo } = await getTrabajoOThrow(casaId, trabajoId);
  if (trabajo.profesionalUid !== uid) {
    throw new HttpsError('permission-denied', 'Solo el profesional asignado puede solicitar un cambio de alcance.');
  }
  const importe = importeAdicional == null ? null : Number(importeAdicional);
  if (importe != null && !Number.isFinite(importe)) throw new HttpsError('invalid-argument', 'Importe adicional inválido.');

  const ref = await trabajoRef.collection('cambiosAlcance').add({
    titulo: titulo.trim().slice(0, 120),
    descripcion: typeof descripcion === 'string' ? descripcion.trim().slice(0, 1000) : null,
    motivo: typeof motivo === 'string' ? motivo.trim().slice(0, 1000) : null,
    fotos: Array.isArray(fotos) ? fotos.slice(0, 10) : [],
    importeAdicional: importe,
    tiempoAdicionalHoras: tiempoAdicionalHoras == null ? null : Number(tiempoAdicionalHoras),
    presupuestoId: typeof presupuestoId === 'string' ? presupuestoId : null,
    estado: 'pendiente',
    creadoPorUid: uid,
    createdAt: FieldValue.serverTimestamp(),
  });

  const casaSnap = await db.collection('casas').doc(casaId).get();
  for (const memberUid of casaSnap.data().members || []) {
    await crearNotificacion(memberUid, 'cambio_alcance_solicitado',
      'Cambio de alcance solicitado', `Se ha solicitado un cambio en "${trabajo.titulo}": ${titulo.trim()}`,
      { casaId, trabajoId, cambioAlcanceId: ref.id });
  }
  return { ok: true, cambioAlcanceId: ref.id };
});

exports.responderCambioAlcance = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { casaId, trabajoId, cambioAlcanceId, aprobar } = request.data || {};
  if (!casaId || !trabajoId || !cambioAlcanceId || typeof aprobar !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Faltan datos.');
  }
  if (!(await esMiembroCasa(casaId, uid))) throw new HttpsError('permission-denied', 'No perteneces a esa casa.');

  const trabajoRef = db.collection('casas').doc(casaId).collection('trabajos').doc(trabajoId);
  const ref = trabajoRef.collection('cambiosAlcance').doc(cambioAlcanceId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'El cambio de alcance no existe.');
  const c = snap.data();
  // El profesional NO puede aprobarse a sí mismo el cambio que él mismo
  // solicitó (sección 20: "El profesional NO debe poder convertir
  // unilateralmente el cambio en aprobado").
  if (c.creadoPorUid === uid) throw new HttpsError('permission-denied', 'No puedes aprobar tu propia solicitud.');
  if (c.estado !== 'pendiente') throw new HttpsError('failed-precondition', 'Esta solicitud ya se respondió.');

  await ref.update(aprobar
    ? { estado: 'aprobado', aprobadoPorUid: uid, aprobadoAt: FieldValue.serverTimestamp() }
    : { estado: 'rechazado', rechazadoPorUid: uid, rechazadoAt: FieldValue.serverTimestamp() });

  if (aprobar && c.importeAdicional) {
    const trabajoSnap = await trabajoRef.get();
    const presupuestoActual = Number(trabajoSnap.data().presupuesto) || 0;
    await trabajoRef.update({ presupuesto: redondear2(presupuestoActual + c.importeAdicional) });
  }

  await crearEventoHistorial(casaId, {
    tipo: 'nota',
    titulo: aprobar ? `Cambio de alcance aprobado: ${c.titulo}` : `Cambio de alcance rechazado: ${c.titulo}`,
    trabajoId,
    coste: aprobar ? c.importeAdicional : null,
    createdBy: uid,
  });

  await crearNotificacion(c.creadoPorUid, aprobar ? 'cambio_alcance_aprobado' : 'cambio_alcance_rechazado',
    aprobar ? 'Cambio de alcance aprobado' : 'Cambio de alcance rechazado',
    `Tu solicitud "${c.titulo}" ha sido ${aprobar ? 'aprobada' : 'rechazada'}.`,
    { casaId, trabajoId, cambioAlcanceId });

  return { ok: true };
});

exports.cancelarCambioAlcance = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { casaId, trabajoId, cambioAlcanceId } = request.data || {};
  if (!casaId || !trabajoId || !cambioAlcanceId) throw new HttpsError('invalid-argument', 'Faltan datos.');

  const ref = db.collection('casas').doc(casaId).collection('trabajos').doc(trabajoId).collection('cambiosAlcance').doc(cambioAlcanceId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'No existe.');
  if (snap.data().creadoPorUid !== uid) throw new HttpsError('permission-denied', 'Solo quien lo creó puede cancelarlo.');
  if (snap.data().estado !== 'pendiente') throw new HttpsError('failed-precondition', 'Ya se respondió a esta solicitud.');
  await ref.update({ estado: 'cancelado' });
  return { ok: true };
});

// =============================================================================
// FINALIZAR TRABAJO (lado profesional) — sección 28 del spec: queda
// registrado como finalizado por el profesional; el propietario conserva la
// capacidad de revisar/completar el registro desde Hogar.
// =============================================================================
exports.finalizarTrabajoProfesional = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { casaId, trabajoId } = request.data || {};
  if (!casaId || !trabajoId) throw new HttpsError('invalid-argument', 'Faltan datos.');

  const { ref: trabajoRef, data: trabajo } = await getTrabajoOThrow(casaId, trabajoId);
  if (trabajo.profesionalUid !== uid) throw new HttpsError('permission-denied', 'No eres el profesional de este trabajo.');
  if (trabajo.estado === 'terminado' || trabajo.estado === 'archivado') {
    throw new HttpsError('failed-precondition', 'Este trabajo ya estaba finalizado.');
  }

  await trabajoRef.update({ estado: 'terminado' });
  await crearEventoHistorial(casaId, {
    tipo: 'nota',
    titulo: `${trabajo.titulo} -- finalizado por el profesional`,
    trabajoId,
    coste: trabajo.presupuesto || null,
    profesionalNombre: trabajo.profesionalNombre || null,
    createdBy: uid,
  });

  const casaSnap = await db.collection('casas').doc(casaId).get();
  for (const memberUid of casaSnap.data().members || []) {
    await crearNotificacion(memberUid, 'trabajo_finalizado',
      'Trabajo finalizado', `El profesional ha marcado "${trabajo.titulo}" como finalizado.`,
      { casaId, trabajoId });
  }
  return { ok: true };
});

// =============================================================================
// NOTIFICAR AL PROFESIONAL CUANDO SE LE REGISTRA UN PAGO
// Los pagos se escriben directo desde el cliente (ver PagoService -- aquí no
// hay ninguna aprobación entre dos partes que proteger, a diferencia de
// presupuestos/cambiosAlcance), pero crear una notificación sí necesita
// Admin SDK porque firestore.rules deniega su escritura directa. Por eso
// esto es un trigger sobre la propia escritura, no una Cloud Function que
// llame el cliente.
// =============================================================================
exports.onPagoCreado = onDocumentCreated(
  { region: REGION, document: 'casas/{casaId}/trabajos/{trabajoId}/pagos/{pagoId}' },
  async (event) => {
    const pago = event.data?.data();
    if (!pago) return;
    const { casaId, trabajoId, pagoId } = event.params;

    const trabajoSnap = await db.collection('casas').doc(casaId).collection('trabajos').doc(trabajoId).get();
    if (!trabajoSnap.exists) return;
    const trabajo = trabajoSnap.data();
    if (!trabajo.profesionalUid) return; // sin profesional en la app, nadie a quien avisar

    await crearNotificacion(trabajo.profesionalUid, 'pago_registrado',
      'Nuevo pago registrado', `Te han registrado un pago de ${Number(pago.importe || 0).toFixed(2)} € en "${trabajo.titulo}".`,
      { casaId, trabajoId, pagoId });
  }
);

// =============================================================================
// 3. CLASIFICAR DOCUMENTO CON IA
// Recibe una o varias páginas (base64, imagen o PDF) de una factura/
// presupuesto/garantía y devuelve una sugerencia estructurada de datos.
// NUNCA escribe directamente en Firestore -- el cliente siempre pide
// confirmación al propietario antes de guardar nada (sección 61 del spec:
// la IA ayuda, nunca decide sola).
// =============================================================================
const TIPOS_MEDIA_VALIDOS = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf'];

exports.classifyDocument = onCall(
  { region: REGION, secrets: [_anthropicKey], timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');

    // [paginas] es la forma nueva (varias páginas de un mismo documento);
    // se mantiene el nombre antiguo imageBase64/mediaType como fallback para
    // no romper si algo sigue llamando a la forma vieja.
    const { paginas, imageBase64, mediaType, elementosDisponibles, trabajosDisponibles } = request.data || {};
    const listaPaginas = Array.isArray(paginas) && paginas.length
        ? paginas
        : (typeof imageBase64 === 'string' && imageBase64 ? [{ data: imageBase64, mediaType: mediaType || 'image/jpeg' }] : []);

    if (!listaPaginas.length) {
      throw new HttpsError('invalid-argument', 'Falta el documento a analizar.');
    }
    if (listaPaginas.length > 10) {
      throw new HttpsError('invalid-argument', 'Demasiadas páginas en un mismo documento (máximo 10).');
    }
    for (const p of listaPaginas) {
      if (typeof p.data !== 'string' || !p.data) {
        throw new HttpsError('invalid-argument', 'Página de documento inválida.');
      }
      if (!TIPOS_MEDIA_VALIDOS.includes(p.mediaType)) {
        throw new HttpsError('invalid-argument', `Formato no admitido: ${p.mediaType}`);
      }
    }

    // Nombres existentes en la casa para que la IA pueda sugerir con cuál se
    // relaciona el documento, sin inventar uno que no existe -- el cliente
    // decide si acepta la sugerencia o elige otro/crea uno nuevo.
    const listaElementos = Array.isArray(elementosDisponibles) ? elementosDisponibles.slice(0, 50) : [];
    const listaTrabajos = Array.isArray(trabajosDisponibles) ? trabajosDisponibles.slice(0, 50) : [];

    const apiKey = _anthropicKey.value();
    if (!apiKey) throw new HttpsError('internal', 'API key no configurada en el servidor.');

    const systemPrompt = `Eres un asistente que extrae información de documentos del hogar (facturas, presupuestos, garantías, manuales, contratos) a partir de una o varias fotos/páginas escaneadas del MISMO documento.
Devuelve EXCLUSIVAMENTE un objeto JSON con esta forma exacta, sin texto adicional ni markdown:
{
  "tipo": "factura|presupuesto|garantia|manual|contrato|otro",
  "fecha": "YYYY-MM-DD o null",
  "fechaVencimiento": "YYYY-MM-DD o null",
  "proveedor": "nombre del profesional o empresa emisora, o null",
  "nifCif": "identificador fiscal del emisor, o null",
  "numeroReferencia": "número de factura/presupuesto, o null",
  "importe": numero total o null,
  "baseImponible": numero o null,
  "impuestos": numero (importe de impuestos, no porcentaje) o null,
  "moneda": "EUR u otra, o null",
  "descripcionTrabajo": "descripción breve del servicio/reparación en 1-2 frases, o null",
  "garantiaTexto": "texto literal sobre garantía si aparece, o null",
  "observaciones": "cualquier detalle relevante que no encaje en los campos anteriores, o null",
  "elementoSugerido": "uno de los nombres EXACTOS de la lista de elementos, o null",
  "trabajoSugerido": "uno de los nombres EXACTOS de la lista de trabajos, o null",
  "confianza": "alta|media|baja"
}
Reglas estrictas:
- Nunca inventes un dato que no puedas leer en el documento: si no se ve o no aparece, usa null.
- "importe" es el total final del documento, no un subtotal.
- La fecha es la del documento (emisión/factura), nunca la de hoy.
- "elementoSugerido" y "trabajoSugerido" deben ser EXACTAMENTE uno de los nombres de las listas de abajo, o null si ninguno encaja -- nunca inventes un nombre nuevo aquí.
- "confianza" baja significa que la imagen es difícil de leer o el documento es ambiguo.
Elementos existentes en esta casa: ${listaElementos.length ? listaElementos.join(', ') : '(ninguno todavía)'}
Trabajos existentes en esta casa: ${listaTrabajos.length ? listaTrabajos.join(', ') : '(ninguno todavía)'}`;

    const contenido = listaPaginas.map((p) => ({
      type: p.mediaType === 'application/pdf' ? 'document' : 'image',
      source: { type: 'base64', media_type: p.mediaType, data: p.data },
    }));
    contenido.push({
      type: 'text',
      text: listaPaginas.length > 1
          ? `Estas ${listaPaginas.length} imágenes son páginas del MISMO documento. Analízalas juntas y devuelve solo el JSON pedido.`
          : 'Analiza este documento y devuelve solo el JSON pedido.',
    });

    let res;
    try {
      res = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 1536,
          system: systemPrompt,
          messages: [{ role: 'user', content: contenido }],
        }),
      });
    } catch (e) {
      console.error('classifyDocument fetch error:', e);
      throw new HttpsError('unavailable', 'No se pudo contactar con el servicio de IA.');
    }

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      // Nunca se registra el contenido del documento -- solo el estado del
      // fallo, para no dejar datos de facturas de usuarios en los logs.
      console.error(`classifyDocument Anthropic error ${res.status}:`, body.slice(0, 300));
      throw new HttpsError('internal', `Error del servicio de IA: ${res.status}`);
    }

    const data = await res.json();
    const textoRespuesta = data.content?.[0]?.text || '{}';
    try {
      const parsed = JSON.parse(textoRespuesta);
      return { ok: true, sugerencia: parsed };
    } catch (e) {
      // Si el modelo no devuelve JSON válido, no se revienta la función --
      // el cliente cae al flujo de clasificación manual (ver estadoIA en
      // lib/models/documento.dart). Nunca se afirma que el documento se
      // procesó correctamente cuando esto pasa.
      console.error('classifyDocument: respuesta no parseable como JSON');
      return { ok: true, sugerencia: null };
    }
  }
);

// =============================================================================
// 4. SUGERIR INTERVALO DE MANTENIMIENTO (calendario autogenerado por tipo de
// elemento, para no depender de que el propietario se acuerde solo). La IA
// solo SUGIERE un número de meses típico para ese tipo de aparato; el
// propietario lo ve y puede cambiarlo o dejarlo en blanco antes de guardar,
// igual que con classifyDocument -- nunca escribe nada directamente.
// =============================================================================
exports.sugerirIntervaloMantenimiento = onCall(
  { region: REGION, secrets: [_anthropicKey], timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
    const { nombre, marca, modelo } = request.data || {};
    if (typeof nombre !== 'string' || !nombre.trim()) {
      throw new HttpsError('invalid-argument', 'Falta el nombre del elemento.');
    }

    const apiKey = _anthropicKey.value();
    if (!apiKey) throw new HttpsError('internal', 'API key no configurada en el servidor.');

    const systemPrompt = `Eres un asistente que sugiere cada cuántos meses conviene revisar o hacer mantenimiento a un aparato o instalación del hogar, a partir de su nombre, marca y modelo.
Devuelve EXCLUSIVAMENTE un objeto JSON con esta forma exacta, sin texto adicional ni markdown:
{
  "intervaloMeses": numero entero entre 1 y 60, o null,
  "motivo": "una frase breve en español explicando por qué ese intervalo, o por qué no aplica"
}
Reglas estrictas:
- Usa el intervalo típico recomendado habitualmente para ese TIPO de aparato (p.ej. caldera de gas ~12 meses, aire acondicionado ~12 meses, extintor ~12 meses, termo eléctrico ~24 meses, filtro de agua ~6 meses).
- Si el nombre no corresponde a nada con mantenimiento periódico conocido (p.ej. una mesa, un sofá, una lámpara decorativa), devuelve intervaloMeses: null y explica brevemente por qué en "motivo".
- Nunca afirmes conocer el manual exacto de ese modelo concreto -- da siempre el intervalo típico general para ese tipo de aparato, nunca un dato inventado como si viniera del fabricante exacto.`;

    const detalle = [
      `Nombre: ${nombre.trim()}`,
      marca ? `Marca: ${String(marca).trim()}` : null,
      modelo ? `Modelo: ${String(modelo).trim()}` : null,
    ].filter(Boolean).join('\n');

    let res;
    try {
      res = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 300,
          system: systemPrompt,
          messages: [{ role: 'user', content: detalle }],
        }),
      });
    } catch (e) {
      console.error('sugerirIntervaloMantenimiento fetch error:', e);
      throw new HttpsError('unavailable', 'No se pudo contactar con el servicio de IA.');
    }

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      console.error(`sugerirIntervaloMantenimiento Anthropic error ${res.status}:`, body.slice(0, 300));
      throw new HttpsError('internal', `Error del servicio de IA: ${res.status}`);
    }

    const data = await res.json();
    const textoRespuesta = data.content?.[0]?.text || '{}';
    try {
      const parsed = JSON.parse(textoRespuesta);
      const bruto = Number(parsed.intervaloMeses);
      const intervalo = Number.isFinite(bruto) ? Math.max(1, Math.min(60, Math.round(bruto))) : null;
      return { ok: true, intervaloMeses: intervalo, motivo: typeof parsed.motivo === 'string' ? parsed.motivo : null };
    } catch (e) {
      console.error('sugerirIntervaloMantenimiento: respuesta no parseable como JSON');
      return { ok: true, intervaloMeses: null, motivo: null };
    }
  }
);
