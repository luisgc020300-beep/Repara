// lib/screens/pagos_section.dart
//
// Lista de pagos de un registro, con fecha e importe a simple vista --
// tocar uno abre un menú (abrir comprobante, editar datos). Eliminar un
// pago vive solo dentro de "Editar datos" (PagoDetailScreen) -- no se
// repite aquí, mismo criterio que registro_simple_acciones.dart ("se
// quitaron de aquí porque duplicaban"). Apartado propio dentro del
// registro, separado del resumen de progreso (ver widgets/progreso_pago.dart).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pago.dart';
import '../services/pago_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart' show EmptyHint;
import '../widgets/documento_abrir.dart' show abrirArchivoProtegido;
import '../widgets/ios_list.dart';
import 'nuevo_documento_flow.dart' show elegirFormaDeAnadirPago;
import 'pago_detail_screen.dart';
import 'presupuestos_section.dart' show RolEnTrabajo;

class PagosSection extends StatelessWidget {
  const PagosSection({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
    required this.registroTitulo,
    required this.presupuesto,
    required this.rol,
    super.key,
  });

  final String casaId;
  final String elementoId;
  final String registroId;
  final String registroTitulo;
  final double? presupuesto;
  final RolEnTrabajo rol;

  @override
  Widget build(BuildContext context) {
    final editable = rol == RolEnTrabajo.propietario;
    return StreamBuilder<List<Pago>>(
      stream: PagoService.streamPagos(casaId, elementoId, registroId),
      builder: (context, snapshot) {
        final pagos = snapshot.data ?? [];
        final total = pagos.fold<double>(0, (acc, p) => acc + p.importe);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Pagos',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (total > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        '(${total.toStringAsFixed(0)} €)',
                        style: ReparaText.amount(
                          context,
                        ).copyWith(fontSize: 15),
                      ),
                    ],
                  ],
                ),
                if (editable)
                  TextButton.icon(
                    onPressed: () => elegirFormaDeAnadirPago(
                      context,
                      casaId: casaId,
                      elementoId: elementoId,
                      registroId: registroId,
                      registroTitulo: registroTitulo,
                      presupuesto: presupuesto,
                      conceptoSugerido: 'Pago ${pagos.length + 1}',
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir pago'),
                  ),
              ],
            ),
            if (pagos.isEmpty)
              const EmptyHint(
                message: 'Sin pagos registrados todavía.',
                icon: Icons.payments_outlined,
              )
            else
              IosSection(
                rows: pagos
                    .map(
                      (p) => IosRow(
                        icon: Icons.payments_outlined,
                        iconColor: context.colors.brand,
                        title: p.concepto?.isNotEmpty == true
                            ? p.concepto!
                            : DateFormat('d MMM yyyy', 'es_ES').format(p.fecha),
                        subtitle: p.concepto?.isNotEmpty == true
                            ? DateFormat('d MMM yyyy', 'es_ES').format(p.fecha)
                            : null,
                        trailing: Text(
                          '${p.importe.toStringAsFixed(2)} €',
                          style: ReparaText.amount(context),
                        ),
                        showChevron: false,
                        onTap: () => mostrarAccionesPago(
                          context,
                          casaId: casaId,
                          elementoId: elementoId,
                          registroId: registroId,
                          registroTitulo: registroTitulo,
                          presupuesto: presupuesto,
                          editable: editable,
                          pago: p,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}

/// Menú de un pago: abrir comprobante, editar datos, eliminar. Lo usan
/// PagosSection (dentro del evento) y la ficha del elemento.
Future<void> mostrarAccionesPago(
  BuildContext context, {
  required String casaId,
  required String elementoId,
  required String registroId,
  required String registroTitulo,
  required double? presupuesto,
  required bool editable,
  required Pago pago,
}) {
  final tieneComprobante = (pago.comprobante ?? '').isNotEmpty;
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ReparaSpace.s4,
          ReparaSpace.s2,
          ReparaSpace.s4,
          ReparaSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: ReparaSpace.s4),
              decoration: BoxDecoration(
                color: ctx.colors.inkMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            IosSection(
              rows: [
                if (tieneComprobante)
                  IosRow(
                    icon: Icons.open_in_new,
                    iconColor: ctx.colors.brand,
                    title: 'Abrir documento',
                    onTap: () {
                      Navigator.pop(ctx);
                      abrirArchivoProtegido(context, pago.comprobante!);
                    },
                  ),
                IosRow(
                  icon: Icons.edit_outlined,
                  iconColor: ctx.colors.inkMuted,
                  title: editable ? 'Editar datos' : 'Ver datos',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PagoDetailScreen(
                          casaId: casaId,
                          elementoId: elementoId,
                          registroId: registroId,
                          registroTitulo: registroTitulo,
                          presupuesto: presupuesto,
                          editable: editable,
                          pago: pago,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
