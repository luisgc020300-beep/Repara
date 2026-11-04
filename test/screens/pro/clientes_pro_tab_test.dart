// test/screens/pro/clientes_pro_tab_test.dart
//
// Clientes + ficha de cliente (ampliación REPARA Pro, Fase 2, noviembre
// 2026): un "cliente" agrupa los trabajos por casaId; la ficha nunca debe
// mostrar teléfono/email del propietario (decisión del CEO).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/pro/clientes_pro_tab.dart';
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
    'agrupa los trabajos por cliente y, al entrar, la ficha no muestra teléfono ni email',
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
            'casaId': 'c1',
            'elementoId': 'e1',
            'elementoNombre': 'Caldera',
            'registroId': 'r2',
            'registroTitulo': 'Cambio termostato',
            'casaNombre': 'Casa Norte',
          },
          {
            'casaId': 'c2',
            'elementoId': 'e2',
            'elementoNombre': 'Tejado',
            'registroId': 'r3',
            'registroTitulo': 'Gotera',
            'casaNombre': 'Casa Sur',
          },
        ],
      });

      Future<void> crear(
        String casaId,
        String elementoId,
        String registroId,
        Map<String, dynamic> datos,
      ) => db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .doc(registroId)
          .set(datos);

      await crear('c1', 'e1', 'r1', {
        'elementoNombre': 'Caldera',
        'tipo': 'reparacion',
        'esConProfesional': true,
        'titulo': 'Revisión caldera',
        'estado': 'nuevo',
        'fecha': Timestamp.now(),
      });
      await crear('c1', 'e1', 'r2', {
        'elementoNombre': 'Caldera',
        'tipo': 'reparacion',
        'esConProfesional': true,
        'titulo': 'Cambio termostato',
        'estado': 'terminado',
        'fecha': Timestamp.now(),
      });
      await crear('c2', 'e2', 'r3', {
        'elementoNombre': 'Tejado',
        'tipo': 'reparacion',
        'esConProfesional': true,
        'titulo': 'Gotera',
        'estado': 'enCurso',
        'fecha': Timestamp.now(),
      });

      _aplicarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ClientesProTab(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Casa Norte'), findsOneWidget);
      expect(find.text('Casa Sur'), findsOneWidget);
      expect(find.textContaining('2 trabajos'), findsOneWidget);
      expect(find.textContaining('1 trabajo ·'), findsOneWidget);

      await tester.tap(find.text('Casa Norte'));
      await tester.pumpAndSettle();

      expect(find.text('Revisión caldera'), findsOneWidget);
      expect(find.text('Cambio termostato'), findsOneWidget);
      // Nunca se pide ni se muestra un teléfono o email en esta ficha.
      expect(find.textContaining('@'), findsNothing);
      expect(find.byIcon(Icons.phone_outlined), findsNothing);
      expect(find.byIcon(Icons.email_outlined), findsNothing);
    },
  );
}
