// test/screens/elemento_not_found_test.dart
//
// Fix de pantalla congelada (auditoría R3, octubre 2026): ElementoDetail
// Screen trataba snapshot.data == null como "todavía cargando" sin
// distinguirlo de "el documento ya no existe" -- así que abrir la ficha de
// un elemento ya borrado (p.ej. desde un documento huérfano en Documentos de
// la casa, cuyo elementoId sigue apuntando a un elemento eliminado, porque
// eliminar un elemento no limpia sus referencias en otras colecciones --
// ver el informe de esta iteración) se quedaba enseñando un spinner para
// siempre, sin botón de volver. Usa FakeFirebaseFirestore (el elemento
// sencillamente no existe en el store), nada de Firebase real.
//
// NO IMPLEMENTADO (limitación real, no simulada, auditoría R4): esta misma
// pantalla distingue ahora también un error de lectura (snapshot.hasError,
// p.ej. permission-denied si se pierde el acceso mientras la ficha está
// abierta) de "no existe" -- ver el comentario completo en
// registro_not_found_test.dart, que explica por qué ese camino no se puede
// provocar con los seams que expone hoy el servicio (FakeFirebaseFirestore
// no aplica reglas de seguridad, y Elemento.fromDoc no lanza nunca con datos
// ausentes). Verificado por revisión de código, no por ejecución.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/elemento_detail_screen.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

void main() {
  tearDown(() => ElementoService.debugFirestoreOverride = null);

  testWidgets(
    'abrir la ficha de un elemento que no existe muestra un aviso claro, nunca un spinner infinito',
    (tester) async {
      ElementoService.debugFirestoreOverride = FakeFirebaseFirestore();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ElementoDetailScreen(casa: _casa, elementoId: 'fantasma'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Este elemento ya no existe.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Con AppBar propio -- el usuario tiene que poder volver, no quedar
      // atrapado en una pantalla sin salida.
      expect(find.byType(AppBar), findsOneWidget);
    },
  );
}
