// lib/screens/nuevo_contacto_sheet.dart
//
// Hoja para crear o editar un contacto de confianza (sección de Contactos).
// Rediseño de fidelidad visual (octubre 2026), misma identidad "REPARA
// Professional" que nuevo_elemento_screen.dart/nuevo_registro_sheet.dart:
// esquinas superiores con ReparaRadius.lg (antes un 20 suelto), espaciados
// con ReparaSpace, y validación visible -- antes "if (nombre.isEmpty ||
// telefono.isEmpty) return;" no decía nada, el formulario simplemente no
// hacía nada al tocar "Guardar" sin explicar por qué.
import 'package:flutter/material.dart';

import '../models/contacto.dart';
import '../services/contacto_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';

Future<void> mostrarNuevoContactoSheet(
  BuildContext context, {
  required String casaId,
  Contacto? existente,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ReparaRadius.lg),
      ),
    ),
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
  late final _nombreCtrl = TextEditingController(
    text: widget.existente?.nombre ?? '',
  );
  late final _telefonoCtrl = TextEditingController(
    text: widget.existente?.telefono ?? '',
  );
  late final _especialidadCtrl = TextEditingController(
    text: widget.existente?.especialidad ?? '',
  );
  late TipoContacto _tipo = widget.existente?.tipo ?? TipoContacto.particular;
  bool _guardando = false;

  /// Eco visual en el propio campo del mismo error que ya muestra el
  /// snackbar de [AppError.show] -- mismo criterio que nuevo_elemento_
  /// screen.dart: no sustituye ese aviso, hace más fácil ver qué campo
  /// exacto falta sin tener que recordar el mensaje que acaba de desaparecer.
  bool _mostrarErrorNombre = false;
  bool _mostrarErrorTelefono = false;

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
    final faltaNombre = nombre.isEmpty;
    final faltaTelefono = telefono.isEmpty;
    if (faltaNombre || faltaTelefono) {
      setState(() {
        _mostrarErrorNombre = faltaNombre;
        _mostrarErrorTelefono = faltaTelefono;
      });
      AppError.show(
        context,
        'Completa el nombre y el teléfono para guardar el contacto.',
      );
      return;
    }
    setState(() => _guardando = true);
    final contacto = Contacto(
      id: widget.existente?.id ?? '',
      nombre: nombre,
      telefono: telefono,
      tipo: _tipo,
      especialidad: _especialidadCtrl.text.trim().isEmpty
          ? null
          : _especialidadCtrl.text.trim(),
    );
    try {
      if (widget.existente != null) {
        await ContactoService.actualizar(
          widget.casaId,
          widget.existente!.id,
          contacto,
        );
      } else {
        await ContactoService.crear(widget.casaId, contacto);
      }
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo guardar el contacto.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: ReparaSpace.s5,
        right: ReparaSpace.s5,
        top: ReparaSpace.s5,
        bottom: ReparaSpace.s5 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existente != null
                  ? 'Editar contacto'
                  : 'Nuevo contacto de confianza',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: ReparaSpace.s4),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Particular'),
                    selected: _tipo == TipoContacto.particular,
                    onSelected: (_) =>
                        setState(() => _tipo = TipoContacto.particular),
                  ),
                ),
                const SizedBox(width: ReparaSpace.s2),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Empresa'),
                    selected: _tipo == TipoContacto.empresa,
                    onSelected: (_) =>
                        setState(() => _tipo = TipoContacto.empresa),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            TextField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre (p.ej. Fontanería López)',
                errorText: _mostrarErrorNombre ? 'Escribe un nombre.' : null,
              ),
              onChanged: (_) {
                if (_mostrarErrorNombre) {
                  setState(() => _mostrarErrorNombre = false);
                }
              },
            ),
            const SizedBox(height: ReparaSpace.s3),
            TextField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Teléfono',
                errorText: _mostrarErrorTelefono
                    ? 'Escribe un teléfono.'
                    : null,
              ),
              onChanged: (_) {
                if (_mostrarErrorTelefono) {
                  setState(() => _mostrarErrorTelefono = false);
                }
              },
            ),
            const SizedBox(height: ReparaSpace.s3),
            TextField(
              controller: _especialidadCtrl,
              decoration: const InputDecoration(
                labelText: 'Especialidad (opcional)',
              ),
            ),
            const SizedBox(height: ReparaSpace.s5),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.brandOn,
                        ),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
