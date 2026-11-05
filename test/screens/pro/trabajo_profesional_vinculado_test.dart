// test/screens/pro/trabajo_profesional_vinculado_test.dart
//
// Fase 2 (noviembre 2026): un trabajo privado ya vinculado a REPARA Hogar
// (campo `vinculo`, escrito solo por responderInvitacionHogar) abre en modo
// de solo lectura -- el editor normal (título/tipo/presupuesto/estado)
// dejaría de tener sentido una vez hay un Registro real llevando esos
// datos de verdad.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/pro/trabajos_pro_tab.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/services/trabajo_profesional_service.dart';
import 'package:repara_core/design_tokens.dart';
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
  TrabajoProfesionalService.debugFirestoreOverride = null;
  TrabajoProfesionalService.debugUidOverride = null;
}

void main() {
  tearDown(_limpiarOverrides);

  testWidgets(
    'un trabajo privado vinculado muestra "Vinculado a REPARA Hogar" en vez del editor',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(_uid).set({'registrosProRefs': []});
      await db
          .collection('profesionales')
          .doc(_uid)
          .collection('trabajosPro')
          .add({
            'clienteId': 'cliente-1',
            'clienteNombre': 'Luis',
            'titulo': 'Caldera no calienta',
            'tipo': 'averia',
            'estado': 'abierto',
            'vinculo': {
              'casaId': 'casa-luis',
              'elementoId': 'elem-caldera',
              'elementoNombre': 'Caldera no calienta',
              'registroId': 'reg-caldera',
              'registroTitulo': 'Caldera no calienta',
              'casaNombre': 'Piso de Luis',
            },
          });
      ProfesionalService.debugFirestoreOverride = db;
      ProfesionalService.debugUidOverride = _uid;
      RegistroService.debugFirestoreOverride = db;
      PagoService.debugFirestoreOverride = db;
      PresupuestoService.debugFirestoreOverride = db;
      CambioAlcanceService.debugFirestoreOverride = db;
      TrabajoProfesionalService.debugFirestoreOverride = db;
      TrabajoProfesionalService.debugUidOverride = _uid;

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const TrabajosProTab()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Vinculado a REPARA Hogar'), findsOneWidget);

      await tester.tap(find.text('Caldera no calienta').first);
      await tester.pumpAndSettle();

      expect(find.text('Vinculado a REPARA Hogar'), findsWidgets);
      expect(find.text('en Piso de Luis'), findsOneWidget);
      expect(find.text('Abrir el trabajo vinculado'), findsOneWidget);
      // El editor normal (campos de texto editables) no debe aparecer.
      expect(find.widgetWithText(TextField, 'Título'), findsNothing);
      expect(find.text('Guardar cambios'), findsNothing);
    },
  );
}
