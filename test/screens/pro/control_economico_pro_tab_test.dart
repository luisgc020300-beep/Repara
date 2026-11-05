// test/screens/pro/control_economico_pro_tab_test.dart
//
// Control económico (ampliación REPARA Pro, Fase 2, noviembre 2026): el
// desglose NO debe mezclar conceptos -- presupuestado, cambios aprobados,
// importe acordado, cobrado y pendiente son cinco números distintos, cada
// uno calculado con la fórmula verificada contra functions/index.js (ver
// el plan de esta fase).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/pro/control_economico_pro_tab.dart';
import 'package:repara/services/pago_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';
import 'package:repara_core/cambio_alcance_service.dart';
import 'package:repara_core/presupuesto_service.dart';
import 'package:repara_core/profesional_service.dart';

const _uid = 'pro-1';

void _limpiarOverrides() {
  ProfesionalService.debugFirestoreOverride = null;
  ProfesionalService.debugUidOverride = null;
  RegistroService.debugFirestoreOverride = null;
  PagoService.debugFirestoreOverride = null;
  PresupuestoService.debugFirestoreOverride = null;
  CambioAlcanceService.debugFirestoreOverride = null;
}

void _aplicarOverrides(FakeFirebaseFirestore db) {
  ProfesionalService.debugFirestoreOverride = db;
  ProfesionalService.debugUidOverride = _uid;
  RegistroService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  PresupuestoService.debugFirestoreOverride = db;
  CambioAlcanceService.debugFirestoreOverride = db;
}

void main() {
  tearDown(_limpiarOverrides);

  testWidgets(
    'presupuesto aceptado (200€) + cambio de alcance aprobado (50€) + pago de 100€ -> desglose correcto, nunca mezclado',
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
        'estado': 'presupuestado',
        'fecha': Timestamp.now(),
        // El servidor ya suma aceptado + cambios aprobados en este campo
        // (responderPresupuesto + responderCambioAlcance) -- se seedea tal
        // cual lo dejaría la Cloud Function real: 200 + 50 = 250.
        'presupuesto': 250,
      });
      await r1.collection('presupuestos').doc('p1').set({
        'numero': 1,
        'version': 1,
        'estado': 'aceptado',
        'lineas': [],
        'subtotal': 200,
        'iva': 0,
        'total': 200,
        'fechaCreacion': Timestamp.now(),
      });
      await r1.collection('cambiosAlcance').doc('ca1').set({
        'titulo': 'Pieza adicional',
        'estado': 'aprobado',
        'importeAdicional': 50,
        'createdAt': Timestamp.now(),
      });
      await r1.collection('pagos').doc('pg1').set({
        'fecha': Timestamp.now(),
        'importe': 100,
      });

      _aplicarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ControlEconomicoProTab(),
        ),
      );
      await tester.pumpAndSettle();

      // "200.00 €" también aparece en la sección Presupuestos (el mismo
      // presupuesto aceptado listado ahí) y "150.00 €" también en "Trabajos
      // con saldo pendiente" -- findsWidgets en esos dos, no
      // findsOneWidget, porque es el mismo número mostrado en dos sitios
      // legítimos, no una duplicación por error.
      expect(
        find.text('200.00 €'),
        findsWidgets,
        reason:
            'Presupuestado = total del presupuesto aceptado, no el acordado',
      );
      expect(
        find.text('50.00 €'),
        findsOneWidget,
        reason: 'Cambios de alcance aprobados, por separado',
      );
      expect(
        find.text('250.00 €'),
        findsOneWidget,
        reason: 'Importe acordado = registro.presupuesto (200 + 50)',
      );
      expect(
        find.text('100.00 €'),
        findsOneWidget,
        reason: 'Total cobrado = solo los pagos reales',
      );
      expect(
        find.text('150.00 €'),
        findsWidgets,
        reason: 'Pendiente de cobro = 250 - 100',
      );
    },
  );

  testWidgets(
    'sin ningún trabajo, los indicadores salen en 0 y no se muestran listas fantasma',
    (tester) async {
      // La pantalla es larga (KPIs + gráficos + varias secciones) -- un
      // surface de test más alto evita que las últimas secciones queden
      // fuera del viewport "visible" para los finders (mismo fix que en
      // trabajos_pro_tab_test.dart, pero en vertical).
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(_uid).set({'registrosProRefs': []});
      _aplicarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ControlEconomicoProTab(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nada pendiente de cobro ahora mismo.'), findsOneWidget);
      expect(
        find.text('Todavía no has creado ningún presupuesto.'),
        findsOneWidget,
      );
    },
  );
}
