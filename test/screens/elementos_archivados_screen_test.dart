// test/screens/elementos_archivados_screen_test.dart
//
// Pantalla dedicada a ver elementos archivados (auditoría R5, octubre
// 2026): nunca mezcla activos con archivados, y muestra un estado vacío
// cuidado cuando no hay ninguno. Usa FakeFirebaseFirestore, nada de
// Firebase real -- el botón "Restaurar" en sí no se ejercita aquí por el
// mismo motivo documentado en elemento_archivar_test.dart.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/elementos_archivados_screen.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

void main() {
  tearDown(() => ElementoService.debugFirestoreOverride = null);

  testWidgets(
    'sin ningún elemento archivado, muestra el estado vacío',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('activo')
          .set({'nombre': 'Activo'});
      ElementoService.debugFirestoreOverride = db;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ElementosArchivadosScreen(casa: _casa),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tienes ningún elemento archivado.'), findsOneWidget);
      expect(find.text('Activo'), findsNothing);
    },
  );

  testWidgets(
    'lista solo los elementos archivados, con botón de restaurar',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('activo')
          .set({'nombre': 'Activo'});
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('viejo')
          .set({'nombre': 'Calentador viejo', 'archivado': true});
      ElementoService.debugFirestoreOverride = db;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ElementosArchivadosScreen(casa: _casa),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Calentador viejo'), findsOneWidget);
      expect(find.text('Activo'), findsNothing);
      expect(find.text('Restaurar'), findsOneWidget);
    },
  );
}
