# REPARA — Separación en dos aplicaciones conectadas

Documentación mínima de referencia local. El informe completo (arquitectura
actual, diagramas, modelo de datos y permisos, flujos de comunicación,
autenticación, estructura de carpetas, plan de migración por fases, riesgos,
complejidad y decisiones pendientes) vive en el documento de análisis
aprobado por el CEO:

https://claude.ai/artifact/NLxQbnTSDsdMWpVHfG6gFg

## Arquitectura aprobada (conceptualmente, por el CEO)

- Monorepo: dos aplicaciones Flutter independientes (**REPARA Hogar** y
  **REPARA Pro**) + un paquete Dart compartido (**`repara_core`**).
- Un único backend Firebase (mismo proyecto `repara-hogar-app`, sin cambios
  de proyecto ni de reglas en esta fase).
- Identidad compatible entre las dos apps -- misma cuenta, nunca un segundo
  registro ni dos sistemas de usuarios.
- Datos privados del propietario, datos privados del profesional y datos
  compartidos por trabajo, claramente separados -- ver sección 4 del
  informe.
- **La interfaz actual de REPARA Hogar se conserva tal cual.** Ningún
  cambio visual sin autorización expresa del CEO, caso por caso.

## Correcciones incorporadas antes de ejecutar la Fase 1

Decisiones del CEO (autorización de la Fase 0) que el plan de fases debe
respetar a partir de aquí:

1. **Nunca transportar un Firebase Custom Token directamente en una URL.**
   El intercambio seguro para el "camino 2" de login cruzado (sección 6 del
   informe) debe rediseñarse como un código temporal de un solo uso: el
   enlace profundo lleva el código, no el token; la app canjea ese código
   contra una Cloud Function, que es quien emite el custom token real.
2. **Verificar las dependencias reales antes de decidir qué entra en
   `repara_core`.** No basta con que algo "parezca" compartido -- revisar
   sus imports antes de moverlo. Ninguna dependencia de UI propia de Hogar
   o de Pro debe entrar en el paquete común.
3. **La revocación de un profesional debe proteger Firestore Y Firebase
   Storage.** El informe (sección 4) solo cubría las reglas de Firestore --
   falta extender el mismo criterio (acceso derivado en vivo de la
   asignación actual, nunca una regla más permisiva) a `storage.rules`.
4. **Identidades históricas y permisos actuales, siempre separados** --
   igual que ya recoge el informe (asignación actual / acceso / atribución
   histórica), reafirmado aquí como no negociable.
5. **Mover código progresivamente**, con la suite completa de tests en
   verde después de cada grupo de cambios -- nunca un movimiento masivo de
   una sola vez.
6. **Preservar la interfaz de REPARA Hogar** sin rediseños ni cambios
   visuales no autorizados -- reafirmado, sin cambios desde la primera
   versión del informe.

## Estado de la separación

| Fase | Estado |
|---|---|
| 0. Preparación | **En curso** -- estructura de carpetas y `repara_core` vacío creados en esta sesión |
| 1. Extraer `repara_core` | Pendiente de autorización explícita del CEO |
| 2-6 | Pendientes |

Nada de código de la app actual se ha movido todavía. La app sigue viviendo
íntegramente en `lib/` (raíz del repositorio) y es la única que se compila,
prueba y despliega.
