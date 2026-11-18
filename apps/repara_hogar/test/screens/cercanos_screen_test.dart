// test/screens/cercanos_screen_test.dart
//
// Estados de permiso de CercanosScreen (noviembre 2026) --
// DeviceLocation.debugServiceOverride nunca toca hardware real (mismo
// patrón que BiometricAuth.debugServiceOverride, ver documento_gate_test.dart
// en repara_core). El camino de éxito real (llamada a
// buscarProfesionalesCercanos) necesita el Cloud Functions emulator, que no
// está disponible en este target -- mismo límite ya documentado en
// cita_section_test.dart (packages/repara_ui/test); ese camino está cubierto
// de verdad en functions-tests/cercanos.test.js (orden por cercanía, radio,
// privacidad, límite diario, autenticación).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/location_service.dart';
import 'package:repara_hogar/screens/cercanos_screen.dart';

class _FakeLocationService implements LocationService {
  SolicitudUbicacionResultado resultadoPermiso =
      SolicitudUbicacionResultado.concedido;
  Coordenadas? posicion = const Coordenadas(40.4168, -3.7038);
  int ajustesUbicacionAbiertos = 0;
  int ajustesAppAbiertos = 0;

  @override
  Future<SolicitudUbicacionResultado> solicitarPermiso() async => resultadoPermiso;

  @override
  Future<Coordenadas?> posicionActual() async => posicion;

  @override
  Future<void> abrirAjustesUbicacion() async => ajustesUbicacionAbiertos++;

  @override
  Future<void> abrirAjustesApp() async => ajustesAppAbiertos++;
}

void main() {
  late _FakeLocationService fakeLocation;

  setUp(() {
    fakeLocation = _FakeLocationService();
    DeviceLocation.debugServiceOverride = fakeLocation;
  });

  tearDown(() {
    DeviceLocation.debugServiceOverride = null;
  });

  Widget envolver() => MaterialApp(
    theme: buildReparaLightTheme(),
    home: const CercanosScreen(casaId: 'casa-1'),
  );

  testWidgets('con el servicio de ubicación desactivado, muestra el aviso y un botón para abrir ajustes', (
    tester,
  ) async {
    fakeLocation.resultadoPermiso = SolicitudUbicacionResultado.servicioDesactivado;
    await tester.pumpWidget(envolver());
    await tester.pumpAndSettle();

    expect(find.text('La ubicación está desactivada'), findsOneWidget);
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pumpAndSettle();
    expect(fakeLocation.ajustesUbicacionAbiertos, 1);
  });

  testWidgets('con el permiso denegado, muestra el aviso para volver a intentar', (
    tester,
  ) async {
    fakeLocation.resultadoPermiso = SolicitudUbicacionResultado.denegado;
    await tester.pumpWidget(envolver());
    await tester.pumpAndSettle();

    expect(find.text('Necesitamos tu ubicación'), findsOneWidget);
    expect(find.text('Volver a intentar'), findsOneWidget);
  });

  testWidgets('con el permiso denegado para siempre, ofrece abrir los ajustes de la app', (
    tester,
  ) async {
    fakeLocation.resultadoPermiso = SolicitudUbicacionResultado.denegadoParaSiempre;
    await tester.pumpWidget(envolver());
    await tester.pumpAndSettle();

    expect(find.text('Permiso de ubicación bloqueado'), findsOneWidget);
    await tester.tap(find.text('Abrir ajustes de la app'));
    await tester.pumpAndSettle();
    expect(fakeLocation.ajustesAppAbiertos, 1);
  });

  testWidgets('con un error al pedir permiso, muestra el aviso genérico', (
    tester,
  ) async {
    fakeLocation.resultadoPermiso = SolicitudUbicacionResultado.error;
    await tester.pumpWidget(envolver());
    await tester.pumpAndSettle();

    expect(find.text('No se pudo buscar'), findsOneWidget);
  });

  testWidgets('con permiso concedido pero sin poder obtener la posición, muestra el aviso genérico', (
    tester,
  ) async {
    fakeLocation.resultadoPermiso = SolicitudUbicacionResultado.concedido;
    fakeLocation.posicion = null;
    await tester.pumpWidget(envolver());
    await tester.pumpAndSettle();

    expect(find.text('No se pudo buscar'), findsOneWidget);
  });
}
