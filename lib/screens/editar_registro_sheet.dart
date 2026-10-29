// lib/screens/editar_registro_sheet.dart
//
// Editar un registro ya creado (título, descripción y, en un registro
// SIMPLE, también coste y profesional de texto libre) -- gap real
// encontrado por el CEO: ni nuevo_registro_sheet.dart ni
// nuevo_elemento_screen.dart ofrecen después ningún sitio para corregir
// o completar estos datos, y el propio encabezado de
// registro_detail_screen.dart ya decía "uno simple... solo muestra sus
// datos con editar/eliminar" sin que "editar" llegara a existir.
//
// Solo cubre lo que firestore.rules ya permite escribir directamente a
// un miembro de la casa (ver `allow update` de registros): nunca toca
// tipo, esConProfesional, estado, profesionalUid, presupuesto ni
// presupuestoAceptadoId -- cambiar cualquiera de esos es una decisión de
// flujo distinta (invitar profesional, presupuestos, Cambios/Pagos), no
// una simple corrección de datos.
//
// En un registro CON profesional, coste y el campo de profesional de
// texto libre no se muestran aquí: ese dato vive en presupuesto/
// profesionalUid, gestionados por sus propias pantallas (ver
// _ResumenEconomico y _SeccionInvitarProfesional en
// registro_detail_screen.dart) -- mostrarlos aquí tentaría a escribir un
// número que no es el que de verdad cuenta.
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/registro.dart';
import '../services/registro_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';

Future<void> mostrarEditarRegistroSheet(
  BuildContext context, {
  required String casaId,
  required String elementoId,
  required Registro registro,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ReparaRadius.lg),
      ),
    ),
    builder: (ctx) => _EditarRegistroForm(
      casaId: casaId,
      elementoId: elementoId,
      registro: registro,
    ),
  );
}

class _EditarRegistroForm extends StatefulWidget {
  const _EditarRegistroForm({
    required this.casaId,
    required this.elementoId,
    required this.registro,
  });

  final String casaId;
  final String elementoId;
  final Registro registro;

  @override
  State<_EditarRegistroForm> createState() => _EditarRegistroFormState();
}

class _EditarRegistroFormState extends State<_EditarRegistroForm> {
  late final _tituloCtrl = TextEditingController(text: widget.registro.titulo);
  late final _descripcionCtrl = TextEditingController(
    text: widget.registro.descripcion ?? '',
  );
  late final _costeCtrl = TextEditingController(
    text: widget.registro.coste == null
        ? ''
        : widget.registro.coste!.toStringAsFixed(2).replaceAll('.', ','),
  );
  late final _profesionalCtrl = TextEditingController(
    text: widget.registro.profesionalNombre ?? '',
  );
  late final _plazoFrecuenciaCtrl = TextEditingController(
    text: widget.registro.plazoFrecuenciaMeses?.toString() ?? '',
  );
  late final _plazoImporteCtrl = TextEditingController(
    text: widget.registro.plazoImporte == null
        ? ''
        : widget.registro.plazoImporte!.toStringAsFixed(2).replaceAll('.', ','),
  );
  late bool _pagaAPlazos = widget.registro.plazoFrecuenciaMeses != null;
  bool _guardando = false;
  bool _mostrarErrorTitulo = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _costeCtrl.dispose();
    _profesionalCtrl.dispose();
    _plazoFrecuenciaCtrl.dispose();
    _plazoImporteCtrl.dispose();
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
    final descripcion = _descripcionCtrl.text.trim();
    // Se escribe explícitamente null (no se omite la clave) cuando el
    // campo queda vacío -- RegistroService.actualizar() pasa el mapa tal
    // cual a Firestore.update(), que solo toca las claves presentes: una
    // clave ausente deja el valor anterior intacto, así que borrar el
    // texto de un campo y guardar debe mandar null explícito, no omitirlo.
    final cambios = <String, dynamic>{
      'titulo': titulo,
      'descripcion': descripcion.isEmpty ? null : descripcion,
    };
    if (!widget.registro.esConProfesional) {
      final coste = double.tryParse(_costeCtrl.text.replaceAll(',', '.'));
      final profesional = _profesionalCtrl.text.trim();
      cambios['coste'] = coste;
      cambios['profesionalNombre'] = profesional.isEmpty ? null : profesional;
      final frecuencia = _pagaAPlazos
          ? int.tryParse(_plazoFrecuenciaCtrl.text)
          : null;
      final importePlazo = _pagaAPlazos
          ? double.tryParse(_plazoImporteCtrl.text.replaceAll(',', '.'))
          : null;
      // Los dos van juntos -- si falta cualquiera, se borran los dos (ver
      // comentario de plazoFrecuenciaMeses en models/registro.dart).
      final plazoCompleto = frecuencia != null && importePlazo != null;
      cambios['plazoFrecuenciaMeses'] = plazoCompleto ? frecuencia : null;
      cambios['plazoImporte'] = plazoCompleto ? importePlazo : null;
    }
    try {
      await RegistroService.actualizar(
        widget.casaId,
        widget.elementoId,
        widget.registro.id,
        cambios,
      );
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudieron guardar los cambios.',
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
              'Editar evento',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: ReparaSpace.s4),
            TextField(
              controller: _tituloCtrl,
              decoration: InputDecoration(
                labelText: 'Título',
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
            if (!widget.registro.esConProfesional) ...[
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
                      decoration: const InputDecoration(
                        labelText: 'Profesional',
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('¿Se paga a plazos?'),
                subtitle: const Text(
                  'Para calcular cuándo toca el próximo pago',
                ),
                value: _pagaAPlazos,
                onChanged: (v) => setState(() => _pagaAPlazos = v),
              ),
              if (_pagaAPlazos)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _plazoFrecuenciaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cada cuántos meses',
                        ),
                      ),
                    ),
                    const SizedBox(width: ReparaSpace.s3),
                    Expanded(
                      child: TextField(
                        controller: _plazoImporteCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Importe por plazo (€)',
                        ),
                      ),
                    ),
                  ],
                ),
            ],
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
                  : const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
