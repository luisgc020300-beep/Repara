// packages/repara_ui/lib/pagos_section.dart
//
// Lista de pagos de un registro, con fecha e importe a simple vista --
// tocar uno abre un menú (abrir comprobante, adjuntar/sustituir
// comprobante, editar datos). Eliminar un pago vive solo dentro de "Editar
// datos" (PagoDetailScreen) -- no se repite aquí, mismo criterio que
// registro_simple_acciones.dart ("se quitaron de aquí porque duplicaban").
// Apartado propio dentro del registro, separado del resumen de progreso
// (ver widgets/progreso_pago.dart).
//
// [verificarAcceso]/[onAnadirPago] (Fase 2B.4, noviembre 2026): capacidades
// inyectadas, mismo criterio que abrir_protegido.dart -- el gate biométrico
// y el flujo de "Añadir pago" (que abre el escáner de documentos, exclusivo
// de Hogar por ahora) nunca se importan directamente aquí. Sin
// [onAnadirPago], el botón de añadir simplemente no se muestra -- hoy eso
// nunca ocurre para Hogar (único rol que lo necesita, siempre lo pasa) y a
// Pro (rol profesional) no le hace falta: ese botón ya estaba oculto para
// él antes de esta separación.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:repara_core/pago.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/registro.dart' show RolEnTrabajo;

import 'abrir_protegido.dart';
import 'app_dialog.dart';
import 'app_error.dart';
import 'package:repara_core/design_tokens.dart';
import 'ios_list.dart';
import 'nuevo_documento_flow.dart' show elegirYSubirArchivosAdjuntos;
import 'pago_detail_screen.dart';

/// Abre el flujo de "escanear un recibo o rellenarlo a mano" para un pago
/// nuevo -- en la app, `elegirFormaDeAnadirPago` de nuevo_documento_flow.dart
/// (exclusivo de Hogar hoy: usa el escáner de documentos con IA).
typedef IniciarAnadirPago =
    void Function(
      BuildContext context, {
      required String casaId,
      required String elementoId,
      required String registroId,
      required String registroTitulo,
      required double? presupuesto,
      required String conceptoSugerido,
      VerificarAccesoDocumento? verificarAcceso,
    });

class PagosSection extends StatelessWidget {
  const PagosSection({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
    required this.registroTitulo,
    required this.presupuesto,
    required this.rol,
    this.verificarAcceso,
    this.onAnadirPago,
    super.key,
  });

  final String casaId;
  final String elementoId;
  final String registroId;
  final String registroTitulo;
  final double? presupuesto;
  final RolEnTrabajo rol;
  final VerificarAccesoDocumento? verificarAcceso;
  final IniciarAnadirPago? onAnadirPago;

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
                if (editable && onAnadirPago != null)
                  TextButton.icon(
                    onPressed: () => onAnadirPago!(
                      context,
                      casaId: casaId,
                      elementoId: elementoId,
                      registroId: registroId,
                      registroTitulo: registroTitulo,
                      presupuesto: presupuesto,
                      conceptoSugerido: 'Pago ${pagos.length + 1}',
                      verificarAcceso: verificarAcceso,
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
                          verificarAcceso: verificarAcceso,
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

/// Menú de un pago: abrir comprobante, adjuntar/sustituir comprobante,
/// editar datos. Lo usan PagosSection (dentro del evento) y la ficha del
/// elemento.
Future<void> mostrarAccionesPago(
  BuildContext context, {
  required String casaId,
  required String elementoId,
  required String registroId,
  required String registroTitulo,
  required double? presupuesto,
  required bool editable,
  required Pago pago,
  VerificarAccesoDocumento? verificarAcceso,
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
                      abrirArchivoProtegido(
                        context,
                        pago.comprobante!,
                        verificarAcceso: verificarAcceso,
                      );
                    },
                  ),
                // Adjuntar el comprobante después (CEO, noviembre 2026): un
                // pago apuntado a mano puede recibir su PDF/foto más tarde,
                // en el mismo pago -- nunca crea un pago nuevo.
                if (editable)
                  IosRow(
                    icon: tieneComprobante
                        ? Icons.sync_outlined
                        : Icons.attach_file,
                    iconColor: ctx.colors.brand,
                    title: tieneComprobante
                        ? 'Sustituir comprobante'
                        : 'Adjuntar PDF o foto',
                    subtitle: tieneComprobante
                        ? null
                        : 'El importe y la fecha no cambian',
                    onTap: () {
                      Navigator.pop(ctx);
                      _adjuntarComprobante(
                        context,
                        casaId: casaId,
                        elementoId: elementoId,
                        registroId: registroId,
                        pago: pago,
                      );
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
                          verificarAcceso: verificarAcceso,
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

/// Sube un PDF/foto y lo guarda como comprobante de ESTE pago. Solo cambia
/// el comprobante; importe, fecha, concepto y método se envían tal cual
/// estaban (ver PagoService.actualizarComprobante). Un pago tiene un único
/// comprobante: si se eligen varias páginas, se guarda la primera.
Future<void> _adjuntarComprobante(
  BuildContext context, {
  required String casaId,
  required String elementoId,
  required String registroId,
  required Pago pago,
}) async {
  if ((pago.comprobante ?? '').isNotEmpty) {
    final seguir = await AppDialog.confirmText(
      context,
      title: '¿Sustituir el comprobante?',
      message:
          'El comprobante actual se cambiará por el nuevo. El importe y la '
          'fecha del pago no cambian.',
      confirmLabel: 'Sustituir',
    );
    if (!seguir || !context.mounted) return;
  }
  final urls = await elegirYSubirArchivosAdjuntos(
    context,
    casaId: casaId,
    elementoId: elementoId,
    registroId: registroId,
  );
  if (urls == null || urls.isEmpty || !context.mounted) return;
  try {
    await PagoService.actualizarComprobante(
      casaId,
      elementoId,
      registroId,
      pago,
      urls.first,
    );
    if (context.mounted) {
      AppError.showSuccess(context, 'Comprobante guardado en el pago.');
    }
  } on FirebaseFunctionsException catch (e, st) {
    if (context.mounted) {
      AppError.show(
        context,
        e.message ?? 'No se pudo guardar el comprobante.',
        error: e,
        stackTrace: st,
      );
    }
  } catch (e, st) {
    if (context.mounted) {
      AppError.show(
        context,
        'No se pudo guardar el comprobante.',
        error: e,
        stackTrace: st,
      );
    }
  }
}