// test/screens/registro_simple_progreso_test.dart
//
// Línea de progreso de 3 pasos de un registro simple (CEO, octubre 2026):
// bug real -- cuando el registro ya estaba "Terminado", el tercer paso se
// quedaba en círculo hueco (_PasoEstado.actual) en vez del check verde
// (_PasoEstado.completado), aunque el proceso entero ya estuviera cerrado.
// No hay ningún paso después de "Terminado" al que seguir "en curso".
// Comprueba los 3 iconos de check según el estado real -- sin
// FakeFirebaseFirestore, el widget es puro (solo lee Registro.estado).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/registro.dart';
import 'package:repara/screens/registro_simple/registro_simple_progreso.dart';
import 'package:repara/theme/design_tokens.dart';

Registro _registro(EstadoRegistro estado) => Registro(
  id: 'r1',
  elementoNombre: 'Pérgolas',
  tipo: TipoRegistro.instalacion,
  esConProfesional: false,
  titulo: 'Placa de metal',
  estado: estado,
  fecha: DateTime(2026, 10, 30),
  coste: 850,
);

void main() {
  testWidgets(
    'pago pendiente: solo "Trabajo realizado" tiene el check, "Terminado" sigue vacío',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: Scaffold(
            body: RegistroSimpleProgreso(registro: _registro(EstadoRegistro.pendientePago)),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    },
  );

  testWidgets(
    'terminado: los 3 pasos (incluido "Terminado") muestran el check -- no queda ninguno a medias',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: Scaffold(
            body: RegistroSimpleProgreso(registro: _registro(EstadoRegistro.terminado)),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsNWidgets(3));
    },
  );

  testWidgets(
    'archivado se trata igual que terminado: los 3 pasos con check',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: Scaffold(
            body: RegistroSimpleProgreso(registro: _registro(EstadoRegistro.archivado)),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsNWidgets(3));
    },
  );
}
