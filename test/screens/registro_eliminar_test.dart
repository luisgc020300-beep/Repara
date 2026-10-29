// test/screens/registro_eliminar_test.dart
//
// Eliminación REAL (CEO, octubre 2026, cierre de R7/R8): "Eliminar evento"
// ahora pide confirmación y, si se confirma, llama a RegistroService.
// eliminar() -- que invoca la Cloud Function eliminarRegistro (limpieza
// completa en servidor: Storage + documentos + recursiveDelete). Usa
// FakeFirebaseFirestore, nada de Firebase real.
//
// NO IMPLEMENTADO (limitación real, no simulada): confirmar de verdad la
// eliminación invoca una Cloud Function real vía FirebaseFunctions.
// instanceFor(...), que no se puede invocar en este entorno de test sin el
// emulador de Firebase -- mismo criterio de honestidad que ya documenta
// elemento_archivar_test.dart (R5/R6). El comportamiento real de
// eliminarRegistro (incluido que rechaza un registro con profesional) se
// verifica en functions-tests/eliminar_registro_elemento.test.js, contra el
// emulador. Aquí solo se comprueba lo que sí se puede probar sin red: que
// aparece el diálogo de confirmación con el texto correcto, y que declinarlo
// no borra nada.
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
    'tocar "Eliminar evento" pide confirmación -- declinarla no borra nada',
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

      expect(find.text('¿Eliminar este evento?'), findsOneWidget);
      expect(find.textContaining('no se puede deshacer'), findsOneWidget);

      // Cancelar -- nunca llega a RegistroService.eliminar().
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(await _existe(db), isTrue);
    },
  );
}
