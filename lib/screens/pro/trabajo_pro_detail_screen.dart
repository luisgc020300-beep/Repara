// lib/screens/pro/trabajo_pro_detail_screen.dart
//
// Vista de un trabajo desde el lado del profesional (sección 12 del spec).
// El profesional gestiona estado, presupuestos formales, cambios de alcance
// y documentos -- pero solo de ESTE trabajo, nunca del resto de la casa (ver
// firestore.rules: el acceso está condicionado a profesionalUid == su uid).
import 'package:cloud_functions/cloud_functions.dart';
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
        title: const Text('Finalizar trabajo'),
        content: const Text('Se marcará como terminado. El propietario podrá revisarlo desde su historial.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar')),
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
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('finalizarTrabajoProfesional');
      await callable.call<Map<String, dynamic>>({'casaId': casaId, 'trabajoId': trabajoId});
      if (context.mounted) AppError.showSuccess(context, 'Trabajo marcado como finalizado.');
    } catch (e) {
      if (context.mounted) AppError.show(context, 'No se pudo finalizar el trabajo.');
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
          floatingActionButton: trabajo.estado == EstadoTrabajo.terminado || trabajo.estado == EstadoTrabajo.archivado
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _finalizar(context, trabajo),
                  icon: const Icon(Icons.check),
                  label: const Text('Finalizar'),
                ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                      // "Terminado"/"Archivado" nunca son una opción aquí --
                      // solo se alcanzan a través de "Finalizar" (auditoría
                      // de seguridad, octubre 2026). Antes saltarse ese
                      // botón dejaba el trabajo marcado como terminado sin
                      // avisar al propietario ni archivar nada.
                      DropdownButtonFormField<EstadoTrabajo>(
                        initialValue: trabajo.estado == EstadoTrabajo.terminado || trabajo.estado == EstadoTrabajo.archivado
                            ? null
                            : trabajo.estado,
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          helperText: trabajo.estado == EstadoTrabajo.terminado || trabajo.estado == EstadoTrabajo.archivado
                              ? 'Ya está finalizado'
                              : null,
                        ),
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
              CambiosAlcanceSection(casaId: casaId, trabajoId: trabajoId, rol: RolEnTrabajo.profesional),
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

String _nombreEstado(EstadoTrabajo e) => switch (e) {
      EstadoTrabajo.nuevo => 'Nuevo',
      EstadoTrabajo.presupuestado => 'Presupuestado',
      EstadoTrabajo.enCurso => 'En curso',
      EstadoTrabajo.terminado => 'Terminado',
      EstadoTrabajo.archivado => 'Archivado',
    };

const _estadosEditables = [EstadoTrabajo.nuevo, EstadoTrabajo.presupuestado, EstadoTrabajo.enCurso];
