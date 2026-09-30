// lib/screens/pro/trabajo_pro_detail_screen.dart
//
// Vista de un trabajo desde el lado del profesional. Deliberadamente más
// ligera que TrabajoDetailScreen (lado propietario): en esta primera pasada
// de REPARA Pro el profesional ve el encargo y gestiona estado/presupuesto,
// pero no tiene acceso a los documentos/historial de la casa (eso exigiría
// ampliar las reglas de Firestore más allá del propio trabajo -- pendiente
// de una fase posterior, ver auditoría).
import 'package:flutter/material.dart';

import '../../models/trabajo.dart';
import '../../services/trabajo_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';

class TrabajoProDetailScreen extends StatefulWidget {
  const TrabajoProDetailScreen({required this.casaId, required this.trabajoId, super.key});

  final String casaId;
  final String trabajoId;

  @override
  State<TrabajoProDetailScreen> createState() => _TrabajoProDetailScreenState();
}

class _TrabajoProDetailScreenState extends State<TrabajoProDetailScreen> {
  final _presupuestoCtrl = TextEditingController();
  bool _guardandoPresupuesto = false;

  @override
  void dispose() {
    _presupuestoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarPresupuesto() async {
    final valor = double.tryParse(_presupuestoCtrl.text.replaceAll(',', '.'));
    if (valor == null) return;
    setState(() => _guardandoPresupuesto = true);
    try {
      await TrabajoService.actualizar(widget.casaId, widget.trabajoId, {'presupuesto': valor});
      if (mounted) AppError.showSuccess(context, 'Presupuesto actualizado.');
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo actualizar el presupuesto.');
    } finally {
      if (mounted) setState(() => _guardandoPresupuesto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trabajo?>(
      stream: TrabajoService.streamTrabajo(widget.casaId, widget.trabajoId),
      builder: (context, snapshot) {
        final trabajo = snapshot.data;
        if (trabajo == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (_presupuestoCtrl.text.isEmpty && trabajo.presupuesto != null) {
          _presupuestoCtrl.text = trabajo.presupuesto!.toStringAsFixed(2);
        }
        return Scaffold(
          appBar: AppBar(title: Text(trabajo.titulo)),
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
                      DropdownButtonFormField<EstadoTrabajo>(
                        initialValue: trabajo.estado,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: EstadoTrabajo.values
                            .map((e) => DropdownMenuItem(value: e, child: Text(_nombreEstado(e))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) TrabajoService.actualizarEstado(widget.casaId, widget.trabajoId, v);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _presupuestoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Presupuesto (€)'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _guardandoPresupuesto
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : TextButton(onPressed: _guardarPresupuesto, child: const Text('Guardar')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No tienes acceso a los documentos ni al historial completo de esta vivienda -- solo a este trabajo.',
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
