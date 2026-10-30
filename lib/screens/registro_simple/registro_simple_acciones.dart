// lib/screens/registro_simple/registro_simple_acciones.dart
//
// Acciones rápidas de un registro simple (CEO, octubre 2026) -- solo
// compartir/exportar. "Registrar pago" y "Añadir documento" se quitaron de
// aquí porque duplicaban el "+ Añadir pago" de PagosSection y el "Escanear
// documento" de la cabecera de Documentos (misma acción, dos sitios) --
// ver _CuerpoSimple en registro_detail_screen.dart. Compartir resumen y
// Descargar PDF se muestran como botones llenos (FilledButton), no como
// filas de lista, a petición explícita del CEO.
import 'package:flutter/material.dart';

import '../../models/casa.dart';
import '../../models/pago.dart';
import '../../models/registro.dart';
import '../../widgets/app_error.dart';
import 'registro_resumen_pdf.dart';

class RegistroSimpleAcciones extends StatefulWidget {
  const RegistroSimpleAcciones({
    required this.casa,
    required this.registro,
    required this.pagos,
    required this.totalPagado,
    required this.onCompartir,
    super.key,
  });

  final Casa casa;
  final Registro registro;
  final List<Pago> pagos;
  final double totalPagado;
  final VoidCallback onCompartir;

  @override
  State<RegistroSimpleAcciones> createState() => _RegistroSimpleAccionesState();
}

class _RegistroSimpleAccionesState extends State<RegistroSimpleAcciones> {
  bool _generandoPdf = false;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones rápidas',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.onCompartir,
            icon: const Icon(Icons.ios_share_outlined, size: 18),
            label: const Text('Compartir resumen'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _generandoPdf ? null : _descargarPdf,
            icon: _generandoPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Descargar PDF'),
          ),
        ),
      ],
    );
  }
}
