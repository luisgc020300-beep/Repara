// test/screens/registro_editar_test.dart
//
// "Editar evento" (gap real que señaló el CEO, octubre 2026): ni crear un
// registro simple (nuevo_registro_sheet.dart) ni crear el registro
// fundacional de un elemento nuevo (nuevo_elemento_screen.dart) ofrecían
// después ningún sitio para corregir título/descripción/coste/profesional.
// Cubre el round-trip completo en un registro simple, y que un registro
// con profesional solo deja tocar título/descripción (coste/profesional
// de texto libre no aplican ahí -- ver editar_registro_sheet.dart). Usa
// FakeFirebaseFirestore, nada de Firebase real.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/registro_detail_screen.dart';
import 'package:repara/services/cambio_alcance_service.dart';
import 'package:repara/services/documento_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/historial_service.dart';
import 'package:repara/services/invitacion_service.dart';
import 'package:repara/services/pago_service.dart';
import 'package:repara/services/presupuesto_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

Future<FakeFirebaseFirestore> _conRegistro(Map<String, dynamic> datos) async {
  final db = FakeFirebaseFirestore();
  await db
      .collection('casas')
      .doc(_casa.id)
      .collection('elementos')
      .doc('e1')
      .set({'nombre': 'Pérgolas'});
  await db
      .collection('casas')
      .doc(_casa.id)
      .collection('elementos')
      .doc('e1')
      .collection('registros')
      .doc('r1')
      .set(datos);
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  HistorialService.debugFirestoreOverride = db;
  CambioAlcanceService.debugFirestoreOverride = db;
  PresupuestoService.debugFirestoreOverride = db;
  InvitacionService.debugFirestoreOverride = db;
  return db;
}

Future<Map<String, dynamic>> _datosRegistro(FakeFirebaseFirestore db) async {
  final doc = await db
      .collection('casas')
      .doc('c1')
      .collection('elementos')
      .doc('e1')
      .collection('registros')
      .doc('r1')
      .get();
  return doc.data()!;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    HistorialService.debugFirestoreOverride = null;
    CambioAlcanceService.debugFirestoreOverride = null;
    PresupuestoService.debugFirestoreOverride = null;
    InvitacionService.debugFirestoreOverride = null;
  });

  testWidgets(
    'editar evento en un registro simple cambia título, descripción, coste y profesional',
    (tester) async {
      final db = await _conRegistro({
        'titulo': 'Instalación placa de metal',
        'tipo': 'instalacion',
        'esConProfesional': false,
        'estado': 'terminado',
        'elementoNombre': 'Pérgolas',
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
        'profesionalNombre': 'Metalistero',
        // Sin coste -- el caso real que reportó el CEO: se dejó en blanco
        // al crearlo y no había después ningún sitio para añadirlo.
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar evento'));
      await tester.pumpAndSettle();

      expect(find.text('Editar evento'), findsWidgets);
      // Prellenado con lo que ya había.
      expect(find.widgetWithText(TextField, 'Metalistero'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Descripción (opcional)'),
        'Para que no cayera agua al llover',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Coste (€)'), '45');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      // La hoja se cierra sola al guardar.
      expect(find.text('Guardar cambios'), findsNothing);

      final datos = await _datosRegistro(db);
      expect(datos['titulo'], 'Instalación placa de metal');
      expect(datos['descripcion'], 'Para que no cayera agua al llover');
      expect(datos['coste'], 45);
      expect(datos['profesionalNombre'], 'Metalistero');
    },
  );

  testWidgets(
    'activar "¿Se paga a plazos?" y rellenar frecuencia/importe los guarda juntos',
    (tester) async {
      final db = await _conRegistro({
        'titulo': 'Instalación de aire acondicionado',
        'tipo': 'instalacion',
        'esConProfesional': false,
        'estado': 'pendientePago',
        'elementoNombre': 'Salón',
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
        'coste': 1200,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar evento'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Cada cuántos meses'), findsNothing);
      await tester.tap(find.text('¿Se paga a plazos?'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Cada cuántos meses'), '3');
      await tester.enterText(find.widgetWithText(TextField, 'Importe por plazo (€)'), '300');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final datos = await _datosRegistro(db);
      expect(datos['plazoFrecuenciaMeses'], 3);
      expect(datos['plazoImporte'], 300);
    },
  );

  testWidgets(
    'desactivar "¿Se paga a plazos?" en un registro que ya tenía plan lo borra entero',
    (tester) async {
      final db = await _conRegistro({
        'titulo': 'Instalación de aire acondicionado',
        'tipo': 'instalacion',
        'esConProfesional': false,
        'estado': 'pendientePago',
        'elementoNombre': 'Salón',
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
        'coste': 1200,
        'plazoFrecuenciaMeses': 3,
        'plazoImporte': 300,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar evento'));
      await tester.pumpAndSettle();

      // Prellenado con el plan ya guardado.
      expect(find.widgetWithText(TextField, '3'), findsOneWidget);
      expect(find.widgetWithText(TextField, '300,00'), findsOneWidget);

      await tester.tap(find.text('¿Se paga a plazos?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final datos = await _datosRegistro(db);
      expect(datos['plazoFrecuenciaMeses'], isNull);
      expect(datos['plazoImporte'], isNull);
    },
  );

  testWidgets(
    'editar evento no deja un título vacío -- avisa y no guarda nada',
    (tester) async {
      final db = await _conRegistro({
        'titulo': 'Placa de madera',
        'tipo': 'instalacion',
        'esConProfesional': false,
        'estado': 'terminado',
        'elementoNombre': 'Pérgolas',
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar evento'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Título'), '   ');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      // Sigue en la hoja -- no se cerró.
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(find.text('Obligatorio'), findsOneWidget);
      final datos = await _datosRegistro(db);
      expect(datos['titulo'], 'Placa de madera');
    },
  );

  testWidgets(
    'en un registro con profesional, "Editar evento" solo pide título y descripción, nunca coste ni '
    'profesional, y "Eliminar evento" no aparece',
    (tester) async {
      final db = await _conRegistro({
        'titulo': 'Reforma/Mejora de Pérgolas',
        'tipo': 'reforma',
        'esConProfesional': true,
        'estado': 'enCurso',
        'elementoNombre': 'Pérgolas',
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Editar evento'), findsOneWidget);
      expect(find.text('Eliminar evento'), findsNothing);

      await tester.tap(find.text('Editar evento'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Título'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Descripción (opcional)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Coste (€)'), findsNothing);
      expect(find.widgetWithText(TextField, 'Profesional'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Descripción (opcional)'),
        'Refuerzo de los laterales de las pérgolas',
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final datos = await _datosRegistro(db);
      expect(datos['descripcion'], 'Refuerzo de los laterales de las pérgolas');
      // Nada de lo que gestionan las otras pantallas (presupuesto,
      // profesionalUid...) se toca por esta vía -- ni siquiera se envían.
      expect(datos.containsKey('coste'), isFalse);
      expect(datos.containsKey('presupuesto'), isFalse);
      expect(datos.containsKey('profesionalUid'), isFalse);
    },
  );
}
