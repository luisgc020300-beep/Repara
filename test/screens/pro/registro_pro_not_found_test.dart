// test/screens/pro/registro_pro_not_found_test.dart
//
// Mismo fix que elemento_not_found_test.dart/registro_not_found_test.dart
// (auditoría R4, octubre 2026), aplicado al lado profesional de la ficha de
// un registro -- ver el comentario completo en registro_detail_screen.dart.
// Usa FakeFirebaseFirestore, nada de Firebase real.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/pro/registro_pro_detail_screen.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';

void main() {
  tearDown(() => RegistroService.debugFirestoreOverride = null);

  testWidgets(
    'abrir, del lado del profesional, la ficha de un evento que no existe muestra un aviso claro, '
    'nunca un spinner infinito',
    (tester) async {
      RegistroService.debugFirestoreOverride = FakeFirebaseFirestore();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const RegistroProDetailScreen(
            casaId: 'c1',
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
