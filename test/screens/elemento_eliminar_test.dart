// test/screens/elemento_eliminar_test.dart
//
// Eliminación definitiva DESHABILITADA (auditoría R6, octubre 2026): el
// botón "Eliminar elemento" (antes borraba directamente el documento, sin
// limpiar subcolecciones ni Storage -- confirmado en R3/R4) ya nunca llama a
// ElementoService.eliminar(). Tocarlo solo explica por qué -- comprueba que
// el elemento sigue existiendo íntegro después de tocarlo, no que se borra
// nada. Usa FakeFirebaseFirestore, nada de Firebase real.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/elemento_detail_screen.dart';
import 'package:repara/services/documento_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/habitacion_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

Future<FakeFirebaseFirestore> _prepararConElemento(String elementoId) async {
  final db = FakeFirebaseFirestore();
  await db
      .collection('casas')
      .doc(_casa.id)
      .collection('elementos')
      .doc(elementoId)
      .set({'nombre': 'Caldera'});
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  HabitacionService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  return db;
}

Future<bool> _existe(FakeFirebaseFirestore db, String elementoId) async {
  final doc = await db.collection('casas').doc('c1').collection('elementos').doc(elementoId).get();
  return doc.exists;
}

void main() {
  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    HabitacionService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
  });

  testWidgets(
    'tocar "Eliminar elemento" no pide confirmación ni borra nada -- solo explica que está deshabilitado',
    (tester) async {
      final db = await _prepararConElemento('e1');

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: ElementoDetailScreen(casa: _casa, elementoId: 'e1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Caldera'), findsWidgets);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
      await tester.pumpAndSettle();

      // Nunca aparece ningún diálogo de confirmación -- no hay nada que
      // confirmar, porque no hay ninguna acción destructiva detrás.
      expect(find.text('¿Eliminar elemento?'), findsNothing);
      expect(
        find.textContaining('eliminación definitiva está temporalmente deshabilitada'),
        findsOneWidget,
      );
      expect(await _existe(db, 'e1'), isTrue);
      expect(find.text('Caldera'), findsWidgets);
    },
  );

  testWidgets(
    'tocar "Eliminar elemento" varias veces seguidas sigue sin borrar nada',
    (tester) async {
      final db = await _prepararConElemento('e1');

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: ElementoDetailScreen(casa: _casa, elementoId: 'e1')),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
        await tester.pumpAndSettle();
      }

      expect(await _existe(db, 'e1'), isTrue);
    },
  );
}
