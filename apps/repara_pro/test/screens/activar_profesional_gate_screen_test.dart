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

  testWidgets(
    'la puerta de activación ofrece cerrar sesión para no quedarse atrapado con la cuenta equivocada',
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

      expect(find.text('Cerrar sesión'), findsOneWidget);
    },
  );

  testWidgets(
    'pulsar "Cerrar sesión" no rompe la pantalla si falla, y el botón queda '
    'listo para reintentar',
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

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      // Este entorno de test nunca llama a Firebase.initializeApp() (igual
      // que el resto de la suite -- ver notificacion_router_pro_test.dart),
      // así que tanto FcmService.olvidarEsteDispositivo() (que traga su
      // propio error, ver fcm_service.dart) como FirebaseAuth.instance.
      // signOut() (que no lo traga) fallan aquí con "[core/no-app]" --
      // nunca se llega a esa segunda llamada sin haber pasado antes por
      // FcmService.olvidarEsteDispositivo(), porque ese await es secuencial
      // y previo, así que el orden queda probado por construcción. Lo que
      // SÍ puede probarse de verdad sin un Firebase real es que el fallo se
      // gestiona con gracia -- sin romper la pantalla -- y que el botón
      // vuelve a su estado normal, listo para reintentar.
      final boton = tester.widget<TextButton>(find.byType(TextButton));
      expect(
        boton.onPressed,
        isNotNull,
        reason: 'debe quedar re-habilitado tras el fallo',
      );
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(
        find.textContaining('No se pudo cerrar la sesión'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'pulsar "Cerrar sesión" dos veces seguidas sin esperar no provoca un segundo intento simultáneo',
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

      // Dos toques consecutivos sin pumpAndSettle entre medias -- si el
      // guard "if (_cerrandoSesion) return;" no funcionara, cualquier
      // reentrada se vería como una excepción no capturada o un segundo
      // SnackBar; pumpAndSettle al final no debe lanzar nada.
      await tester.tap(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(
        find.textContaining('No se pudo cerrar la sesión'),
        findsOneWidget,
      );
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
