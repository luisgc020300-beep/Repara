// test/services/notificacion_router_test.dart
//
// Corrige el problema #1 de la auditoría de comunicación cruzada (noviembre
// 2026): tocar la notificación "tu cliente ha rechazado vincular tu
// trabajo" no hacía nada -- el guard `if (casaId == null...) return` cortaba
// el flujo antes de llegar siquiera a mirar el tipo. Ahora
// invitacion_hogar_rechazada se gestiona ANTES de ese guard (su `extra` no
// trae casaId/elementoId/registroId porque el vínculo nunca llegó a
// crearse) y lleva al profesional a la pestaña Trabajos del shell Pro.
import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/elemento_detail_screen.dart';
import 'package:repara/screens/pro/repara_pro_shell_screen.dart';
import 'package:repara/services/casa_service.dart';
import 'package:repara/services/cliente_profesional_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/habitacion_service.dart';
import 'package:repara/services/notificacion_router.dart';
import 'package:repara/services/trabajo_profesional_service.dart';
import 'package:repara_core/cambio_alcance_service.dart';
import 'package:repara_core/cita_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/documento_service.dart';
import 'package:repara_core/historial_service.dart';
import 'package:repara_core/invitacion_service.dart';
import 'package:repara_core/notificacion_service.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/presupuesto_service.dart';
import 'package:repara_core/profesional_service.dart';
import 'package:repara_core/registro_service.dart';

const _uid = 'pro-1';

void _limpiarOverrides() {
  CasaService.debugFirestoreOverride = null;
  CasaService.debugUidOverride = null;
  ElementoService.debugFirestoreOverride = null;
  HabitacionService.debugFirestoreOverride = null;
  DocumentoService.debugFirestoreOverride = null;
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
  TrabajoProfesionalService.debugFirestoreOverride = null;
  TrabajoProfesionalService.debugUidOverride = null;
  ClienteProfesionalService.debugFirestoreOverride = null;
  ClienteProfesionalService.debugUidOverride = null;
  CitaService.debugFirestoreOverride = null;
  CitaService.debugUidOverride = null;
}

void _aplicarOverrides(FakeFirebaseFirestore db) {
  CasaService.debugFirestoreOverride = db;
  CasaService.debugUidOverride = _uid;
  ElementoService.debugFirestoreOverride = db;
  HabitacionService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
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
  TrabajoProfesionalService.debugFirestoreOverride = db;
  TrabajoProfesionalService.debugUidOverride = _uid;
  ClienteProfesionalService.debugFirestoreOverride = db;
  ClienteProfesionalService.debugUidOverride = _uid;
  CitaService.debugFirestoreOverride = db;
  CitaService.debugUidOverride = _uid;
}

void main() {
  tearDown(_limpiarOverrides);

  testWidgets(
    'invitacion_hogar_rechazada lleva al profesional a la pestaña Trabajos del shell Pro',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(_uid).set({'registrosProRefs': []});
      _aplicarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => abrirDestinoNotificacion(
                context,
                tipo: 'invitacion_hogar_rechazada',
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      final shell = tester.widget<ReparaProShellScreen>(
        find.byType(ReparaProShellScreen),
      );
      expect(shell.initialIndex, 1);
      // La pestaña Trabajos está activa -- NavigationBar en el índice 1.
      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.currentIndex, 1);
    },
  );

  testWidgets(
    'invitacion_hogar_recibida sigue volviendo a la pantalla raíz, sin abrir el shell Pro',
    (tester) async {
      var vecesConstruido = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: Builder(
            builder: (outerContext) {
              vecesConstruido++;
              return Navigator(
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (innerContext) => ElevatedButton(
                    onPressed: () => abrirDestinoNotificacion(
                      innerContext,
                      tipo: 'invitacion_hogar_recibida',
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // No se ha abierto ningún shell Pro -- el guard anterior a este tipo
      // sigue intacto.
      expect(find.byType(ReparaProShellScreen), findsNothing);
      expect(vecesConstruido, 1);
    },
  );

  testWidgets(
    'una notificación de elemento sin registroId (garantía/mantenimiento/archivado) abre la ficha del elemento',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('casas').doc('casa-1').set({
        'nombre': 'Mi casa',
        'members': [_uid],
      });
      await db
          .collection('casas')
          .doc('casa-1')
          .collection('elementos')
          .doc('elemento-1')
          .set({'nombre': 'Caldera'});
      _aplicarOverrides(db);

      // Dos trampas de temporización, ninguna de las cuales admite
      // pumpAndSettle(): 1) esta rama tiene un hueco async real
      // (CasaService.streamCasa(...).first) ANTES del Navigator.push, y nada
      // reconstruye el árbol mientras se espera -- pumpAndSettle puede dar
      // por "asentado" el árbol antes de que ese hueco termine. 2) el propio
      // Future que devuelve Navigator.push NUNCA se completa aquí (solo lo
      // hace cuando la ruta se cierra, y este test no la cierra) -- así que
      // no se puede esperar ese Future directamente (cuelga para siempre, ni
      // siquiera pump()/pumpAndSettle() lo libran). La solución es no
      // esperar la llamada en sí (se deja "en vuelo", igual que hace
      // onPressed con un tap real) y bombear un número acotado de frames
      // para dejarla progresar.
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      unawaited(abrirDestinoNotificacion(
        capturedContext,
        tipo: 'garantia_proxima_vencer',
        casaId: 'casa-1',
        elementoId: 'elemento-1',
      ));
      // El Future de CasaService.streamCasa(...).first no se resuelve con
      // pump()/pumpAndSettle() normales en este caso (no está atado a
      // ningún widget que fuerce un frame mientras se espera) -- runAsync()
      // deja progresar la asincronía real antes de pedir el frame final.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ElementoDetailScreen), findsOneWidget);
      final pantalla = tester.widget<ElementoDetailScreen>(
        find.byType(ElementoDetailScreen),
      );
      expect(pantalla.elementoId, 'elemento-1');
    },
  );
}
