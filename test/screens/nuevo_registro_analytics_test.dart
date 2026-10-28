// test/screens/nuevo_registro_analytics_test.dart
//
// Evento de analítica al crear un registro (iteración R2, defecto 2):
// AnalyticsService.workCreated() se dispara SOLO tras una creación
// correcta, nunca si la validación rechaza el formulario antes de
// llegar a RegistroService.crear(). AnalyticsService llama a
// FirebaseAnalytics.instance de verdad, que no se puede invocar (ni
// comprobar que se llamó) sin Firebase Core inicializado -- este
// proyecto no mockea Firebase Core en sus tests (ver test/widget_test.
// dart). Lo que SÍ se puede comprobar sin ningún mock es la mitad
// "nunca" de la regla: con el título vacío, la validación corta el
// flujo ANTES de tocar RegistroService.crear() (que es Firestore puro,
// aquí sí falseable) y, por construcción del código -- la llamada a
// AnalyticsService.workCreated() está varias líneas después de ese
// await dentro del mismo bloque try, nunca antes --, tampoco se
// alcanza. El camino positivo (creación con éxito -> el evento sí se
// dispara) queda confirmado por revisión de código, no por este test:
// ver el informe de la iteración.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/nuevo_registro_sheet.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';

void main() {
  tearDown(() => RegistroService.debugFirestoreOverride = null);

  testWidgets(
    'un título vacío no crea el registro -- RegistroService.crear() nunca se alcanza, '
    'y por tanto tampoco el evento de analítica que va después',
    (tester) async {
      final db = FakeFirebaseFirestore();
      RegistroService.debugFirestoreOverride = db;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => mostrarNuevoRegistroSheet(
                    context,
                    casaId: 'c1',
                    elementoId: 'e1',
                    elementoNombre: 'Caldera',
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Título vacío a propósito -- no se rellena _tituloCtrl.
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // La hoja sigue abierta (no se guardó nada) y Firestore sigue vacío.
      expect(find.text('Añadir evento'), findsOneWidget);
      final registros = await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .get();
      expect(registros.docs, isEmpty);
    },
  );
}
