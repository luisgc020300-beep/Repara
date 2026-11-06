# repara_ui

Paquete Dart/Flutter compartido entre `apps/repara_hogar` y `apps/repara_pro`,
referenciado por ambas vía `path:` en su `pubspec.yaml`. Widgets y
componentes visuales reutilizables -- nunca una pantalla completa de una app
concreta.

Depende de `repara_core` (modelos, servicios, tokens de diseño), nunca al
revés. No importa nada de `lib/` ni de `apps/`: si un componente que parece
compartido arrastra una dependencia exclusiva de Hogar o de Pro (una
pantalla, un servicio de seguridad local, el *service locator* de una app
concreta...), esa dependencia hay que resolverla primero, o el componente se
queda donde está. Ver `miniatura_documento.dart` en `lib/widgets/`: bloqueado
por el gate biométrico de `documento_abrir.dart` (Fase 2B.2, noviembre 2026).

## Contenido (Fase 2B.2)

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
