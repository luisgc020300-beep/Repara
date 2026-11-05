// test/screens/registro_detail_screen_test.dart
//
// Auditoría de estabilidad (noviembre 2026): registro_detail_screen.dart
// abre a la vez 6-7 StreamBuilder anidados (Registro, Elemento, Pagos,
// Presupuestos, Historial, Próxima visita...) y cada rebuild del árbol
// -- que ocurre en cascada cada vez que el stream del Registro emite --
// recreaba todos esos streams desde cero, lo que disparaba
// "FIRESTORE INTERNAL ASSERTION FAILED (ID: ca9)" en el SDK de Firestore
// Web. El arreglo (ver lib/services/stream_sharing.dart) memoiza cada
// stream por clave para que el mismo StreamBuilder no cancele/resuscriba
// en cada rebuild.
//
// Estos tests corren en la VM de Dart con fake_cloud_firestore -- no
// pueden reproducir el fallo concreto del SDK JS de Firestore Web (eso
// solo existe en cloud_firestore_web, inalcanzable desde un widget test),
// pero sí prueban la causa real: que las secciones (Presupuestos,
// Historial, Próxima visita) muestran sus datos, y que una ráfaga de
// escrituras rápidas al documento del registro -- que antes disparaba una
// cascada de cancelaciones/suscripciones simultáneas en 6-7 streams --
// no las deja vacías ni lanza ninguna excepción. La reproducción real del
// crash del SDK se verificó por separado contra el emulador + Flutter Web
// (ver informe).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/registro_detail_screen.dart';
import 'package:repara/services/cambio_alcance_service.dart';
import 'package:repara/services/cita_service.dart';
import 'package:repara/services/documento_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/historial_service.dart';
import 'package:repara/services/invitacion_service.dart';
import 'package:repara/services/pago_service.dart';
import 'package:repara/services/presupuesto_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';
import 'package:repara_core/stream_sharing.dart';

const _casaId = 'casa-1';
const _elementoId = 'elem-1';
const _registroId = 'reg-1';
const _profesionalUid = 'pro-1';

Future<FakeFirebaseFirestore> _sembrar() async {
  final db = FakeFirebaseFirestore();
  final ahora = DateTime.now();

  await db
      .collection('casas')
      .doc(_casaId)
      .collection('elementos')
      .doc(_elementoId)
      .set({'nombre': 'Caldera', 'createdAt': Timestamp.fromDate(ahora)});

  final registroRef = db
      .collection('casas')
      .doc(_casaId)
      .collection('elementos')
      .doc(_elementoId)
      .collection('registros')
      .doc(_registroId);
  await registroRef.set({
    'elementoNombre': 'Caldera',
    'tipo': 'reparacion',
    'esConProfesional': true,
    'titulo': 'Revisión de la caldera',
    'estado': 'enCurso',
    'fecha': Timestamp.fromDate(ahora),
    'profesionalUid': _profesionalUid,
    'presupuesto': 500.0,
    'createdAt': Timestamp.fromDate(ahora),
  });

  await registroRef.collection('presupuestos').doc('p1').set({
    'numero': 1,
    'version': 1,
    'estado': 'aceptado',
    'lineas': [
      {'descripcion': 'Revisión', 'cantidad': 1, 'precioUnitario': 500.0},
    ],
    'subtotal': 413.22,
    'iva': 86.78,
    'total': 500.0,
    'fechaCreacion': Timestamp.fromDate(ahora),
  });

  for (var i = 0; i < 4; i++) {
    await registroRef.collection('historial').add({
      'entidad': 'presupuesto',
      'accion': 'enviado',
      'actorUid': _profesionalUid,
      'actorNombre': 'Fontanero Pepe',
      'timestamp': Timestamp.fromDate(ahora.subtract(Duration(hours: i))),
    });
  }

  await db
      .collection('profesionales')
      .doc(_profesionalUid)
      .collection('citas')
      .doc('cita-1')
      .set({
        'titulo': 'Revisión in situ',
        'fecha': Timestamp.fromDate(ahora.add(const Duration(days: 2))),
        'todoElDia': false,
        'compartida': true,
        'registroId': _registroId,
        'casaId': _casaId,
        'elementoId': _elementoId,
        'createdAt': Timestamp.fromDate(ahora),
      });

  return db;
}

void _conectarServicios(FakeFirebaseFirestore db) {
  RegistroService.debugFirestoreOverride = db;
  ElementoService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  HistorialService.debugFirestoreOverride = db;
  CitaService.debugFirestoreOverride = db;
  PresupuestoService.debugFirestoreOverride = db;
  CambioAlcanceService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  InvitacionService.debugFirestoreOverride = db;
}

void _desconectarServicios() {
  RegistroService.debugFirestoreOverride = null;
  ElementoService.debugFirestoreOverride = null;
  PagoService.debugFirestoreOverride = null;
  HistorialService.debugFirestoreOverride = null;
  CitaService.debugFirestoreOverride = null;
  PresupuestoService.debugFirestoreOverride = null;
  CambioAlcanceService.debugFirestoreOverride = null;
  DocumentoService.debugFirestoreOverride = null;
  InvitacionService.debugFirestoreOverride = null;
}

const _casa = Casa(
  id: _casaId,
  nombre: 'Mi casa',
  ownerUid: 'owner-1',
  members: ['owner-1'],
  memberProfiles: {},
);

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));
  tearDown(() {
    _desconectarServicios();
    debugLimpiarCacheDeStreamsCompartidos();
  });

  testWidgets(
    'muestra Presupuestos, Historial y Próxima visita con datos reales',
    (tester) async {
      final db = await _sembrar();
      _conectarServicios(db);
      // El Resumen es un ListView largo (estado, profesional, próxima
      // visita, presupuestos, mantenimiento, historial) -- con la
      // superficie de test por defecto (800x600) la mayoría queda fuera
      // del viewport y ni se construye. Una superficie más alta evita
      // depender de desplazar manualmente sección por sección.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaDarkTheme(),
          home: const RegistroDetailScreen(
            casa: _casa,
            elementoId: _elementoId,
            registroId: _registroId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Próxima visita (la cita compartida sembrada).
      expect(find.text('Próxima visita'), findsOneWidget);
      expect(find.text('Revisión in situ'), findsOneWidget);

      // Presupuestos (el título de la sección puede repetirse si el PDF o
      // algún otro widget comparte la misma etiqueta -- basta con que
      // aparezca, no con que aparezca una sola vez).
      expect(find.text('Presupuestos'), findsWidgets);

      // Historial de la reparación -- los 4 eventos sembrados.
      expect(find.text('Historial de la reparación'), findsOneWidget);
      expect(find.textContaining('Fontanero Pepe'), findsWidgets);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'una ráfaga de escrituras rápidas al registro no vacía las secciones ni lanza excepciones',
    (tester) async {
      final db = await _sembrar();
      _conectarServicios(db);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaDarkTheme(),
          home: const RegistroDetailScreen(
            casa: _casa,
            elementoId: _elementoId,
            registroId: _registroId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final registroRef = db
          .collection('casas')
          .doc(_casaId)
          .collection('elementos')
          .doc(_elementoId)
          .collection('registros')
          .doc(_registroId);

      // Antes del arreglo, cada una de estas escrituras hacía que el
      // StreamBuilder<Registro?> de más arriba recibiera un snapshot
      // nuevo y reconstruyera todo el árbol -- cancelando y resuscribiendo
      // los 6-7 streams anidados de golpe en cada vuelta. Aquí se repite
      // deliberadamente muchas veces seguidas para forzar esa cascada.
      for (var i = 0; i < 15; i++) {
        // Un campo que no cambia ninguna rama condicional del árbol de
        // widgets (a diferencia de `descripcion`, que inserta un Text
        // nuevo nada más dejar de ser null) -- aísla la tormenta de
        // listen/unlisten de un simple cambio de forma del árbol.
        await registroRef.update({'tituloDebug': 'Vuelta $i'});
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Próxima visita'), findsOneWidget);
      expect(find.text('Presupuestos'), findsWidgets);
      expect(find.text('Historial de la reparación'), findsOneWidget);
      expect((await registroRef.get()).data()?['tituloDebug'], 'Vuelta 14');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'un campo que cambia la forma del árbol (descripción null -> con valor) no pierde las secciones',
    (tester) async {
      // Este es el hallazgo real distinto al de la ráfaga de arriba: no
      // hace falta repetir muchas veces -- basta con que `descripcion`
      // pase de null a tener valor UNA sola vez mientras la pantalla
      // está abierta. Eso inserta un Text nuevo al principio del
      // ListView y desplaza todo lo de abajo; sin Key explícita en
      // _SeccionProximaVisita/PresupuestosSection/_SeccionHistorial (ver
      // fix en registro_detail_screen.dart), Flutter reconciliaba mal
      // esas posiciones y las secciones perdían sus datos.
      final db = await _sembrar();
      _conectarServicios(db);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaDarkTheme(),
          home: const RegistroDetailScreen(
            casa: _casa,
            elementoId: _elementoId,
            registroId: _registroId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final registroRef = db
          .collection('casas')
          .doc(_casaId)
          .collection('elementos')
          .doc(_elementoId)
          .collection('registros')
          .doc(_registroId);

      await registroRef.update({'descripcion': 'Revisión anual'});
      await tester.pumpAndSettle();

      expect(find.text('Revisión anual'), findsOneWidget);
      expect(find.text('Próxima visita'), findsOneWidget);
      expect(find.text('Revisión in situ'), findsOneWidget);
      expect(find.text('Presupuestos'), findsWidgets);
      expect(find.text('Presupuesto #1 · v1'), findsOneWidget);
      expect(find.text('Historial de la reparación'), findsOneWidget);
      expect(find.textContaining('Fontanero Pepe'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
