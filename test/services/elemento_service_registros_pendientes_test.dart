// test/services/elemento_service_registros_pendientes_test.dart
//
// registrosConTrabajoPendiente() -- trasladado desde registro_service_test.dart
// (Fase 1, Grupo 6A, noviembre 2026): el método es un cruce de Elemento +
// Registro, pero vive en ElementoService porque su única razón de ser es
// exclusiva de Hogar (el banner de "Trabajos pendientes" de Inicio) -- ver
// la nota en elemento_service.dart. Contra un Firestore falso, ver también
// el seam debugFirestoreOverride de RegistroService (lo usa internamente
// para leer los registros de cada elemento).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara_core/registro.dart';

void main() {
  const casaId = 'casa-1';
  const elementoId = 'elemento-1';

  tearDown(() {
    RegistroService.debugFirestoreOverride = null;
    ElementoService.debugFirestoreOverride = null;
  });

  Registro registro({
    String titulo = 'Avería',
    EstadoRegistro estado = EstadoRegistro.nuevo,
  }) => Registro(
    id: '',
    elementoNombre: 'Caldera',
    tipo: TipoRegistro.averia,
    esConProfesional: false,
    titulo: titulo,
    estado: estado,
    fecha: DateTime(2026, 1, 1),
  );

  test(
    'registrosConTrabajoPendiente() cuenta registros con profesional sin cerrar',
    () async {
      final db = FakeFirebaseFirestore();
      RegistroService.debugFirestoreOverride = db;
      ElementoService.debugFirestoreOverride = db;

      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .set({'nombre': 'Caldera', 'createdAt': Timestamp.now()});
      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .add({
            ...registro(estado: EstadoRegistro.enCurso).toMap(),
            'esConProfesional': true,
            'fecha': Timestamp.fromDate(DateTime(2026, 2, 1)),
          });
      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .add({
            ...registro(estado: EstadoRegistro.terminado).toMap(),
            'esConProfesional': true,
            'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });

      final pendientes = await ElementoService.registrosConTrabajoPendiente(
        casaId,
      );
      expect(
        pendientes,
        hasLength(1),
      ); // el terminado no cuenta, el en curso sí
    },
  );

  // CEO, octubre 2026: "Trabajos pendientes" (Inicio) mostraba siempre el
  // icono genérico, aunque el registro tuviera foto -- faltaba propagar
  // r.fotos (fotoUrl heredado o fotoUrls nuevo) en el record que alimenta
  // esa pantalla.
  test(
    'registrosConTrabajoPendiente() propaga la primera foto del registro, con fotoUrl heredado o con fotoUrls',
    () async {
      final db = FakeFirebaseFirestore();
      RegistroService.debugFirestoreOverride = db;
      ElementoService.debugFirestoreOverride = db;

      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .set({'nombre': 'Pérgolas', 'createdAt': Timestamp.now()});
      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .add({
            ...registro(estado: EstadoRegistro.enCurso).toMap(),
            'esConProfesional': true,
            'fecha': Timestamp.fromDate(DateTime(2026, 2, 1)),
            'fotoUrl': 'https://example.com/antigua.jpg',
          });
      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .add({
            ...registro(estado: EstadoRegistro.pendientePago).toMap(),
            'fecha': Timestamp.fromDate(DateTime(2026, 2, 2)),
            'fotoUrls': [
              'https://example.com/primera.jpg',
              'https://example.com/segunda.jpg',
            ],
          });

      final pendientes = await ElementoService.registrosConTrabajoPendiente(
        casaId,
      );
      expect(pendientes, hasLength(2));
      expect(pendientes[0].fotoUrl, 'https://example.com/antigua.jpg');
      expect(pendientes[1].fotoUrl, 'https://example.com/primera.jpg');
    },
  );

  // CEO, octubre 2026: antes, un elemento con varios registros pendientes a
  // la vez (p.ej. dos instalaciones y una reforma sobre "Pérgolas") solo
  // mostraba el más antiguo -- el resto desaparecía del aviso de Inicio sin
  // ningún indicio de que había más. Ahora cuenta cada registro pendiente
  // por separado, aunque compartan elemento.
  test(
    'registrosConTrabajoPendiente() cuenta CADA registro pendiente, no solo uno por elemento',
    () async {
      final db = FakeFirebaseFirestore();
      RegistroService.debugFirestoreOverride = db;
      ElementoService.debugFirestoreOverride = db;

      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .set({'nombre': 'Pérgolas', 'createdAt': Timestamp.now()});
      final registros = db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros');
      await registros.add({
        ...registro(
          titulo: 'Reforma/Mejora',
          estado: EstadoRegistro.enCurso,
        ).toMap(),
        'esConProfesional': true,
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
      });
      await registros.add({
        ...registro(
          titulo: 'Instalación placa de madera',
          estado: EstadoRegistro.pendientePago,
        ).toMap(),
        'esConProfesional': false,
        'coste': 2000,
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 30)),
      });
      await registros.add({
        ...registro(
          titulo: 'Instalación placa de metal',
          estado: EstadoRegistro.pendientePago,
        ).toMap(),
        'esConProfesional': false,
        'coste': 2000,
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 31)),
      });

      final pendientes = await ElementoService.registrosConTrabajoPendiente(
        casaId,
      );
      expect(pendientes, hasLength(3));
      expect(pendientes.map((p) => p.registroTitulo), [
        'Reforma/Mejora', // la más antigua sale primero
        'Instalación placa de madera',
        'Instalación placa de metal',
      ]);
    },
  );

  // CEO, octubre 2026: "terminado" exige trabajo Y pago -- un registro
  // SIMPLE (sin profesional) en pendientePago también debe salir en el
  // aviso de Inicio, no solo los que tienen profesional.
  test(
    'registrosConTrabajoPendiente() también cuenta un registro simple en pago pendiente',
    () async {
      final db = FakeFirebaseFirestore();
      RegistroService.debugFirestoreOverride = db;
      ElementoService.debugFirestoreOverride = db;

      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .set({'nombre': 'Caldera', 'createdAt': Timestamp.now()});
      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .add({
            ...registro(estado: EstadoRegistro.pendientePago).toMap(),
            'esConProfesional': false,
            'coste': 2000,
            'fecha': Timestamp.fromDate(DateTime(2026, 2, 1)),
          });

      final pendientes = await ElementoService.registrosConTrabajoPendiente(
        casaId,
      );
      expect(pendientes, hasLength(1));
    },
  );
}
