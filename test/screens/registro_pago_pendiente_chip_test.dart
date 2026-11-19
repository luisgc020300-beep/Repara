// test/screens/registro_pago_pendiente_chip_test.dart
//
// "Terminado" exige trabajo Y pago (CEO, octubre 2026): un registro en
// pendientePago debe mostrarse como tal en la cabecera (EstadoRegistroChip)
// con un aviso explicando qué falta, y sin el botón "Finalizar" de un
// registro con profesional (ya no hay nada que finalizar del lado del
// trabajo -- solo falta el pago, que se gestiona desde Pagos). Usa
// FakeFirebaseFirestore, nada de Firebase real.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/registro_detail_screen.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/documento_service.dart';
import 'package:repara_core/historial_service.dart';
import 'package:repara_core/invitacion_service.dart';
import 'package:repara_core/presupuesto_service.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

Future<void> _prepararRegistroPendientePago() async {
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
        'estado': 'pendientePago',
        'elementoNombre': 'Pérgolas',
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
        'coste': 2000,
        'profesionalNombre': 'Metalistero',
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
    InvitacionService.debugFirestoreOverride = null;
    PresupuestoService.debugFirestoreOverride = null;
  });

  testWidgets(
    'un registro simple en pago pendiente muestra el chip y el aviso correctos',
    (tester) async {
      await _prepararRegistroPendientePago();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PAGO PENDIENTE'), findsOneWidget); // EstadoRegistroChip, en mayúsculas
      expect(
        find.textContaining('El trabajo está hecho, pero todavía falta cobrarlo'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'un registro con profesional en pago pendiente no ofrece "Finalizar" -- solo "Compartir resumen"',
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
          .doc('r1')
          .set({
            'titulo': 'Reforma de pérgola',
            'tipo': 'reforma',
            'esConProfesional': true,
            'estado': 'pendientePago',
            'elementoNombre': 'Pérgolas',
            'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
            'presupuesto': 500,
          });
      ElementoService.debugFirestoreOverride = db;
      RegistroService.debugFirestoreOverride = db;
      PagoService.debugFirestoreOverride = db;
      DocumentoService.debugFirestoreOverride = db;
      HistorialService.debugFirestoreOverride = db;
      InvitacionService.debugFirestoreOverride = db;
      // PresupuestosSection vive en _ResumenTab (registro_detail_screen.dart)
      // -- antes de que "Compartir resumen" se moviera al final del scroll
      // (CEO, noviembre 2026), nunca llegaba a construirse en este test sin
      // hacer scroll, así que esta carencia pasaba desapercibida.
      PresupuestoService.debugFirestoreOverride = db;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PAGO PENDIENTE'), findsOneWidget);
      expect(
        find.textContaining('El trabajo está hecho, pero todavía falta cobrarlo'),
        findsOneWidget,
      );
      expect(find.text('Finalizar'), findsNothing);
      // "Compartir resumen" ya no es una barra fija: vive al final del
      // scroll del Resumen (CEO, noviembre 2026: "que no quede fija abajo
      // tapando cosas").
      await tester.scrollUntilVisible(
        find.text('Compartir resumen'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('tab-resumen')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Compartir resumen'), findsOneWidget);
    },
  );
}
