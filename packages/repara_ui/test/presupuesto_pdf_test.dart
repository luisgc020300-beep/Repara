// packages/repara_ui/test/presupuesto_pdf_test.dart
//
// Documento de presupuesto en PDF (ampliación REPARA Pro, Fase 3, noviembre
// 2026): prueba de humo -- construye bytes de verdad sin lanzar, con y sin
// los campos opcionales (casaNombre no siempre está disponible del lado
// profesional, ver presupuestos_section.dart). También es la prueba real de
// que la fuente Unicode se carga bien como asset DEL PROPIO PAQUETE (ver
// pdf_fuente_unicode.dart, Fase 2B.5) -- si la ruta 'packages/repara_ui/...'
// estuviera mal, esto fallaría con un error de asset no encontrado.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara_core/presupuesto.dart';
import 'package:repara_ui/presupuesto_pdf.dart';

void main() {
  // testWidgets, no test: cargarTemaPdfUnicode() carga la fuente como asset
  // (rootBundle), que exige un binding de Flutter inicializado -- testWidgets
  // lo hace por nosotros, igual que el resto de pruebas de PDF del repo
  // (ver expediente_vivienda_pdf_test.dart en la app).
  setUpAll(() => initializeDateFormatting('es_ES'));

  testWidgets('construirBytes() genera un PDF no vacío con todos los campos', (
    tester,
  ) async {
    final presupuesto = Presupuesto(
      id: 'p1',
      numero: 1,
      version: 1,
      estado: EstadoPresupuesto.aceptado,
      lineas: const [
        LineaPresupuesto(
          descripcion: 'Desplazamiento',
          cantidad: 1,
          precioUnitario: 25,
          ivaPorcentaje: 21,
        ),
        LineaPresupuesto(
          descripcion: 'Mano de obra',
          cantidad: 2,
          precioUnitario: 40,
          ivaPorcentaje: 21,
        ),
      ],
      subtotal: 105,
      iva: 22.05,
      total: 127.05,
      notas: 'Incluye desplazamiento hasta la vivienda.',
      fechaCreacion: DateTime(2026, 11, 1),
      fechaEnvio: DateTime(2026, 11, 2),
    );

    final bytes = await PresupuestoPdf.construirBytes(
      presupuesto: presupuesto,
      registroTitulo: 'Revisión caldera',
      elementoNombre: 'Caldera',
      casaNombre: 'Casa Norte',
      profesionalNombre: 'Fontanería García',
    );

    expect(bytes, isNotEmpty);
  });

  testWidgets(
    'construirBytes() no lanza cuando faltan los campos opcionales (lado profesional, sin casaNombre)',
    (tester) async {
      final presupuesto = Presupuesto(
        id: 'p2',
        numero: 1,
        version: 1,
        estado: EstadoPresupuesto.borrador,
        lineas: const [
          LineaPresupuesto(
            descripcion: 'Revisión',
            cantidad: 1,
            precioUnitario: 50,
            ivaPorcentaje: 21,
          ),
        ],
        subtotal: 50,
        iva: 10.5,
        total: 60.5,
      );

      final bytes = await PresupuestoPdf.construirBytes(
        presupuesto: presupuesto,
        registroTitulo: 'Gotera',
      );

      expect(bytes, isNotEmpty);
    },
  );
}
