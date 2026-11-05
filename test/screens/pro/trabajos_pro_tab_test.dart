// test/screens/pro/trabajos_pro_tab_test.dart
//
// Vista de trabajos ampliada (ampliación REPARA Pro, Fase 1, noviembre
// 2026): el filtro "Activos" (por defecto) oculta lo terminado tanto en
// Lista como en Tablero, y el Tablero agrupa cada trabajo en la columna
// que le corresponde según su estado real.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/trabajo_profesional.dart';
import 'package:repara/screens/pro/trabajos_pro_tab.dart';
import 'package:repara/services/cambio_alcance_service.dart';
import 'package:repara/services/pago_service.dart';
import 'package:repara/services/presupuesto_service.dart';
import 'package:repara/services/profesional_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/services/trabajo_profesional_service.dart';
import 'package:repara/theme/design_tokens.dart';
import 'package:repara_core/registro.dart';

const _uid = 'pro-1';

Future<FakeFirebaseFirestore> _seed() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc(_uid).set({
    'registrosProRefs': [
      {
        'casaId': 'c1',
        'elementoId': 'e1',
        'elementoNombre': 'Caldera',
        'registroId': 'r1',
        'registroTitulo': 'Sin presupuestar aún',
        'casaNombre': 'Casa Norte',
      },
      {
        'casaId': 'c1',
        'elementoId': 'e1',
        'elementoNombre': 'Caldera',
        'registroId': 'r2',
        'registroTitulo': 'Obra en marcha',
        'casaNombre': 'Casa Norte',
      },
      {
        'casaId': 'c2',
        'elementoId': 'e2',
        'elementoNombre': 'Tejado',
        'registroId': 'r3',
        'registroTitulo': 'Reparación de tejas',
        'casaNombre': 'Casa Sur',
      },
    ],
  });

  Future<void> crear(
    String casaId,
    String elementoId,
    String registroId,
    Map<String, dynamic> datos,
  ) => db
      .collection('casas')
      .doc(casaId)
      .collection('elementos')
      .doc(elementoId)
      .collection('registros')
      .doc(registroId)
      .set(datos);

  await crear('c1', 'e1', 'r1', {
    'elementoNombre': 'Caldera',
    'tipo': 'reparacion',
    'esConProfesional': true,
    'titulo': 'Sin presupuestar aún',
    'estado': 'nuevo',
    'fecha': Timestamp.now(),
  });
  await crear('c1', 'e1', 'r2', {
    'elementoNombre': 'Caldera',
    'tipo': 'reparacion',
    'esConProfesional': true,
    'titulo': 'Obra en marcha',
    'estado': 'enCurso',
    'fecha': Timestamp.now(),
  });
  await crear('c2', 'e2', 'r3', {
    'elementoNombre': 'Tejado',
    'tipo': 'reparacion',
    'esConProfesional': true,
    'titulo': 'Reparación de tejas',
    'estado': 'terminado',
    'fecha': Timestamp.now(),
  });

  return db;
}

void main() {
  tearDown(() {
    ProfesionalService.debugFirestoreOverride = null;
    ProfesionalService.debugUidOverride = null;
    RegistroService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
    PresupuestoService.debugFirestoreOverride = null;
    CambioAlcanceService.debugFirestoreOverride = null;
    TrabajoProfesionalService.debugFirestoreOverride = null;
    TrabajoProfesionalService.debugUidOverride = null;
  });

  testWidgets(
    'el filtro "Activos" (por defecto) oculta lo terminado en la lista',
    (tester) async {
      final db = await _seed();
      ProfesionalService.debugFirestoreOverride = db;
      ProfesionalService.debugUidOverride = _uid;
      RegistroService.debugFirestoreOverride = db;
      PagoService.debugFirestoreOverride = db;
      PresupuestoService.debugFirestoreOverride = db;
      CambioAlcanceService.debugFirestoreOverride = db;
      TrabajoProfesionalService.debugFirestoreOverride = db;
      TrabajoProfesionalService.debugUidOverride = _uid;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const TrabajosProTab(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin presupuestar aún'), findsOneWidget);
      expect(find.text('Obra en marcha'), findsOneWidget);
      expect(find.text('Reparación de tejas'), findsNothing);
    },
  );

  testWidgets(
    'el Tablero agrupa cada trabajo en su columna real y respeta el filtro',
    (tester) async {
      // Las 7 columnas en una fila horizontal no caben en el ancho por
      // defecto del test (800px) -- un finder no encuentra lo que está fuera
      // del viewport visible de un ListView. Mismo fix que
      // documento_editar_eliminar_test.dart.
      tester.view.physicalSize = const Size(2400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = await _seed();
      ProfesionalService.debugFirestoreOverride = db;
      ProfesionalService.debugUidOverride = _uid;
      RegistroService.debugFirestoreOverride = db;
      PagoService.debugFirestoreOverride = db;
      PresupuestoService.debugFirestoreOverride = db;
      CambioAlcanceService.debugFirestoreOverride = db;
      TrabajoProfesionalService.debugFirestoreOverride = db;
      TrabajoProfesionalService.debugUidOverride = _uid;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const TrabajosProTab(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Tablero'));
      await tester.pumpAndSettle();

      // Columna por defecto ("Sin presupuestar") ya está seleccionada.
      expect(find.text('Sin presupuestar aún'), findsOneWidget);
      expect(find.text('Obra en marcha'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'En curso (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Obra en marcha'), findsOneWidget);
      expect(find.text('Sin presupuestar aún'), findsNothing);

      // Con el filtro por defecto ("Activos"), lo terminado no cuenta en
      // ninguna columna del tablero.
      expect(find.widgetWithText(ChoiceChip, 'Terminado (0)'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Terminado (1)'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Terminado (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Reparación de tejas'), findsOneWidget);
    },
  );

  testWidgets(
    'la vista Lista muestra una sección Privados con los trabajos propios del profesional',
    (tester) async {
      final db = await _seed();
      ProfesionalService.debugFirestoreOverride = db;
      ProfesionalService.debugUidOverride = _uid;
      RegistroService.debugFirestoreOverride = db;
      PagoService.debugFirestoreOverride = db;
      PresupuestoService.debugFirestoreOverride = db;
      CambioAlcanceService.debugFirestoreOverride = db;
      TrabajoProfesionalService.debugFirestoreOverride = db;
      TrabajoProfesionalService.debugUidOverride = _uid;

      await TrabajoProfesionalService.crear(
        const TrabajoProfesional(
          id: '',
          clienteId: 'cliente-1',
          clienteNombre: 'Cliente privado',
          titulo: 'Trabajo privado sin invitación',
          tipo: TipoRegistro.reparacion,
          estado: EstadoTrabajoProfesional.abierto,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const TrabajosProTab(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privados'), findsOneWidget);
      expect(find.text('Trabajo privado sin invitación'), findsOneWidget);
      // El Tablero (compartido) sigue mostrando solo trabajos compartidos --
      // no se mezcla con los privados, que no tienen las mismas fases.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tablero'));
      await tester.pumpAndSettle();
      expect(find.text('Trabajo privado sin invitación'), findsNothing);
    },
  );
}
