# CLAUDE.md — REPARA

## Qué es

La memoria digital de una vivienda. Jerarquía: Casa → Habitación → Elemento →
Trabajo → Presupuesto/CambioAlcance/Pago/Documento → Historial. Dos
experiencias en la misma cuenta: REPARA Hogar (propietario) y REPARA Pro
(profesional).

## Principio no negociable: nunca un marketplace

No existen ni deben existir: búsqueda pública de profesionales, rankings,
valoraciones, pujas, directorio público, comparación de profesionales.
REPARA conecta solo a propietarios y profesionales que ya se conocen o que
el propietario ya ha elegido. Cualquier feature que empiece a parecerse a
esto, aunque sea "solo un poco" o "solo para casos sin contacto", se
rechaza.

## Decisiones "nunca construir" (auditoría de producto, octubre 2026)

Estas ideas van a volver a proponerse bajo presión de crecimiento. La
respuesta ya está decidida:

- **Chat en vivo dentro de la app.** Competir con WhatsApp en su propio
  terreno y perder. WhatsApp es el canal de conversación; Repara es el
  sistema de registro (ver más abajo).
- **Gamificación** (puntos, rachas, insignias, rankings). No encaja con la
  frecuencia real del producto -- nadie repara su casa cada semana.
- **ERP para el profesional** (nóminas, stock de materiales, rutas).
  REPARA Pro es una herramienta ligera para gestionar trabajos dentro de
  Repara, nunca un sustituto de la gestión completa de un negocio.
- **Monetizar el lado Pro con cuota desde el principio.** Es el motor del
  bucle viral (el profesional invita a sus propios clientes); cobrar ahí
  antes de tener tracción real lo mata antes de que exista.
- **Construir Verifactu completo o ir a por B2B/inmobiliarias antes de
  tener usuarios reales** usando el ciclo cerrado pedir→presupuestar→
  controlar cambios→pagar→archivar. Son apuestas de fase de crecimiento,
  no de producto inicial.

## WhatsApp: convivir, no competir

REPARA no intenta sustituir la conversación. Un profesional puede seguir
negociando un cambio de precio por WhatsApp -- lo que importa es que el
registro OFICIAL (presupuesto, cambio de alcance, pago) siempre quede
dentro de Repara, nunca solo en un mensaje que se pierde en el scroll.

## Nota de arquitectura pendiente: Vivienda vs Casa-cuenta

Hoy `Casa` mezcla dos conceptos que algún día conviene separar:

1. La identidad física del inmueble (dirección, elementos, historial) --
   lo que debería sobrevivir a quien lo posee.
2. El grupo de miembros con acceso -- lo que cambia cuando la vivienda se
   vende o alquila.

No hace falta tocar nada mientras no exista "cambio de propietario" como
funcionalidad real. Pero el día que se construya (identificada en la
auditoría como una de las diferenciaciones más difíciles de copiar: el
historial pertenece a la vivienda, no a la cuenta), el refactor natural es
separar `Vivienda` (inmutable, ahí vive el historial, elementos y
documentos técnicos) de `Membresía` (quién tiene acceso hoy). Diseñar esto
antes de que haya mucho dato real evita una migración dolorosa después.
Privacidad a decidir con cuidado en ese momento: Pagos y contacto de
profesionales probablemente NO deban transferirse automáticamente al nuevo
propietario (son datos de quien pagó, no del inmueble), mientras que
Elementos/garantías/documentos técnicos sí.

## Stack técnico

Flutter (iOS + Android), Firebase (Firestore, Auth, Storage, Cloud
Functions en `europe-west1`, Crashlytics, App Check), IA vía Claude
(Anthropic) a través de un proxy en Cloud Functions. La IA siempre
propone, nunca decide sola -- el propietario confirma antes de guardar
cualquier dato sugerido.

## Seguridad -- patrón establecido

Un profesional nunca es miembro de la casa. Tiene un segundo camino de
acceso en las reglas de Firestore/Storage, acotado solo al trabajo
concreto donde está asignado (`profesionalUid`), nunca a la casa entera.
Dinero crítico (presupuestos, cambios de alcance) se calcula y aprueba
siempre en Cloud Functions con Admin SDK, con bloqueo explícito de
autoaprobación. El campo `profesionalUid` de un trabajo solo lo escribe
`responderInvitacion` (Admin SDK) -- nunca un miembro por escritura
directa (fix de seguridad real, octubre 2026).

**App Check sigue en modo Monitor, no Enforce**, porque las builds
actuales son sideloaded (no vienen de una tienda) y Enforce las
bloquearía a todas. Mientras tanto, `classifyDocument` y
`sugerirIntervaloMantenimiento` tienen un límite diario de uso por usuario
(colección `usoIA`) como mitigación del coste de IA sin control. Pasar a
Enforce es una decisión a tomar explícitamente antes de publicar en
tiendas, no algo que deba hacerse sin más.

## Trabajo pendiente (fuera de alcance deliberado, no descuidado)

- Push notifications reales (FCM): la infraestructura de notificaciones
  internas ya existe y está lista para conectarse, pero requiere
  configurar una clave APNs en la consola de Firebase para iOS (paso
  manual) y pruebas en dispositivo real antes de poder darlo por
  terminado -- no se ha construido a medias solo por completar una lista.
- Exportación del Expediente de la vivienda a PDF real (hoy es resumen en
  pantalla + compartir como texto).
- Transferencia de propietario al vender la casa (requiere el refactor
  Vivienda/Membresía de arriba).
