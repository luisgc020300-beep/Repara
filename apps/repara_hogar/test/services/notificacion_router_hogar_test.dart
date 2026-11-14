// test/services/notificacion_router_hogar_test.dart
//
// Sistema de notificaciones activas (noviembre 2026): hasta ahora, tocar una
// notificación de nivel de elemento sin un trabajo concreto detrás (garantía
// próxima a vencer, mantenimiento pendiente, elemento archivado/restaurado)
// no hacía nada -- el guard `if (casaId == null || elementoId == null ||
// registroId == null) return;` exigía siempre registroId, así que esas
// notificaciones ya eran mudas al tocarlas. Esta era la app real de Hogar,
// sin ningún test propio de su router (ver auditoría de notificaciones).
import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_hogar/screens/elemento_detail_screen.dart';
import 'package:repara_hogar/services/casa_service.dart';
import 'package:repara_hogar/services/elemento_service.dart';
import 'package:repara_hogar/services/habitacion_service.dart';
import 'package:repara_hogar/services/notificacion_router_hogar.dart';
import 'package:repara_core/cambio_alcance_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/documento_service.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/registro_service.dart';

const _uid = 'owner-1';

void _limpiarOverrides() {
  CasaService.debugFirestoreOverride = null;
  CasaService.debugUidOverride = null;
  ElementoService.debugFirestoreOverride = null;
  HabitacionService.debugFirestoreOverride = null;
  DocumentoService.debugFirestoreOverride = null;
  RegistroService.debugFirestoreOverride = null;
  PagoService.debugFirestoreOverride = null;
  CambioAlcanceService.debugFirestoreOverride = null;
}

void _aplicarOverrides(FakeFirebaseFirestore db) {
  CasaService.debugFirestoreOverride = db;
  CasaService.debugUidOverride = _uid;
  ElementoService.debugFirestoreOverride = db;
  HabitacionService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  CambioAlcanceService.debugFirestoreOverride = db;
}

void main() {
  tearDown(_limpiarOverrides);

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

      // Dos trampas de temporización (ver notificacion_router_test.dart del
      // monolito, mismo hallazgo): 1) hueco async real
      // (CasaService.streamCasa(...).first) antes del Navigator.push, sin
      // nada que reconstruya el árbol mientras se espera; 2) el Future que
      // devuelve Navigator.push nunca se completa aquí (solo al cerrar la
      // ruta, que este test no hace) -- esperarlo directamente cuelga para
      // siempre. Se deja la llamada "en vuelo" (como un tap real) y se
      // bombean frames acotados para dejarla progresar.
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
      unawaited(abrirDestinoNotificacionHogar(
        capturedContext,
        tipo: 'mantenimiento_pendiente',
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

  testWidgets(
    'invitacion_hogar_recibida sigue volviendo a la pantalla raíz, sin elementoId/casaId',
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
                    onPressed: () => abrirDestinoNotificacionHogar(
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

      expect(find.byType(ElementoDetailScreen), findsNothing);
      expect(vecesConstruido, 1);
    },
  );
}
