# repara_core

Paquete Dart/Flutter compartido entre `apps/repara_hogar` y `apps/repara_pro`,
referenciado por ambas vía `path:` en su `pubspec.yaml`. Sin pantallas ni
widgets de composición visual completos -- solo lo que las dos apps
necesitan de verdad que sea una única fuente de verdad.

**Estado: vacío (Fase 0).** Ver `docs/ARQUITECTURA_SEPARACION.md` en la raíz
del repositorio para el plan completo.

## Qué va a vivir aquí (Fase 1, todavía no movido)

- Modelos de un trabajo compartido: `Registro`, `Pago`, `Presupuesto`,
  `CambioAlcance`, `Documento`, `HistorialEvento`, `Cita`, `Notificacion`.
- Los servicios que leen/escriben esas mismas colecciones (`RegistroService`,
  `PagoService`, `PresupuestoService`, `CambioAlcanceService`,
  `HistorialService`, `DocumentoService`, `CitaService`,
  `NotificacionService`).
- Los dos puentes de invitación (`InvitacionService`,
  `InvitacionHogarService`).
- Utilidades transversales (`stream_sharing.dart`, `stream_error_logging.dart`,
  idempotencia).
- Tokens de diseño de marca (colores, tipografía, radios, espaciados) --
  nunca widgets completos.

## Criterio para decidir si algo va aquí o se queda en su app

¿Este archivo lee o escribe una colección que las DOS apps necesitan tocar?
Antes de mover nada, verificar sus dependencias reales (imports) -- si algo
que parece compartido arrastra una dependencia de UI específica de Hogar o
de Pro, esa dependencia hay que resolverla primero (o el archivo no está
tan compartido como parecía). Nunca se introduce aquí una dependencia de UI
propia de una sola app.
