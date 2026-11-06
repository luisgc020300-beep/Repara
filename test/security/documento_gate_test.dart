// test/security/documento_gate_test.dart
//
// verificarAccesoDocumentoHogar() -- el VerificarAccesoDocumento real de
// Hogar (Fase 2B.3, noviembre 2026): mismo comportamiento que tenía
// abrirArchivoProtegido() antes de separarse en documento_gate.dart + el
// contrato inyectable de repara_ui/abrir_protegido.dart. FakeBiometricService
// nunca toca hardware real (ver la nota en biometric_service.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/core/service_locator.dart';
import 'package:repara/services/security/biometric_service.dart';
import 'package:repara/services/security/documento_gate.dart';
import 'package:repara/services/security/security_preferences_service.dart';

import '../fakes/fake_secure_storage_channel.dart';

class _FakeBiometricService implements BiometricService {
  BiometricAuthResult resultado = BiometricAuthResult.success;
  int llamadas = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<BiometricAuthResult> authenticate(String reason) async {
    llamadas++;
    return resultado;
  }
}

void main() {
  late _FakeBiometricService fakeBiometric;

  setUp(() {
    instalarSecureStorageFalso();
    fakeBiometric = _FakeBiometricService();
    sl.registerSingleton<BiometricService>(fakeBiometric);
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget envolver(Widget Function(BuildContext) builder) =>
      MaterialApp(home: Scaffold(body: Builder(builder: builder)));

  testWidgets(
    'con la protección de documentos desactivada, autoriza sin pedir biometría',
    (tester) async {
      await SecurityPreferencesService.instance.setDocumentProtectionEnabled(
        false,
      );
      bool? autorizado;
      await tester.pumpWidget(
        envolver(
          (context) => ElevatedButton(
            onPressed: () async {
              autorizado = await verificarAccesoDocumentoHogar(context);
            },
            child: const Text('comprobar'),
          ),
        ),
      );
      await tester.tap(find.text('comprobar'));
      await tester.pumpAndSettle();

      expect(autorizado, isTrue);
      expect(fakeBiometric.llamadas, 0);
    },
  );

  testWidgets(
    'con la protección activada y biometría correcta, autoriza',
    (tester) async {
      await SecurityPreferencesService.instance.setDocumentProtectionEnabled(
        true,
      );
      fakeBiometric.resultado = BiometricAuthResult.success;
      bool? autorizado;
      await tester.pumpWidget(
        envolver(
          (context) => ElevatedButton(
            onPressed: () async {
              autorizado = await verificarAccesoDocumentoHogar(context);
            },
            child: const Text('comprobar'),
          ),
        ),
      );
      await tester.tap(find.text('comprobar'));
      await tester.pumpAndSettle();

      expect(autorizado, isTrue);
      expect(fakeBiometric.llamadas, 1);
    },
  );

  testWidgets(
    'con la protección activada y biometría fallida, no autoriza',
    (tester) async {
      await SecurityPreferencesService.instance.setDocumentProtectionEnabled(
        true,
      );
      fakeBiometric.resultado = BiometricAuthResult.failed;
      bool? autorizado;
      await tester.pumpWidget(
        envolver(
          (context) => ElevatedButton(
            onPressed: () async {
              autorizado = await verificarAccesoDocumentoHogar(context);
            },
            child: const Text('comprobar'),
          ),
        ),
      );
      await tester.tap(find.text('comprobar'));
      await tester.pumpAndSettle();

      expect(autorizado, isFalse);
    },
  );
}
