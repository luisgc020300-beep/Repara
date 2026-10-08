// lib/services/security/biometric_service.dart
//
// Abstracción de autenticación biométrica (misión de seguridad local,
// octubre 2026) -- ninguna pantalla habla directamente con `local_auth`,
// todas pasan por esta interfaz. Dos motivos:
//   1. Testeable sin depender de hardware real (ver FakeBiometricService
//      en test/fakes/, usado por los 6 casos de la sección 32 de la misión).
//   2. La biometría NUNCA sustituye a Firebase Auth ni a las reglas de
//      servidor -- es solo una cerradura local sobre un dispositivo que ya
//      tiene sesión iniciada. Si un día cambia el paquete nativo usado,
//      solo se toca esta clase.
//
// Importante: REPARA nunca almacena huellas, rostros ni plantillas
// biométricas -- eso lo gestiona el sistema operativo. Aquí solo se recibe
// un resultado (éxito/fallo/cancelado/no disponible/error).
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

enum BiometricAuthResult { success, failed, cancelled, unavailable, error }

abstract class BiometricService {
  /// true si el dispositivo tiene biometría configurada y disponible ahora
  /// mismo -- úsalo para decidir si mostrar la opción en Ajustes, nunca
  /// para decidir permisos de negocio.
  Future<bool> isAvailable();

  /// Pide autenticación biométrica con [reason] como mensaje al usuario.
  /// Nunca lanza una excepción -- cualquier fallo de la plataforma se
  /// traduce a [BiometricAuthResult.error] o [BiometricAuthResult.unavailable].
  Future<BiometricAuthResult> authenticate(String reason);
}

class LocalAuthBiometricService implements BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      final soportado = await _auth.isDeviceSupported();
      final puedeComprobar = await _auth.canCheckBiometrics;
      return soportado && puedeComprobar;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BiometricAuthResult> authenticate(String reason) async {
    try {
      final exito = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      // Según la documentación del propio paquete: `false` es un reto
      // fallido sin más efectos (p.ej. huella no reconocida una vez) --
      // cancelación, bloqueo o error siempre llegan como excepción, nunca
      // como `false`.
      return exito ? BiometricAuthResult.success : BiometricAuthResult.failed;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
          return BiometricAuthResult.cancelled;
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          return BiometricAuthResult.unavailable;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          // Bloqueado temporalmente por demasiados intentos -- no es que no
          // haya biometría, es que hay que esperar o usar el fallback del
          // propio sistema. Se trata como fallo, no como "no disponible".
          return BiometricAuthResult.failed;
        default:
          return BiometricAuthResult.error;
      }
    } catch (_) {
      return BiometricAuthResult.error;
    }
  }
}
