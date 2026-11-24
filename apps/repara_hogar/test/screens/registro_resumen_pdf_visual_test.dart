// test/screens/registro_resumen_pdf_visual_test.dart
//
// Verificación visual manual del Informe de intervención (CEO, noviembre
// 2026, rediseño del PDF de un evento) -- NO es un test de regresión
// automático con expects: genera PDF de verdad con datos sintéticos
// (ningún dato real de Firestore) y los guarda en disco para inspeccionarlos
// con el visor de PDF. Mismo patrón que
// elemento_resumen_pdf_visual_test.dart: sirve las fotos de prueba por un
// servidor HTTP local (loopback) para ejercer el mismo camino real de
// descarga (descargarImagenesPdf) que usa la app.
//
// Ejecutar: flutter test test/screens/registro_resumen_pdf_visual_test.dart
// Los PDF se guardan en build/registro_pdf_visual/*.pdf (ruta impresa al
// terminar cada caso).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara_core/pago.dart';
import 'package:repara_core/registro.dart';

import 'package:repara_hogar/models/casa.dart';
import 'package:repara_hogar/screens/registro_simple/registro_resumen_pdf.dart';

// Mismo generador de PNG sólido que elemento_resumen_pdf_visual_test.dart
// (un PNG "mínimo conocido" copiado a mano no lo decodifica el paquete
// `pdf`) -- aquí además con un ancho/alto distintos por color para poder
// comprobar que el PDF respeta la proporción real de cada foto (CEO: "que
// no aparezcan deformadas").
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

// Apaisada (4:3) y vertical (3:4) a propósito -- para comprobar que el
// documento no fuerza un recorte cuadrado sobre fotos con proporciones
// distintas.
final _fotoApaisada = _pngSolido(400, 300, 0x8A, 0xA6, 0xC2);
final _fotoVertical = _pngSolido(300, 400, 0xB0, 0x8A, 0x6E);

Future<HttpServer> _servidorDeFotos() async {
  final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  servidor.listen((req) {
    final esVertical = req.uri.path.contains('vertical');
    req.response
      ..headers.contentType = ContentType('image', 'png')
      ..add(esVertical ? _fotoVertical : _fotoApaisada)
      ..close();
  });
  return servidor;
}

const _casa = Casa(
  id: 'casa-granada',
  nombre: 'Casa Granada',
  ownerUid: 'uid-owner',
  members: ['uid-owner'],
  memberProfiles: {},
);

Future<void> _guardar(String nombre, Uint8List bytes) async {
  final dir = Directory('build/registro_pdf_visual');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$nombre.pdf');
  await file.writeAsBytes(bytes);
  // ignore: avoid_print
  print('PDF generado: ${file.absolute.path} (${bytes.length} bytes)');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Ver nota de elemento_resumen_pdf_visual_test.dart: el binding de test
  // instala un HttpOverrides propio que intercepta cualquier socket HTTP
  // real -- hay que desactivarlo para poder ejercer el camino real de
  // descarga de fotos contra el servidor local de abajo.
  HttpOverrides.global = null;

  late HttpServer servidor;
  late String fotoUrl;
  late String fotoVerticalUrl;

  setUpAll(() async {
    await initializeDateFormatting('es_ES');
    servidor = await _servidorDeFotos();
    fotoUrl = 'http://127.0.0.1:${servidor.port}/foto.png';
    fotoVerticalUrl = 'http://127.0.0.1:${servidor.port}/vertical.png';
  });

  tearDownAll(() async {
    await servidor.close(force: true);
  });

  // --------------------------------------------------------------------
  // Escenario 1: el ejemplo real que dio el CEO -- "Refuerzo" en Pérgolas
  // de Casa Granada, terminado, pagado por completo con dos pagos.
  // --------------------------------------------------------------------
  test('escenario: evento terminado y pagado por completo (ejemplo real del CEO)', () async {
    final registro = Registro(
      id: 'reg-refuerzo',
      elementoNombre: 'Pérgolas',
      tipo: TipoRegistro.reforma,
      esConProfesional: true,
      titulo: 'Refuerzo',
      estado: EstadoRegistro.terminado,
      fecha: DateTime(2026, 10, 30),
      descripcion: 'Refuerzo de los laterales.',
      presupuesto: 700,
      profesionalNombre: 'Metalistero',
      profesionales: const [ProfesionalRegistro(nombre: 'Metalistero', telefono: '611222333')],
      fotoUrls: [fotoUrl],
    );
    final pagos = [
      Pago(id: 'p1', fecha: DateTime(2026, 10, 28), importe: 680, concepto: 'Material y mano de obra', metodo: MetodoPago.transferencia),
      Pago(id: 'p2', fecha: DateTime(2026, 10, 30), importe: 20, concepto: 'Ajuste final', metodo: MetodoPago.efectivo),
    ];
    final bytes = await _generarParaTest(registro: registro, pagos: pagos);
    expect(bytes, isNotEmpty);
    await _guardar('1_refuerzo_terminado_pagado', bytes);
  });

  // --------------------------------------------------------------------
  // Escenario 2: información mínima -- sin descripción, sin profesional,
  // sin coste, sin pagos, sin fotos (todos los apartados opcionales deben
  // desaparecer limpiamente, nunca mostrarse vacíos).
  // --------------------------------------------------------------------
  test('escenario: información incompleta -- solo los datos imprescindibles', () async {
    final registro = Registro(
      id: 'reg-minimo',
      elementoNombre: 'Toldo',
      tipo: TipoRegistro.nota,
      esConProfesional: false,
      titulo: 'Revisión visual',
      estado: EstadoRegistro.terminado,
      fecha: DateTime(2026, 6, 1),
    );
    final bytes = await _generarParaTest(registro: registro, pagos: const []);
    expect(bytes, isNotEmpty);
    await _guardar('2_informacion_minima', bytes);
  });

  // --------------------------------------------------------------------
  // Escenario 3: muchos pagos (la tabla debe partirse entre páginas
  // repitiendo la cabecera) y saldo pendiente (debe distinguirse con
  // claridad de "pagado por completo").
  // --------------------------------------------------------------------
  test('escenario: muchos pagos con saldo pendiente', () async {
    final registro = Registro(
      id: 'reg-muchos-pagos',
      elementoNombre: 'Piscina',
      tipo: TipoRegistro.reforma,
      esConProfesional: true,
      titulo: 'Renovación completa del vaso',
      estado: EstadoRegistro.pendientePago,
      fecha: DateTime(2026, 9, 15),
      descripcion:
          'Sustitución del liner, revisión de la depuradora y repintado de bordes. '
          'Incluye dos visitas adicionales para ajustar el nivel de cloro tras el '
          'llenado.',
      presupuesto: 6200,
      profesionales: const [
        ProfesionalRegistro(nombre: 'Piscinas Granada S.L.', telefono: '600987654'),
        ProfesionalRegistro(nombre: 'Juan (electricista de apoyo)'),
      ],
      fotoUrls: [fotoUrl, fotoVerticalUrl, fotoUrl, fotoVerticalUrl, fotoUrl],
    );
    final pagos = [
      for (var i = 0; i < 14; i++)
        Pago(
          id: 'p$i',
          fecha: DateTime(2026, 7, 1).add(Duration(days: i * 10)),
          importe: 350 + (i * 5),
          concepto: i.isEven ? 'Plazo mensual' : null,
          metodo: MetodoPago.values[i % MetodoPago.values.length],
        ),
    ];
    final totalPagado = pagos.fold<double>(0, (acc, p) => acc + p.importe);
    final bytes = await _generarParaTest(
      registro: registro,
      pagos: pagos,
      totalPagadoOverride: totalPagado,
    );
    expect(bytes, isNotEmpty);
    await _guardar('3_muchos_pagos_saldo_pendiente', bytes);
  });
}

// `construirBytes` es el mismo método público que usa `descargar()` en la
// app real (ver nota en registro_resumen_pdf.dart) -- aquí solo se evita
// repetir el cálculo de `totalPagado` en cada escenario.
Future<Uint8List> _generarParaTest({
  required Registro registro,
  required List<Pago> pagos,
  double? totalPagadoOverride,
}) {
  final totalPagado = totalPagadoOverride ?? pagos.fold<double>(0, (acc, p) => acc + p.importe);
  return RegistroResumenPdf.construirBytes(
    registro: registro,
    casa: _casa,
    pagos: pagos,
    totalPagado: totalPagado,
  );
}
