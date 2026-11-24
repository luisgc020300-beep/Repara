// test/screens/elemento_resumen_pdf_visual_test.dart
//
// Verificación visual manual del expediente PDF de un elemento (CEO,
// noviembre 2026, rediseño del PDF) -- NO es un test de regresión
// automático con expects: genera PDF de verdad con datos sintéticos
// (ningún dato real de Firestore) que cubren los 7 escenarios pedidos en
// la especificación, y los guarda en disco para inspeccionarlos con el
// visor de PDF. Sirve el par de imágenes de prueba por un servidor HTTP
// local (loopback) para ejercer el mismo camino real de descarga de fotos
// (descargarImagenesPdf) que usa la app, sin tocar ningún código de
// producción solo para la prueba.
//
// Ejecutar: flutter test test/screens/elemento_resumen_pdf_visual_test.dart
// Los PDF se guardan en build/elemento_pdf_visual/*.pdf (ruta impresa al
// terminar cada caso).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara_core/cambio_alcance.dart';
import 'package:repara_core/documento.dart';
import 'package:repara_core/pago.dart';
import 'package:repara_core/registro.dart';

import 'package:repara_hogar/models/casa.dart';
import 'package:repara_hogar/models/elemento.dart';
import 'package:repara_hogar/screens/elemento_resumen_pdf.dart';
import 'package:repara_hogar/widgets/pdf_trabajo.dart';

// Generador propio de un PNG RGB sólido pequeño -- más fiable que copiar de
// memoria una secuencia de bytes "PNG mínimo conocido" (la primera versión
// de este archivo lo intentó así y el decodificador del paquete `pdf` la
// rechazó: "Unable decode the image"). CRC32 estándar de PNG/zlib.
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
    8, 2, 0, 0, 0, // profundidad 8, color RGB, sin filtro/entrelazado especial
  ];
  final cruda = <int>[];
  for (var y = 0; y < alto; y++) {
    cruda.add(0); // sin filtro en esta línea
    for (var x = 0; x < ancho; x++) {
      cruda
        ..add(r)
        ..add(g)
        ..add(b);
    }
  }
  final idat = ZLibCodec().encode(cruda);
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // firma PNG
    ..._chunkPng('IHDR', ihdr),
    ..._chunkPng('IDAT', idat),
    ..._chunkPng('IEND', const []),
  ]);
}

final _pngMinimo = _pngSolido(120, 90, 0x8A, 0xA6, 0xC2);

Future<HttpServer> _servidorDeFotos() async {
  final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  servidor.listen((req) {
    req.response
      ..headers.contentType = ContentType('image', 'png')
      ..add(_pngMinimo)
      ..close();
  });
  return servidor;
}

const _casa = Casa(
  id: 'casa-test',
  nombre: 'Casa de Prueba',
  ownerUid: 'uid-owner',
  members: ['uid-owner'],
  memberProfiles: {},
);

Future<void> _guardar(String nombre, Uint8List bytes) async {
  final dir = Directory('build/elemento_pdf_visual');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$nombre.pdf');
  await file.writeAsBytes(bytes);
  // ignore: avoid_print
  print('PDF generado: ${file.absolute.path} (${bytes.length} bytes)');
}

void main() {
  // cargarTemaPdfUnicode() carga la fuente Unicode como asset de Flutter
  // (rootBundle) -- necesita el binding de test inicializado, igual que
  // cualquier otra prueba que toque el asset bundle. Pero inicializar ese
  // binding instala también un HttpOverrides propio del entorno de test
  // que intercepta cualquier socket HTTP real y lo responde con 400 Bad
  // Request -- un comportamiento puramente del arnés de pruebas de
  // Flutter, nunca presente en la app real. Se desactiva justo después
  // para poder ejercer el camino real de descarga de fotos
  // (descargarImagenesPdf) contra el servidor HTTP local de abajo.
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late HttpServer servidor;
  late String fotoUrl1;
  late String fotoUrl2;

  setUpAll(() async {
    // La app real lo hace en main.dart al arrancar -- el entorno de test no
    // pasa por ahí, así que hay que inicializarlo aquí para poder usar
    // DateFormat con locale 'es_ES' (ver ElementoResumenPdf.construirBytes).
    await initializeDateFormatting('es_ES');
    servidor = await _servidorDeFotos();
    fotoUrl1 = 'http://127.0.0.1:${servidor.port}/foto1.png';
    fotoUrl2 = 'http://127.0.0.1:${servidor.port}/foto2.png';
  });

  tearDownAll(() async {
    await servidor.close(force: true);
  });

  // ----------------------------------------------------------------------
  // Escenario 1: elemento con pocos registros.
  // Escenario 7 (parcial): información incompleta -- sin foto de portada,
  // sin descripción en el único registro, sin cambios de alcance.
  // ----------------------------------------------------------------------
  test('escenario: elemento con pocos registros e información incompleta', () async {
    const elemento = Elemento(
      id: 'elem-1',
      nombre: 'Termo eléctrico',
      // Sin habitacionId, sin marca/modelo, sin fechaInstalacion, sin
      // coste, sin profesionalNombre, sin garantía, sin mantenimiento --
      // deliberadamente casi vacío (escenario 7).
    );
    final registro = Registro(
      id: 'reg-1',
      elementoNombre: elemento.nombre,
      tipo: TipoRegistro.compra,
      esConProfesional: false,
      titulo: 'Compra del termo',
      estado: EstadoRegistro.terminado,
      fecha: DateTime(2026, 3, 10),
      // Sin descripción, sin coste, sin fotos.
    );
    final bytes = await ElementoResumenPdf.construirBytes(
      casa: _casa,
      elemento: elemento,
      ubicacion: null,
      trabajos: [TrabajoConDetalle(registro: registro)],
    );
    expect(bytes, isNotEmpty);
    await _guardar('1_pocos_registros_incompleto', bytes);
  });

  // ----------------------------------------------------------------------
  // Escenarios 2, 3, 4, 5 y 6 combinados: numerosos registros, estados
  // mixtos (terminado/en curso/pendiente de pago/pendiente de
  // confirmación), varios pagos en una misma intervención, muchas
  // fotografías repartidas entre varias intervenciones, y documentos
  // vinculados (incluido uno "pendiente" de IA que NO debe aparecer).
  // ----------------------------------------------------------------------
  test(
    'escenario: numerosos registros, estados mixtos, varios pagos, muchas fotos y documentos',
    () async {
      final elemento = Elemento(
        id: 'elem-2',
        nombre: 'Pérgola bioclimática',
        habitacionId: 'hab-1',
        marca: 'Lumon',
        modelo: 'Bioclim Pro X200 con lamas motorizadas de aluminio',
        fechaInstalacion: DateTime(2023, 6, 1),
        coste: 8900,
        profesionalNombre: 'Aluminios del Sur S.L.',
        garantiaHasta: DateTime.now().add(const Duration(days: 12)),
        intervaloMantenimientoMeses: 12,
        proximoMantenimiento: DateTime.now().add(const Duration(days: 45)),
      );

      final trabajos = <TrabajoConDetalle>[
        // Terminado, con varios pagos (escenario 4) y varias fotos
        // (escenario 5).
        TrabajoConDetalle(
          registro: Registro(
            id: 'reg-pergola-1',
            elementoNombre: elemento.nombre,
            tipo: TipoRegistro.instalacion,
            esConProfesional: true,
            titulo: 'Instalación completa de la pérgola',
            estado: EstadoRegistro.terminado,
            fecha: DateTime(2023, 6, 1),
            descripcion:
                'Instalación de la estructura, motorización de las lamas y '
                'conexión eléctrica a cuadro independiente.',
            presupuesto: 8900,
            profesionalNombre: 'Aluminios del Sur S.L.',
            profesionales: const [
              ProfesionalRegistro(nombre: 'Aluminios del Sur S.L.', telefono: '600111222'),
            ],
            fotoUrls: [fotoUrl1, fotoUrl2, fotoUrl1, fotoUrl2, fotoUrl1, fotoUrl2],
          ),
          pagos: [
            Pago(
              id: 'p1',
              fecha: DateTime(2023, 5, 20),
              importe: 3000,
              concepto: 'Señal',
              metodo: MetodoPago.transferencia,
            ),
            Pago(
              id: 'p2',
              fecha: DateTime(2023, 6, 1),
              importe: 4000,
              concepto: 'Segundo pago a mitad de obra',
              metodo: MetodoPago.bizum,
            ),
            Pago(
              id: 'p3',
              fecha: DateTime(2023, 6, 15),
              importe: 1900,
              concepto: 'Liquidación final',
              metodo: MetodoPago.efectivo,
            ),
          ],
          cambios: [
            const CambioAlcance(
              id: 'ca1',
              titulo: 'Motor adicional para toldo lateral',
              estado: EstadoCambioAlcance.aprobado,
              importeAdicional: 450,
            ),
          ],
        ),
        // Pendiente de pago (requiere atención).
        TrabajoConDetalle(
          registro: Registro(
            id: 'reg-pergola-2',
            elementoNombre: elemento.nombre,
            tipo: TipoRegistro.reparacion,
            esConProfesional: true,
            titulo: 'Reparación de motor de lamas',
            estado: EstadoRegistro.pendientePago,
            fecha: DateTime(2024, 9, 12),
            descripcion: 'Sustitución del motor de la lama central, que no respondía.',
            presupuesto: 320,
            profesionalNombre: 'Aluminios del Sur S.L.',
            fotoUrls: [fotoUrl1],
          ),
          pagos: [
            Pago(id: 'p4', fecha: DateTime(2024, 9, 12), importe: 150, metodo: MetodoPago.bizum),
          ],
        ),
        // Pendiente de confirmación (requiere atención).
        TrabajoConDetalle(
          registro: Registro(
            id: 'reg-pergola-3',
            elementoNombre: elemento.nombre,
            tipo: TipoRegistro.mantenimiento,
            esConProfesional: true,
            titulo: 'Revisión anual de motores y sellado',
            estado: EstadoRegistro.pendienteConfirmacion,
            fecha: DateTime(2025, 6, 2),
            presupuesto: 180,
            profesionalNombre: 'Aluminios del Sur S.L.',
          ),
        ),
        // En curso, sin profesional todavía.
        TrabajoConDetalle(
          registro: Registro(
            id: 'reg-pergola-4',
            elementoNombre: elemento.nombre,
            tipo: TipoRegistro.averia,
            esConProfesional: false,
            titulo: 'Lama atascada en posición cerrada',
            estado: EstadoRegistro.enCurso,
            fecha: DateTime.now().subtract(const Duration(days: 3)),
            descripcion: 'A la espera de que venga el técnico a revisarla.',
          ),
        ),
        // Terminado, sin coste ni pagos (para comprobar que el bloque
        // económico de la tarjeta no aparece cuando no hay nada que
        // mostrar).
        TrabajoConDetalle(
          registro: Registro(
            id: 'reg-pergola-5',
            elementoNombre: elemento.nombre,
            tipo: TipoRegistro.nota,
            esConProfesional: false,
            titulo: 'Limpieza anual de lamas (hecha por el propietario)',
            estado: EstadoRegistro.terminado,
            fecha: DateTime(2024, 4, 1),
          ),
        ),
      ];
      // Numerosos registros (escenario 2): añade varios registros simples
      // más para forzar más de una página de historial.
      for (var i = 0; i < 10; i++) {
        trabajos.add(
          TrabajoConDetalle(
            registro: Registro(
              id: 'reg-pergola-extra-$i',
              elementoNombre: elemento.nombre,
              tipo: TipoRegistro.nota,
              esConProfesional: false,
              titulo: 'Anotación de seguimiento número $i',
              estado: EstadoRegistro.terminado,
              fecha: DateTime(2024, 1, 1).add(Duration(days: i * 20)),
              descripcion: i.isEven
                  ? 'Revisión visual rutinaria sin incidencias.'
                  : null,
            ),
          ),
        );
      }

      final documentos = [
        Documento(
          id: 'doc-1',
          url: 'http://example.invalid/factura1.pdf',
          nombreArchivo: 'Factura instalación pérgola.pdf',
          tipo: TipoDocumento.factura,
          fecha: DateTime(2023, 6, 1),
          importe: 8900,
          registroId: 'reg-pergola-1',
          estadoIA: EstadoIA.confirmado,
        ),
        Documento(
          id: 'doc-2',
          url: 'http://example.invalid/garantia.pdf',
          nombreArchivo: 'Garantía fabricante Lumon.pdf',
          tipo: TipoDocumento.garantia,
          fecha: DateTime(2023, 6, 1),
          estadoIA: EstadoIA.manual,
        ),
        // Borrador sin confirmar -- NO debe aparecer en el expediente.
        Documento(
          id: 'doc-3',
          url: 'http://example.invalid/borrador.jpg',
          nombreArchivo: 'foto_recibo_sin_revisar.jpg',
          tipo: TipoDocumento.otro,
          estadoIA: EstadoIA.pendiente,
        ),
      ];

      final bytes = await ElementoResumenPdf.construirBytes(
        casa: _casa,
        elemento: elemento,
        ubicacion: 'Jardín',
        trabajos: trabajos,
        documentos: documentos,
      );
      expect(bytes, isNotEmpty);
      await _guardar('2_numerosos_mixto_pagos_fotos_documentos', bytes);
    },
  );
}
