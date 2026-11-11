// test/documento_gate_test.dart
//
// verificarAccesoDocumento() -- el VerificarAccesoDocumento real, movido
// del monolito (verificarAccesoDocumentoHogar) a repara_core en noviembre
// 2026 para que Hogar y Pro lo reutilicen sin duplicarlo. Mismo
// comportamiento exacto de siempre: solo pide biometría si la protección
// de documentos está activada. BiometricAuth.debugServiceOverride nunca
// toca hardware real (ver la nota en biometric_service.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/biometric_service.dart';
import 'package:repara_core/documento_gate.dart';
import 'package:repara_core/security_preferences_service.dart';

import 'fakes/fake_secure_storage_channel.dart';

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
    BiometricAuth.debugServiceOverride = fakeBiometric;
  });

  tearDown(() {
    BiometricAuth.debugServiceOverride = null;
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
              autorizado = await verificarAccesoDocumento(context);
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
              autorizado = await verificarAccesoDocumento(context);
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
              autorizado = await verificarAccesoDocumento(context);
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
