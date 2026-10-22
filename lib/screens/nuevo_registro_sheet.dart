// lib/screens/nuevo_registro_sheet.dart
//
// Hoja para añadir un registro simple (sin profesional) a un elemento que
// ya existe -- p.ej. "cambio de depuradora" sobre la Piscina, o anotar una
// revisión hecha a mano. El flujo completo con presupuesto/profesional
// nunca se crea aquí: eso siempre empieza desde el propio registro ya
// creado (ver registro_detail_screen.dart). Un registro nunca vive sin
// elemento (octubre 2026, fusión Elemento/Trabajo/Evento) -- a diferencia
// del antiguo NuevoEventoSheet, aquí elementoId es obligatorio.
//
// Rediseño de fidelidad visual (octubre 2026), misma identidad "REPARA
// Professional" que nuevo_contacto_sheet.dart/nuevo_elemento_screen.dart:
// esquinas superiores con ReparaRadius.lg (antes un 20 suelto), espaciados
// con ReparaSpace, y el mismo eco visual de error en el campo obligatorio
// (título) que ya usa nuevo_contacto_sheet.dart -- el snackbar de
// AppError.show ya existía y no era silencioso, pero no se veía reflejado
// en el propio campo.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/registro.dart';
import '../services/registro_service.dart';
import '../theme/design_tokens.dart';
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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ReparaRadius.lg),
      ),
    ),
    builder: (ctx) => _NuevoRegistroForm(
      casaId: casaId,
      elementoId: elementoId,
      elementoNombre: elementoNombre,
    ),
  );
}

class _NuevoRegistroForm extends StatefulWidget {
  const _NuevoRegistroForm({
    required this.casaId,
    required this.elementoId,
    required this.elementoNombre,
  });

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

  /// Eco visual en el propio campo del mismo error que ya muestra el
  /// snackbar de [AppError.show] -- mismo criterio que nuevo_contacto_
  /// sheet.dart: no sustituye ese aviso, hace más fácil ver qué campo
  /// exacto falta sin tener que recordar el mensaje que acaba de desaparecer.
  bool _mostrarErrorTitulo = false;

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
      setState(() => _mostrarErrorTitulo = true);
      AppError.show(context, 'Escribe un título para el evento.');
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
          descripcion: _descripcionCtrl.text.trim().isEmpty
              ? null
              : _descripcionCtrl.text.trim(),
          coste: double.tryParse(_costeCtrl.text.replaceAll(',', '.')),
          profesionalNombre: _profesionalCtrl.text.trim().isEmpty
              ? null
              : _profesionalCtrl.text.trim(),
          fecha: _fecha,
        ),
        createdBy: uid,
      );
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo guardar el evento.',
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
              'Añadir evento',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: ReparaSpace.s4),
            Wrap(
              spacing: ReparaSpace.s2,
              runSpacing: ReparaSpace.s2,
              children: TipoRegistro.values.map((t) {
                return ChoiceChip(
                  label: Text(nombreTipoRegistro(t)),
                  selected: _tipo == t,
                  onSelected: (_) => setState(() => _tipo = t),
                );
              }).toList(),
            ),
            const SizedBox(height: ReparaSpace.s4),
            TextField(
              controller: _tituloCtrl,
              decoration: InputDecoration(
                labelText: 'Título (p.ej. Reparación de fuga)',
                errorText: _mostrarErrorTitulo ? 'Obligatorio' : null,
              ),
              onChanged: (_) {
                if (_mostrarErrorTitulo) {
                  setState(() => _mostrarErrorTitulo = false);
                }
              },
            ),
            const SizedBox(height: ReparaSpace.s3),
            TextField(
              controller: _descripcionCtrl,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: ReparaSpace.s3),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _costeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Coste (€)'),
                  ),
                ),
                const SizedBox(width: ReparaSpace.s3),
                Expanded(
                  child: TextField(
                    controller: _profesionalCtrl,
                    decoration: const InputDecoration(labelText: 'Profesional'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s3),
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
            const SizedBox(height: ReparaSpace.s5),
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
    );
  }
}
