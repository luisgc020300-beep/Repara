// test/screens/expediente_vivienda_pdf_test.dart
//
// "Generar dossier PDF de mi vivienda" (CEO, octubre 2026) -- antes esta
// pantalla solo tenía "Compartir resumen" (texto). Prueba que el nuevo
// botón aparece junto al de compartir, que al tocarlo se ve primero la
// hoja explicativa con el aviso de privacidad (pedido explícito del
// encargo, sección 8: "pulsa y ve una explicación breve de qué
// información puede incluir" + sección 6: avisar de que puede llevar
// datos personales/económicos), y que la generación en sí queda scopeada
// a la casa que se le pasa a la pantalla -- nunca a otra.
//
// NO PROBADO AQUÍ (limitación real, no simulada): completar de verdad la
// generación invoca Printing.layoutPdf, que necesita un canal de
// plataforma que no existe en este entorno de test -- mismo criterio de
// honestidad que el resto de la suite. El contenido real del PDF
// (ExpedienteViviendaPdf.construirBytes) se prueba aparte, sin necesidad
// de Printing, en expediente_vivienda_dossier_pdf_test.dart. Usa
// FakeFirebaseFirestore, nada de Firebase real.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/expediente_vivienda_screen.dart';
import 'package:repara/services/cambio_alcance_service.dart';
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

void _activarOverrides(FakeFirebaseFirestore db) {
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  HabitacionService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  CambioAlcanceService.debugFirestoreOverride = db;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    HabitacionService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
    CambioAlcanceService.debugFirestoreOverride = null;
  });

  testWidgets(
    'ofrece "Generar dossier PDF" junto a "Compartir resumen", incluso sin elementos todavía',
    (tester) async {
      final db = FakeFirebaseFirestore();
      _activarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ExpedienteViviendaScreen(casa: _casa),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compartir resumen'), findsOneWidget);
      expect(find.text('Generar dossier PDF'), findsOneWidget);
    },
  );

  testWidgets(
    'con elementos y eventos reales, sigue ofreciendo ambos botones',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('casas').doc(_casa.id).collection('elementos').doc('e1').set({
        'nombre': 'Caldera',
        'coste': 800,
        'garantiaHasta': Timestamp.fromDate(DateTime(2030, 1, 1)),
      });
      await db
          .collection('casas')
          .doc(_casa.id)
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .doc('r1')
          .set({
            'titulo': 'Instalación',
            'tipo': 'instalacion',
            'esConProfesional': false,
            'estado': 'terminado',
            'elementoNombre': 'Caldera',
            'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
            'coste': 800,
          });
      _activarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ExpedienteViviendaScreen(casa: _casa),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compartir resumen'), findsOneWidget);
      expect(find.text('Generar dossier PDF'), findsOneWidget);
    },
  );

  testWidgets(
    'tocar "Generar dossier PDF" muestra antes una hoja explicativa con aviso de privacidad',
    (tester) async {
      final db = FakeFirebaseFirestore();
      _activarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ExpedienteViviendaScreen(casa: _casa),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generar dossier PDF'));
      await tester.pumpAndSettle();

      expect(find.text('Generar dossier PDF de mi vivienda'), findsOneWidget);
      expect(
        find.textContaining('revísalo antes de compartirlo con otra persona'),
        findsOneWidget,
      );
      expect(find.text('Generar PDF'), findsOneWidget);
    },
  );

  testWidgets(
    'el dossier de la Casa A nunca muestra elementos de la Casa B (aislamiento entre viviendas)',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('casas').doc('c1').collection('elementos').doc('ea').set({
        'nombre': 'Caldera de la Casa A',
      });
      await db.collection('casas').doc('otra-casa').collection('elementos').doc('eb').set({
        'nombre': 'Caldera de la Casa B',
      });
      _activarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ExpedienteViviendaScreen(casa: _casa),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Caldera de la Casa A'), findsOneWidget);
      expect(find.text('Caldera de la Casa B'), findsNothing);
    },
  );
}
