// packages/repara_ui/test/miniatura_documento_test.dart
//
// MiniaturaDocumento -- una imagen se amplía inline (FotoAmpliadaScreen,
// sin gate), un PDF se abre con abrirArchivoProtegido() y la capacidad
// [verificarAcceso] que se le inyecte (Fase 2B.3, noviembre 2026).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/foto_ampliada_screen.dart';
import 'package:repara_ui/miniatura_documento.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  String? ultimaUrlLanzada;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    ultimaUrlLanzada = url;
    return true;
  }
}

void main() {
  late _FakeUrlLauncherPlatform fake;

  setUp(() {
    fake = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fake;
  });

  Widget envolver(Widget child) => MaterialApp(
    theme: buildReparaLightTheme(),
    home: Scaffold(body: child),
  );

  testWidgets('una imagen se amplía inline, sin pasar por ningún gate', (
    tester,
  ) async {
    var verificado = false;
    await tester.pumpWidget(
      envolver(
        MiniaturaDocumento(
          url: 'https://example.com/foto.jpg',
          nombreArchivo: 'foto.jpg',
          verificarAcceso: (_) async {
            verificado = true;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.byType(MiniaturaDocumento));
    await tester.pumpAndSettle();

    expect(find.byType(FotoAmpliadaScreen), findsOneWidget);
    expect(verificado, isFalse);
    expect(fake.ultimaUrlLanzada, isNull);
  });

  testWidgets('un PDF sin capacidad inyectada se abre directamente', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        const MiniaturaDocumento(
          url: 'https://example.com/factura.pdf',
          nombreArchivo: 'factura.pdf',
        ),
      ),
    );
    await tester.tap(find.byType(MiniaturaDocumento));
    await tester.pumpAndSettle();

    expect(fake.ultimaUrlLanzada, 'https://example.com/factura.pdf');
  });

  testWidgets('un PDF con una capacidad que deniega no llega a abrirse', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        MiniaturaDocumento(
          url: 'https://example.com/factura.pdf',
          nombreArchivo: 'factura.pdf',
          verificarAcceso: (_) async => false,
        ),
      ),
    );
    await tester.tap(find.byType(MiniaturaDocumento));
    await tester.pumpAndSettle();

    expect(fake.ultimaUrlLanzada, isNull);
  });
}
