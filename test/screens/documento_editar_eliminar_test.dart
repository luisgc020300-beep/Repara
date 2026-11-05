// test/screens/documento_editar_eliminar_test.dart
//
// "Cada documento debería poder ser editable y eliminable" (CEO, noviembre
// 2026: "por si subo uno donde no era o me equivoco en algo"). Antes,
// tocar un documento solo lo abría (documento_abrir.dart); borrar solo
// existía, sin ningún indicio visual, como gesto de mantener pulsado en el
// listado de Documentos de la casa, y editar no existía en ningún sitio.
// Ahora tocar un documento ofrece un menú corto (mostrarAccionesDocumento)
// -- este test cubre esa pantalla (DocumentosCasaScreen); las otras dos
// (elemento_detail_screen.dart, registro_detail_screen.dart) comparten el
// mismo widget, no se repite la cobertura ahí. Usa FakeFirebaseFirestore,
// nada de Firebase real.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/documentos_casa_screen.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/documento_service.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

Future<FakeFirebaseFirestore> _conDocumento() async {
  final db = FakeFirebaseFirestore();
  await db.collection('casas').doc(_casa.id).collection('documentos').doc('d1').set({
    'url': 'https://example.com/factura.pdf',
    'nombreArchivo': 'factura.pdf',
    'tipo': 'factura',
    'proveedor': 'Fontanero Pepe',
    'importe': 120,
    'fecha': Timestamp.fromDate(DateTime(2026, 10, 1)),
    'estadoIA': 'confirmado',
    'archivosAdicionales': <String>[],
  });
  DocumentoService.debugFirestoreOverride = db;
  return db;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));
  tearDown(() => DocumentoService.debugFirestoreOverride = null);

  testWidgets(
    'tocar un documento ofrece Abrir/Editar/Eliminar en vez de abrirlo directamente',
    (tester) async {
      await _conDocumento();

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const DocumentosCasaScreen(casa: _casa)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fontanero Pepe'));
      await tester.pumpAndSettle();

      expect(find.text('Abrir documento'), findsOneWidget);
      expect(find.text('Editar datos'), findsOneWidget);
      expect(find.text('Eliminar documento'), findsOneWidget);
    },
  );

  testWidgets(
    '"Editar datos" abre el formulario prellenado y "Guardar cambios" corrige el documento',
    (tester) async {
      final db = await _conDocumento();
      // Formulario largo dentro de una hoja modal -- con el tamaño de
      // superficie de test por defecto (800x600), "Guardar cambios" queda
      // fuera del viewport incluso tras desplazar. Una superficie más alta
      // evita eso sin cambiar el layout real de la hoja.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const DocumentosCasaScreen(casa: _casa)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fontanero Pepe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar datos'));
      await tester.pumpAndSettle();

      // Prellenado con lo que ya había.
      expect(find.widgetWithText(TextField, 'Fontanero Pepe'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Profesional / empresa emisora'),
        'Fontanería Pepe e Hijos',
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      // La hoja se cierra sola al guardar.
      expect(find.text('Guardar cambios'), findsNothing);

      final doc = await db.collection('casas').doc(_casa.id).collection('documentos').doc('d1').get();
      expect(doc.data()!['proveedor'], 'Fontanería Pepe e Hijos');
      // El resto de campos no se toca.
      expect(doc.data()!['importe'], 120);
      expect(doc.data()!['url'], 'https://example.com/factura.pdf');
    },
  );

  testWidgets(
    '"Eliminar documento" pide confirmación -- declinarla no borra nada',
    (tester) async {
      final db = await _conDocumento();

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const DocumentosCasaScreen(casa: _casa)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fontanero Pepe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar documento'));
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar este documento?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      final doc = await db.collection('casas').doc(_casa.id).collection('documentos').doc('d1').get();
      expect(doc.exists, isTrue);
    },
  );

  testWidgets(
    '"Eliminar documento" + confirmar lo borra de verdad',
    (tester) async {
      final db = await _conDocumento();

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const DocumentosCasaScreen(casa: _casa)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fontanero Pepe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar documento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      final doc = await db.collection('casas').doc(_casa.id).collection('documentos').doc('d1').get();
      expect(doc.exists, isFalse);
      expect(find.text('Fontanero Pepe'), findsNothing);
    },
  );
}
