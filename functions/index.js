// functions/index.js
// Cloud Functions para Repara — casas, invitación de miembros y clasificación
// de documentos por IA.
// Deploy: firebase deploy --only functions

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

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
// 3. CLASIFICAR DOCUMENTO CON IA
// Recibe una imagen (base64) de una factura/presupuesto/garantía y devuelve
// una sugerencia de tipo/fecha/proveedor/importe. NUNCA escribe directamente
// en Firestore -- el cliente siempre pide confirmación al propietario antes
// de guardar nada (sección 61 del spec: la IA ayuda, nunca decide sola).
// =============================================================================
exports.classifyDocument = onCall(
  { region: REGION, secrets: [_anthropicKey], timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');

    const { imageBase64, mediaType, elementosDisponibles } = request.data || {};
    if (typeof imageBase64 !== 'string' || !imageBase64) {
      throw new HttpsError('invalid-argument', 'Falta la imagen del documento.');
    }
    const tipoMedia = typeof mediaType === 'string' ? mediaType : 'image/jpeg';
    // Lista de nombres de elementos de la casa (p.ej. "Aire acondicionado
    // salón", "Caldera") para que la IA pueda sugerir con cuál se relaciona
    // el documento, sin inventar uno que no existe.
    const listaElementos = Array.isArray(elementosDisponibles) ? elementosDisponibles.slice(0, 50) : [];

    const apiKey = _anthropicKey.value();
    if (!apiKey) throw new HttpsError('internal', 'API key no configurada en el servidor.');

    const systemPrompt = `Eres un asistente que clasifica documentos del hogar (facturas, presupuestos, garantías, manuales, contratos) a partir de una foto o escaneo.
Devuelve EXCLUSIVAMENTE un objeto JSON con esta forma exacta, sin texto adicional ni markdown:
{"tipo":"factura|presupuesto|garantia|manual|contrato|otro","fecha":"YYYY-MM-DD o null","proveedor":"nombre o null","importe":numero o null,"elementoSugerido":"uno de los nombres de la lista o null","confianza":"alta|media|baja"}
Nunca inventes un dato que no puedas leer en la imagen: si no se ve, usa null. La fecha es la del documento (fecha de emisión/factura), no la de hoy.
Elementos existentes en esta casa: ${listaElementos.length ? listaElementos.join(', ') : '(ninguno todavía)'}`;

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
          max_tokens: 1024,
          system: systemPrompt,
          messages: [
            {
              role: 'user',
              content: [
                { type: 'image', source: { type: 'base64', media_type: tipoMedia, data: imageBase64 } },
                { type: 'text', text: 'Clasifica este documento y devuelve solo el JSON pedido.' },
              ],
            },
          ],
        }),
      });
    } catch (e) {
      console.error('classifyDocument fetch error:', e);
      throw new HttpsError('unavailable', 'No se pudo contactar con el servicio de IA.');
    }

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      console.error(`classifyDocument Anthropic error ${res.status}:`, body);
      throw new HttpsError('internal', `Error del servicio de IA: ${res.status}`);
    }

    const data = await res.json();
    const textoRespuesta = data.content?.[0]?.text || '{}';
    try {
      const parsed = JSON.parse(textoRespuesta);
      return { ok: true, sugerencia: parsed };
    } catch (e) {
      // Si el modelo no devuelve JSON válido, no se revienta la función --
      // se manda el texto crudo y el cliente cae al flujo de clasificación
      // manual (ver estadoIA en lib/models/documento.dart).
      console.error('classifyDocument: respuesta no parseable como JSON:', textoRespuesta);
      return { ok: true, sugerencia: null, raw: textoRespuesta };
    }
  }
);
