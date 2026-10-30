// lib/services/registro_service.dart
//
// Octubre 2026 -- reemplaza TrabajoService (y la mitad de EventoService que
// vivía como "nota" ligada a un trabajo): un registro es cada suceso de un
// Elemento, casas/{casaId}/elementos/{elementoId}/registros/{registroId}.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/elemento.dart';
import '../models/registro.dart';
import 'elemento_service.dart';
import 'pago_service.dart';
import 'stream_error_logging.dart';

class RegistroService {
  /// Seam de solo test -- nunca se asigna en código de producción. Ver
  /// casa_service.dart para el criterio general.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;

  static FirebaseFirestore get _db =>
      debugFirestoreOverride ?? FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static CollectionReference<Map<String, dynamic>> _col(
    String casaId,
    String elementoId,
  ) => _db
      .collection('casas')
      .doc(casaId)
      .collection('elementos')
      .doc(elementoId)
      .collection('registros');

  static Stream<List<Registro>> streamRegistros(
    String casaId,
    String elementoId,
  ) {
    return _col(casaId, elementoId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Registro.fromDoc).toList())
        .conRegistroDeErrores();
  }

  static Stream<Registro?> streamRegistro(
    String casaId,
    String elementoId,
    String registroId,
  ) {
    return _col(casaId, elementoId)
        .doc(registroId)
        .snapshots()
        .map((d) => d.exists ? Registro.fromDoc(d) : null)
        .conRegistroDeErrores();
  }

  /// "Trabajo activo o pendiente" en el sentido de sección 25 del spec
  /// (aviso de Inicio) y, desde la auditoría R5 (octubre 2026), también el
  /// criterio que bloquea archivar un elemento: un registro con profesional
  /// todavía no cerrado, O CUALQUIER registro (con o sin profesional) en
  /// `pendientePago` -- trabajo hecho pero sin cobrar, CEO octubre 2026, no
  /// debe poder "olvidarse" una vez el trabajo está físicamente terminado.
  /// Mismo criterio, repetido server-side en functions/index.js
  /// (tieneTrabajoActivo) porque la decisión de bloquear el archivado tiene
  /// que tomarse en servidor, no solo aquí -- esta función de aquí es solo
  /// para que la UI pueda mostrar u ocultar el botón sin tener que llamar a
  /// la Cloud Function a ciegas.
  static bool esTrabajoActivo(Registro r) =>
      r.estado == EstadoRegistro.pendientePago ||
      (r.esConProfesional &&
          r.estado != EstadoRegistro.terminado &&
          r.estado != EstadoRegistro.archivado);

  /// Mismo criterio y MISMA tolerancia (0.01) que ya usa el servidor para
  /// bloquear el archivado por saldo sin cobrar (tieneSaldoPendiente en
  /// functions/index.js) -- repetido aquí SOLO como ayuda visual para
  /// deshabilitar el botón de archivar, nunca como autoridad: la Cloud
  /// Function vuelve a comprobarlo de cero en su propia transacción.
  /// presupuesto == null nunca cuenta como saldo pendiente (mismo criterio
  /// que registrarPago: "sin presupuesto fijado, se deja pagar libremente").
  /// Se evalúa en TODOS los registros, no solo los activos -- un trabajo ya
  /// terminado con un saldo sin cobrar sigue siendo una deuda real.
  static Future<bool> tieneSaldoPendiente(
    String casaId,
    String elementoId,
    List<Registro> registros,
  ) async {
    for (final r in registros) {
      final presupuesto = r.presupuesto;
      if (presupuesto == null) continue;
      final totalPagado = await PagoService.totalPagado(
        casaId,
        elementoId,
        r.id,
      );
      final saldo = ((presupuesto - totalPagado) * 100).round() / 100;
      if (saldo > 0.01) return true;
    }
    return false;
  }

  /// `casaId` se guarda también como campo (no solo en la ruta) porque el
  /// resumen de "pendientes" lo necesita para su consulta collectionGroup
  /// del lado servidor (ver onRegistroEstadoCambiado en functions/index.js).
  static Future<String> crear(
    String casaId,
    String elementoId,
    Registro registro, {
    required String createdBy,
  }) async {
    final ref = await _col(
      casaId,
      elementoId,
    ).add({...registro.toMap(), 'casaId': casaId, 'createdBy': createdBy});
    return ref.id;
  }

  static Future<void> actualizarEstado(
    String casaId,
    String elementoId,
    String registroId,
    EstadoRegistro estado,
  ) async {
    await _col(
      casaId,
      elementoId,
    ).doc(registroId).update({'estado': estado.name});
  }

  /// Mismo patrón que ElementoService.subirFoto -- nombre de archivo fijo
  /// ("foto"), una foto nueva sustituye a la anterior, nunca se acumulan
  /// fotos sueltas. Es la foto DE ESTE registro (p.ej. la reparación en
  /// curso), nunca toca la foto del elemento padre.
  static Future<String> subirFoto(
    String casaId,
    String elementoId,
    String registroId,
    File archivo,
  ) async {
    final ref = FirebaseStorage.instance.ref().child(
      'casas/$casaId/elementos/$elementoId/registros/$registroId/foto',
    );
    await ref.putFile(archivo);
    return ref.getDownloadURL();
  }

  static Future<void> actualizarFoto(
    String casaId,
    String elementoId,
    String registroId,
    String fotoUrl,
  ) async {
    await _col(casaId, elementoId).doc(registroId).update({'fotoUrl': fotoUrl});
  }

  /// Galería de un registro simple (CEO, octubre 2026) -- a diferencia de
  /// [subirFoto] (nombre de archivo fijo, una foto sustituye a la
  /// anterior), cada foto de la galería vive en su propio archivo bajo
  /// "fotos/", igual que DocumentoService.subirArchivo (timestamp +
  /// nombre, nunca se pisan entre sí). [fotosActuales] es Registro.fotos
  /// (ya incluye, si hace falta, la [fotoUrl] antigua de un registro
  /// creado antes de esta mejora, ver ese getter) -- se escribe la lista
  /// COMPLETA resultante en vez de un FieldValue.arrayUnion sobre el campo
  /// en bruto, para que la primera foto que se añada a un registro antiguo
  /// "migre" sola esa foto heredada al array nuevo. Sube todos los
  /// archivos primero y solo entonces escribe, para que un fallo a mitad
  /// de la subida nunca deje en Firestore una URL que no llegó a existir.
  static Future<void> agregarFotos(
    String casaId,
    String elementoId,
    String registroId,
    List<String> fotosActuales,
    List<File> archivosNuevos,
  ) async {
    final urls = [...fotosActuales];
    for (final archivo in archivosNuevos) {
      final ref = FirebaseStorage.instance.ref().child(
        'casas/$casaId/elementos/$elementoId/registros/$registroId/fotos/'
        '${DateTime.now().microsecondsSinceEpoch}_${urls.length}',
      );
      await ref.putFile(archivo);
      urls.add(await ref.getDownloadURL());
    }
    // fotoUrl (campo antiguo) se borra aquí -- a partir de la primera vez
    // que se toca la galería nueva, [fotoUrls] pasa a ser la única fuente
    // de verdad para este registro; dejar fotoUrl vivo podría "resucitar"
    // una foto ya borrada si fotoUrls llega a quedar vacío (ver el
    // criterio de compatibilidad de Registro.fotos).
    await _col(casaId, elementoId).doc(registroId).update({
      'fotoUrls': urls,
      'fotoUrl': FieldValue.delete(),
    });
  }

  /// Borra una foto de la galería: el archivo real en Storage primero (si
  /// ese borrado falla, se corta aquí -- mejor un archivo huérfano que
  /// hacer creer que se borró sin haberlo hecho de verdad) y solo entonces
  /// se escribe la lista restante -- mismo criterio de "lista completa,
  /// nunca arrayRemove en bruto" que [agregarFotos], por si la foto que se
  /// borra era la heredada de la [fotoUrl] antigua.
  static Future<void> eliminarFoto(
    String casaId,
    String elementoId,
    String registroId,
    List<String> fotosActuales,
    String url,
  ) async {
    await FirebaseStorage.instance.refFromURL(url).delete();
    final restantes = fotosActuales.where((u) => u != url).toList();
    await _col(casaId, elementoId).doc(registroId).update({
      'fotoUrls': restantes,
      'fotoUrl': FieldValue.delete(),
    });
  }

  static Future<void> actualizar(
    String casaId,
    String elementoId,
    String registroId,
    Map<String, dynamic> cambios,
  ) async {
    await _col(casaId, elementoId).doc(registroId).update(cambios);
  }

  /// Borrado real (CEO, octubre 2026, cierre de R7/R8): la Cloud Function
  /// hace en servidor lo que un borrado directo del cliente nunca podía
  /// hacer bien -- limpiar también la foto del registro en Storage y los
  /// documentos (con sus archivos) que lo referencian, con Admin SDK.
  /// firestore.rules sigue bloqueando el `delete` directo del cliente a
  /// propósito (ver esas reglas): esta función es la única vía legítima.
  /// Rechaza con `failed-precondition` un registro con profesional -- ver
  /// la propia Cloud Function para el motivo.
  static Future<void> eliminar(
    String casaId,
    String elementoId,
    String registroId,
  ) async {
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('eliminarRegistro');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
    });
  }

  /// El propietario cierra el registro directamente, o confirma que el
  /// profesional de verdad ha terminado (modelo de dos pasos).
  static Future<void> finalizar(
    String casaId,
    String elementoId,
    String registroId,
  ) async {
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('finalizarTrabajoPropietario');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
    });
  }

  /// El profesional dice que ha terminado -- no cierra el registro todavía,
  /// solo lo deja pendiente de que el propietario lo confirme o lo rechace
  /// (modelo de dos pasos, auditoría de producto, octubre 2026).
  static Future<void> marcarFinalizadoProfesional(
    String casaId,
    String elementoId,
    String registroId,
  ) async {
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('marcarTrabajoFinalizadoProfesional');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
    });
  }

  /// El propietario dice que todavía no está terminado -- devuelve el
  /// registro al estado en que estaba antes de que el profesional lo
  /// marcara, y avisa al profesional.
  static Future<void> rechazarFinalizacionProfesional(
    String casaId,
    String elementoId,
    String registroId,
  ) async {
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('rechazarFinalizacionProfesional');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
    });
  }

  /// Banner de "pendientes" en Inicio -- un único documento mantenido por
  /// la Cloud Function onRegistroEstadoCambiado (ver el porqué, evitando
  /// una consulta collectionGroup directa, en firestore.rules).
  static Stream<List<Map<String, dynamic>>> streamPendientes(String casaId) {
    return _db
        .collection('casas')
        .doc(casaId)
        .collection('resumen')
        .doc('pendientes')
        .snapshots()
        .map(
          (d) => List<Map<String, dynamic>>.from(
            (d.data()?['registros'] as List?)?.map(
                  (e) => Map<String, dynamic>.from(e as Map),
                ) ??
                const [],
          ),
        )
        .conRegistroDeErrores();
  }

  /// Botón "Trabajos pendientes" de Inicio: una fila por cada REGISTRO
  /// pendiente, no una por elemento (CEO, octubre 2026) -- antes, si un
  /// mismo elemento tenía varios registros pendientes a la vez (p.ej. dos
  /// instalaciones y una reforma, todas sobre "Pérgolas"), solo se
  /// mostraba la más antigua y el resto desaparecía sin ningún aviso de
  /// que había más. Lectura puntual (no stream) recorriendo la
  /// subcolección de registros de cada elemento -- un registro nunca vive
  /// en una colección a nivel de casa, así que no hay una única consulta
  /// que lo traiga todo de golpe (mismo patrón que
  /// ExpedienteViviendaScreen._todosLosRegistros). Ordenado por fecha
  /// ascendente: el que lleva más tiempo esperando sale primero.
  static Future<
    List<
      ({
        Elemento elemento,
        String registroId,
        String registroTitulo,
        DateTime fecha,
      })
    >
  >
  registrosConTrabajoPendiente(String casaId) async {
    final elementos = await ElementoService.streamElementos(casaId).first;
    final resultado =
        <
          ({
            Elemento elemento,
            String registroId,
            String registroTitulo,
            DateTime fecha,
          })
        >[];
    for (final elemento in elementos) {
      final registros = await streamRegistros(casaId, elemento.id).first;
      for (final r in registros.where(esTrabajoActivo)) {
        resultado.add((
          elemento: elemento,
          registroId: r.id,
          registroTitulo: r.titulo,
          fecha: r.fecha,
        ));
      }
    }
    resultado.sort((a, b) => a.fecha.compareTo(b.fecha));
    return resultado;
  }
}
