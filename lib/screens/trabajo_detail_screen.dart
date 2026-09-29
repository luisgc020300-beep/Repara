// lib/screens/trabajo_detail_screen.dart
//
// Expediente de un trabajo (sección 13 del spec, simplificado para v1: sin
// ScopeGuard/cambios de alcance todavía). Al finalizar, se ofrece volcar el
// trabajo como un evento permanente en el historial de la casa (sección 21:
// "¿Qué quieres guardar en el historial de la vivienda?").
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../models/evento.dart';
import '../models/trabajo.dart';
import '../services/documento_service.dart';
import '../services/evento_service.dart';
import '../services/trabajo_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import 'nuevo_documento_flow.dart';

class TrabajoDetailScreen extends StatelessWidget {
  const TrabajoDetailScreen({required this.casa, required this.trabajoId, super.key});

  final Casa casa;
  final String trabajoId;

  Future<void> _finalizar(BuildContext context, Trabajo trabajo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar trabajo'),
        content: const Text('Se marcará como terminado y quedará guardado en el historial de la casa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirmar != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await EventoService.crear(
        casa.id,
        Evento(
          id: '',
          tipo: _tipoEventoDeTrabajo(trabajo.tipo),
          titulo: trabajo.titulo,
          descripcion: trabajo.descripcion,
          elementoId: trabajo.elementoId,
          habitacionId: trabajo.habitacionId,
          trabajoId: trabajo.id,
          coste: trabajo.presupuesto,
          profesionalNombre: trabajo.profesionalNombre,
          fecha: DateTime.now(),
        ),
        createdBy: uid,
      );
      await TrabajoService.actualizarEstado(casa.id, trabajo.id, EstadoTrabajo.terminado);
      if (context.mounted) AppError.showSuccess(context, 'Trabajo archivado en el historial.');
    } catch (e) {
      if (context.mounted) AppError.show(context, 'No se pudo finalizar el trabajo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trabajo?>(
      stream: TrabajoService.streamTrabajo(casa.id, trabajoId),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (trabajo.descripcion != null) ...[
                        Text(trabajo.descripcion!),
                        const SizedBox(height: 12),
                      ],
                      DropdownButtonFormField<EstadoTrabajo>(
                        initialValue: trabajo.estado,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: EstadoTrabajo.values
                            .map((e) => DropdownMenuItem(value: e, child: Text(_nombreEstado(e))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) TrabajoService.actualizarEstado(casa.id, trabajo.id, v);
                        },
                      ),
                      if (trabajo.profesionalNombre != null) ...[
                        const SizedBox(height: 8),
                        Text('Profesional: ${trabajo.profesionalNombre}${trabajo.profesionalContacto != null ? ' · ${trabajo.profesionalContacto}' : ''}'),
                      ],
                      if (trabajo.presupuesto != null) ...[
                        const SizedBox(height: 4),
                        Text('Presupuesto: ${trabajo.presupuesto!.toStringAsFixed(0)} €'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Documentos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  TextButton.icon(
                    onPressed: () => iniciarNuevoDocumento(context, casaId: casa.id, trabajoId: trabajo.id),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir'),
                  ),
                ],
              ),
              StreamBuilder<List<Documento>>(
                stream: DocumentoService.streamDocumentos(casa.id, trabajoId: trabajo.id),
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
            ],
          ),
        );
      },
    );
  }
}

TipoEvento _tipoEventoDeTrabajo(TipoTrabajo t) => switch (t) {
      TipoTrabajo.averia => TipoEvento.reparacion,
      TipoTrabajo.reparacion => TipoEvento.reparacion,
      TipoTrabajo.mantenimiento => TipoEvento.revision,
      TipoTrabajo.reforma => TipoEvento.reforma,
      TipoTrabajo.instalacion => TipoEvento.instalacion,
      TipoTrabajo.otro => TipoEvento.nota,
    };

String _nombreEstado(EstadoTrabajo e) => switch (e) {
      EstadoTrabajo.nuevo => 'Nuevo',
      EstadoTrabajo.presupuestado => 'Presupuestado',
      EstadoTrabajo.enCurso => 'En curso',
      EstadoTrabajo.terminado => 'Terminado',
      EstadoTrabajo.archivado => 'Archivado',
    };
