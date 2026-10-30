// test/screens/elemento_historial_foto_test.dart
//
// Historial del elemento (CEO, octubre 2026): cada fila mostraba siempre el
// mismo icono genérico, aunque el evento tuviera su propia foto -- IosRow
// ya soportaba una miniatura en vez del icono (imageUrl, ver
// widgets/ios_list.dart, usada en otras listas), solo faltaba pasarle
// r.fotoUrl en esta.
//
// Regresión (CEO, octubre 2026): en cuanto un evento pasa a tener varias
// fotos, el campo antiguo fotoUrl se borra (ver RegistroService.
// agregarFotos) -- esta fila seguía leyendo r.fotoUrl directamente, así que
// el evento dejaba de mostrar foto en el Historial aunque tuviera 2+. Ahora
// lee r.fotos (fotoUrls si existen, si no cae a fotoUrl) y siempre muestra
// la primera que se subió. Usa FakeFirebaseFirestore, nada de Firebase real.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/elemento_detail_screen.dart';
import 'package:repara/services/documento_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/habitacion_service.dart';
import 'package:repara/services/pago_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';
import 'package:repara/widgets/ios_list.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

Future<void> _prepararConDosRegistros() async {
  final db = FakeFirebaseFirestore();
  await db.collection('casas').doc(_casa.id).collection('elementos').doc('e1').set({
    'nombre': 'Pérgolas',
  });
  final registros = db
      .collection('casas')
      .doc(_casa.id)
      .collection('elementos')
      .doc('e1')
      .collection('registros');
  await registros.doc('con-foto').set({
    'titulo': 'Instalación placa de metal',
    'tipo': 'instalacion',
    'esConProfesional': false,
    'estado': 'terminado',
    'elementoNombre': 'Pérgolas',
    'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
    'fotoUrl': 'https://example.com/foto.jpg',
  });
  await registros.doc('sin-foto').set({
    'titulo': 'Reforma/Mejora de Pérgolas',
    'tipo': 'reforma',
    'esConProfesional': true,
    'estado': 'enCurso',
    'elementoNombre': 'Pérgolas',
    'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
  });
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  HabitacionService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    HabitacionService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
  });

  testWidgets(
    'en el Historial, un evento con foto muestra su miniatura y uno sin foto sigue mostrando el icono',
    (tester) async {
      await _prepararConDosRegistros();

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const ElementoDetailScreen(casa: _casa, elementoId: 'e1')),
      );
      await tester.pumpAndSettle();
      // Sin red real en el entorno de test -- ver registro_foto_test.dart.
      tester.takeException();

      expect(find.text('Instalación placa de metal'), findsOneWidget);
      expect(find.text('Reforma/Mejora de Pérgolas'), findsOneWidget);

      final filaConFoto = tester.widget<IosRow>(
        find.ancestor(of: find.text('Instalación placa de metal'), matching: find.byType(IosRow)),
      );
      final filaSinFoto = tester.widget<IosRow>(
        find.ancestor(of: find.text('Reforma/Mejora de Pérgolas'), matching: find.byType(IosRow)),
      );
      expect(filaConFoto.imageUrl, 'https://example.com/foto.jpg');
      expect(filaSinFoto.imageUrl, isNull);
    },
  );

  testWidgets(
    'en el Historial, un evento con varias fotos (sin fotoUrl heredado) muestra la primera que se subió',
    (tester) async {
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
          .doc('con-varias-fotos')
          .set({
            'titulo': 'Placa de madera',
            'tipo': 'instalacion',
            'esConProfesional': false,
            'estado': 'terminado',
            'elementoNombre': 'Pérgolas',
            'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
            'fotoUrls': [
              'https://example.com/primera.jpg',
              'https://example.com/segunda.jpg',
            ],
          });
      ElementoService.debugFirestoreOverride = db;
      RegistroService.debugFirestoreOverride = db;
      HabitacionService.debugFirestoreOverride = db;
      DocumentoService.debugFirestoreOverride = db;
      PagoService.debugFirestoreOverride = db;

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const ElementoDetailScreen(casa: _casa, elementoId: 'e1')),
      );
      await tester.pumpAndSettle();
      tester.takeException(); // sin red real -- ver registro_foto_test.dart.

      final fila = tester.widget<IosRow>(
        find.ancestor(of: find.text('Placa de madera'), matching: find.byType(IosRow)),
      );
      expect(fila.imageUrl, 'https://example.com/primera.jpg');
    },
  );
}
