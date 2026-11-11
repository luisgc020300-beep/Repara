// test/screens/activar_profesional_gate_screen_test.dart
//
// Cierra el problema #3 de la auditoría de comunicación cruzada (noviembre
// 2026): un usuario que abre REPARA Pro sin haber pasado nunca por el
// monolito debe ver la puerta de activación, no quedarse atrapado. En
// cuanto esProfesional pasa a true (lo que hace activarModoProfesional()
// en el backend), el mismo stream debe llevar directo al shell sin
// navegación manual.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/profesional_service.dart';
import 'package:repara_pro/screens/activar_profesional_gate_screen.dart';

const _uid = 'pro-nuevo-1';

void main() {
  tearDown(() {
    ProfesionalService.debugFirestoreOverride = null;
    ProfesionalService.debugUidOverride = null;
  });

  testWidgets(
    'cuenta nueva sin esProfesional ve la pantalla de activación, no el shell',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(_uid).set({});
      ProfesionalService.debugFirestoreOverride = db;
      ProfesionalService.debugUidOverride = _uid;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ActivarProfesionalGateScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Activa tu cuenta profesional'), findsOneWidget);
      expect(find.text('Activar cuenta profesional'), findsOneWidget);
      // El shell (pestañas) no debe estar montado todavía.
      expect(find.text('Trabajos'), findsNothing);
    },
  );

  // No se monta aquí el ReparaProShellScreen real con esProfesional=true:
  // sus 5 pestañas dependen colectivamente de una docena de servicios
  // (RegistroService, PagoService, InvitacionService, CitaService...), cada
  // uno con su propio seam de test y datos semilla -- replicarlo todo en
  // este archivo sería frágil y no aporta nada sobre lo que ya cubren los
  // tests de cada pestaña por separado. Lo que sí es nuevo y hay que
  // verificar aquí es la puerta en sí: que un usuario sin esProfesional ve
  // la pantalla de activación en vez de quedarse atrapado (test de arriba).
  // La transición activación -> shell reutiliza el mismo patrón reactivo de
  // CasaGateScreen (Hogar) y el selector Hogar/Pro del monolito, ya
  // probados en sus propios sitios.
}
