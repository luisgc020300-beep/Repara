// test/screens/elemento_archivar_test.dart
//
// Botón de archivar/restaurar en la ficha del elemento (auditoría R5/R6,
// octubre 2026): visible y habilitado solo cuando NO hay trabajo
// profesional activo NI saldo pendiente de pago -- la autoridad real es
// archivarElemento (Cloud Function), esto solo comprueba que la UI
// ofrece/oculta el botón según el mismo criterio
// (RegistroService.esTrabajoActivo/tieneSaldoPendiente). Usa
// FakeFirebaseFirestore, nada de Firebase real.
//
// NO IMPLEMENTADO (limitación real, no simulada): confirmar de verdad un
// archivado o una restauración llama a ElementoService.archivar()/
// restaurar(), que invocan una Cloud Function real vía
// FirebaseFunctions.instanceFor(...). Eso no se puede invocar de verdad en
// este entorno de test sin el emulador de Firebase -- mismo motivo, y mismo
// criterio de honestidad, que ya documentan cambio_alcance_cancelar_test.dart
// (R2) y los tests del emulador de functions-tests/elementos.test.js (R5/R6),
// que sí verifican el comportamiento real de esas dos funciones.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/elemento_detail_screen.dart';
import 'package:repara/services/documento_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/habitacion_service.dart';
import 'package:repara/services/pago_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

Future<FakeFirebaseFirestore> _prepararElemento(
  String elementoId, {
  bool archivado = false,
}) async {
  final db = FakeFirebaseFirestore();
  await db
      .collection('casas')
      .doc(_casa.id)
      .collection('elementos')
      .doc(elementoId)
      .set({'nombre': 'Caldera', if (archivado) 'archivado': true});
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  HabitacionService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  return db;
}

Widget _envolver(String elementoId) => MaterialApp(
  theme: buildReparaLightTheme(),
  home: ElementoDetailScreen(casa: _casa, elementoId: elementoId),
);

void main() {
  // La ficha del elemento formatea fechas con DateFormat(..., 'es_ES') al
  // listar sus registros -- en la app real, main.dart ya llama a esto antes
  // de pintar nada; aquí hay que repetirlo a mano o cualquier registro con
  // fecha revienta con LocaleDataException (descubierto al escribir los
  // tests de esta iteración que, a diferencia de elemento_eliminar_test.dart,
  // sí seedean un registro con contenido bajo el elemento).
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    HabitacionService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
  });

  testWidgets(
    'sin ningún registro con profesional activo, el botón "Archivar elemento" está habilitado',
    (tester) async {
      await _prepararElemento('e1');

      await tester.pumpWidget(_envolver('e1'));
      await tester.pumpAndSettle();

      final boton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.archive_outlined),
      );
      expect(boton.onPressed, isNotNull);
      expect(boton.tooltip, 'Archivar elemento');
    },
  );

  testWidgets(
    'con un registro de profesional todavía activo, el botón de archivar aparece deshabilitado',
    (tester) async {
      final db = await _prepararElemento('e1');
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .add({
            'titulo': 'Reparación en curso',
            'esConProfesional': true,
            'estado': 'enCurso',
            'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });

      await tester.pumpWidget(_envolver('e1'));
      await tester.pumpAndSettle();

      final boton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.archive_outlined),
      );
      expect(boton.onPressed, isNull);
      expect(
        boton.tooltip,
        'No se puede archivar: tiene trabajo activo o pendiente de pago',
      );
    },
  );

  testWidgets(
    'un registro simple en pago pendiente también bloquea el archivado, aunque no tenga profesional',
    (tester) async {
      final db = await _prepararElemento('e1');
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .add({
            'titulo': 'Instalación sin cobrar',
            'esConProfesional': false,
            'estado': 'pendientePago',
            'coste': 2000,
            'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });

      await tester.pumpWidget(_envolver('e1'));
      await tester.pumpAndSettle();

      final boton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.archive_outlined),
      );
      expect(boton.onPressed, isNull);
      expect(
        boton.tooltip,
        'No se puede archivar: tiene trabajo activo o pendiente de pago',
      );
    },
  );

  testWidgets(
    'un registro con profesional ya terminado no bloquea el archivado',
    (tester) async {
      final db = await _prepararElemento('e1');
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .add({
            'titulo': 'Reparación ya cerrada',
            'esConProfesional': true,
            'estado': 'terminado',
            'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });

      await tester.pumpWidget(_envolver('e1'));
      await tester.pumpAndSettle();

      final boton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.archive_outlined),
      );
      expect(boton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'un elemento ya archivado muestra el aviso, el botón de restaurar, y oculta "Añadir evento"',
    (tester) async {
      await _prepararElemento('e1', archivado: true);

      await tester.pumpWidget(_envolver('e1'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Elemento archivado'),
        findsOneWidget,
      );
      expect(
        find.widgetWithIcon(IconButton, Icons.unarchive_outlined),
        findsOneWidget,
      );
      expect(find.widgetWithIcon(IconButton, Icons.archive_outlined), findsNothing);
      expect(find.text('Añadir evento'), findsNothing);
      // El historial sigue siendo accesible -- la foto/ficha normal del
      // elemento se sigue pintando, no un estado vacío ni un bloqueo.
      expect(find.text('Caldera'), findsWidgets);
    },
  );

  // ── Saldo pendiente (auditoría R6, octubre 2026) ──────────────────────

  testWidgets(
    'con un registro ya terminado pero con saldo sin cobrar, el botón de archivar aparece deshabilitado',
    (tester) async {
      final db = await _prepararElemento('e1');
      final registroRef = await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .add({
            'titulo': 'Reparación ya cerrada',
            'esConProfesional': true,
            'estado': 'terminado',
            'presupuesto': 100,
            'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });
      // Solo 40 de 100 pagados -- saldo pendiente de 60.
      await registroRef.collection('pagos').add({
        'importe': 40,
        'fecha': Timestamp.fromDate(DateTime(2026, 1, 2)),
      });

      await tester.pumpWidget(_envolver('e1'));
      await tester.pumpAndSettle();

      final boton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.archive_outlined),
      );
      expect(boton.onPressed, isNull);
      expect(
        boton.tooltip,
        'No se puede archivar: tiene un saldo pendiente de pago',
      );
    },
  );

  testWidgets(
    'con el presupuesto completamente cubierto por los pagos, el botón de archivar permanece habilitado',
    (tester) async {
      final db = await _prepararElemento('e1');
      final registroRef = await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .add({
            'titulo': 'Reparación ya cerrada y cobrada',
            'esConProfesional': true,
            'estado': 'terminado',
            'presupuesto': 100,
            'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });
      // Dos pagos parciales que juntos cubren el presupuesto completo.
      await registroRef.collection('pagos').add({
        'importe': 60,
        'fecha': Timestamp.fromDate(DateTime(2026, 1, 2)),
      });
      await registroRef.collection('pagos').add({
        'importe': 40,
        'fecha': Timestamp.fromDate(DateTime(2026, 1, 3)),
      });

      await tester.pumpWidget(_envolver('e1'));
      await tester.pumpAndSettle();

      final boton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.archive_outlined),
      );
      expect(boton.onPressed, isNotNull);
      expect(boton.tooltip, 'Archivar elemento');
    },
  );

  testWidgets(
    'un registro sin presupuesto fijado (null) nunca cuenta como saldo pendiente',
    (tester) async {
      final db = await _prepararElemento('e1');
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .add({
            'titulo': 'Compra simple, sin presupuesto',
            'esConProfesional': false,
            'estado': 'terminado',
            'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });

      await tester.pumpWidget(_envolver('e1'));
      await tester.pumpAndSettle();

      final boton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.archive_outlined),
      );
      expect(boton.onPressed, isNotNull);
    },
  );
}
