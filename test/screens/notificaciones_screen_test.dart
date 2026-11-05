// test/screens/notificaciones_screen_test.dart
//
// Centro de notificaciones (rediseño de avisos inteligentes, noviembre
// 2026): agrupación Hoy/Ayer/Anteriores y "Marcar todas como leídas" --
// antes era una única lista plana sin esa acción.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/screens/notificaciones_screen.dart';
import 'package:repara/services/notificacion_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _uid = 'owner-1';

Future<FakeFirebaseFirestore> _sembrar() async {
  final db = FakeFirebaseFirestore();
  final hoy = DateTime.now();
  final ayer = hoy.subtract(const Duration(days: 1));
  final haceUnaSemana = hoy.subtract(const Duration(days: 7));
  await db.collection('notificaciones').add({
    'uid': _uid, 'tipo': 'presupuesto_enviado', 'titulo': 'De hoy', 'cuerpo': 'c',
    'leida': false, 'createdAt': Timestamp.fromDate(hoy),
  });
  // 'pago_registrado' es un tipo "para profesional" (ver notificacion.dart)
  // -- se filtraría antes de agrupar porque este test abre la pantalla con
  // modoPro:false. Se usa un tipo de Hogar para que llegue a agruparse.
  await db.collection('notificaciones').add({
    'uid': _uid, 'tipo': 'cambio_alcance_solicitado', 'titulo': 'De ayer', 'cuerpo': 'c',
    'leida': false, 'createdAt': Timestamp.fromDate(ayer),
  });
  await db.collection('notificaciones').add({
    'uid': _uid, 'tipo': 'trabajo_finalizado', 'titulo': 'De hace una semana', 'cuerpo': 'c',
    'leida': true, 'createdAt': Timestamp.fromDate(haceUnaSemana),
  });
  return db;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    NotificacionService.debugFirestoreOverride = null;
    NotificacionService.debugUidOverride = null;
  });

  testWidgets('agrupa en Hoy/Ayer/Anteriores y muestra el contador de pendientes', (
    tester,
  ) async {
    final db = await _sembrar();
    NotificacionService.debugFirestoreOverride = db;
    NotificacionService.debugUidOverride = _uid;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildReparaLightTheme(),
        home: const NotificacionesScreen(modoPro: false),
      ),
    );
    await tester.pumpAndSettle();

    // IosSection pinta el header en mayúsculas (ver ios_list.dart).
    expect(find.text('HOY'), findsOneWidget);
    expect(find.text('AYER'), findsOneWidget);
    expect(find.text('ANTERIORES'), findsOneWidget);
    expect(find.text('De hoy'), findsOneWidget);
    expect(find.text('De ayer'), findsOneWidget);
    expect(find.text('De hace una semana'), findsOneWidget);
    expect(find.text('2 sin leer'), findsOneWidget);
  });

  testWidgets('"Marcar todas como leídas" marca todas y actualiza el contador', (
    tester,
  ) async {
    final db = await _sembrar();
    NotificacionService.debugFirestoreOverride = db;
    NotificacionService.debugUidOverride = _uid;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildReparaLightTheme(),
        home: const NotificacionesScreen(modoPro: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marcar todas como leídas'));
    await tester.pumpAndSettle();

    expect(find.text('Todo al día'), findsOneWidget);
    expect(find.text('Marcar todas como leídas'), findsNothing);
  });
}
