// packages/repara_ui/test/abrir_protegido_test.dart
//
// abrirArchivoProtegido() -- sin capacidad inyectada (como Pro, que no
// depende de servicios exclusivos de Hogar) abre directamente; con una
// capacidad que autoriza, abre igual; con una que deniega, no llega a
// abrir nada (Fase 2B.3, noviembre 2026).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_ui/abrir_protegido.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  String? ultimaUrlLanzada;
  bool resultadoLanzamiento = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    ultimaUrlLanzada = url;
    return resultadoLanzamiento;
  }
}

void main() {
  late _FakeUrlLauncherPlatform fake;

  setUp(() {
    fake = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fake;
  });

  Widget envolver(Widget Function(BuildContext) builder) =>
      MaterialApp(home: Scaffold(body: Builder(builder: builder)));

  testWidgets('sin capacidad inyectada, abre directamente (caso Pro)', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        (context) => ElevatedButton(
          onPressed: () =>
              abrirArchivoProtegido(context, 'https://example.com/doc.pdf'),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(fake.ultimaUrlLanzada, 'https://example.com/doc.pdf');
  });

  testWidgets('con una capacidad que autoriza, abre el archivo', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        (context) => ElevatedButton(
          onPressed: () => abrirArchivoProtegido(
            context,
            'https://example.com/doc.pdf',
            verificarAcceso: (_) async => true,
          ),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(fake.ultimaUrlLanzada, 'https://example.com/doc.pdf');
  });

  testWidgets('con una capacidad que deniega, no llega a abrir nada', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        (context) => ElevatedButton(
          onPressed: () => abrirArchivoProtegido(
            context,
            'https://example.com/doc.pdf',
            verificarAcceso: (_) async => false,
          ),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(fake.ultimaUrlLanzada, isNull);
  });

  testWidgets('si falla el lanzamiento, muestra un error', (tester) async {
    fake.resultadoLanzamiento = false;
    await tester.pumpWidget(
      envolver(
        (context) => ElevatedButton(
          onPressed: () =>
              abrirArchivoProtegido(context, 'https://example.com/doc.pdf'),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo abrir el documento.'), findsOneWidget);
  });
}
