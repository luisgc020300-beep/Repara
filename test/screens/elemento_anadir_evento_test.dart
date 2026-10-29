// test/screens/elemento_anadir_evento_test.dart
//
// "+ Añadir evento" (CEO, octubre 2026): dentro de un elemento ya
// existente solo se podía crear un evento a mano -- iniciarNuevoDocumento()
// ya sabía crear el registro fundacional de un elemento concreto a partir
// de un documento escaneado (ver nuevo_documento_flow.dart), pero nada lo
// ofrecía desde aquí. Ahora el botón abre a elegir entre las dos vías,
// igual que el "+" global de Inicio (menu_anadir.dart). Usa
// FakeFirebaseFirestore, nada de Firebase real; no se llega a tocar ningún
// plugin nativo de cámara/galería -- solo se comprueba que el selector se
// abre.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/elemento_detail_screen.dart';
import 'package:repara/services/documento_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/habitacion_service.dart';
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

Future<FakeFirebaseFirestore> _prepararConElemento() async {
  final db = FakeFirebaseFirestore();
  await db
      .collection('casas')
      .doc(_casa.id)
      .collection('elementos')
      .doc('e1')
      .set({'nombre': 'Pérgolas'});
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  HabitacionService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  return db;
}

void main() {
  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    HabitacionService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
  });

  testWidgets(
    'tocar "+ Añadir evento" ofrece elegir entre escanear un documento o rellenarlo a mano',
    (tester) async {
      await _prepararConElemento();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ElementoDetailScreen(casa: _casa, elementoId: 'e1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Añadir evento'));
      await tester.pumpAndSettle();

      expect(find.text('Escanear factura o documento'), findsOneWidget);
      expect(find.text('Añadir evento a mano'), findsOneWidget);
    },
  );

  testWidgets(
    '"Añadir evento a mano" sigue abriendo el formulario manual de siempre',
    (tester) async {
      await _prepararConElemento();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ElementoDetailScreen(casa: _casa, elementoId: 'e1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Añadir evento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir evento a mano'));
      await tester.pumpAndSettle();

      expect(find.text('Guardar'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Título (p.ej. Reparación de fuga)'), findsOneWidget);
    },
  );

  testWidgets(
    '"Escanear factura o documento" abre el selector de foto/galería/archivo',
    (tester) async {
      await _prepararConElemento();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ElementoDetailScreen(casa: _casa, elementoId: 'e1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Añadir evento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escanear factura o documento'));
      await tester.pumpAndSettle();

      expect(find.text('Hacer una foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
    },
  );
}
