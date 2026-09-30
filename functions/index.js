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
