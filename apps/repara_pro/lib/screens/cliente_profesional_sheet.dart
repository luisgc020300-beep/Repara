// apps/repara_pro/lib/screens/cliente_profesional_sheet.dart
//
// Hoja para crear o editar un cliente privado del profesional (Fase 1,
// noviembre 2026). Mismo patrón visual que nuevo_contacto_sheet.dart --
// solo el nombre es obligatorio, el resto son datos de contacto sueltos
// para poder llamar/escribir/ubicar sin obligar a rellenar un formulario
// largo para una ficha rápida.
import 'package:flutter/material.dart';

import '../models/cliente_profesional.dart';
import '../services/cliente_profesional_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/confirmar_salida_formulario.dart';

Future<String?> mostrarEditorClienteProfesional(
  BuildContext context, {
  ClienteProfesional? existente,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    // El arrastre hacia abajo para cerrar la hoja llama a Navigator.pop
    // directamente (ver BottomSheet._handleDragEnd), que ignora el
    // canPop:false de ConfirmarSalidaFormulario -- sin esto, se podría
    // perder un cliente a medio rellenar arrastrando la hoja sin que
    // saltara ningún aviso.
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ReparaRadius.lg),
      ),
    ),
    builder: (_) => _EditorClienteProfesionalSheet(existente: existente),
  );
}

class _EditorClienteProfesionalSheet extends StatefulWidget {
  const _EditorClienteProfesionalSheet({this.existente});

  final ClienteProfesional? existente;

  @override
  State<_EditorClienteProfesionalSheet> createState() =>
      _EditorClienteProfesionalSheetState();
}

class _EditorClienteProfesionalSheetState
    extends State<_EditorClienteProfesionalSheet> {
  late final _nombreCtrl = TextEditingController(
    text: widget.existente?.nombre ?? '',
  );
  late final _telefonoCtrl = TextEditingController(
    text: widget.existente?.telefono ?? '',
  );
  late final _emailCtrl = TextEditingController(
    text: widget.existente?.email ?? '',
  );
  late final _direccionCtrl = TextEditingController(
    text: widget.existente?.direccion ?? '',
  );
  late final _notasCtrl = TextEditingController(
    text: widget.existente?.notas ?? '',
  );
  // Ojo: NO leer esto de los controllers (_nombreCtrl.text...) -- al ser
  // "late final", solo se evaluarían la primera vez que se accede a ellos,
  // que es dentro de _hayCambiosSinGuardar(), ya con lo que el usuario haya
  // tecleado puesto. Mismo valor que usan los controllers arriba, pero
  // leído directamente de widget.existente, que nunca cambia.
  late final String _nombreInicial = widget.existente?.nombre ?? '';
  late final String _telefonoInicial = widget.existente?.telefono ?? '';
  late final String _emailInicial = widget.existente?.email ?? '';
  late final String _direccionInicial = widget.existente?.direccion ?? '';
  late final String _notasInicial = widget.existente?.notas ?? '';
  bool _guardando = false;
  bool _mostrarErrorNombre = false;
  // Se pone a true justo antes del pop que sigue a un guardado con éxito --
  // sin esto, ConfirmarSalidaFormulario preguntaría "¿Salir sin guardar?"
  // aunque los datos ya estén guardados (mismo criterio que nuevo_registro_
  // screen.dart en Hogar).
  bool _guardadoConExito = false;

  bool get _esEdicion => widget.existente != null;

  bool _hayCambiosSinGuardar() =>
      !_guardadoConExito &&
      (_nombreCtrl.text.trim() != _nombreInicial.trim() ||
          _telefonoCtrl.text.trim() != _telefonoInicial.trim() ||
          _emailCtrl.text.trim() != _emailInicial.trim() ||
          _direccionCtrl.text.trim() != _direccionInicial.trim() ||
          _notasCtrl.text.trim() != _notasInicial.trim());

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _mostrarErrorNombre = true);
      AppError.show(context, 'Ponle un nombre al cliente.');
      return;
    }
    setState(() => _guardando = true);
    final cliente = ClienteProfesional(
      id: widget.existente?.id ?? '',
      nombre: nombre,
      telefono: _telefonoCtrl.text.trim().isEmpty
          ? null
          : _telefonoCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim().isEmpty
          ? null
          : _direccionCtrl.text.trim(),
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );
    try {
      String? id;
      if (_esEdicion) {
        await ClienteProfesionalService.actualizar(
          widget.existente!.id,
          cliente,
        );
        id = widget.existente!.id;
      } else {
        id = await ClienteProfesionalService.crear(cliente);
      }
      _guardadoConExito = true;
      if (mounted) Navigator.pop(context, id);
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo guardar el cliente.',
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
    return ConfirmarSalidaFormulario(
      hayCambiosSinGuardar: _hayCambiosSinGuardar,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
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
                  _esEdicion ? 'Editar cliente' : 'Nuevo cliente',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: ReparaSpace.s3),
                TextField(
                  controller: _nombreCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    errorText: _mostrarErrorNombre
                        ? 'Escribe un nombre.'
                        : null,
                  ),
                  onChanged: (_) {
                    if (_mostrarErrorNombre) {
                      setState(() => _mostrarErrorNombre = false);
                    }
                  },
                ),
                const SizedBox(height: ReparaSpace.s2),
                TextField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                  ),
                ),
                const SizedBox(height: ReparaSpace.s2),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (opcional)',
                  ),
                ),
                const SizedBox(height: ReparaSpace.s2),
                TextField(
                  controller: _direccionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección (opcional)',
                  ),
                ),
                const SizedBox(height: ReparaSpace.s2),
                TextField(
                  controller: _notasCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                ),
                const SizedBox(height: ReparaSpace.s4),
                FilledButton(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
