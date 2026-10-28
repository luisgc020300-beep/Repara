// test/screens/registro_eliminar_test.dart
//
// Eliminación definitiva DESHABILITADA (auditoría R7/R8, octubre 2026): el
// menú "Eliminar evento" de un registro simple (sin profesional) -- antes
// borraba directamente el documento, sin limpiar su propia foto en Storage
// ni los documentos asociados -- ya nunca llama a RegistroService.eliminar().
// Tocarlo solo explica por qué -- comprueba que el registro sigue existiendo
// íntegro después de tocarlo, no que se borra nada. Usa FakeFirebaseFirestore,
// nada de Firebase real.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/registro_detail_screen.dart';
import 'package:repara/services/documento_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/historial_service.dart';
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

Future<FakeFirebaseFirestore> _prepararConRegistroSimple() async {
  final db = FakeFirebaseFirestore();
  await db
      .collection('casas')
      .doc(_casa.id)
      .collection('elementos')
      .doc('e1')
      .set({'nombre': 'Caldera'});
  await db
      .collection('casas')
      .doc(_casa.id)
      .collection('elementos')
      .doc('e1')
      .collection('registros')
      .doc('r1')
      .set({
        'titulo': 'Freidora nueva',
        'tipo': 'compra',
        'esConProfesional': false,
        'estado': 'terminado',
        'elementoNombre': 'Caldera',
        'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  HistorialService.debugFirestoreOverride = db;
  return db;
}

Future<bool> _existe(FakeFirebaseFirestore db) async {
  final doc = await db
      .collection('casas')
      .doc('c1')
      .collection('elementos')
      .doc('e1')
      .collection('registros')
      .doc('r1')
      .get();
  return doc.exists;
}

void main() {
  // RegistroDetailScreen formatea la fecha del propio registro con
  // DateFormat(..., 'es_ES') -- mismo motivo que elemento_archivar_test.dart
  // (R6): sin esto, revienta con LocaleDataException.
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    HistorialService.debugFirestoreOverride = null;
  });

  testWidgets(
    'tocar "Eliminar evento" en un registro simple no borra nada -- solo explica que está deshabilitado',
    (tester) async {
      final db = await _prepararConRegistroSimple();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(
            casa: _casa,
            elementoId: 'e1',
            registroId: 'r1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Freidora nueva'), findsWidgets);

      // Abrir el menú "⋮" y tocar "Eliminar evento".
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar evento'));
      await tester.pumpAndSettle();

      // Nunca aparece ningún diálogo de confirmación -- no hay nada que
      // confirmar, porque no hay ninguna acción destructiva detrás.
      expect(find.text('¿Eliminar este evento?'), findsNothing);
      expect(
        find.textContaining('eliminación definitiva está temporalmente deshabilitada'),
        findsOneWidget,
      );
      expect(await _existe(db), isTrue);
    },
  );
}
