# repara_ui

Paquete Dart/Flutter compartido entre `apps/repara_hogar` y `apps/repara_pro`,
referenciado por ambas vía `path:` en su `pubspec.yaml`. Widgets y
componentes visuales reutilizables -- nunca una pantalla completa de una app
concreta.

Depende de `repara_core` (modelos, servicios, tokens de diseño), nunca al
revés. No importa nada de `lib/` ni de `apps/`: si un componente que parece
compartido arrastra una dependencia exclusiva de Hogar o de Pro (una
pantalla, un servicio de seguridad local, el *service locator* de una app
concreta...), esa dependencia se resuelve como una capacidad inyectada
(ver `VerificarAccesoDocumento` en `abrir_protegido.dart`, `IniciarAnadirPago`
en `pagos_section.dart`) o el componente se queda donde está -- nunca se
importa directamente.

## Contenido

- `app_error.dart` -- feedback de error/éxito compartido (`AppError`,
  `EmptyHint`).
- `app_dialog.dart` -- diálogos de confirmación y de texto (`AppDialog`).
- `ios_list.dart` -- lista agrupada estilo iOS (`IosSection`, `IosRow`,
  `IosValueRow`).
- `estado_registro_chip.dart` -- chrome visual de un `Registro`
  (`EstadoRegistroChip`, `AvisoRegistro`, `nombreEstadoRegistro`,
  `iconoTipoRegistro`).
- `keyboard_dismiss_bar.dart` -- barra para ocultar el teclado
  (`KeyboardDismissBar`).
- `abrir_protegido.dart` -- apertura de un archivo externo con gate
  opcional inyectado (`abrirArchivoProtegido`, `VerificarAccesoDocumento`).
- `foto_ampliada_screen.dart` -- foto a pantalla completa con zoom
  (`FotoAmpliadaScreen`).
- `miniatura_documento.dart` -- miniatura clicable de un documento/
  comprobante (`MiniaturaDocumento`).
- `pagos_section.dart` -- lista de pagos de un registro (`PagosSection`,
  `mostrarAccionesPago`, `IniciarAnadirPago`).
- `pago_detail_screen.dart` -- detalle/alta de un pago (`PagoDetailScreen`).
- `cambio_alcance_section.dart` -- solicitudes de cambio de alcance
  (`CambiosAlcanceSection`).

## Qué sigue en `lib/` (Fase 2B.4)

- `presupuestos_section.dart` y `widgets/presupuesto_pdf.dart` -- no se han
  movido en esta fase (fuera de alcance explícito). `RolEnTrabajo` ya vive en
  `repara_core/registro.dart`, así que ya no es lo que los bloquea.
