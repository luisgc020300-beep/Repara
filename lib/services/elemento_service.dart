// lib/services/elemento_service.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/elemento.dart';
import '../models/registro.dart';
import 'stream_error_logging.dart';

class ElementoService {
  /// Seam de solo test -- nunca se asigna en código de producción. Ver
  /// casa_service.dart para el criterio general.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;

  static FirebaseFirestore get _db =>
      debugFirestoreOverride ?? FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static CollectionReference<Map<String, dynamic>> _col(String casaId) =>
      _db.collection('casas').doc(casaId).collection('elementos');

  // El más reciente primero (CEO, octubre 2026: sin orderBy, Firestore
  // devuelve los documentos en un orden interno no garantizado -- no es el
  // orden de creación -- así que un elemento recién añadido podía aparecer
  // en cualquier sitio de la lista, no arriba).
  //
  // [incluirArchivados] false por defecto (auditoría R5, octubre 2026): el
  // filtro se hace en el cliente, nunca con un .where('archivado', ...) de
  // Firestore -- una query de igualdad de Firestore NO encuentra los
  // documentos a los que les falta el campo, así que filtrar en servidor
  // habría escondido de golpe TODOS los elementos antiguos (antes de esta
  // iteración, ninguno tiene este campo). Filtrando aquí, con
  // Elemento.archivado ya resuelto a false por fromDoc cuando el campo no
  // existe, un elemento antiguo se sigue viendo como activo sin ninguna
  // migración.
  static Stream<List<Elemento>> streamElementos(
    String casaId, {
    String? habitacionId,
    bool incluirArchivados = false,
  }) {
    Query<Map<String, dynamic>> q = _col(
      casaId,
    ).orderBy('createdAt', descending: true);
    if (habitacionId != null) {
      q = q.where('habitacionId', isEqualTo: habitacionId);
    }
    return q
        .snapshots()
        .map((s) => s.docs.map(Elemento.fromDoc).toList())
        .map(
          (lista) => incluirArchivados
              ? lista
              : lista.where((e) => !e.archivado).toList(),
        )
        .conRegistroDeErrores();
  }

  /// Solo los archivados -- para la pantalla dedicada a verlos (nunca
  /// mezclados con los activos, ver streamElementos). Mismo motivo de filtro
  /// en cliente que arriba.
  static Stream<List<Elemento>> streamElementosArchivados(String casaId) {
    return _col(casaId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(Elemento.fromDoc)
              .where((e) => e.archivado)
              .toList(),
        )
        .conRegistroDeErrores();
  }

  /// Bloquea en servidor si tiene trabajo profesional activo o pendiente, o
  /// si ya está archivado -- la UI puede (y debe) evitar ofrecer el botón en
  /// esos casos, pero la decisión real es de archivarElemento (Cloud
  /// Function), nunca de este método ni de ningún botón deshabilitado.
  static Future<void> archivar(String casaId, String elementoId) async {
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('archivarElemento');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
    });
  }

  static Future<void> restaurar(String casaId, String elementoId) async {
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('restaurarElemento');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
    });
  }

  static Stream<Elemento?> streamElemento(String casaId, String elementoId) {
    return _col(casaId)
        .doc(elementoId)
        .snapshots()
        .map((d) => d.exists ? Elemento.fromDoc(d) : null)
        .conRegistroDeErrores();
  }

  static Future<String> crear(String casaId, Elemento elemento) async {
    final ref = await _col(
      casaId,
    ).add({...elemento.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    return ref.id;
  }

  /// A diferencia de [crear] (que usa toMap(), omitiendo las claves nulas --
  /// perfecto para un documento nuevo), aquí hay que escribir explícitamente
  /// null en cada campo editable para que vaciar un campo en el formulario
  /// (p.ej. borrar un typo en "Marca") de verdad lo borre en Firestore --
  /// `.update()` nunca toca una clave que no se le pase (auditoría de
  /// producto, octubre 2026). `fotoUrl` queda fuera a propósito: ningún
  /// formulario lo edita todavía, así que nunca debe tocarse aquí.
  static Future<void> actualizar(
    String casaId,
    String elementoId,
    Elemento elemento,
  ) async {
    await _col(casaId).doc(elementoId).update({
      'nombre': elemento.nombre,
      'habitacionId': elemento.habitacionId,
      'marca': elemento.marca,
      'modelo': elemento.modelo,
      'fechaInstalacion': elemento.fechaInstalacion != null
          ? Timestamp.fromDate(elemento.fechaInstalacion!)
          : null,
      'coste': elemento.coste,
      'profesionalNombre': elemento.profesionalNombre,
      'garantiaHasta': elemento.garantiaHasta != null
          ? Timestamp.fromDate(elemento.garantiaHasta!)
          : null,
      'intervaloMantenimientoMeses': elemento.intervaloMantenimientoMeses,
      'proximoMantenimiento': elemento.proximoMantenimiento != null
          ? Timestamp.fromDate(elemento.proximoMantenimiento!)
          : null,
    });
  }

  /// DESHABILITADA en servidor (auditoría R6, octubre 2026): borra solo este
  /// documento, nunca sus subcolecciones ni los archivos de Storage
  /// asociados -- firestore.rules ya bloquea este `delete` con
  /// `allow delete: if false`, así que llamar a este método ahora falla
  /// siempre con `permission-denied`. Ningún código de la app lo llama (ver
  /// informe de R6) -- se mantiene sin borrar para no perder el historial de
  /// por qué `allow delete` está bloqueado, no porque tenga ningún uso
  /// legítimo pendiente. No lo reactives sin una limpieza segura de
  /// subcolecciones/Storage detrás.
  static Future<void> eliminar(String casaId, String elementoId) async {
    await _col(casaId).doc(elementoId).delete();
  }

  /// Foto del elemento -- la única forma de rellenar [Elemento.fotoUrl],
  /// aparte del propio campo en Firestore (CEO, octubre 2026: se edita desde
  /// la ficha, tocando el hueco de foto, no desde el formulario de
  /// creación -- muchas veces la foto se hace después, no al crear el
  /// elemento). Nombre de archivo fijo ("foto") en vez de con timestamp: una
  /// foto nueva sustituye a la anterior, nunca se acumulan fotos sueltas.
  static Future<String> subirFoto(
    String casaId,
    String elementoId,
    File archivo,
  ) async {
    final ref = FirebaseStorage.instance.ref().child(
      'casas/$casaId/elementos/$elementoId/foto',
    );
    await ref.putFile(archivo);
    return ref.getDownloadURL();
  }

  /// [fotoUrl] null borra la foto (no el archivo en Storage, solo la
  /// referencia -- mismo criterio de limpieza que el resto de la app, ver
  /// nota en subirFoto: una foto nueva ya sustituye a la anterior en el
  /// mismo nombre de archivo, así que no se acumula basura en Storage).
  static Future<void> actualizarFoto(
    String casaId,
    String elementoId,
    String? fotoUrl,
  ) async {
    await _col(casaId).doc(elementoId).update({'fotoUrl': fotoUrl});
  }

  /// Único flujo de creación de la app (octubre 2026, fusión Elemento/
  /// Trabajo/Evento): un elemento nunca nace solo, siempre con su registro
  /// fundacional -- "compré una freidora" tanto como "me cambiaron la
  /// depuradora de la piscina" se crean exactamente igual. En un batch (no
  /// hace falta una transacción: no hay ninguna condición de carrera entre
  /// crear el elemento y su primer registro) para que nunca quede un
  /// elemento huérfano sin ningún registro si algo falla a medias.
  static Future<({String elementoId, String registroId})>
  crearConRegistroFundacional({
    required String casaId,
    required Elemento elemento,
    required Registro registroFundacional,
    required String createdBy,
  }) async {
    final elementoRef = _col(casaId).doc();
    final registroRef = elementoRef.collection('registros').doc();
    final batch = _db.batch();
    batch.set(elementoRef, {
      ...elemento.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(registroRef, {
      ...registroFundacional.toMap(),
      'elementoNombre': elemento.nombre,
      'casaId': casaId,
      'createdBy': createdBy,
    });
    await batch.commit();
    return (elementoId: elementoRef.id, registroId: registroRef.id);
  }

  /// Elementos con garantía a menos de 30 días -- usado en el dashboard de
  /// Inicio (sección 25 del spec: avisar de garantías próximas a vencer).
  static Future<List<Elemento>> conGarantiaProximaAVencer(String casaId) async {
    final snap = await _col(casaId).get();
    return snap.docs
        .map(Elemento.fromDoc)
        .where((e) => e.garantiaProximaAVencer)
        .toList();
  }

  /// Elementos con revisión periódica próxima o ya atrasada -- calendario
  /// de mantenimiento autogenerado, mismo dashboard de Inicio.
  static Future<List<Elemento>> conRevisionPendiente(String casaId) async {
    final snap = await _col(casaId).get();
    return snap.docs
        .map(Elemento.fromDoc)
        .where((e) => e.revisionPendiente)
        .toList();
  }

  /// TODOS los elementos con una fecha de garantía guardada, pendiente o no
  /// -- el aviso de Inicio solo enseña lo urgente (<=30 días), pero "encontrar
  /// una garantía" (auditoría de producto, octubre 2026) necesita poder
  /// consultar también las que vencen más adelante, no solo las que aprietan.
  static Future<List<Elemento>> conGarantia(String casaId) async {
    final snap = await _col(casaId).get();
    final elementos = snap.docs
        .map(Elemento.fromDoc)
        .where((e) => e.garantiaHasta != null)
        .toList();
    elementos.sort((a, b) => a.garantiaHasta!.compareTo(b.garantiaHasta!));
    return elementos;
  }

  /// TODOS los elementos con un calendario de mantenimiento configurado,
  /// pendiente o no -- mismo motivo que [conGarantia]: "ver qué mantenimiento
  /// está pendiente" no debe depender de que ya esté a punto de vencer.
  static Future<List<Elemento>> conMantenimientoConfigurado(
    String casaId,
  ) async {
    final snap = await _col(casaId).get();
    final elementos = snap.docs
        .map(Elemento.fromDoc)
        .where((e) => e.proximoMantenimiento != null)
        .toList();
    elementos.sort(
      (a, b) => a.proximoMantenimiento!.compareTo(b.proximoMantenimiento!),
    );
    return elementos;
  }

  /// Avanza la próxima revisión [intervaloMeses] meses desde HOY (no desde
  /// la fecha antigua) -- si estaba muy atrasada, no tiene sentido arrastrar
  /// ese retraso para siempre.
  static Future<void> marcarRevisionHecha(
    String casaId,
    String elementoId,
    int intervaloMeses,
  ) async {
    final ahora = DateTime.now();
    final proxima = DateTime(
      ahora.year,
      ahora.month + intervaloMeses,
      ahora.day,
    );
    await _col(casaId).doc(elementoId).update({
      'proximoMantenimiento': Timestamp.fromDate(proxima),
    });
  }

  /// Edición manual del calendario de mantenimiento -- por si la sugerencia
  /// de la IA no encajaba o el propietario quiere cambiarla más tarde.
  /// Ambos valores pueden ser null para quitar el recordatorio por completo.
  static Future<void> actualizarMantenimiento(
    String casaId,
    String elementoId, {
    required int? intervaloMeses,
    required DateTime? proximoMantenimiento,
  }) async {
    await _col(casaId).doc(elementoId).update({
      'intervaloMantenimientoMeses': intervaloMeses,
      'proximoMantenimiento': proximoMantenimiento != null
          ? Timestamp.fromDate(proximoMantenimiento)
          : null,
    });
  }

  /// Pide a la IA un intervalo típico de revisión según el tipo de
  /// elemento -- solo SUGIERE, nunca se guarda sin que el propietario lo
  /// confirme (mismo principio que DocumentoService.clasificarConIA).
  static Future<({int? intervaloMeses, String? motivo})>
  sugerirIntervaloMantenimiento({
    required String nombre,
    String? marca,
    String? modelo,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('sugerirIntervaloMantenimiento');
    final result = await callable.call<Map<String, dynamic>>({
      'nombre': nombre,
      'marca': marca,
      'modelo': modelo,
    });
    return (
      intervaloMeses: (result.data['intervaloMeses'] as num?)?.toInt(),
      motivo: result.data['motivo'] as String?,
    );
  }
}
