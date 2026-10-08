// test/models/notificacion_test.dart
//
// Fase O de la misión de seguridad local (octubre 2026): cobertura directa
// de tipoEsParaProfesional, que ya causó un bug real en producción -- a
// 'trabajo_finalizacion_rechazada' le faltaba estar en _tiposParaProfesional,
// así que esa notificación nunca llegaba al profesional y, de haberlo
// hecho, lo habría mandado a la pantalla del propietario (a la que no tiene
// acceso) en vez de a la suya. Esta lista es la única fuente de verdad de
// hacia dónde navega cada tipo de notificación (ver
// services/notificacion_router.dart) -- un tipo nuevo sin clasificar aquí
// es exactamente la misma clase de bug.
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/notificacion.dart';

void main() {
  group('tipoEsParaProfesional', () {
    const tiposParaProfesional = {
      'presupuesto_aceptado',
      'presupuesto_rechazado',
      'cambio_alcance_aprobado',
      'cambio_alcance_rechazado',
      'pago_registrado',
      'trabajo_finalizacion_rechazada',
    };

    const tiposParaPropietario = {
      'presupuesto_enviado',
      'cambio_alcance_solicitado',
      'trabajo_finalizado',
      'trabajo_pendiente_confirmacion',
    };

    for (final tipo in tiposParaProfesional) {
      test('"$tipo" es para el profesional', () {
        expect(tipoEsParaProfesional(tipo), isTrue);
      });
    }

    for (final tipo in tiposParaPropietario) {
      test('"$tipo" es para el propietario, no el profesional', () {
        expect(tipoEsParaProfesional(tipo), isFalse);
      });
    }

    test('un tipo desconocido no se clasifica como profesional por defecto', () {
      expect(tipoEsParaProfesional('tipo_que_no_existe'), isFalse);
    });
  });

  group('Notificacion.fromDoc', () {
    test('esParaProfesional delega en tipoEsParaProfesional', () {
      const n = Notificacion(
        id: 'n1',
        tipo: 'pago_registrado',
        titulo: 'Te han registrado un pago',
        cuerpo: '100 €',
        leida: false,
      );
      expect(n.esParaProfesional, isTrue);
    });
  });
}
