// lib/models/habitacion.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Habitacion {
  const Habitacion({
    required this.id,
    required this.nombre,
    required this.orden,
    this.icono,
  });

  final String id;
  final String nombre;
  final int orden;
  final String? icono;

  factory Habitacion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Habitacion(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      orden: (data['orden'] as num?)?.toInt() ?? 0,
      icono: data['icono'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'orden': orden,
        if (icono != null) 'icono': icono,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
