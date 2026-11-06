// test/screens/pro/registro_pro_detail_screen_test.dart
//
// Mismo fix que registro_detail_screen_test.dart (auditoría de estabilidad,
// noviembre 2026), aplicado al lado profesional: PresupuestosSection,
// CambiosAlcanceSection y PagosSection viven en el mismo ListView que varios
// bloques condicionales (estado, descripción, presupuesto acordado) -- sin
// Key explícita, que uno de esos bloques pase de ausente a presente
// mientras el profesional tiene la pantalla abierta desplaza esas tres
// secciones y Flutter puede perder sus datos, igual que en el lado de
// Hogar.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/screens/pro/registro_pro_detail_screen.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/cambio_alcance_service.dart';
import 'package:repara_core/documento_service.dart';
import 'package:repara_core/presupuesto_service.dart';
import 'package:repara_core/stream_sharing.dart';

const _casaId = 'casa-1';
const _elementoId = 'elem-1';
const _registroId = 'reg-1';

Future<FakeFirebaseFirestore> _sembrar() async {
  final db = FakeFirebaseFirestore();
  final ahora = DateTime.now();

  final registroRef = db
      .collection('casas')
      .doc(_casaId)
      .collection('elementos')
      .doc(_elementoId)
      .collection('registros')
      .doc(_registroId);
  await registroRef.set({
    'elementoNombre': 'Caldera',
    'tipo': 'reparacion',
    'esConProfesional': true,
    'titulo': 'Revisión de la caldera',
    'estado': 'enCurso',
    'fecha': Timestamp.fromDate(ahora),
    'profesionalUid': 'pro-1',
    'presupuesto': 500.0,
    'createdAt': Timestamp.fromDate(ahora),
  });

  await registroRef.collection('presupuestos').doc('p1').set({
    'numero': 1,
    'version': 1,
    'estado': 'aceptado',
    'lineas': [
      {'descripcion': 'Revisión', 'cantidad': 1, 'precioUnitario': 500.0},
    ],
    'subtotal': 413.22,
    'iva': 86.78,
    'total': 500.0,
    'fechaCreacion': Timestamp.fromDate(ahora),
  });

  return db;
}

void _conectarServicios(FakeFirebaseFirestore db) {
  RegistroService.debugFirestoreOverride = db;
  PresupuestoService.debugFirestoreOverride = db;
  CambioAlcanceService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
}

void _desconectarServicios() {
  RegistroService.debugFirestoreOverride = null;
  PresupuestoService.debugFirestoreOverride = null;
  CambioAlcanceService.debugFirestoreOverride = null;
  PagoService.debugFirestoreOverride = null;
  DocumentoService.debugFirestoreOverride = null;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));
  tearDown(() {
    _desconectarServicios();
    debugLimpiarCacheDeStreamsCompartidos();
  });

  testWidgets(
    'un cambio de forma del árbol (descripción null -> con valor) no vacía Presupuestos/Cambios/Pagos',
    (tester) async {
      final db = await _sembrar();
      _conectarServicios(db);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaDarkTheme(),
          home: const RegistroProDetailScreen(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final registroRef = db
          .collection('casas')
          .doc(_casaId)
          .collection('elementos')
          .doc(_elementoId)
          .collection('registros')
          .doc(_registroId);

      // Antes del arreglo, insertar `descripcion` (null -> con valor)
      // desplazaba PresupuestosSection/CambiosAlcanceSection/PagosSection
      // en el ListView; sin Key, Flutter podía perder sus suscripciones.
      await registroRef.update({'descripcion': 'Revisar termostato'});
      await tester.pumpAndSettle();

      expect(find.text('Revisar termostato'), findsOneWidget);
      expect(find.text('Presupuesto #1 · v1'), findsOneWidget);
      expect(find.text('Cambios del evento'), findsOneWidget);
      expect(find.text('Pagos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // El escenario de "oyente tardío" (trabajo_pro_agregado.dart ya
  // suscrito cuando se abre el detalle del mismo trabajo -- el bug real
  // de "se queda cargando para siempre" en producción, noviembre 2026) se
  // prueba en test/services/registro_service_late_subscriber_test.dart
  // contra el servicio real, sin widgets: un widget test equivalente
  // aquí se colgaba de forma consistente al desmontar el StreamBuilder,
  // pero aislado (confirmado con fake_cloud_firestore + RegistroService
  // directamente, sin flutter_test de por medio) el mecanismo funciona
  // correctamente y no cuelga -- es un artefacto del reloj simulado de
  // flutter_test al cerrar este Stream.multi concreto, no un fallo real.
}
