// test/screens/registro_simple_pagos_test.dart
//
// "Pagos" en un registro SIMPLE (CEO, octubre 2026): hasta ahora solo
// existía esa sección para un registro con profesional -- "Coste" es un
// número informativo, nunca un registro de lo que de verdad se ha pagado.
// PagosSection ya estaba preparada para funcionar sin presupuesto
// (presupuesto: null) -- registrarPago en servidor tampoco lo exige --
// solo faltaba conectarla a _CuerpoSimple.
//
// NO IMPLEMENTADO AQUÍ (limitación real, no simulada): completar de verdad
// "Añadir pago" invoca la Cloud Function registrarPago vía FirebaseFunctions.
// instanceFor(...), que no se puede invocar en este entorno de test sin el
// emulador de Firebase -- mismo criterio de honestidad que
// elemento_archivar_test.dart. Aquí se comprueba lo que sí se puede probar
// sin red: que la sección aparece, que un pago ya existente se lista, y que
// "Añadir pago" navega al formulario correcto sin tope de presupuesto.
// Usa FakeFirebaseFirestore, nada de Firebase real.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/pago_detail_screen.dart';
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

Future<FakeFirebaseFirestore> _prepararConRegistroSimple({bool conPago = false}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('casas').doc(_casa.id).collection('elementos').doc('e1').set({
    'nombre': 'Pérgolas',
  });
  final regRef = db
      .collection('casas')
      .doc(_casa.id)
      .collection('elementos')
      .doc('e1')
      .collection('registros')
      .doc('r1');
  await regRef.set({
    'titulo': 'Instalación placa de metal',
    'tipo': 'instalacion',
    'esConProfesional': false,
    'estado': 'terminado',
    'elementoNombre': 'Pérgolas',
    'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
    'coste': 2000,
    'profesionalNombre': 'Metalistero',
  });
  if (conPago) {
    await regRef.collection('pagos').add({
      'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
      'importe': 2000,
      'concepto': 'Pago 1',
      'createdBy': 'u1',
    });
  }
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  HistorialService.debugFirestoreOverride = db;
  return db;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    HistorialService.debugFirestoreOverride = null;
  });

  testWidgets(
    'un registro simple sin pagos muestra la sección "Pagos" con su estado vacío y el botón de añadir',
    (tester) async {
      await _prepararConRegistroSimple();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pagos'), findsOneWidget);
      expect(find.text('Sin pagos registrados todavía.'), findsOneWidget);
      expect(find.text('Añadir pago'), findsOneWidget);
    },
  );

  testWidgets(
    'un pago ya registrado en un registro simple se lista en la sección Pagos',
    (tester) async {
      await _prepararConRegistroSimple(conPago: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin pagos registrados todavía.'), findsNothing);
      expect(find.text('Pago 1'), findsOneWidget);
      expect(find.text('2000.00 €'), findsOneWidget);
    },
  );

  // CEO, octubre 2026: pidió la misma barra de progreso verde (Coste/
  // Pagado/Saldo) que ya tenía un registro con profesional (presupuesto),
  // también para uno simple -- _TarjetaEconomica ya existía, solo faltaba
  // reutilizarla aquí con "Coste" en vez de "Presupuesto".
  testWidgets(
    'un registro simple con coste y un pago parcial muestra la barra de progreso Coste/Pagado/Saldo',
    (tester) async {
      final db = await _prepararConRegistroSimple();
      await db
          .collection('casas')
          .doc(_casa.id)
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .doc('r1')
          .collection('pagos')
          .add({
            'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
            'importe': 800,
            'concepto': 'Primer plazo',
            'createdBy': 'u1',
          });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COSTE'), findsOneWidget);
      expect(find.text('PAGADO'), findsOneWidget);
      expect(find.text('SALDO'), findsOneWidget);
      expect(find.text('2000 €'), findsOneWidget);
      expect(find.text('800 €'), findsOneWidget);
      expect(find.text('1200 €'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'un registro simple con coste completamente pagado muestra "Completado", sin barra de progreso',
    (tester) async {
      await _prepararConRegistroSimple(conPago: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completado'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    '"Añadir pago" en un registro simple abre el formulario sin ningún tope de presupuesto',
    (tester) async {
      await _prepararConRegistroSimple();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      // Con la cabecera/progreso/acciones rápidas nuevas, "Añadir pago"
      // queda fuera del viewport inicial -- hay que desplazarse antes de
      // poder tocarlo. scrollUntilVisible para en cuanto el widget EXISTE
      // en el árbol, no necesariamente dentro del viewport visible todavía
      // -- un segundo arrastre de sobra lo deja ya tocable de verdad.
      await tester.scrollUntilVisible(
        find.text('Añadir pago'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir pago'));
      await tester.pumpAndSettle();

      final pantalla = tester.widget<PagoDetailScreen>(find.byType(PagoDetailScreen));
      expect(pantalla.presupuesto, isNull);
      expect(pantalla.editable, isTrue);
      expect(find.text('Guardar'), findsOneWidget);
    },
  );
}
