// lib/profesional_cercano.dart
//
// Resultado de buscarProfesionalesCercanos (Cloud Function) -- nunca se
// construye desde un DocumentSnapshot porque el cliente nunca lee
// directamente coordenadas ni la colección profesionales ajena, solo el
// resultado ya calculado en servidor (ver functions/index.js).
class ProfesionalCercano {
  const ProfesionalCercano({
    required this.uid,
    this.nombreComercial,
    this.especialidad,
    this.trabajosTerminados = 0,
    this.valoracionMedia,
    required this.distanciaAproxKm,
  });

  final String uid;
  final String? nombreComercial;
  final String? especialidad;
  final int trabajosTerminados;
  final double? valoracionMedia;
  final double distanciaAproxKm;

  factory ProfesionalCercano.fromMap(Map<String, dynamic> map) =>
      ProfesionalCercano(
        uid: map['uid'] as String? ?? '',
        nombreComercial: map['nombreComercial'] as String?,
        especialidad: map['especialidad'] as String?,
        trabajosTerminados: (map['trabajosTerminados'] as num?)?.toInt() ?? 0,
        valoracionMedia: (map['valoracionMedia'] as num?)?.toDouble(),
        distanciaAproxKm: (map['distanciaAproxKm'] as num?)?.toDouble() ?? 0,
      );
}
