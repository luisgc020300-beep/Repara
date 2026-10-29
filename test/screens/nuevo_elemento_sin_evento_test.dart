// test/screens/nuevo_elemento_sin_evento_test.dart
//
// "Un elemento nace solo" (CEO, octubre 2026): antes, crear un elemento
// forzaba de paso un primer evento ("registro fundacional") con su propio
// tipo y, opcionalmente, flujo de profesional -- no tenía sentido obligar
// a registrar un evento solo por dar de alta el objeto. Ahora el
// formulario solo pide datos del elemento en sí (Coste/Profesional
// incluidos, siempre visibles, sin el interruptor que los escondía); los
// eventos se añaden después, cuando de verdad ocurren, desde "+ Añadir
// evento" (ver nuevo_registro_sheet.dart, que ya cubre tanto el caso
// simple como el de profesional).
//
// NO PROBADO AQUÍ COMO WIDGET (limitación real, no simulada): tocar
// "Guardar elemento" de verdad dispara, tras crear el elemento,
// AnalyticsService.firstElementCreated() -- que lanza de forma síncrona
// (FirebaseAnalytics.instance, fuera de cualquier Future) en cuanto
// Firebase Core no está inicializado, antes incluso de llegar a
// Navigator.pop(). Mismo límite real que ya documenta
// nuevo_registro_analytics_test.dart para el mismo tipo de llamada. Lo que
// SÍ se puede probar sin red es: (a) que el formulario ya no ofrece Tipo/
// interruptor de profesional, y (b) que ElementoService.crear() -- el
// único método que este formulario llama ya para crear, crearConRegistro
// Fundacional() ni siquiera existe ya en el código -- nunca toca la
// subcolección de registros del elemento que crea.
// Usa FakeFirebaseFirestore, nada de Firebase real.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/models/elemento.dart';
import 'package:repara/screens/nuevo_elemento_screen.dart';
import 'package:repara/services/contacto_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/habitacion_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

void main() {
  testWidgets(
    'no ofrece "Tipo de elemento" ni "¿Lo hace un profesional?" -- Coste y Profesional siempre visibles',
    (tester) async {
      final db = FakeFirebaseFirestore();
      ElementoService.debugFirestoreOverride = db;
      HabitacionService.debugFirestoreOverride = db;
      ContactoService.debugFirestoreOverride = db;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: NuevoElementoScreen(casa: _casa),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tipo de elemento'), findsNothing);
      expect(find.text('¿Lo hace un profesional?'), findsNothing);
      expect(find.widgetWithText(TextField, 'Coste (€)'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Profesional (opcional)'),
        findsOneWidget,
      );

      ElementoService.debugFirestoreOverride = null;
      HabitacionService.debugFirestoreOverride = null;
      ContactoService.debugFirestoreOverride = null;
    },
  );

  test(
    'ElementoService.crear() crea el elemento sin ningún registro en su subcolección',
    () async {
      final db = FakeFirebaseFirestore();
      ElementoService.debugFirestoreOverride = db;

      final id = await ElementoService.crear(
        'c1',
        const Elemento(
          id: '',
          nombre: 'Pérgolas',
          coste: 2000,
          profesionalNombre: 'Metalistero',
        ),
      );

      final elemento = await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc(id)
          .get();
      expect(elemento.data()!['nombre'], 'Pérgolas');

      final registros = await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc(id)
          .collection('registros')
          .get();
      expect(registros.docs, isEmpty);

      ElementoService.debugFirestoreOverride = null;
    },
  );
}
