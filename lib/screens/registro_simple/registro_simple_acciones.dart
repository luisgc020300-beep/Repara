// lib/screens/registro_simple/registro_simple_acciones.dart
//
// Acciones rápidas de un registro simple (CEO, octubre 2026) -- solo las
// que ya existían y tienen sentido en esta pantalla: registrar un pago
// (la más importante si queda saldo, ver pagos_section.dart), escanear un
// documento (nuevo_documento_flow.dart), compartir el resumen por texto
// (ya existía, ver _compartirResumen en registro_detail_screen.dart) y
// descargar el PDF nuevo. Nada de "contactar con el profesional" -- un
// registro simple no tiene ningún profesional con cuenta en Repara al
// otro lado, inventar ese botón aquí prometería algo que no existe.
import 'package:flutter/material.dart';

import '../../models/casa.dart';
import '../../models/pago.dart';
import '../../models/registro.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';
import '../../widgets/ios_list.dart';
import '../nuevo_documento_flow.dart';
import '../pago_detail_screen.dart';
import 'registro_resumen_pdf.dart';

class RegistroSimpleAcciones extends StatefulWidget {
  const RegistroSimpleAcciones({
    required this.casa,
    required this.elementoId,
    required this.registro,
    required this.pagos,
    required this.totalPagado,
    required this.onCompartir,
    super.key,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;
  final List<Pago> pagos;
  final double totalPagado;
  final VoidCallback onCompartir;

  @override
  State<RegistroSimpleAcciones> createState() => _RegistroSimpleAccionesState();
}

class _RegistroSimpleAccionesState extends State<RegistroSimpleAcciones> {
  bool _generandoPdf = false;

  double? get _saldo {
    final deuda = montoDebidoRegistro(widget.registro);
    if (deuda == null) return null;
    return (deuda - widget.totalPagado).clamp(0, double.infinity).toDouble();
  }

  Future<void> _descargarPdf() async {
    setState(() => _generandoPdf = true);
    try {
      await RegistroResumenPdf.descargar(
        context,
        registro: widget.registro,
        casa: widget.casa,
        pagos: widget.pagos,
        totalPagado: widget.totalPagado,
      );
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo generar el PDF.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saldo = _saldo;
    final conSaldoPendiente = saldo != null && saldo > 0.01;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones rápidas',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        if (conSaldoPendiente)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PagoDetailScreen(
                    casaId: widget.casa.id,
                    elementoId: widget.elementoId,
                    registroId: widget.registro.id,
                    registroTitulo: widget.registro.titulo,
                    presupuesto: null,
                    editable: true,
                    conceptoSugerido: 'Pago ${widget.pagos.length + 1}',
                  ),
                ),
              ),
              icon: const Icon(Icons.payment_outlined, size: 18),
              label: const Text('Registrar pago'),
            ),
          ),
        if (conSaldoPendiente) const SizedBox(height: 10),
        IosSection(
          rows: [
            IosRow(
              icon: Icons.document_scanner_outlined,
              iconColor: context.colors.brand,
              title: 'Añadir documento',
              onTap: () => iniciarNuevoDocumento(
                context,
                casaId: widget.casa.id,
                elementoId: widget.elementoId,
                registroId: widget.registro.id,
              ),
            ),
            IosRow(
              icon: Icons.ios_share_outlined,
              iconColor: context.colors.brand,
              title: 'Compartir resumen',
              onTap: widget.onCompartir,
            ),
            IosRow(
              icon: Icons.picture_as_pdf_outlined,
              iconColor: context.colors.brand,
              title: 'Descargar PDF',
              trailing: _generandoPdf
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.brand,
                      ),
                    )
                  : null,
              onTap: _generandoPdf ? null : _descargarPdf,
            ),
          ],
        ),
      ],
    );
  }
}
