// test/fakes/fake_secure_storage_channel.dart
//
// flutter_secure_storage habla por un MethodChannel con la plataforma
// nativa, que no existe en `flutter test` (Dart VM, sin iOS/Android real).
// Esto simula ese canal en memoria para poder testear
// SecurityPreferencesService/AppLockController sin necesitar un
// dispositivo -- mismo canal y protocolo exactos que usa el paquete
// (verificado contra su propio test de plataforma).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _kChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Llamar una vez en el `setUp`/inicio del test. Devuelve el mapa en
/// memoria que respalda el almacenamiento simulado, por si el test quiere
/// inspeccionarlo o limpiarlo directamente entre casos.
Map<String, String> instalarSecureStorageFalso() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final almacen = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_kChannel, (call) async {
    switch (call.method) {
      case 'write':
        almacen[call.arguments['key'] as String] = call.arguments['value'] as String;
        return null;
      case 'read':
        return almacen[call.arguments['key'] as String];
      case 'containsKey':
        return almacen.containsKey(call.arguments['key'] as String);
      case 'delete':
        almacen.remove(call.arguments['key'] as String);
        return null;
      case 'deleteAll':
        almacen.clear();
        return null;
      case 'readAll':
        return almacen;
      default:
        return null;
    }
  });
  return almacen;
}
