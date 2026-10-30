// test/screens/registro_cabecera_foto_test.dart
//
// Galería de varias fotos en un registro CON PROFESIONAL (CEO, octubre
// 2026) -- RegistroCabecera (antes "_CabeceraRegistro", de una sola foto y
// exclusiva de este lado) pasa a ser la MISMA cabecera que ya tenía el
// registro simple: miniatura pequeña a la derecha, texto a la izquierda, y
// ahora también galería de varias fotos (ver registro_service.dart:
// agregarFotos/eliminarFoto, ya eran genéricos). Mismo comportamiento que
// prueba registro_simple_galeria_fotos_test.dart, aquí del lado con
// profesional. Usa FakeFirebaseFirestore, nada de Firebase real.
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
import 'package:repara/widgets/galeria_fotos_screen.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

Future<void> _prepararConRegistro(Map<String, dynamic> extra) async {
  final db = FakeFirebaseFirestore();
  await db.collection('casas').doc(_casa.id).collection('elementos').doc('e1').set({
    'nombre': 'Pérgolas',
  });
  await db
      .collection('casas')
      .doc(_casa.id)
      .collection('elementos')
      .doc('e1')
      .collection('registros')
      .doc('r1')
      .set({
        'titulo': 'Reforma de pérgola',
        'tipo': 'reforma',
        'esConProfesional': true,
        'estado': 'terminado',
        'elementoNombre': 'Pérgolas',
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
        ...extra,
      });
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  HistorialService.debugFirestoreOverride = db;
  InvitacionService.debugFirestoreOverride = db;
  PresupuestoService.debugFirestoreOverride = db;
  CambioAlcanceService.debugFirestoreOverride = db;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    HistorialService.debugFirestoreOverride = null;
    InvitacionService.debugFirestoreOverride = null;
    PresupuestoService.debugFirestoreOverride = null;
    CambioAlcanceService.debugFirestoreOverride = null;
  });

  testWidgets(
    'sin foto todavía, tocar la miniatura abre directamente el selector para añadirla',
    (tester) async {
      await _prepararConRegistro({});

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_a_photo_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Hacer una foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
    },
  );

  testWidgets(
    'con una sola foto heredada (fotoUrl antiguo, sin fotoUrls), tocar la miniatura abre la galería con esa foto',
    (tester) async {
      await _prepararConRegistro({'fotoUrl': 'https://example.com/foto.jpg'});

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException(); // sin red real -- Image.network falla en test.

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      tester.takeException();

      final galeria = tester.widget<GaleriaFotosScreen>(
        find.byType(GaleriaFotosScreen),
      );
      expect(galeria.urls, ['https://example.com/foto.jpg']);
    },
  );

  testWidgets(
    'con varias fotos, muestra el contador y la galería recibe todas, con opción de borrar',
    (tester) async {
      await _prepararConRegistro({
        'fotoUrls': [
          'https://example.com/1.jpg',
          'https://example.com/2.jpg',
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      tester.takeException();

      final galeria = tester.widget<GaleriaFotosScreen>(
        find.byType(GaleriaFotosScreen),
      );
      expect(galeria.urls, hasLength(2));
      expect(galeria.onEliminar, isNotNull);
    },
  );

  testWidgets(
    'con fotos ya puestas, el botón de la esquina también ofrece añadir más',
    (tester) async {
      await _prepararConRegistro({
        'fotoUrls': ['https://example.com/1.jpg'],
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.byIcon(Icons.add_a_photo_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Hacer una foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
    },
  );
}
