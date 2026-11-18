// test/services/contacto_service_test.dart
//
// ContactoService.buscarPorTelefono (organización de Contactos, noviembre
// 2026) -- evitar duplicados al añadir un contacto a mano, comparando solo
// por dígitos (mismo criterio que importar_contactos_screen.dart). Y
// Contacto.favorito, el único campo nuevo del modelo.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_hogar/models/contacto.dart';
import 'package:repara_hogar/services/contacto_service.dart';

void main() {
  final existentes = [
    const Contacto(
      id: 'c1',
      nombre: 'Fontanería López',
      telefono: '600 11 22 33',
      tipo: TipoContacto.empresa,
    ),
    const Contacto(
      id: 'c2',
      nombre: 'Juan (electricista)',
      telefono: '611223344',
      tipo: TipoContacto.particular,
      favorito: true,
    ),
  ];

  test('buscarPorTelefono encuentra el mismo número aunque esté escrito distinto', () {
    final encontrado = ContactoService.buscarPorTelefono(existentes, '600-11-22-33');
    expect(encontrado?.id, 'c1');
  });

  test('buscarPorTelefono devuelve null si no hay ningún contacto con ese teléfono', () {
    expect(ContactoService.buscarPorTelefono(existentes, '699999999'), isNull);
  });

  test('buscarPorTelefono ignora excluirId (el propio contacto al editar)', () {
    expect(
      ContactoService.buscarPorTelefono(existentes, '600 11 22 33', excluirId: 'c1'),
      isNull,
    );
  });

  test('Contacto.favorito por defecto es false, y toMap/fromDoc lo conservan', () {
    const contacto = Contacto(
      id: 'x',
      nombre: 'Test',
      telefono: '600000000',
      tipo: TipoContacto.particular,
    );
    expect(contacto.favorito, isFalse);

    final map = contacto.copyWith(favorito: true).toMap();
    expect(map['favorito'], isTrue);
  });

  test(
    'profesionalUidVinculado se lee de Firestore pero nunca viaja en toMap() (vinculación de contactos, noviembre 2026)',
    () async {
      final db = FakeFirebaseFirestore();
      final ref = await db.collection('contactos').add({
        'nombre': 'Fontanero',
        'telefono': '600000000',
        'tipo': 'particular',
        'favorito': false,
        'profesionalUidVinculado': 'profesional-x',
      });
      final doc = await ref.get();
      final contacto = Contacto.fromDoc(doc);

      expect(contacto.profesionalUidVinculado, 'profesional-x');
      // Nunca escribible por el cliente -- si algún día se colara en
      // toMap(), firestore.rules dejaría de ser la única defensa real (ver
      // contactos/{ctid} en firestore.rules).
      expect(contacto.toMap().containsKey('profesionalUidVinculado'), isFalse);
      // copyWith también debe conservarlo -- no perderlo en una
      // actualización optimista en memoria (p.ej. al marcar favorito).
      expect(contacto.copyWith(favorito: true).profesionalUidVinculado, 'profesional-x');
    },
  );

  test(
    'un contacto sin ninguna invitación aceptada no tiene profesionalUidVinculado',
    () async {
      final db = FakeFirebaseFirestore();
      final ref = await db.collection('contactos').add({
        'nombre': 'Fontanero',
        'telefono': '600000000',
        'tipo': 'particular',
        'favorito': false,
      });
      final doc = await ref.get();
      expect(Contacto.fromDoc(doc).profesionalUidVinculado, isNull);
    },
  );
}
