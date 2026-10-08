// test/fakes/fake_biometric_service.dart
//
// Doble de prueba para BiometricService (sección 32 de la misión de
// seguridad local) -- permite testear los 6 casos de biometría sin
// hardware real: configura `proximoResultado` y `disponible` antes de cada
// caso.
import 'package:repara/services/security/biometric_service.dart';

class FakeBiometricService implements BiometricService {
  FakeBiometricService({this.disponible = true, this.proximoResultado = BiometricAuthResult.success});

  bool disponible;
  BiometricAuthResult proximoResultado;

  /// Cuántas veces se ha llamado a authenticate() -- para comprobar que NO
  /// se pide biometría cuando no toca (caso 5 de la misión).
  int llamadasAAuthenticate = 0;

  @override
  Future<bool> isAvailable() async => disponible;

  @override
  Future<BiometricAuthResult> authenticate(String reason) async {
    llamadasAAuthenticate++;
    if (!disponible) return BiometricAuthResult.unavailable;
    return proximoResultado;
  }
}
