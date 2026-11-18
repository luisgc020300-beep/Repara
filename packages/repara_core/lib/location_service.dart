// lib/location_service.dart
//
// Abstracción de ubicación del dispositivo (Cercanos, noviembre 2026 --
// mismo criterio que biometric_service.dart: ninguna pantalla habla
// directamente con `geolocator`, todas pasan por esta interfaz, para poder
// sustituirla por un fake en tests sin depender de hardware/permisos
// reales).
//
// Deliberadamente solo pide precisión BAJA (`LocationAccuracy.low`,
// variable según plataforma pero del orden de ~1-3 km) -- "Cercanos" nunca
// necesita ni muestra una posición exacta (ver buscarProfesionalesCercanos
// en functions/index.js), así que no tiene sentido pedirle al sistema más
// precisión de la que se va a usar.
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:geolocator/geolocator.dart';

enum SolicitudUbicacionResultado {
  concedido,
  denegado,
  denegadoParaSiempre,
  servicioDesactivado,
  error,
}

class Coordenadas {
  const Coordenadas(this.lat, this.lng);
  final double lat;
  final double lng;
}

abstract class LocationService {
  /// Pide permiso si hace falta y, si se concede, también comprueba que el
  /// servicio de ubicación del dispositivo esté activado -- nunca lanza.
  Future<SolicitudUbicacionResultado> solicitarPermiso();

  /// Asume que ya hay permiso concedido (llamar siempre después de
  /// [solicitarPermiso] con resultado `concedido`). null si no se pudo
  /// obtener una posición por cualquier motivo.
  Future<Coordenadas?> posicionActual();

  /// Abre los ajustes de ubicación del sistema -- recuperación razonable
  /// cuando [solicitarPermiso] devuelve `servicioDesactivado`.
  Future<void> abrirAjustesUbicacion();

  /// Abre los ajustes de la propia app -- recuperación razonable cuando
  /// [solicitarPermiso] devuelve `denegadoParaSiempre` (el sistema ya no
  /// vuelve a mostrar el diálogo de permiso).
  Future<void> abrirAjustesApp();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<SolicitudUbicacionResultado> solicitarPermiso() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return SolicitudUbicacionResultado.servicioDesactivado;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      switch (permiso) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return SolicitudUbicacionResultado.concedido;
        case LocationPermission.deniedForever:
          return SolicitudUbicacionResultado.denegadoParaSiempre;
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return SolicitudUbicacionResultado.denegado;
      }
    } catch (_) {
      return SolicitudUbicacionResultado.error;
    }
  }

  @override
  Future<Coordenadas?> posicionActual() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      return Coordenadas(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> abrirAjustesUbicacion() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {
      // No hay nada razonable que hacer si ni siquiera se puede abrir el
      // selector de ajustes -- el usuario ya ve el mensaje en pantalla.
    }
  }

  @override
  Future<void> abrirAjustesApp() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }
}

/// Punto único de acceso a [LocationService] -- mismo patrón que
/// BiometricAuth en biometric_service.dart.
class DeviceLocation {
  DeviceLocation._();

  @visibleForTesting
  static LocationService? debugServiceOverride;

  static LocationService? _instance;

  static LocationService get instance =>
      debugServiceOverride ?? (_instance ??= GeolocatorLocationService());
}
