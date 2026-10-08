// lib/screens/nuevo_evento_sheet.dart
//
// Hoja para registrar un evento en la historia de la casa (sección 14 del
// spec: "Crear trabajo" simplificado a un evento de historial directo,
// sin el flujo completo de trabajo/profesional cuando no hace falta --
// p.ej. anotar "revisión de la caldera" no necesita presupuesto ni estado).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/evento.dart';
import '../services/evento_service.dart';
import '../widgets/app_error.dart';

Future<void> mostrarNuevoEventoSheet(
  BuildContext context, {
  required String casaId,
  String? elementoId,
  String? habitacionId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _NuevoEventoForm(casaId: casaId, elementoId: elementoId, habitacionId: habitacionId),
  );
}

class _NuevoEventoForm extends StatefulWidget {
  const _NuevoEventoForm({required this.casaId, this.elementoId, this.habitacionId});

  final String casaId;
  final String? elementoId;
  final String? habitacionId;

  @override
  State<_NuevoEventoForm> createState() => _NuevoEventoFormState();
}

class _NuevoEventoFormState extends State<_NuevoEventoForm> {
  TipoEvento _tipo = TipoEvento.reparacion;
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _costeCtrl = TextEditingController();
  final _profesionalCtrl = TextEditingController();
  DateTime _fecha = DateTime.now();
  bool _guardando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _costeCtrl.dispose();
    _profesionalCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      AppError.show(context, 'Escribe un título para el evento.');
      return;
    }
    setState(() => _guardando = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await EventoService.crear(
        widget.casaId,
        Evento(
          id: '',
          tipo: _tipo,
          titulo: titulo,
          descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
          elementoId: widget.elementoId,
          habitacionId: widget.habitacionId,
          coste: double.tryParse(_costeCtrl.text.replaceAll(',', '.')),
          profesionalNombre: _profesionalCtrl.text.trim().isEmpty ? null : _profesionalCtrl.text.trim(),
          fecha: _fecha,
        ),
        createdBy: uid,
      );
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) AppError.show(context, 'No se pudo guardar el evento.', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Registrar en el historial', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: TipoEvento.values.map((t) {
                return ChoiceChip(
                  label: Text(_nombreTipo(t)),
                  selected: _tipo == t,
                  onSelected: (_) => setState(() => _tipo = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: 'Título (p.ej. Reparación de fuga)')),
            const SizedBox(height: 12),
            TextField(
              controller: _descripcionCtrl,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _costeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Coste (€)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _profesionalCtrl,
                    decoration: const InputDecoration(labelText: 'Profesional'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final elegida = await showDatePicker(
                  context: context,
                  initialDate: _fecha,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (elegida != null) setState(() => _fecha = elegida);
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('${_fecha.day}/${_fecha.month}/${_fecha.year}'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

String _nombreTipo(TipoEvento t) => switch (t) {
      TipoEvento.instalacion => 'Instalación',
      TipoEvento.revision => 'Revisión',
      TipoEvento.reparacion => 'Reparación',
      TipoEvento.sustitucion => 'Sustitución',
      TipoEvento.reforma => 'Reforma',
      TipoEvento.nota => 'Nota',
    };
