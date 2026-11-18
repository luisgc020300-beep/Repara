// test/services/contacto_service_test.dart
//
// ContactoService.buscarPorTelefono (organización de Contactos, noviembre
// 2026) -- evitar duplicados al añadir un contacto a mano, comparando solo
// por dígitos (mismo criterio que importar_contactos_screen.dart). Y
// Contacto.favorito, el único campo nuevo del modelo.
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
}
