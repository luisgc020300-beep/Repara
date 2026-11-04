// test/screens/pro/inicio_pro_tab_test.dart
//
// Dashboard profesional (ampliación REPARA Pro, Fase 1, noviembre 2026):
// el estado vacío no debe mostrar listas fantasma, y con datos reales los
// KPIs/"Necesita tu atención" deben reflejar lo que hay de verdad.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/pro/inicio_pro_tab.dart';
import 'package:repara/services/historial_service.dart';
import 'package:repara/services/invitacion_service.dart';
import 'package:repara/services/notificacion_service.dart';
import 'package:repara/services/cambio_alcance_service.dart';
import 'package:repara/services/pago_service.dart';
import 'package:repara/services/presupuesto_service.dart';
import 'package:repara/services/profesional_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _uid = 'pro-1';

void _limpiarOverrides() {
  ProfesionalService.debugFirestoreOverride = null;
  ProfesionalService.debugUidOverride = null;
  RegistroService.debugFirestoreOverride = null;
  PagoService.debugFirestoreOverride = null;
  PresupuestoService.debugFirestoreOverride = null;
  CambioAlcanceService.debugFirestoreOverride = null;
  InvitacionService.debugFirestoreOverride = null;
  InvitacionService.debugUidOverride = null;
  HistorialService.debugFirestoreOverride = null;
  NotificacionService.debugFirestoreOverride = null;
  NotificacionService.debugUidOverride = null;
}

void _aplicarOverrides(FakeFirebaseFirestore db) {
  ProfesionalService.debugFirestoreOverride = db;
  ProfesionalService.debugUidOverride = _uid;
  RegistroService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  PresupuestoService.debugFirestoreOverride = db;
  CambioAlcanceService.debugFirestoreOverride = db;
  InvitacionService.debugFirestoreOverride = db;
  InvitacionService.debugUidOverride = _uid;
  HistorialService.debugFirestoreOverride = db;
  NotificacionService.debugFirestoreOverride = db;
  NotificacionService.debugUidOverride = _uid;
}

void main() {
  tearDown(_limpiarOverrides);

  testWidgets(
    'sin trabajos ni invitaciones, el Dashboard muestra los estados vacíos reales',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(_uid).set({'registrosProRefs': []});
      _aplicarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const InicioProTab()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tienes invitaciones nuevas.'), findsOneWidget);
      expect(
        find.text('Nada pendiente de tu atención ahora mismo.'),
        findsOneWidget,
      );
      expect(find.text('Todavía no hay actividad registrada.'), findsOneWidget);
      expect(
        find.textContaining('presupuestos esperando respuesta'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'un presupuesto enviado y un trabajo con saldo pendiente aparecen en los KPIs y en "Necesita tu atención"',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(_uid).set({
        'registrosProRefs': [
          {
            'casaId': 'c1',
            'elementoId': 'e1',
            'elementoNombre': 'Caldera',
            'registroId': 'r1',
            'registroTitulo': 'Revisión caldera',
            'casaNombre': 'Casa Norte',
          },
          {
            'casaId': 'c2',
            'elementoId': 'e2',
            'elementoNombre': 'Tejado',
            'registroId': 'r2',
            'registroTitulo': 'Gotera',
            'casaNombre': 'Casa Sur',
          },
        ],
      });

      final r1 = db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .doc('r1');
      await r1.set({
        'elementoNombre': 'Caldera',
        'tipo': 'reparacion',
        'esConProfesional': true,
        'titulo': 'Revisión caldera',
        'estado': 'nuevo',
        'fecha': Timestamp.now(),
      });
      await r1.collection('presupuestos').doc('p1').set({
        'numero': 1,
        'version': 1,
        'estado': 'enviado',
        'lineas': [],
        'subtotal': 0,
        'iva': 0,
        'total': 150,
        'fechaCreacion': Timestamp.now(),
      });

      final r2 = db
          .collection('casas')
          .doc('c2')
          .collection('elementos')
          .doc('e2')
          .collection('registros')
          .doc('r2');
      await r2.set({
        'elementoNombre': 'Tejado',
        'tipo': 'reparacion',
        'esConProfesional': true,
        'titulo': 'Gotera',
        'estado': 'pendientePago',
        'fecha': Timestamp.now(),
        'presupuesto': 200,
      });
      await r2.collection('pagos').doc('pg1').set({
        'fecha': Timestamp.now(),
        'importe': 80,
      });

      _aplicarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const InicioProTab()),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('presupuesto esperando respuesta'),
        findsOneWidget,
      );
      expect(find.text('Revisión caldera'), findsOneWidget);
      expect(find.text('Gotera'), findsOneWidget);
      expect(
        find.textContaining('Pendiente de cobro -- 120.00 €'),
        findsOneWidget,
      );
    },
  );
}
