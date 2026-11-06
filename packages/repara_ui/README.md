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
- `presupuestos_section.dart` -- presupuestos formales (`PresupuestosSection`).
- `presupuesto_pdf.dart` -- documento PDF del presupuesto (`PresupuestoPdf`).
- `pdf_estilo.dart` -- estilo visual compartido por todos los PDF de la app
  (colores, `tituloSeccionPdf`, `etiquetaPdf`, `miniaturaPdf`,
  `formatoImportePdf`) -- también lo usan `pdf_trabajo.dart`,
  `elemento_resumen_pdf.dart`, `expediente_vivienda_pdf.dart` y
  `registro_resumen_pdf.dart`, que se quedan en `lib/` (no generan el PDF de
  un presupuesto) pero importan este archivo desde aquí para no duplicarlo.
- `pdf_fuente_unicode.dart` -- fuente Unicode para el símbolo "€"
  (`cargarTemaPdfUnicode`), con sus dos `.ttf` como asset propio del paquete
  (ver `assets/fonts/` y `pubspec.yaml`) -- movida junto con la fuente desde
  `assets/fonts/` de la app, que ya no la necesita.

## Qué sigue en `lib/`

No queda ningún bloqueo identificado para `PresupuestosSection` ni para los
cuatro consumidores de `pdf_estilo.dart`/`pdf_fuente_unicode.dart`
mencionados arriba -- se quedan en `lib/` porque generan otros documentos
(ficha de elemento, expediente de la vivienda, resumen de un registro
simple), no porque dependan de algo exclusivo de Hogar o de Pro.
