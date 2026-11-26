// test/screens/nuevo_registro_screen_repetir_test.dart
//
// "Repetir un mantenimiento anterior" (CEO, noviembre 2026): desde el
// historial de un elemento, repetir un mantenimiento abre el mismo
// formulario de "Añadir evento" (nuevo_registro_screen.dart) con los datos
// descriptivos del original precargados -- nunca fecha, coste, presupuesto,
// plazos, fotos, documentos ni estado, que siempre nacen vacíos/por
// defecto, igual que si se hubiera abierto la pantalla a mano.
//
// Estos tests no llegan a pulsar "Guardar": _guardar() lee
// FirebaseAuth.instance.currentUser antes de cualquier try/catch, y no hay
// ninguna infraestructura de mocks de FirebaseAuth en este repositorio (ver
// nuevo_documento_flow_sugerencias_test.dart, que tiene la misma limitación
// y tampoco llega a guardar). Lo que hay que comprobar -- qué se precarga y
// qué no -- es observable igual en el formulario ya montado, sin necesidad
// de completar el guardado real.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/registro.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_hogar/models/casa.dart';
import 'package:repara_hogar/screens/nuevo_registro_screen.dart';
import 'package:repara_hogar/screens/registro_detail_screen.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

final _mantenimientoCompleto = Registro(
  id: 'r_original',
  elementoNombre: 'Caldera',
  tipo: TipoRegistro.mantenimiento,
  esConProfesional: false,
  titulo: 'Revisión anual caldera',
  estado: EstadoRegistro.terminado,
  fecha: DateTime(2025, 3, 10),
  descripcion: 'Revisión y limpieza de quemadores',
  garantiaHasta: DateTime(2026, 3, 10),
  coste: 120,
  fotoUrls: const ['https://ejemplo.com/foto1.jpg'],
  documentoIds: const ['doc1'],
  profesionales: const [
    ProfesionalRegistro(
      nombre: 'Fontanería López',
      telefono: '600111222',
      contactoId: 'ct1',
    ),
  ],
  presupuesto: 150,
  plazoFrecuenciaMeses: 12,
  plazoImporte: 50,
);

Future<void> _abrir(WidgetTester tester, {Registro? plantilla}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildReparaLightTheme(),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => abrirNuevoRegistroScreen(
            context,
            casa: _casa,
            elementoId: 'e1',
            elementoNombre: 'Caldera',
            plantilla: plantilla,
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => RegistroService.debugFirestoreOverride = null);

  group('repetir mantenimiento -- qué se precarga', () {
    testWidgets(
      'tipo, título, descripción y profesional del original llegan ya rellenos',
      (tester) async {
        await _abrir(tester, plantilla: _mantenimientoCompleto);

        expect(find.text('Repetir mantenimiento'), findsWidgets);
        expect(
          find.widgetWithText(TextField, 'Revisión anual caldera'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextField, 'Revisión y limpieza de quemadores'),
          findsOneWidget,
        );
        expect(find.text('Fontanería López'), findsOneWidget);
      },
    );

    testWidgets(
      'fecha y coste nacen con sus valores por defecto, no los del original',
      (tester) async {
        await _abrir(tester, plantilla: _mantenimientoCompleto);

        final hoy = DateTime.now();
        expect(
          find.text('${hoy.day}/${hoy.month}/${hoy.year}'),
          findsOneWidget,
        );
        expect(find.text('10/3/2025'), findsNothing);
        // El coste del original (120) no debe aparecer en ningún campo.
        expect(find.text('120'), findsNothing);
        expect(find.text('120.0'), findsNothing);
      },
    );

    testWidgets(
      'presupuesto, plazos, estado, fotos, documentos y garantía del original no aparecen en el formulario',
      (tester) async {
        await _abrir(tester, plantilla: _mantenimientoCompleto);

        expect(find.text('150'), findsNothing); // presupuesto
        expect(find.text('50'), findsNothing); // plazoImporte
        expect(find.text('12'), findsNothing); // plazoFrecuenciaMeses
        expect(find.text('Terminado'), findsNothing); // estado original
        // El formulario simple no tiene ninguna sección de fotos/documentos
        // -- si el original las tenía, sencillamente no hay dónde mostrarlas
        // por error.
        expect(find.byIcon(Icons.photo_outlined), findsNothing);
      },
    );

    testWidgets(
      'si el profesional del original ya no está disponible como contacto, el formulario no se rompe y conserva su nombre',
      (tester) async {
        final plantillaSinContactoVivo = Registro(
          id: 'r2',
          elementoNombre: 'Caldera',
          tipo: TipoRegistro.mantenimiento,
          esConProfesional: false,
          titulo: 'Revisión de caldera',
          estado: EstadoRegistro.terminado,
          fecha: DateTime(2024, 1, 1),
          profesionales: const [
            ProfesionalRegistro(
              nombre: 'Un fontanero que ya no está en Contactos',
              contactoId: 'contacto-borrado-hace-tiempo',
            ),
          ],
        );

        await _abrir(tester, plantilla: plantillaSinContactoVivo);

        expect(
          find.text('Un fontanero que ya no está en Contactos'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'sin plantilla, "Añadir evento" sigue arrancando completamente vacío',
      (tester) async {
        await _abrir(tester);

        expect(find.text('Añadir evento'), findsWidgets);
        expect(find.widgetWithText(TextField, 'Elegir de tus contactos'), findsNothing);
        expect(
          find.widgetWithText(TextField, 'Revisión anual caldera'),
          findsNothing,
        );
      },
    );
  });

  group('repetir mantenimiento -- independencia del original', () {
    testWidgets(
      'abrir "Repetir mantenimiento" no modifica el registro original ni crea uno nuevo por sí solo',
      (tester) async {
        final db = FakeFirebaseFirestore();
        RegistroService.debugFirestoreOverride = db;
        final ref = db
            .collection('casas')
            .doc('c1')
            .collection('elementos')
            .doc('e1')
            .collection('registros')
            .doc('r_original');
        await ref.set({
          ..._mantenimientoCompleto.toMap(),
          'createdAt': Timestamp.fromDate(DateTime(2025, 3, 10)),
        });
        final antes = (await ref.get()).data();

        await _abrir(tester, plantilla: _mantenimientoCompleto);

        final despues = (await ref.get()).data();
        expect(despues, antes);
        final todos = await db
            .collection('casas')
            .doc('c1')
            .collection('elementos')
            .doc('e1')
            .collection('registros')
            .get();
        expect(todos.docs.length, 1);
      },
    );
  });

  group('puedeRepetirMantenimiento', () {
    test('es true para un mantenimiento', () {
      expect(puedeRepetirMantenimiento(_mantenimientoCompleto), isTrue);
    });

    test(
      'es false para averías, compras, instalaciones, reformas, reparaciones, sustituciones y notas',
      () {
        for (final tipo in TipoRegistro.values) {
          if (tipo == TipoRegistro.mantenimiento) continue;
          final r = Registro(
            id: 'x',
            elementoNombre: 'Caldera',
            tipo: tipo,
            esConProfesional: false,
            titulo: 'Algo',
            estado: EstadoRegistro.terminado,
            fecha: DateTime(2025, 1, 1),
          );
          expect(
            puedeRepetirMantenimiento(r),
            isFalse,
            reason: 'tipo ${tipo.name} no debería permitir repetir',
          );
        }
      },
    );
  });
}
