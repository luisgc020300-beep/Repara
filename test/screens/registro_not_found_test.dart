// test/screens/registro_not_found_test.dart
//
// Mismo fix que elemento_not_found_test.dart (auditoría R4, octubre 2026):
// RegistroDetailScreen trataba snapshot.data == null como "todavía
// cargando" sin distinguirlo de "el registro ya no existe" -- se quedaba
// enseñando un spinner para siempre, sin botón de volver. Usa
// FakeFirebaseFirestore (el registro sencillamente no existe en el store),
// nada de Firebase real.
//
// NO IMPLEMENTADO (limitación real, no simulada): esta misma pantalla
// también distingue ahora un error de lectura (snapshot.hasError, p.ej.
// permission-denied si se pierde el acceso mientras la ficha está abierta)
// de "no existe" -- ver el comentario en registro_detail_screen.dart.
// RegistroService.streamRegistro() nunca lanza un error con
// FakeFirebaseFirestore (no aplica reglas de seguridad, y Registro.fromDoc
// está escrito a propósito para no lanzar nunca con datos ausentes/
// incompletos, "as String? ?? ''" en cada campo) -- no hay ninguna forma de
// provocar ese camino con los seams que expone hoy el servicio. Verificado
// por revisión de código (conRegistroDeErrores() relanza cualquier error del
// stream, y la rama "if (snapshot.hasError)" existe y antecede a la de
// "data == null"), no por ejecución.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/registro_detail_screen.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

void main() {
  tearDown(() => RegistroService.debugFirestoreOverride = null);

  testWidgets(
    'abrir la ficha de un evento que no existe muestra un aviso claro, nunca un spinner infinito',
    (tester) async {
      RegistroService.debugFirestoreOverride = FakeFirebaseFirestore();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroDetailScreen(
            casa: _casa,
            elementoId: 'e-fantasma',
            registroId: 'r-fantasma',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Este evento ya no existe.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
    },
  );
}
