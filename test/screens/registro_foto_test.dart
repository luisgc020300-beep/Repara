// test/screens/registro_foto_test.dart
//
// Foto de un registro (CEO, octubre 2026): con foto, toda la miniatura
// compartía un único GestureDetector que siempre abría el selector de
// cámara/galería para CAMBIARLA -- nunca se podía ampliar para verla
// mejor, a diferencia de la foto del elemento (_FotoElemento en
// elemento_detail_screen.dart), que ya separaba "tocar la foto = ampliar"
// de "tocar el lápiz = cambiar" desde una corrección anterior. Aplica aquí
// el mismo criterio, reutilizando FotoAmpliadaScreen (antes privado de esa
// pantalla, ahora en lib/widgets/). Usa FakeFirebaseFirestore, nada de
// Firebase real.
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
import 'package:repara/widgets/foto_ampliada_screen.dart';

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
    'con foto, tocar la miniatura la amplía a pantalla completa (no abre el selector de cámara/galería)',
    (tester) async {
      await _prepararConRegistro({'fotoUrl': 'https://example.com/foto.jpg'});

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();
      // En el entorno de test no hay red real -- Image.network falla
      // siempre (lo gestiona errorBuilder en pantalla, pero el propio
      // framework de test también lo registra como excepción pendiente).
      // Se consume aquí para no confundirlo con un fallo real del test.
      tester.takeException();

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(FotoAmpliadaScreen), findsOneWidget);
      expect(find.text('Hacer una foto'), findsNothing);
    },
  );

  testWidgets(
    'el lápiz de la esquina sigue abriendo el selector para cambiar la foto, aunque ya haya una',
    (tester) async {
      await _prepararConRegistro({'fotoUrl': 'https://example.com/foto.jpg'});

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException(); // sin red real -- ver nota del test anterior.

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Hacer una foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
      expect(find.byType(FotoAmpliadaScreen), findsNothing);
    },
  );

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

      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Hacer una foto'), findsOneWidget);
    },
  );
}
