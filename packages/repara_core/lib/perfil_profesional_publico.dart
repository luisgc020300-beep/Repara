// lib/perfil_profesional_publico.dart
//
// Perfil público del profesional (mejora de perfiles profesionales,
// noviembre 2026): solo lo que puede verse sin exponer nada de una vivienda
// concreta -- nombre comercial, especialidad, nº de trabajos terminados y
// valoración media. Mantenido por Cloud Functions a partir de
// profesionales/{uid} (privado) y de la colección valoraciones -- nunca
// escrito directamente por el cliente (ver firestore.rules).
import 'package:cloud_firestore/cloud_firestore.dart';

class PerfilProfesionalPublico {
  const PerfilProfesionalPublico({
    required this.uid,
    this.nombreComercial,
    this.especialidad,
    this.fotoUrl,
    this.descripcion,
    this.trabajosTerminados = 0,
    this.sumaPuntuaciones = 0,
    this.numValoraciones = 0,
  });

  final String uid;
  final String? nombreComercial;
  final String? especialidad;

  /// Mejora de perfiles, noviembre 2026 -- sincronizados desde
  /// profesionales/{uid} vía Cloud Function, igual que nombreComercial/
  /// especialidad justo arriba.
  final String? fotoUrl;
  final String? descripcion;
  final int trabajosTerminados;
  final int sumaPuntuaciones;
  final int numValoraciones;

  /// null si todavía no tiene ninguna valoración -- nunca se muestra "0.0".
  double? get valoracionMedia =>
      numValoraciones <= 0 ? null : sumaPuntuaciones / numValoraciones;

  factory PerfilProfesionalPublico.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PerfilProfesionalPublico(
      uid: doc.id,
      nombreComercial: data['nombreComercial'] as String?,
      especialidad: data['especialidad'] as String?,
      fotoUrl: data['fotoUrl'] as String?,
      descripcion: data['descripcion'] as String?,
      trabajosTerminados: (data['trabajosTerminados'] as num?)?.toInt() ?? 0,
      sumaPuntuaciones: (data['sumaPuntuaciones'] as num?)?.toInt() ?? 0,
      numValoraciones: (data['numValoraciones'] as num?)?.toInt() ?? 0,
    );
  }
}

/// La propia valoración de quien pregunta, para un registro concreto -- para
/// poder mostrar "ya valoraste esto" en vez del formulario otra vez. Nunca
/// se lee la valoración de otra persona (ver firestore.rules).
class MiValoracion {
  const MiValoracion({required this.puntuacion, this.comentario});

  final int puntuacion;
  final String? comentario;

  factory MiValoracion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MiValoracion(
      puntuacion: (data['puntuacion'] as num?)?.toInt() ?? 0,
      comentario: data['comentario'] as String?,
    );
  }
}

/// Una valoración recibida, vista por el propio profesional en REPARA Pro
/// (reputación, noviembre 2026) -- solo lo que ya le pertenece: su
/// puntuación, el comentario, cuándo, y el título del trabajo (ya tenía
/// acceso de lectura a ese registro, ver firestore.rules). Nunca nombre de
/// la vivienda, del propietario, ni ningún otro dato privado del cliente.
class ValoracionRecibida {
  const ValoracionRecibida({
    required this.id,
    required this.puntuacion,
    this.comentario,
    this.registroTitulo,
    this.createdAt,
  });

  final String id;
  final int puntuacion;
  final String? comentario;
  final String? registroTitulo;
  final DateTime? createdAt;

  factory ValoracionRecibida.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ValoracionRecibida(
      id: doc.id,
      puntuacion: (data['puntuacion'] as num?)?.toInt() ?? 0,
      comentario: data['comentario'] as String?,
      registroTitulo: data['registroTitulo'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
