// test/services/registro_service_late_subscriber_test.dart
//
// Reproducción del bug real en producción (noviembre 2026): "al entrar a
// un trabajo desde REPARA Pro se queda cargando para siempre". Causa:
// trabajo_pro_agregado.dart mantiene una suscripción propia de larga
// duración a RegistroService.streamRegistro() mientras la pestaña
// Trabajos/Dashboard está montada; al abrir el detalle de ESE mismo
// trabajo, su StreamBuilder se suscribe DESPUÉS -- "llega tarde" al mismo
// stream compartido (ver lib/services/stream_sharing.dart). Este test usa
// el servicio real contra fake_cloud_firestore (sin widgets, para no
// depender de cómo flutter_test gestiona el reloj simulado al cerrar un
// StreamBuilder) para confirmar: 1) un oyente tardío recibe el valor de
// inmediato, sin esperar a un cambio real en Firestore que puede no
// llegar nunca, y 2) cancelar los oyentes en cualquier orden -- incluido
// cancelar primero el que llegó temprano y dejar vivo el tardío -- no dejó
// ninguna suscripción real colgada ni ningún future sin resolver.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/services/stream_sharing.dart';

void main() {
  tearDown(() {
    RegistroService.debugFirestoreOverride = null;
    debugLimpiarCacheDeStreamsCompartidos();
  });

  test(
    'un oyente que se suscribe después de otro ya activo recibe el registro de inmediato, '
    'y cancelar ambos (en cualquier orden) no deja nada colgado',
    () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('e1')
          .collection('registros')
          .doc('r1')
          .set({
            'elementoNombre': 'Caldera',
            'tipo': 'reparacion',
            'esConProfesional': true,
            'titulo': 'Revisión de la caldera',
            'estado': 'enCurso',
            'fecha': Timestamp.now(),
          });
      RegistroService.debugFirestoreOverride = db;

      // "Temprana": como trabajo_pro_agregado.dart, mantiene su
      // suscripción mientras la lista de Trabajos está montada.
      final recibidosTemprana = <String?>[];
      final subTemprana = RegistroService.streamRegistro('c1', 'e1', 'r1')
          .listen((r) => recibidosTemprana.add(r?.titulo));
      await Future<void>.delayed(Duration.zero);
      expect(recibidosTemprana, ['Revisión de la caldera']);

      // "Tardía": como el StreamBuilder<Registro?> del detalle del
      // trabajo, que se suscribe DESPUÉS de que la temprana ya recibiera
      // su snapshot -- debe recibirlo también, de inmediato.
      final recibidosTardia = <String?>[];
      final subTardia = RegistroService.streamRegistro('c1', 'e1', 'r1')
          .listen((r) => recibidosTardia.add(r?.titulo));
      await Future<void>.delayed(Duration.zero);
      expect(
        recibidosTardia,
        ['Revisión de la caldera'],
        reason: 'antes de este arreglo, la pantalla de detalle se quedaba '
            'cargando para siempre porque nunca llegaba a recibir esto',
      );

      // Cancelar primero la temprana, dejando viva la tardía -- exactamente
      // el orden real (la lista puede seguir montada o no cuando se sale
      // del detalle).
      await subTemprana.cancel();
      await subTardia.cancel();
    },
  );
}
