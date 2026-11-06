// packages/repara_core/lib/conceptos_frecuentes_service.dart
//
// Biblioteca de conceptos frecuentes de presupuesto (ampliación REPARA Pro,
// Fase 3 -- CEO, noviembre 2026): "Desplazamiento", "Mano de obra",
// "Instalación"... que un profesional reutiliza en muchos presupuestos sin
// volver a teclearlos cada vez. Local por dispositivo (SharedPreferences),
// mismo criterio que la plantilla del último presupuesto que ya existía
// (ver presupuestos_section.dart, _claveUltimaPlantilla): evita abrir una
// colección nueva de Firestore -- y su propia regla de seguridad -- solo
// para esto. Sencillo a propósito: nombre + precio + IVA, nada de
// categorías ni de un catálogo grande (CEO: "no obligues a crear un
// catálogo enorme"). Testable con SharedPreferences.setMockInitialValues
// (API estándar del propio paquete), sin seam propio.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _clave = 'repara_conceptos_frecuentes_presupuesto';

class ConceptoFrecuente {
  const ConceptoFrecuente({
    required this.nombre,
    required this.precioUnitario,
    required this.ivaPorcentaje,
  });

  final String nombre;
  final double precioUnitario;
  final double ivaPorcentaje;

  factory ConceptoFrecuente.fromMap(Map<String, dynamic> m) =>
      ConceptoFrecuente(
        nombre: m['nombre'] as String? ?? '',
        precioUnitario: (m['precioUnitario'] as num?)?.toDouble() ?? 0,
        ivaPorcentaje: (m['ivaPorcentaje'] as num?)?.toDouble() ?? 21,
      );

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'precioUnitario': precioUnitario,
    'ivaPorcentaje': ivaPorcentaje,
  };
}

class ConceptosFrecuentesService {
  ConceptosFrecuentesService._();

  static Future<List<ConceptoFrecuente>> listar() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_clave);
    if (json == null) return const [];
    try {
      final lista = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      return lista.map(ConceptoFrecuente.fromMap).toList();
    } catch (e) {
      // Dato local corrupto -- nunca debe impedir trabajar con el editor,
      // solo se pierde la biblioteca guardada.
      debugPrint(
        'ConceptosFrecuentesService: dato local corrupto, se ignora: $e',
      );
      return const [];
    }
  }

  /// Guardar con un nombre ya existente actualiza ese concepto (precio/IVA)
  /// en vez de duplicarlo -- comparación insensible a mayúsculas/espacios.
  static Future<void> guardar(ConceptoFrecuente concepto) async {
    final actuales = await listar();
    final sinElMismoNombre = actuales
        .where(
          (c) =>
              c.nombre.trim().toLowerCase() !=
              concepto.nombre.trim().toLowerCase(),
        )
        .toList();
    await _persistir([...sinElMismoNombre, concepto]);
  }

  static Future<void> eliminar(String nombre) async {
    final actuales = await listar();
    await _persistir(actuales.where((c) => c.nombre != nombre).toList());
  }

  static Future<void> _persistir(List<ConceptoFrecuente> conceptos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode(conceptos.map((c) => c.toMap()).toList()),
    );
  }
}
