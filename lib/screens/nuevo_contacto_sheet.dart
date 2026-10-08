// lib/screens/nuevo_contacto_sheet.dart
import 'package:flutter/material.dart';

import '../models/contacto.dart';
import '../services/contacto_service.dart';
import '../widgets/app_error.dart';

Future<void> mostrarNuevoContactoSheet(BuildContext context, {required String casaId, Contacto? existente}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _NuevoContactoForm(casaId: casaId, existente: existente),
  );
}

class _NuevoContactoForm extends StatefulWidget {
  const _NuevoContactoForm({required this.casaId, this.existente});

  final String casaId;
  final Contacto? existente;

  @override
  State<_NuevoContactoForm> createState() => _NuevoContactoFormState();
}

class _NuevoContactoFormState extends State<_NuevoContactoForm> {
  late final _nombreCtrl = TextEditingController(text: widget.existente?.nombre ?? '');
  late final _telefonoCtrl = TextEditingController(text: widget.existente?.telefono ?? '');
  late final _especialidadCtrl = TextEditingController(text: widget.existente?.especialidad ?? '');
  late TipoContacto _tipo = widget.existente?.tipo ?? TipoContacto.particular;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _especialidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();
    if (nombre.isEmpty || telefono.isEmpty) return;
    setState(() => _guardando = true);
    final contacto = Contacto(
      id: widget.existente?.id ?? '',
      nombre: nombre,
      telefono: telefono,
      tipo: _tipo,
      especialidad: _especialidadCtrl.text.trim().isEmpty ? null : _especialidadCtrl.text.trim(),
    );
    try {
      if (widget.existente != null) {
        await ContactoService.actualizar(widget.casaId, widget.existente!.id, contacto);
      } else {
        await ContactoService.crear(widget.casaId, contacto);
      }
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) AppError.show(context, 'No se pudo guardar el contacto.', error: e, stackTrace: st);
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
            Text(
              widget.existente != null ? 'Editar contacto' : 'Nuevo contacto de confianza',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Particular'),
                    selected: _tipo == TipoContacto.particular,
                    onSelected: (_) => setState(() => _tipo = TipoContacto.particular),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Empresa'),
                    selected: _tipo == TipoContacto.empresa,
                    onSelected: (_) => setState(() => _tipo = TipoContacto.empresa),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre (p.ej. Fontanería López)')),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _especialidadCtrl, decoration: const InputDecoration(labelText: 'Especialidad (opcional)')),
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
