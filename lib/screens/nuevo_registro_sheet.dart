// lib/screens/nuevo_registro_sheet.dart
//
// Hoja para añadir un registro simple (sin profesional) a un elemento que
// ya existe -- p.ej. "cambio de depuradora" sobre la Piscina, o anotar una
// revisión hecha a mano. El flujo completo con presupuesto/profesional
// nunca se crea aquí: eso siempre empieza desde el propio registro ya
// creado (ver registro_detail_screen.dart). Un registro nunca vive sin
// elemento (octubre 2026, fusión Elemento/Trabajo/Evento) -- a diferencia
// del antiguo NuevoEventoSheet, aquí elementoId es obligatorio.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/registro.dart';
import '../services/registro_service.dart';
import '../widgets/app_error.dart';

Future<void> mostrarNuevoRegistroSheet(
  BuildContext context, {
  required String casaId,
  required String elementoId,
  required String elementoNombre,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _NuevoRegistroForm(casaId: casaId, elementoId: elementoId, elementoNombre: elementoNombre),
  );
}

class _NuevoRegistroForm extends StatefulWidget {
  const _NuevoRegistroForm({required this.casaId, required this.elementoId, required this.elementoNombre});

  final String casaId;
  final String elementoId;
  final String elementoNombre;

  @override
  State<_NuevoRegistroForm> createState() => _NuevoRegistroFormState();
}

class _NuevoRegistroFormState extends State<_NuevoRegistroForm> {
  TipoRegistro _tipo = TipoRegistro.reparacion;
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
      AppError.show(context, 'Escribe un título para el registro.');
      return;
    }
    setState(() => _guardando = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await RegistroService.crear(
        widget.casaId,
        widget.elementoId,
        Registro(
          id: '',
          elementoNombre: widget.elementoNombre,
          tipo: _tipo,
          esConProfesional: false,
          titulo: titulo,
          estado: EstadoRegistro.terminado,
          descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
          coste: double.tryParse(_costeCtrl.text.replaceAll(',', '.')),
          profesionalNombre: _profesionalCtrl.text.trim().isEmpty ? null : _profesionalCtrl.text.trim(),
          fecha: _fecha,
        ),
        createdBy: uid,
      );
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) AppError.show(context, 'No se pudo guardar el registro.', error: e, stackTrace: st);
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
            Text('Añadir registro', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: TipoRegistro.values.map((t) {
                return ChoiceChip(
                  label: Text(nombreTipoRegistro(t)),
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
