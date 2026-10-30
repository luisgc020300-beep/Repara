// test/screens/registro_simple_galeria_fotos_test.dart
//
// Galería de varias fotos en un registro SIMPLE (CEO, octubre 2026) -- ver
// RegistroSimpleCabecera/GaleriaFotosScreen. Comprueba: el contador "N
// fotos", que tocar la portada abre la galería con TODAS las fotos (tanto
// con [fotoUrls] nuevo como con el [fotoUrl] antiguo de un registro creado
// antes de esta mejora, sin ninguna migración de datos -- ver
// Registro.fotos), y que el botón "+" siempre ofrece añadir más.
//
// NO PROBADO AQUÍ (limitación real, no simulada): completar de verdad una
// subida o un borrado invoca FirebaseStorage.instance, que no se puede
// usar en este entorno de test sin el emulador de Firebase -- mismo
// criterio de honestidad que el resto de esta suite (ver
// registro_simple_pagos_test.dart). Lo que sí se puede probar sin red es
// la navegación y qué fotos se le pasan a la galería.
// Usa FakeFirebaseFirestore, nada de Firebase real.
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
        'titulo': 'Placa de madera',
        'tipo': 'instalacion',
        'esConProfesional': false,
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
    'sin ninguna foto, tocar la portada abre el selector para añadir la primera',
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
    'con una sola foto heredada (fotoUrl antiguo, sin fotoUrls), tocar la portada abre la galería con esa foto',
    (tester) async {
      await _prepararConRegistro({'fotoUrl': 'https://example.com/antigua.jpg'});

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException(); // sin red real -- Image.network falla en test.

      // Sin "N fotos" porque solo hay una.
      expect(find.textContaining('fotos'), findsNothing);

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      tester.takeException(); // sin red real -- ver nota de la cabecera.

      final galeria = tester.widget<GaleriaFotosScreen>(
        find.byType(GaleriaFotosScreen),
      );
      expect(galeria.urls, ['https://example.com/antigua.jpg']);
    },
  );

  testWidgets(
    'con varias fotos, muestra el contador y la galería recibe todas',
    (tester) async {
      await _prepararConRegistro({
        'fotoUrls': [
          'https://example.com/1.jpg',
          'https://example.com/2.jpg',
          'https://example.com/3.jpg',
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

      expect(find.text('3 fotos'), findsOneWidget);

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      tester.takeException(); // sin red real -- ver nota de la cabecera.

      final galeria = tester.widget<GaleriaFotosScreen>(
        find.byType(GaleriaFotosScreen),
      );
      expect(galeria.urls, hasLength(3));
      expect(galeria.onEliminar, isNotNull);
    },
  );

  testWidgets(
    'con fotos ya puestas, el botón "+" de la esquina también ofrece añadir más',
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

      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Hacer una foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
    },
  );
}
