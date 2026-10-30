// test/screens/registro_historial_y_pdf_test.dart
//
// Dos pedidos del CEO en la misma pasada (octubre 2026), ambos reutilizando
// piezas que ya existían:
//
// 1. El historial cronológico vertical ("Historial de la reparación",
//    _SeccionHistorial) solo aparecía en un registro CON profesional. Es un
//    widget genérico (casa/elementoId/registro) y los eventos que muestra
//    (cierre del registro, pagos) ya se registran en Firestore para
//    cualquier registro -- se añade también al cuerpo simple, sin tocar el
//    widget en sí.
// 2. "Descargar PDF" solo existía en el registro simple (RegistroSimpleAcciones,
//    RegistroResumenPdf). El registro con profesional ahora también lo
//    ofrece en su barra inferior, junto a "Compartir resumen" -- mismo
//    RegistroResumenPdf, que ya era genérico (usa registro.presupuesto o
//    registro.coste según toque, ver montoDebidoRegistro).
//
// Usa FakeFirebaseFirestore, nada de Firebase real.
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

Future<void> _prepararElemento(FakeFirebaseFirestore db) async {
  await db.collection('casas').doc(_casa.id).collection('elementos').doc('e1').set({
    'nombre': 'Pérgolas',
  });
}

void _activarOverrides(FakeFirebaseFirestore db) {
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
    'un registro SIMPLE terminado muestra "Historial de la reparación" con "Trabajo finalizado"',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await _prepararElemento(db);
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
            'coste': 600,
          });
      _activarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Historial de la reparación'), findsOneWidget);
      expect(find.text('Trabajo finalizado'), findsOneWidget);
    },
  );

  testWidgets(
    'un registro CON profesional, terminado, ofrece "Descargar PDF" junto a "Compartir resumen"',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await _prepararElemento(db);
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
            'presupuesto': 500,
          });
      _activarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compartir resumen'), findsOneWidget);
      expect(find.text('Descargar PDF'), findsOneWidget);
    },
  );

  testWidgets(
    'un registro CON profesional en curso (sin estado controlado) también ofrece "Descargar PDF" junto a "Finalizar"',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await _prepararElemento(db);
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
            'estado': 'enCurso',
            'elementoNombre': 'Pérgolas',
            'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
            'presupuesto': 500,
          });
      _activarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(casa: _casa, elementoId: 'e1', registroId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Finalizar'), findsOneWidget);
      expect(find.text('Descargar PDF'), findsOneWidget);
    },
  );
}
