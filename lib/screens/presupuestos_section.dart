// lib/screens/presupuestos_section.dart
//
// Sección de presupuestos formales (secciones 15-18 del spec), reutilizada
// tanto en la ficha de trabajo de Hogar (rol propietario: aceptar/rechazar)
// como en la de Pro (rol profesional: crear, enviar, versionar). Los totales
// mostrados aquí son solo para revisión visual -- los que cuentan de verdad
// son los que calcula el servidor en Cloud Functions.
import 'package:flutter/material.dart';

import '../models/presupuesto.dart';
import '../services/presupuesto_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';

enum RolEnTrabajo { propietario, profesional }

class PresupuestosSection extends StatelessWidget {
  const PresupuestosSection({required this.casaId, required this.trabajoId, required this.rol, super.key});

  final String casaId;
  final String trabajoId;
  final RolEnTrabajo rol;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Presupuesto>>(
      stream: PresupuestoService.streamPresupuestos(casaId, trabajoId),
      builder: (context, snapshot) {
        final presupuestos = snapshot.data ?? [];
        final ultimo = presupuestos.isEmpty ? null : presupuestos.first;
        final puedeCrearNuevo = rol == RolEnTrabajo.profesional &&
            (ultimo == null || ultimo.estado == EstadoPresupuesto.rechazado);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Presupuestos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (puedeCrearNuevo)
                  TextButton.icon(
                    onPressed: () => _abrirEditor(
                      context,
                      presupuestoAnteriorId: ultimo?.estado == EstadoPresupuesto.rechazado ? ultimo!.id : null,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(ultimo != null ? 'Nueva versión' : 'Crear presupuesto'),
                  ),
              ],
            ),
            if (presupuestos.isEmpty)
              Text('Sin presupuestos todavía.', style: TextStyle(color: context.colors.inkMuted))
            else
              ...presupuestos.map((p) => _PresupuestoCard(casaId: casaId, trabajoId: trabajoId, presupuesto: p, rol: rol)),
          ],
        );
      },
    );
  }

  Future<void> _abrirEditor(BuildContext context, {String? presupuestoAnteriorId}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditorPresupuestoSheet(
        casaId: casaId,
        trabajoId: trabajoId,
        presupuestoAnteriorId: presupuestoAnteriorId,
      ),
    );
  }
}

class _PresupuestoCard extends StatelessWidget {
  const _PresupuestoCard({required this.casaId, required this.trabajoId, required this.presupuesto, required this.rol});

  final String casaId;
  final String trabajoId;
  final Presupuesto presupuesto;
  final RolEnTrabajo rol;

  Color _colorEstado(BuildContext context) => switch (presupuesto.estado) {
        EstadoPresupuesto.borrador => context.colors.inkMuted,
        EstadoPresupuesto.enviado => context.colors.warning,
        EstadoPresupuesto.aceptado => context.colors.success,
        EstadoPresupuesto.rechazado => context.colors.error,
        EstadoPresupuesto.cancelado => context.colors.inkMuted,
      };

  Future<void> _responder(BuildContext context, bool aceptar) async {
    try {
      await PresupuestoService.responder(casaId: casaId, trabajoId: trabajoId, presupuestoId: presupuesto.id, aceptar: aceptar);
    } catch (e) {
      if (context.mounted) AppError.show(context, 'No se pudo responder al presupuesto.');
    }
  }

  Future<void> _enviar(BuildContext context) async {
    try {
      await PresupuestoService.enviar(casaId: casaId, trabajoId: trabajoId, presupuestoId: presupuesto.id);
      if (context.mounted) AppError.showSuccess(context, 'Presupuesto enviado.');
    } catch (e) {
      if (context.mounted) AppError.show(context, 'No se pudo enviar el presupuesto.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Presupuesto #${presupuesto.numero} · v${presupuesto.version}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _colorEstado(context).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(_nombreEstado(presupuesto.estado), style: TextStyle(color: _colorEstado(context), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...presupuesto.lineas.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text('${l.descripcion} (${l.cantidad.toStringAsFixed(l.cantidad == l.cantidad.roundToDouble() ? 0 : 1)})')),
                      Text('${l.importeSinIva.toStringAsFixed(2)} €'),
                    ],
                  ),
                )),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal ${presupuesto.subtotal.toStringAsFixed(2)} € · IVA ${presupuesto.iva.toStringAsFixed(2)} €'),
                Text('${presupuesto.total.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            if (presupuesto.estado == EstadoPresupuesto.borrador && rol == RolEnTrabajo.profesional) ...[
              const SizedBox(height: 10),
              FilledButton(onPressed: () => _enviar(context), child: const Text('Enviar al propietario')),
            ],
            if (presupuesto.estado == EstadoPresupuesto.enviado && rol == RolEnTrabajo.propietario) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => _responder(context, false), child: const Text('Rechazar'))),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(onPressed: () => _responder(context, true), child: const Text('Aceptar'))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditorPresupuestoSheet extends StatefulWidget {
  const _EditorPresupuestoSheet({required this.casaId, required this.trabajoId, this.presupuestoAnteriorId});

  final String casaId;
  final String trabajoId;
  final String? presupuestoAnteriorId;

  @override
  State<_EditorPresupuestoSheet> createState() => _EditorPresupuestoSheetState();
}

class _LineaEnEdicion {
  final descripcionCtrl = TextEditingController();
  final cantidadCtrl = TextEditingController(text: '1');
  final precioCtrl = TextEditingController();
  final ivaCtrl = TextEditingController(text: '21');
}

class _EditorPresupuestoSheetState extends State<_EditorPresupuestoSheet> {
  final _notasCtrl = TextEditingController();
  final List<_LineaEnEdicion> _lineas = [_LineaEnEdicion()];
  bool _guardando = false;

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  double get _totalEstimado {
    var total = 0.0;
    for (final l in _lineas) {
      final cantidad = double.tryParse(l.cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
      final precio = double.tryParse(l.precioCtrl.text.replaceAll(',', '.')) ?? 0;
      final iva = double.tryParse(l.ivaCtrl.text.replaceAll(',', '.')) ?? 0;
      total += cantidad * precio * (1 + iva / 100);
    }
    return total;
  }

  Future<void> _guardarYEnviar() async {
    final lineasValidas = _lineas.where((l) => l.descripcionCtrl.text.trim().isNotEmpty).toList();
    if (lineasValidas.isEmpty) {
      AppError.show(context, 'Añade al menos una línea con descripción.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final lineas = lineasValidas
          .map((l) => (
                descripcion: l.descripcionCtrl.text.trim(),
                cantidad: double.tryParse(l.cantidadCtrl.text.replaceAll(',', '.')) ?? 1,
                precioUnitario: double.tryParse(l.precioCtrl.text.replaceAll(',', '.')) ?? 0,
                ivaPorcentaje: double.tryParse(l.ivaCtrl.text.replaceAll(',', '.')) ?? 21,
              ))
          .toList();
      if (widget.presupuestoAnteriorId != null) {
        await PresupuestoService.crearNuevaVersion(
          casaId: widget.casaId,
          trabajoId: widget.trabajoId,
          presupuestoAnteriorId: widget.presupuestoAnteriorId!,
          lineas: lineas
              .map((l) => LineaPresupuesto(
                  descripcion: l.descripcion, cantidad: l.cantidad, precioUnitario: l.precioUnitario, ivaPorcentaje: l.ivaPorcentaje))
              .toList(),
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
      } else {
        await PresupuestoService.crear(
          casaId: widget.casaId,
          trabajoId: widget.trabajoId,
          lineas: lineas
              .map((l) => LineaPresupuesto(
                  descripcion: l.descripcion, cantidad: l.cantidad, precioUnitario: l.precioUnitario, ivaPorcentaje: l.ivaPorcentaje))
              .toList(),
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
      }
      if (mounted) {
        AppError.showSuccess(context, 'Presupuesto guardado como borrador.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo guardar el presupuesto.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nuevo presupuesto', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._lineas.asMap().entries.map((entry) {
              final i = entry.key;
              final l = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: TextField(controller: l.descripcionCtrl, decoration: const InputDecoration(labelText: 'Descripción'))),
                        if (_lineas.length > 1)
                          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _lineas.removeAt(i))),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: l.cantidadCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Cant.', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: l.precioCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Precio (€)', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: l.ivaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'IVA %', isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _lineas.add(_LineaEnEdicion())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir línea'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(controller: _notasCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Notas (opcional)')),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Total estimado: ${_totalEstimado.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _guardando ? null : _guardarYEnviar,
              child: _guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar como borrador'),
            ),
          ],
        ),
      ),
    );
  }
}

String _nombreEstado(EstadoPresupuesto e) => switch (e) {
      EstadoPresupuesto.borrador => 'Borrador',
      EstadoPresupuesto.enviado => 'Enviado',
      EstadoPresupuesto.aceptado => 'Aceptado',
      EstadoPresupuesto.rechazado => 'Rechazado',
      EstadoPresupuesto.cancelado => 'Cancelado',
    };
