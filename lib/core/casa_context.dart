// lib/core/casa_context.dart
//
// Singleton con la casa activa del usuario -- mismo rol que HouseholdContext
// en Convive. Un usuario puede tener varias viviendas (sección 5 del spec de
// producto), pero v1 solo necesita recordar cuál está viendo ahora mismo.
import 'package:flutter/foundation.dart';

class CasaContext extends ChangeNotifier {
  CasaContext._();
  static final CasaContext instance = CasaContext._();

  String? _casaActivaId;
  String? get casaActivaId => _casaActivaId;

  void setCasaActiva(String? casaId) {
    if (_casaActivaId == casaId) return;
    _casaActivaId = casaId;
    notifyListeners();
  }
}
