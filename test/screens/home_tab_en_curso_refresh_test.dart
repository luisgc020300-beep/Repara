// test/screens/home_tab_en_curso_refresh_test.dart
//
// "En curso" de Inicio se quedaba obsoleto hasta cerrar y reabrir la app
// entera (CEO, octubre 2026): registrosConTrabajoPendiente() es una lectura
// puntual (Future), no un Stream -- terminar un trabajo en otra pantalla y
// volver a Inicio nunca relanzaba esa lectura, porque _KeepAlivePage
// mantiene HomeTab montado al cambiar de pestaña (a propósito, para no
// perder la posición de scroll/re-suscribir streams sin necesidad). Prueba
// el arreglo real: sin volver a montar el widget desde cero (eso sería
// trampa, no reproduce el bug), solo incrementando refreshTick -- el mismo
// mecanismo que casa_shell_screen.dart dispara al volver a la pestaña
// Inicio -- el número debe refrescarse solo.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/home_tab.dart';
import 'package:repara/services/documento_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/habitacion_service.dart';
import 'package:repara/services/notificacion_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

// _MetricTile es privado de home_tab.dart -- no se puede referenciar su
// tipo desde este fichero. Su Column tiene siempre [Icon, SizedBox,
// Text(numero), SizedBox, Text(etiqueta.toUpperCase())] -- se localiza por
// la etiqueta (ya en mayúsculas en pantalla) y se lee el Text del número,
// dos posiciones antes en la misma Column.
String _numeroDeTile(WidgetTester tester, String etiquetaMayus) {
  final columna = tester.widget<Column>(
    find
        .ancestor(of: find.text(etiquetaMayus), matching: find.byType(Column))
        .first,
  );
  final textos = columna.children.whereType<Text>().toList();
  return textos.first.data!;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    HabitacionService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    NotificacionService.debugFirestoreOverride = null;
    NotificacionService.debugUidOverride = null;
  });

  testWidgets(
    'terminar un trabajo y volver a Inicio (refreshTick) actualiza "En curso" sin remontar la pantalla',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('casas').doc(_casa.id).collection('elementos').doc('e1').set({
        'nombre': 'Pérgolas',
      });
      final registroRef = db
          .collection('casas')
          .doc(_casa.id)
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .doc('r1');
      await registroRef.set({
        'titulo': 'Placa de metal',
        'tipo': 'instalacion',
        'esConProfesional': true,
        'estado': 'enCurso',
        'elementoNombre': 'Pérgolas',
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 30)),
      });
      ElementoService.debugFirestoreOverride = db;
      RegistroService.debugFirestoreOverride = db;
      HabitacionService.debugFirestoreOverride = db;
      DocumentoService.debugFirestoreOverride = db;
      // BotonNotificaciones (en el AppBar de HomeTab) necesita esto para no
      // disparar FirebaseAuth.instance real -- sin él, el error del stream
      // desbordaba el AppBar en el test (nada que ver con el bug de "En
      // curso" en sí).
      NotificacionService.debugFirestoreOverride = db;
      NotificacionService.debugUidOverride = 'u1';

      final refreshTick = ValueNotifier<int>(0);
      addTearDown(refreshTick.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: HomeTab(casa: _casa, refreshTick: refreshTick),
        ),
      );
      await tester.pumpAndSettle();

      expect(_numeroDeTile(tester, 'EN CURSO'), '1');

      // Simula lo que hace la Cloud Function al cobrar el trabajo del todo
      // (estadoTrasCambioDePago) -- directamente en Firestore, como si
      // hubiera pasado en otra pantalla mientras Inicio seguía montado.
      await registroRef.update({'estado': 'terminado'});

      // Sin esto, "En curso" se quedaría en 1 -- es justo el bug: nada
      // relanza la lectura solo por cambiar el dato en Firestore.
      refreshTick.value++;
      await tester.pumpAndSettle();

      expect(_numeroDeTile(tester, 'EN CURSO'), '0');
    },
  );
}
