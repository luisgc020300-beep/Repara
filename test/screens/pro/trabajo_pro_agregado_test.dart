// test/screens/pro/trabajo_pro_agregado_test.dart
//
// TrabajosProAgregadosController es la base de datos del Dashboard y del
// tablero de Trabajos (ampliación REPARA Pro, Fase 1, noviembre 2026):
// combina, por cada trabajo del profesional, su Registro + sus pagos + si
// tiene un presupuesto esperando respuesta. Aquí se verifica esa
// combinación y las columnas derivadas, no la UI que las consume (eso lo
// cubren inicio_pro_tab_test.dart y trabajos_pro_tab_test.dart).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/pro/trabajo_pro_agregado.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara_core/cambio_alcance_service.dart';
import 'package:repara_core/presupuesto_service.dart';
import 'package:repara_core/profesional_service.dart';

const _uid = 'pro-1';

Future<FakeFirebaseFirestore> _seed() async {
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

  final r2 = db
      .collection('casas')
      .doc('c1')
      .collection('elementos')
      .doc('e1')
      .collection('registros')
      .doc('r2');
  await r2.set({
    'elementoNombre': 'Caldera',
    'tipo': 'sustitucion',
    'esConProfesional': true,
    'titulo': 'Cambio termostato',
    'estado': 'nuevo',
    'fecha': Timestamp.now(),
  });
  await r2.collection('presupuestos').doc('p1').set({
    'numero': 1,
    'version': 1,
    'estado': 'enviado',
    'lineas': [],
    'subtotal': 0,
    'iva': 0,
    'total': 120,
    'fechaCreacion': Timestamp.now(),
  });

  final r3 = db
      .collection('casas')
      .doc('c2')
      .collection('elementos')
      .doc('e2')
      .collection('registros')
      .doc('r3');
  await r3.set({
    'elementoNombre': 'Tejado',
    'tipo': 'reparacion',
    'esConProfesional': true,
    'titulo': 'Gotera',
    'estado': 'pendientePago',
    'fecha': Timestamp.now(),
    'presupuesto': 100,
  });
  await r3.collection('pagos').doc('pg1').set({
    'fecha': Timestamp.now(),
    'importe': 40,
  });

  return db;
}

void main() {
  tearDown(() {
    ProfesionalService.debugFirestoreOverride = null;
    ProfesionalService.debugUidOverride = null;
    RegistroService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
    PresupuestoService.debugFirestoreOverride = null;
    CambioAlcanceService.debugFirestoreOverride = null;
  });

  testWidgets(
    'agrega estado, pagos y presupuesto de cada trabajo del profesional',
    (tester) async {
      final db = await _seed();
      ProfesionalService.debugFirestoreOverride = db;
      ProfesionalService.debugUidOverride = _uid;
      RegistroService.debugFirestoreOverride = db;
      PagoService.debugFirestoreOverride = db;
      PresupuestoService.debugFirestoreOverride = db;
      CambioAlcanceService.debugFirestoreOverride = db;

      List<TrabajoProAgregado>? recibidos;
      await tester.pumpWidget(
        MaterialApp(
          home: TrabajosProAgregadosBuilder(
            builder: (context, trabajos, cargando) {
              recibidos = trabajos;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(recibidos, isNotNull);
      expect(recibidos!.length, 3);

      final r1 = recibidos!.firstWhere((t) => t.ref.registroId == 'r1');
      expect(
        r1.columna,
        ColumnaTableroPro.sinPresupuestar,
        reason: 'nuevo, sin presupuesto enviado todavía',
      );
      expect(r1.presupuestoEsperandoRespuesta, isFalse);

      final r2 = recibidos!.firstWhere((t) => t.ref.registroId == 'r2');
      expect(r2.presupuestoEsperandoRespuesta, isTrue);
      expect(r2.columna, ColumnaTableroPro.presupuestoEnviado);

      final r3 = recibidos!.firstWhere((t) => t.ref.registroId == 'r3');
      expect(r3.columna, ColumnaTableroPro.pendienteCobro);
      expect(r3.montoDebido, 100);
      expect(r3.totalPagado, 40);
      expect(r3.saldoPendiente, 60);
    },
  );

  testWidgets(
    'un trabajo que deja de estar en registrosProRefs se retira de la lista agregada',
    (tester) async {
      final db = await _seed();
      ProfesionalService.debugFirestoreOverride = db;
      ProfesionalService.debugUidOverride = _uid;
      RegistroService.debugFirestoreOverride = db;
      PagoService.debugFirestoreOverride = db;
      PresupuestoService.debugFirestoreOverride = db;
      CambioAlcanceService.debugFirestoreOverride = db;

      List<TrabajoProAgregado>? recibidos;
      await tester.pumpWidget(
        MaterialApp(
          home: TrabajosProAgregadosBuilder(
            builder: (context, trabajos, cargando) {
              recibidos = trabajos;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(recibidos!.length, 3);

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
      await tester.pumpAndSettle();

      expect(recibidos!.length, 1);
      expect(recibidos!.single.ref.registroId, 'r1');
    },
  );
}
