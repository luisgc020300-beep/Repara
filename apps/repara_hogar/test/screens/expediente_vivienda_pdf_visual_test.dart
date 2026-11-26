// test/screens/expediente_vivienda_pdf_visual_test.dart
//
// Verificación visual manual del Expediente de la vivienda (CEO, noviembre
// 2026, rediseño integral) -- NO es un test de regresión automático con
// expects: genera PDF de verdad con datos sintéticos (ningún dato real de
// Firestore) y los guarda en disco para inspeccionarlos con el visor de
// PDF. Mismo patrón que elemento_resumen_pdf_visual_test.dart y
// registro_resumen_pdf_visual_test.dart: sirve las fotos de prueba por un
// servidor HTTP local (loopback) para ejercer el mismo camino real de
// descarga (descargarImagenesPdf) que usa la app.
//
// Ejecutar: flutter test test/screens/expediente_vivienda_pdf_visual_test.dart
// Los PDF se guardan en build/expediente_pdf_visual/*.pdf (ruta impresa al
// terminar cada caso).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara_core/documento.dart';
import 'package:repara_core/pago.dart';
import 'package:repara_core/registro.dart';

import 'package:repara_hogar/models/casa.dart';
import 'package:repara_hogar/models/elemento.dart';
import 'package:repara_hogar/models/habitacion.dart';
import 'package:repara_hogar/screens/expediente_vivienda_pdf.dart';
import 'package:repara_hogar/widgets/pdf_trabajo.dart';

// Mismo generador de PNG sólido que los otros dos test visuales -- un PNG
// "mínimo conocido" copiado a mano no lo decodifica el paquete `pdf`.
final List<int> _crcTabla = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTabla[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _bigEndianUint32(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.big);

List<int> _chunkPng(String tipo, List<int> datos) {
  final tipoBytes = tipo.codeUnits;
  final cuerpo = [...tipoBytes, ...datos];
  return [
    ..._bigEndianUint32(datos.length),
    ...cuerpo,
    ..._bigEndianUint32(_crc32(cuerpo)),
  ];
}

Uint8List _pngSolido(int ancho, int alto, int r, int g, int b) {
  final ihdr = [
    ..._bigEndianUint32(ancho),
    ..._bigEndianUint32(alto),
    8, 2, 0, 0, 0,
  ];
  final cruda = <int>[];
  for (var y = 0; y < alto; y++) {
    cruda.add(0);
    for (var x = 0; x < ancho; x++) {
      cruda
        ..add(r)
        ..add(g)
        ..add(b);
    }
  }
  final idat = ZLibCodec().encode(cruda);
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ..._chunkPng('IHDR', ihdr),
    ..._chunkPng('IDAT', idat),
    ..._chunkPng('IEND', const []),
  ]);
}

final _fotoA = _pngSolido(400, 300, 0x8A, 0xA6, 0xC2);
final _fotoB = _pngSolido(300, 400, 0xB0, 0x8A, 0x6E);
final _fotoElemento = _pngSolido(320, 320, 0x9E, 0xB0, 0x8E);

Future<HttpServer> _servidorDeFotos() async {
  final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  servidor.listen((req) {
    final bytes = req.uri.path.contains('elemento')
        ? _fotoElemento
        : req.uri.path.contains('b')
            ? _fotoB
            : _fotoA;
    req.response
      ..headers.contentType = ContentType('image', 'png')
      ..add(bytes)
      ..close();
  });
  return servidor;
}

Future<void> _guardar(String nombre, Uint8List bytes) async {
  final dir = Directory('build/expediente_pdf_visual');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$nombre.pdf');
  await file.writeAsBytes(bytes);
  // ignore: avoid_print
  print('PDF generado: ${file.absolute.path} (${bytes.length} bytes)');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late HttpServer servidor;
  late String fotoA;
  late String fotoB;
  late String fotoElemento;

  setUpAll(() async {
    await initializeDateFormatting('es_ES');
    servidor = await _servidorDeFotos();
    fotoA = 'http://127.0.0.1:${servidor.port}/a.png';
    fotoB = 'http://127.0.0.1:${servidor.port}/b.png';
    fotoElemento = 'http://127.0.0.1:${servidor.port}/elemento.png';
  });

  tearDownAll(() async {
    await servidor.close(force: true);
  });

  const casaPequena = Casa(
    id: 'casa-pequena',
    nombre: 'Piso de Calle Arenal',
    ownerUid: 'uid-owner',
    members: ['uid-owner'],
    memberProfiles: {},
  );
  const casaGrande = Casa(
    id: 'casa-grande',
    nombre: 'Casa Granada',
    ownerUid: 'uid-owner',
    members: ['uid-owner'],
    memberProfiles: {},
  );

  // --------------------------------------------------------------------
  // Escenario 1: vivienda con pocos registros e información incompleta --
  // un elemento sin ubicación ni foto, un trabajo sin profesional ni
  // coste, sin documentos, sin garantías.
  // --------------------------------------------------------------------
  test('escenario: vivienda con pocos registros e información incompleta', () async {
    const elementos = [
      Elemento(id: 'el-1', nombre: 'Caldera de gas'),
    ];
    final trabajos = [
      TrabajoConDetalle(
        registro: Registro(
          id: 'r1',
          elementoNombre: 'Caldera de gas',
          tipo: TipoRegistro.mantenimiento,
          esConProfesional: false,
          titulo: 'Revisión anual',
          estado: EstadoRegistro.terminado,
          fecha: DateTime(2026, 3, 1),
        ),
      ),
    ];
    final bytes = await ExpedienteViviendaPdf.construirBytes(
      casa: casaPequena,
      elementos: elementos,
      habitaciones: const [],
      trabajos: trabajos,
      documentos: const [],
    );
    expect(bytes, isNotEmpty);
    await _guardar('1_pocos_registros_incompleto', bytes);
  });

  // --------------------------------------------------------------------
  // Escenario 2: vivienda con mucha información -- varias habitaciones,
  // elementos activos y archivados, trabajos en varios estados repartidos
  // en 3 años distintos (fuerza la agrupación por año), varios pagos por
  // trabajo, documentos de los tres tipos (incluido uno con un nombre de
  // archivo técnico -- debe aparecer con una denominación legible), y
  // garantías en los tres estados (vigente/próxima/vencida).
  // --------------------------------------------------------------------
  test('escenario: vivienda con mucha información a lo largo de varios años', () async {
    const habitaciones = [
      Habitacion(id: 'hab-salon', nombre: 'Salón', orden: 0),
      Habitacion(id: 'hab-cocina', nombre: 'Cocina', orden: 1),
      Habitacion(id: 'hab-jardin', nombre: 'Jardín', orden: 2),
    ];
    final elementos = [
      Elemento(
        id: 'el-aire',
        nombre: 'Aire acondicionado',
        habitacionId: 'hab-salon',
        marca: 'Mitsubishi',
        modelo: 'MSZ-AP',
        fechaInstalacion: DateTime(2022, 5, 1),
        coste: 1200,
        profesionalNombre: 'ClimaGranada',
        garantiaHasta: DateTime.now().add(const Duration(days: 10)), // próxima
        fotoUrl: fotoElemento,
      ),
      Elemento(
        id: 'el-nevera',
        nombre: 'Frigorífico',
        habitacionId: 'hab-cocina',
        marca: 'Balay',
        fechaInstalacion: DateTime(2020, 1, 1),
        coste: 650,
        garantiaHasta: DateTime(2022, 1, 1), // vencida
      ),
      const Elemento(
        id: 'el-horno',
        nombre: 'Horno',
        habitacionId: 'hab-cocina',
        archivado: true,
      ),
      Elemento(
        id: 'el-pergola',
        nombre: 'Pérgola bioclimática',
        habitacionId: 'hab-jardin',
        marca: 'Lumon',
        fechaInstalacion: DateTime(2023, 6, 1),
        coste: 8900,
        garantiaHasta: DateTime.now().add(const Duration(days: 600)), // vigente
      ),
    ];

    final trabajos = <TrabajoConDetalle>[
      TrabajoConDetalle(
        registro: Registro(
          id: 'r-aire-1',
          elementoNombre: 'Aire acondicionado',
          tipo: TipoRegistro.instalacion,
          esConProfesional: true,
          titulo: 'Instalación del aire acondicionado',
          estado: EstadoRegistro.terminado,
          fecha: DateTime(2022, 5, 1),
          descripcion: 'Instalación de la unidad interior y exterior en el salón.',
          presupuesto: 1200,
          profesionales: const [ProfesionalRegistro(nombre: 'ClimaGranada', telefono: '600111222')],
          fotoUrls: [fotoA, fotoB],
        ),
        pagos: [
          Pago(id: 'p1', fecha: DateTime(2022, 5, 1), importe: 1200, metodo: MetodoPago.transferencia),
        ],
      ),
      TrabajoConDetalle(
        registro: Registro(
          id: 'r-aire-2',
          elementoNombre: 'Aire acondicionado',
          tipo: TipoRegistro.mantenimiento,
          esConProfesional: true,
          titulo: 'Recarga de gas refrigerante',
          estado: EstadoRegistro.pendientePago,
          fecha: DateTime(2024, 7, 15),
          presupuesto: 180,
          profesionales: const [ProfesionalRegistro(nombre: 'ClimaGranada')],
        ),
        pagos: [
          Pago(id: 'p2', fecha: DateTime(2024, 7, 15), importe: 80, metodo: MetodoPago.bizum),
        ],
      ),
      TrabajoConDetalle(
        registro: Registro(
          id: 'r-pergola-1',
          elementoNombre: 'Pérgola bioclimática',
          tipo: TipoRegistro.instalacion,
          esConProfesional: true,
          titulo: 'Instalación completa de la pérgola',
          estado: EstadoRegistro.terminado,
          fecha: DateTime(2023, 6, 1),
          descripcion: 'Estructura, lamas motorizadas y conexión eléctrica.',
          presupuesto: 8900,
          profesionales: const [ProfesionalRegistro(nombre: 'Aluminios del Sur S.L.')],
          fotoUrls: [fotoA, fotoB, fotoA, fotoB, fotoA],
        ),
        pagos: [
          Pago(id: 'p3', fecha: DateTime(2023, 5, 20), importe: 4000, metodo: MetodoPago.transferencia),
          Pago(id: 'p4', fecha: DateTime(2023, 6, 1), importe: 4900, metodo: MetodoPago.bizum),
        ],
      ),
      TrabajoConDetalle(
        registro: Registro(
          id: 'r-horno-1',
          elementoNombre: 'Horno',
          tipo: TipoRegistro.averia,
          esConProfesional: false,
          titulo: 'Resistencia fundida',
          estado: EstadoRegistro.archivado,
          fecha: DateTime(2021, 2, 1),
          coste: 60,
        ),
      ),
      TrabajoConDetalle(
        registro: Registro(
          id: 'r-nevera-1',
          elementoNombre: 'Frigorífico',
          tipo: TipoRegistro.reparacion,
          esConProfesional: false,
          titulo: 'Cambio de junta de puerta',
          estado: EstadoRegistro.enCurso,
          fecha: DateTime.now().subtract(const Duration(days: 4)),
        ),
      ),
    ];

    final documentos = [
      Documento(
        id: 'doc-1',
        url: fotoA,
        nombreArchivo: 'image_picker_8841223344556677.jpg',
        tipo: TipoDocumento.factura,
        fecha: DateTime(2022, 5, 1),
        importe: 1200,
        proveedor: 'ClimaGranada',
        elementoId: 'el-aire',
        registroId: 'r-aire-1',
        estadoIA: EstadoIA.confirmado,
      ),
      Documento(
        id: 'doc-2',
        url: 'http://example.invalid/presupuesto.pdf',
        nombreArchivo: 'Presupuesto pérgola bioclimática.pdf',
        tipo: TipoDocumento.presupuesto,
        fecha: DateTime(2023, 5, 15),
        importe: 8900,
        elementoId: 'el-pergola',
        registroId: 'r-pergola-1',
        estadoIA: EstadoIA.manual,
      ),
      Documento(
        id: 'doc-3',
        url: 'http://example.invalid/garantia.pdf',
        nombreArchivo: 'Garantía Mitsubishi.pdf',
        tipo: TipoDocumento.garantia,
        fecha: DateTime(2022, 5, 1),
        elementoId: 'el-aire',
        estadoIA: EstadoIA.manual,
      ),
      // Borrador sin confirmar -- NO debe aparecer en el expediente.
      Documento(
        id: 'doc-4',
        url: 'http://example.invalid/borrador.jpg',
        nombreArchivo: 'foto_recibo_sin_revisar.jpg',
        tipo: TipoDocumento.otro,
        estadoIA: EstadoIA.pendiente,
      ),
    ];

    final bytes = await ExpedienteViviendaPdf.construirBytes(
      casa: casaGrande,
      elementos: elementos,
      habitaciones: habitaciones,
      trabajos: trabajos,
      documentos: documentos,
    );
    expect(bytes, isNotEmpty);
    await _guardar('2_mucha_informacion_varios_anios', bytes);
  });
}
