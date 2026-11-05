// test/screens/home_tab_solicitudes_profesionales_test.dart
//
// Fase 2 (noviembre 2026): "Solicitudes de profesionales" en Inicio --
// espejo de "Invitaciones pendientes" en inicio_pro_tab.dart, pero solo
// visible cuando hay alguna (nunca un bloque permanente de "no tienes
// solicitudes" en Inicio). Solo se prueba aquí lo que es Firestore puro
// (aparece/desaparece, muestra los datos correctos) -- aceptar/rechazar
// pasan por Cloud Functions (httpsCallable), igual que el resto de
// invitaciones de la app, sin test Dart dedicado (ver
// invitacion_hogar_service_test.dart).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/home_tab.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/habitacion_service.dart';
import 'package:repara/services/invitacion_hogar_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';
import 'package:repara_core/documento_service.dart';
import 'package:repara_core/notificacion_service.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

void _conectarServicios(FakeFirebaseFirestore db) {
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  HabitacionService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  NotificacionService.debugFirestoreOverride = db;
  NotificacionService.debugUidOverride = 'u1';
  InvitacionHogarService.debugFirestoreOverride = db;
  InvitacionHogarService.debugUidOverride = 'u1';
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    HabitacionService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    NotificacionService.debugFirestoreOverride = null;
    NotificacionService.debugUidOverride = null;
    InvitacionHogarService.debugFirestoreOverride = null;
    InvitacionHogarService.debugUidOverride = null;
  });

  testWidgets(
    'sin ninguna solicitud pendiente, la sección no aparece',
    (tester) async {
      final db = FakeFirebaseFirestore();
      _conectarServicios(db);

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const HomeTab(casa: _casa)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solicitudes de profesionales'), findsNothing);
    },
  );

  testWidgets(
    'con una solicitud pendiente, muestra el título del trabajo y el nombre del profesional',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('invitacionesHogar').add({
        'propietarioUid': 'u1',
        'profesionalUid': 'pro-1',
        'profesionalNombre': 'Fontanería Pérez',
        'titulo': 'Caldera no calienta',
        'estado': 'pendiente',
      });
      _conectarServicios(db);

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const HomeTab(casa: _casa)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solicitudes de profesionales'), findsOneWidget);
      expect(find.text('Caldera no calienta'), findsOneWidget);
      expect(find.textContaining('Fontanería Pérez'), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);
    },
  );

  testWidgets(
    'una solicitud ya aceptada o de otro propietario no se muestra',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('invitacionesHogar').add({
        'propietarioUid': 'u1', 'profesionalUid': 'pro-1', 'titulo': 'Ya aceptada', 'estado': 'aceptada',
      });
      await db.collection('invitacionesHogar').add({
        'propietarioUid': 'otro-propietario', 'profesionalUid': 'pro-1', 'titulo': 'De otro', 'estado': 'pendiente',
      });
      _conectarServicios(db);

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const HomeTab(casa: _casa)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solicitudes de profesionales'), findsNothing);
    },
  );
}
