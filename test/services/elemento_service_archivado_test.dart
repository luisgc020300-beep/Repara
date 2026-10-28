// test/services/elemento_service_archivado_test.dart
//
// Archivado de elementos (auditoría R5, octubre 2026): filtrado en CLIENTE,
// nunca con un .where('archivado', ...) de Firestore -- una query de
// igualdad no encuentra los documentos a los que les falta el campo, así
// que filtrar en servidor habría escondido de golpe todos los elementos
// antiguos. Usa FakeFirebaseFirestore, nada de Firebase real; archivar()/
// restaurar() en sí (que llaman a una Cloud Function real) no se prueban
// aquí -- eso vive en functions-tests/elementos.test.js, contra el
// emulador real.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/elemento.dart';
import 'package:repara/services/elemento_service.dart';

void main() {
  tearDown(() => ElementoService.debugFirestoreOverride = null);

  test(
    'un elemento antiguo sin el campo "archivado" se interpreta como activo',
    () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('viejo')
          .set({'nombre': 'Caldera de antes de esta iteración'});
      ElementoService.debugFirestoreOverride = db;

      final activos = await ElementoService.streamElementos('c1').first;
      expect(activos, hasLength(1));
      expect(activos.single.archivado, isFalse);
    },
  );

  test(
    'streamElementos() no incluye por defecto los elementos archivados',
    () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('activo')
          .set({'nombre': 'Activo'});
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('archivado')
          .set({
            'nombre': 'Archivado',
            'archivado': true,
            'archivadoPorUid': 'u1',
          });
      ElementoService.debugFirestoreOverride = db;

      final activos = await ElementoService.streamElementos('c1').first;
      expect(activos.map((e) => e.id), ['activo']);

      final todos = await ElementoService.streamElementos(
        'c1',
        incluirArchivados: true,
      ).first;
      expect(todos, hasLength(2));
    },
  );

  test(
    'streamElementosArchivados() solo devuelve los que están archivados',
    () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('activo')
          .set({'nombre': 'Activo'});
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('archivado')
          .set({'nombre': 'Archivado', 'archivado': true});
      ElementoService.debugFirestoreOverride = db;

      final archivados = await ElementoService.streamElementosArchivados(
        'c1',
      ).first;
      expect(archivados, hasLength(1));
      expect(archivados.single.id, 'archivado');
    },
  );

  test(
    'Elemento.fromDoc lee archivadoAt/archivadoPorUid cuando existen',
    () async {
      final db = FakeFirebaseFirestore();
      final ahora = DateTime(2026, 10, 15);
      await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('e1')
          .set({
            'nombre': 'Caldera',
            'archivado': true,
            'archivadoAt': Timestamp.fromDate(ahora),
            'archivadoPorUid': 'u1',
          });
      final doc = await db
          .collection('casas')
          .doc('c1')
          .collection('elementos')
          .doc('e1')
          .get();
      final elemento = Elemento.fromDoc(doc);
      expect(elemento.archivado, isTrue);
      expect(elemento.archivadoPorUid, 'u1');
    },
  );
}
