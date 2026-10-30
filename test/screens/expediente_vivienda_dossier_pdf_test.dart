// test/screens/expediente_vivienda_dossier_pdf_test.dart
//
// Dossier completo de la vivienda (CEO, octubre 2026) -- ExpedienteVivienda
// Pdf.construirBytes es una función Dart pura (modelos + helpers, sin
// BuildContext ni Printing.layoutPdf), así que se puede llamar directamente
// desde un test() normal (no testWidgets()) -- sin FakeFirebaseFirestore,
// sin pantalla, solo los modelos reales construidos a mano. Esto permite
// probar de verdad que el PDF se genera sin reventar, con datos ricos y con
// una vivienda casi vacía, y que un fallo de red al traer una foto no tira
// abajo el resto del documento (aquí no hay mocking de HttpClient como en
// testWidgets() -- una URL que no resuelve de verdad falla rápido y
// _descargarImagen ya lo captura, así que sirve como prueba real de ese
// camino, no solo simulada).
//
// NO PROBADO AQUÍ (limitación real, no simulada): el contenido exacto del
// PDF (qué texto cae en qué página) no se puede aserção sin un extractor de
// texto de PDF, que este proyecto no tiene y el encargo pide no añadir
// herramientas solo por comodidad. Se verifica que el PDF es válido
// (cabecera %PDF, tamaño no vacío) y que la generación no lanza con
// distintas combinaciones de datos -- la inspección visual real del
// contenido se hizo aparte, escribiendo los bytes a un fichero y
// leyéndolo con la herramienta de lectura de PDF (ver informe final).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/cambio_alcance.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/models/documento.dart';
import 'package:repara/models/elemento.dart';
import 'package:repara/models/habitacion.dart';
import 'package:repara/models/pago.dart';
import 'package:repara/models/registro.dart';
import 'package:repara/screens/expediente_vivienda_pdf.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Casa de Prueba',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

void _esperarPdfValido(List<int> bytes) {
  expect(bytes, isNotEmpty);
  // Cabecera estándar de cualquier PDF válido -- confirma que el paquete
  // `pdf` produjo un documento real, no bytes vacíos o corruptos.
  expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
}

void main() {
  // No es un test() con widgets, pero PdfGoogleFonts (ver
  // _cargarTemaUnicode en expediente_vivienda_pdf.dart) consulta el
  // AssetManifest a través del binding de servicios -- sin esto, sigue
  // funcionando (cae a su propio manejo del error), pero deja un aviso
  // ruidoso en la consola de test que no aporta nada.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('es_ES'));

  test('vivienda sin ningún dato todavía genera un PDF válido, sin reventar', () async {
    final bytes = await ExpedienteViviendaPdf.construirBytes(
      casa: _casa,
      elementos: const [],
      habitaciones: const [],
      trabajos: const [],
      documentos: const [],
    );
    _esperarPdfValido(bytes);
  });

  test(
    'vivienda con varios elementos, trabajos en distintos estados, pagos, cambios de alcance y documentos genera un PDF válido',
    () async {
      final habitaciones = [
        const Habitacion(id: 'h1', nombre: 'Cocina', orden: 0),
        const Habitacion(id: 'h2', nombre: 'Baño', orden: 1),
      ];
      final elementos = [
        const Elemento(
          id: 'e1',
          nombre: 'Caldera',
          habitacionId: 'h1',
          marca: 'Vaillant',
          modelo: 'EcoTec',
        ),
        // Elemento con la mayoría de campos opcionales rellenos, incluida
        // una foto que FALLARÁ al descargar de verdad (URL inventada) --
        // prueba el camino de "foto que no carga no bloquea el resto".
        Elemento(
          id: 'e2',
          nombre: 'Placa de madera',
          habitacionId: 'h2',
          marca: 'Pérgolas del Sur',
          modelo: null,
          fechaInstalacion: DateTime(2024, 3, 1),
          coste: 600,
          profesionalNombre: 'Metalistero',
          garantiaHasta: DateTime.now().add(const Duration(days: 10)),
          fotoUrl: 'https://no-existe-de-verdad.invalid/foto.jpg',
        ),
        // Elemento con garantía ya vencida y SIN habitación asignada --
        // prueba que "ubicación" se omite en vez de mostrar un hueco vacío.
        Elemento(
          id: 'e3',
          nombre: 'Lavadora',
          garantiaHasta: DateTime.now().subtract(const Duration(days: 400)),
        ),
      ];
      final trabajos = [
        TrabajoConDetalle(
          registro: Registro(
            id: 'r1',
            elementoNombre: 'Caldera',
            tipo: TipoRegistro.reparacion,
            esConProfesional: true,
            titulo: 'Revisión anual',
            estado: EstadoRegistro.terminado,
            fecha: DateTime(2026, 2, 1),
            presupuesto: 180,
            profesionalNombre: 'Climatizaciones Pérez',
          ),
          pagos: [
            Pago(
              id: 'p1',
              fecha: DateTime(2026, 2, 2),
              importe: 180,
              concepto: 'Pago único',
              metodo: MetodoPago.bizum,
            ),
          ],
        ),
        TrabajoConDetalle(
          registro: Registro(
            id: 'r2',
            elementoNombre: 'Placa de madera',
            tipo: TipoRegistro.instalacion,
            esConProfesional: false,
            titulo: 'Instalación placa de madera',
            estado: EstadoRegistro.pendientePago,
            fecha: DateTime(2026, 3, 1),
            coste: 600,
          ),
        ),
        // Trabajo con profesional y un cambio de alcance aprobado.
        TrabajoConDetalle(
          registro: Registro(
            id: 'r3',
            elementoNombre: 'Caldera',
            tipo: TipoRegistro.sustitucion,
            esConProfesional: true,
            titulo: 'Sustitución de válvula',
            estado: EstadoRegistro.enCurso,
            fecha: DateTime(2026, 5, 10),
            presupuesto: 220,
          ),
          cambios: const [
            CambioAlcance(
              id: 'ca1',
              titulo: 'Válvula adicional encontrada dañada',
              estado: EstadoCambioAlcance.aprobado,
              importeAdicional: 45,
            ),
          ],
        ),
      ];
      final documentos = [
        const Documento(
          id: 'd1',
          url: 'https://no-existe-de-verdad.invalid/factura.pdf',
          nombreArchivo: 'factura_caldera.pdf',
          tipo: TipoDocumento.factura,
          proveedor: 'Climatizaciones Pérez',
          importe: 180,
          elementoId: 'e1',
          estadoIA: EstadoIA.confirmado,
        ),
        // Documento todavía sin confirmar (borrador de IA) -- debe quedar
        // fuera del dossier (ver filtro en construirBytes).
        const Documento(
          id: 'd2',
          url: 'https://no-existe-de-verdad.invalid/borrador.jpg',
          nombreArchivo: 'borrador.jpg',
          tipo: TipoDocumento.otro,
          estadoIA: EstadoIA.pendiente,
        ),
      ];

      final bytes = await ExpedienteViviendaPdf.construirBytes(
        casa: _casa,
        elementos: elementos,
        habitaciones: habitaciones,
        trabajos: trabajos,
        documentos: documentos,
      );
      _esperarPdfValido(bytes);

      // Guarda una copia real para inspección visual manual -- fuera del
      // repositorio (scratchpad), no es un fichero que deba persistir en
      // el proyecto ni formar parte de la suite de aserciones.
      final rutaInspeccion = Platform.environment['REPARA_DOSSIER_PDF_OUT'];
      if (rutaInspeccion != null && rutaInspeccion.isNotEmpty) {
        await File(rutaInspeccion).writeAsBytes(bytes);
      }
    },
  );

  test(
    'un trabajo sin profesional, sin pagos y sin cambios de alcance no revienta (campos opcionales ausentes)',
    () async {
      final bytes = await ExpedienteViviendaPdf.construirBytes(
        casa: _casa,
        elementos: const [
          Elemento(id: 'e1', nombre: 'Freidora de aire'),
        ],
        habitaciones: const [],
        trabajos: [
          TrabajoConDetalle(
            registro: Registro(
              id: 'r1',
              elementoNombre: 'Freidora de aire',
              tipo: TipoRegistro.compra,
              esConProfesional: false,
              titulo: 'Compra',
              estado: EstadoRegistro.terminado,
              fecha: DateTime(2026, 1, 1),
            ),
          ),
        ],
        documentos: const [],
      );
      _esperarPdfValido(bytes);
    },
  );
}
