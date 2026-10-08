// lib/screens/pro/trabajo_pro_detail_screen.dart
//
// Vista de un trabajo desde el lado del profesional (sección 12 del spec).
// El profesional gestiona estado, presupuestos formales, cambios de alcance
// y documentos -- pero solo de ESTE trabajo, nunca del resto de la casa (ver
// firestore.rules: el acceso está condicionado a profesionalUid == su uid).
import 'package:flutter/material.dart';

import '../../models/documento.dart';
import '../../models/trabajo.dart';
import '../../services/documento_service.dart';
import '../../services/pago_service.dart';
import '../../services/trabajo_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';
import '../../widgets/progreso_pago.dart';
import '../cambio_alcance_section.dart';
import '../nuevo_documento_flow.dart';
import '../pagos_section.dart';
import '../presupuestos_section.dart';

class TrabajoProDetailScreen extends StatelessWidget {
  const TrabajoProDetailScreen({required this.casaId, required this.trabajoId, super.key});

  final String casaId;
  final String trabajoId;

  Future<void> _finalizar(BuildContext context, Trabajo trabajo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como finalizado'),
        content: const Text('Se le pedirá al propietario que confirme que el trabajo está terminado -- todavía no se cierra hasta que lo haga.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Marcar como finalizado')),
        ],
      ),
    );
    if (confirmar != true) return;

    // Mismo aviso no bloqueante que en el lado del propietario: al
    // profesional también le interesa no perder de vista un cobro
    // pendiente, pero no se le impide cerrar el trabajo por ello.
    if (trabajo.presupuesto != null) {
      final pagado = await PagoService.totalPagado(casaId, trabajoId);
      if (pagado < trabajo.presupuesto! && context.mounted) {
        final seguir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('El cliente todavía no ha pagado del todo'),
            content: Text(
              'Lleva pagado ${pagado.toStringAsFixed(2)} € de ${trabajo.presupuesto!.toStringAsFixed(2)} €. '
              '¿Quieres finalizar igualmente?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar igualmente')),
            ],
          ),
        );
        if (seguir != true) return;
      }
    }
    if (!context.mounted) return;
    try {
      await TrabajoService.marcarFinalizadoProfesional(casaId, trabajoId);
      if (context.mounted) AppError.showSuccess(context, 'Esperando a que el propietario lo confirme.');
    } catch (e, st) {
      if (context.mounted) AppError.show(context, 'No se pudo marcar el trabajo como finalizado.', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trabajo?>(
      stream: TrabajoService.streamTrabajo(casaId, trabajoId),
      builder: (context, snapshot) {
        final trabajo = snapshot.data;
        if (trabajo == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(title: Text(trabajo.titulo)),
          floatingActionButton: _estadoControlado(trabajo.estado)
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _finalizar(context, trabajo),
                  icon: const Icon(Icons.check),
                  label: const Text('Finalizar'),
                ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (trabajo.estado == EstadoTrabajo.pendienteConfirmacion) ...[
                Card(
                  color: context.colors.warning.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_top_outlined, color: context.colors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Esperando a que el propietario confirme que está terminado.',
                            style: TextStyle(color: context.colors.ink, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (trabajo.descripcion != null) ...[
                Text(trabajo.descripcion!),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // "Terminado"/"Archivado"/"PendienteConfirmacion" nunca
                      // son una opción aquí -- solo se alcanzan a través de
                      // "Finalizar" (auditoría de seguridad, octubre 2026).
                      // El servidor ya lo bloquea aunque se fuerce desde fuera
                      // de la app, pero antes el desplegable seguía
                      // mostrando las opciones como tocables en un trabajo ya
                      // cerrado -- el servidor lo rechazaba en silencio, pero
                      // si el estado local optimista hacía reaparecer el
                      // botón "Finalizar", volver a tocarlo duplicaba el
                      // evento en el historial (auditoría de producto,
                      // octubre 2026). Ahora, si ya está en un estado
                      // controlado, el campo se deshabilita del todo.
                      if (_estadoControlado(trabajo.estado))
                        TextFormField(
                          key: ValueKey(trabajo.estado),
                          initialValue: _nombreEstado(trabajo.estado),
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Estado',
                            helperText: switch (trabajo.estado) {
                              EstadoTrabajo.pendienteConfirmacion => 'Esperando confirmación del propietario',
                              _ => 'Ya está finalizado',
                            },
                          ),
                        )
                      else
                        DropdownButtonFormField<EstadoTrabajo>(
                          initialValue: trabajo.estado,
                          decoration: const InputDecoration(labelText: 'Estado'),
                          items: _estadosEditables
                              .map((e) => DropdownMenuItem(value: e, child: Text(_nombreEstado(e))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) TrabajoService.actualizarEstado(casaId, trabajoId, v);
                          },
                        ),
                      if (trabajo.presupuesto != null) ...[
                        const SizedBox(height: 8),
                        Text('Presupuesto acordado: ${trabajo.presupuesto!.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        ProgresoPago(casaId: casaId, trabajoId: trabajoId, presupuesto: trabajo.presupuesto!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              PresupuestosSection(casaId: casaId, trabajoId: trabajoId, rol: RolEnTrabajo.profesional),
              const SizedBox(height: 20),
              CambiosAlcanceSection(
                casaId: casaId,
                trabajoId: trabajoId,
                rol: RolEnTrabajo.profesional,
                trabajoCerrado: trabajo.estado == EstadoTrabajo.terminado || trabajo.estado == EstadoTrabajo.archivado,
              ),
              const SizedBox(height: 20),
              PagosSection(
                casaId: casaId,
                trabajoId: trabajoId,
                trabajoTitulo: trabajo.titulo,
                presupuesto: trabajo.presupuesto,
                rol: RolEnTrabajo.profesional,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Documentos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  TextButton.icon(
                    onPressed: () => iniciarNuevoDocumento(context, casaId: casaId, trabajoId: trabajoId),
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    label: const Text('Añadir'),
                  ),
                ],
              ),
              StreamBuilder<List<Documento>>(
                stream: DocumentoService.streamDocumentos(casaId, trabajoId: trabajoId),
                builder: (context, snapshot) {
                  final documentos = snapshot.data ?? [];
                  if (documentos.isEmpty) {
                    return Text('Sin documentos todavía.', style: TextStyle(color: context.colors.inkMuted));
                  }
                  return Column(
                    children: documentos
                        .map((d) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.insert_drive_file_outlined),
                                title: Text(d.proveedor ?? d.nombreArchivo),
                                trailing: d.importe != null ? Text('${d.importe!.toStringAsFixed(0)} €') : null,
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Solo ves este trabajo -- no tienes acceso al resto de la casa ni a su historial completo.',
                style: TextStyle(color: context.colors.inkMuted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _estadoControlado(EstadoTrabajo e) =>
    e == EstadoTrabajo.terminado || e == EstadoTrabajo.archivado || e == EstadoTrabajo.pendienteConfirmacion;

String _nombreEstado(EstadoTrabajo e) => switch (e) {
      EstadoTrabajo.nuevo => 'Nuevo',
      EstadoTrabajo.presupuestado => 'Presupuestado',
      EstadoTrabajo.enCurso => 'En curso',
      EstadoTrabajo.pendienteConfirmacion => 'Pendiente de confirmación',
      EstadoTrabajo.terminado => 'Terminado',
      EstadoTrabajo.archivado => 'Archivado',
    };

const _estadosEditables = [EstadoTrabajo.nuevo, EstadoTrabajo.presupuestado, EstadoTrabajo.enCurso];
