// test/screens/elemento_eliminar_test.dart
//
// Eliminación REAL (CEO, octubre 2026, cierre de R6): el botón "Eliminar
// elemento" pide confirmación y, si se confirma, llama a ElementoService.
// eliminar() -- que invoca la Cloud Function eliminarElemento (limpieza
// completa en servidor). Se deshabilita (con tooltip) si el elemento tiene
// algún registro con profesional -- mismo criterio que repite la Cloud
// Function en servidor, decisión de producto del CEO para proteger el
// historial de trabajos/pagos. Usa FakeFirebaseFirestore, nada de Firebase
// real.
//
// NO IMPLEMENTADO (limitación real, no simulada): confirmar de verdad la
// eliminación invoca una Cloud Function real -- no se puede invocar en este
// entorno de test sin el emulador de Firebase, mismo criterio de honestidad
// que elemento_archivar_test.dart (R5/R6). El comportamiento real de
// eliminarElemento se verifica en
// functions-tests/eliminar_registro_elemento.test.js, contra el emulador.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/elemento_detail_screen.dart';
import 'package:repara/services/documento_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/habitacion_service.dart';
import 'package:repara/services/pago_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

Future<FakeFirebaseFirestore> _prepararConElemento(
  String elementoId, {
  bool conRegistroProfesional = false,
}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('casas').doc(_casa.id).collection('elementos').doc(elementoId).set({
    'nombre': 'Caldera',
  });
  if (conRegistroProfesional) {
    await db
        .collection('casas')
        .doc(_casa.id)
        .collection('elementos')
        .doc(elementoId)
        .collection('registros')
        .doc('r1')
        .set({
          'titulo': 'Reparación de la caldera',
          'tipo': 'reparacion',
          'esConProfesional': true,
          // Terminado y todo -- el CEO decidió que esto también debe
          // bloquear el borrado, no solo un trabajo todavía activo.
          'estado': 'terminado',
          'elementoNombre': 'Caldera',
          'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });
  }
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  HabitacionService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  return db;
}

Future<bool> _existe(FakeFirebaseFirestore db, String elementoId) async {
  final doc = await db.collection('casas').doc('c1').collection('elementos').doc(elementoId).get();
  return doc.exists;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    HabitacionService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
  });

  testWidgets(
    'tocar "Eliminar elemento" pide confirmación -- declinarla no borra nada',
    (tester) async {
      final db = await _prepararConElemento('e1');

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: ElementoDetailScreen(casa: _casa, elementoId: 'e1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Caldera'), findsWidgets);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar este elemento?'), findsOneWidget);
      expect(find.textContaining('no se puede deshacer'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(await _existe(db, 'e1'), isTrue);
    },
  );

  testWidgets(
    'con algún registro con profesional (aunque ya esté terminado), el botón de eliminar está '
    'deshabilitado',
    (tester) async {
      await _prepararConElemento('e1', conRegistroProfesional: true);

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: ElementoDetailScreen(casa: _casa, elementoId: 'e1')),
      );
      await tester.pumpAndSettle();

      final boton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(boton.onPressed, isNull);
      expect(boton.tooltip, contains('algún evento con profesional'));
    },
  );
}
