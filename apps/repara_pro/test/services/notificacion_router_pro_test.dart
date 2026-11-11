// test/services/notificacion_router_pro_test.dart
//
// Corrige el problema #1 de la auditoría de comunicación cruzada (noviembre
// 2026): tocar la notificación "tu cliente ha rechazado vincular tu
// trabajo" no hacía nada -- el guard `if (casaId == null...) return` cortaba
// el flujo antes de llegar siquiera a mirar el tipo. Ahora
// invitacion_hogar_rechazada se gestiona ANTES de ese guard (su `extra` no
// trae casaId/elementoId/registroId porque el vínculo nunca llegó a
// crearse) y lleva al profesional a la pestaña Trabajos del shell --
// reemplazando la pila de navegación (pushAndRemoveUntil), ya que aquí el
// shell es la app entera, no una pantalla a la que se entra.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/cambio_alcance_service.dart';
import 'package:repara_core/cita_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/historial_service.dart';
import 'package:repara_core/invitacion_service.dart';
import 'package:repara_core/notificacion_service.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/presupuesto_service.dart';
import 'package:repara_core/profesional_service.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_pro/screens/repara_pro_shell_screen.dart';
import 'package:repara_pro/services/cliente_profesional_service.dart';
import 'package:repara_pro/services/notificacion_router_pro.dart';
import 'package:repara_pro/services/trabajo_profesional_service.dart';

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
  TrabajoProfesionalService.debugFirestoreOverride = null;
  TrabajoProfesionalService.debugUidOverride = null;
  ClienteProfesionalService.debugFirestoreOverride = null;
  ClienteProfesionalService.debugUidOverride = null;
  CitaService.debugFirestoreOverride = null;
  CitaService.debugUidOverride = null;
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
    'invitacion_hogar_rechazada lleva al profesional a la pestaña Trabajos del shell',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(_uid).set({'registrosProRefs': []});
      _aplicarOverrides(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => abrirDestinoNotificacionPro(
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
      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.currentIndex, 1);
      // pushAndRemoveUntil: no debe quedar nada más en la pila por debajo.
      expect(find.byType(ElevatedButton), findsNothing);
    },
  );
}
