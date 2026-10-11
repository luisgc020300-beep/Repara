// lib/screens/nuevo_elemento_screen.dart
//
// Único flujo de creación de la app (octubre 2026, fusión Elemento/Trabajo/
// Evento): un elemento nunca nace solo, siempre con su registro fundacional
// -- "compré una freidora" tanto como "me cambiaron la depuradora de la
// piscina" se crean exactamente igual, con el mismo formulario. El tipo de
// registro + "¿lo hace un profesional?" deciden, para ESTE primer registro,
// si hace falta algo más que título/fecha/coste -- el flujo completo con
// presupuesto/invitación se hace después, desde el propio registro.
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../models/contacto.dart';
import '../models/elemento.dart';
import '../models/habitacion.dart';
import '../models/registro.dart';
import '../services/analytics_service.dart';
import '../services/contacto_service.dart';
import '../services/elemento_service.dart';
import '../services/habitacion_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';

class NuevoElementoScreen extends StatefulWidget {
  const NuevoElementoScreen({required this.casa, this.habitacionIdInicial, this.existente, super.key});

  final Casa casa;

  /// Preselecciona la ubicación cuando se abre desde dentro de una
  /// habitación concreta (Casa tab) -- sigue siendo editable en el propio
  /// formulario, nunca un valor fijo.
  final String? habitacionIdInicial;

  /// Si no es null, la pantalla edita este elemento en vez de crear uno
  /// nuevo -- solo los campos del elemento en sí, no su registro fundacional
  /// (eso se edita desde el propio registro).
  final Elemento? existente;

  @override
  State<NuevoElementoScreen> createState() => _NuevoElementoScreenState();
}

class _NuevoElementoScreenState extends State<NuevoElementoScreen> {
  late final _nombreCtrl = TextEditingController(text: widget.existente?.nombre ?? '');
  late final _marcaCtrl = TextEditingController(text: widget.existente?.marca ?? '');
  late final _modeloCtrl = TextEditingController(text: widget.existente?.modelo ?? '');
  late final _costeCtrl = TextEditingController(text: widget.existente?.coste?.toString() ?? '');
  late final _profesionalCtrl = TextEditingController(text: widget.existente?.profesionalNombre ?? '');
  final _profesionalFocusNode = FocusNode();
  late final _intervaloCtrl = TextEditingController(text: widget.existente?.intervaloMantenimientoMeses?.toString() ?? '');
  late DateTime? _fechaInstalacion = widget.existente?.fechaInstalacion;
  late DateTime? _garantiaHasta = widget.existente?.garantiaHasta;
  late String? _habitacionId = widget.existente?.habitacionId ?? widget.habitacionIdInicial;
  TipoRegistro _tipo = TipoRegistro.compra;
  bool _esConProfesional = false;
  bool _guardando = false;
  bool _sugiriendo = false;

  // Para que al tocar "Profesional" salgan por defecto los contactos ya
  // guardados de esta casa, en vez de obligar a teclear el nombre entero
  // cada vez (CEO, octubre 2026).
  List<Contacto> _contactos = const [];
  StreamSubscription<List<Contacto>>? _contactosSub;

  @override
  void initState() {
    super.initState();
    _contactosSub = ContactoService.streamContactos(widget.casa.id).listen((c) {
      if (mounted) setState(() => _contactos = c);
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _costeCtrl.dispose();
    _profesionalCtrl.dispose();
    _profesionalFocusNode.dispose();
    _intervaloCtrl.dispose();
    _contactosSub?.cancel();
    super.dispose();
  }

  Future<void> _sugerirIntervalo() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      AppError.show(context, 'Escribe antes el nombre del elemento.');
      return;
    }
    setState(() => _sugiriendo = true);
    try {
      final sugerencia = await ElementoService.sugerirIntervaloMantenimiento(
        nombre: nombre,
        marca: _marcaCtrl.text.trim().isEmpty ? null : _marcaCtrl.text.trim(),
        modelo: _modeloCtrl.text.trim().isEmpty ? null : _modeloCtrl.text.trim(),
      );
      if (!mounted) return;
      if (sugerencia.intervaloMeses == null) {
        AppError.show(context, sugerencia.motivo ?? 'La IA no sugiere una revisión periódica para esto.');
      } else {
        setState(() => _intervaloCtrl.text = sugerencia.intervaloMeses.toString());
        AppError.showSuccess(
          context,
          sugerencia.motivo ?? 'Sugerencia: revisar cada ${sugerencia.intervaloMeses} meses.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        AppError.show(
          context,
          e.code == 'resource-exhausted'
              ? (e.message ?? 'Has alcanzado el límite diario de análisis con IA.')
              : 'No se pudo contactar con el servicio de IA.',
        );
      }
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo contactar con el servicio de IA.');
    } finally {
      if (mounted) setState(() => _sugiriendo = false);
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      AppError.show(context, 'Escribe un nombre para el elemento.');
      return;
    }
    final intervaloMeses = int.tryParse(_intervaloCtrl.text.trim());
    setState(() => _guardando = true);
    try {
      final coste = double.tryParse(_costeCtrl.text.replaceAll(',', '.'));
      final profesional = _profesionalCtrl.text.trim().isEmpty ? null : _profesionalCtrl.text.trim();

      if (widget.existente != null) {
        // Si el intervalo no ha cambiado, conserva la próxima revisión tal
        // cual estaba guardada -- pudo ajustarse a mano o avanzar al marcar
        // una revisión como hecha, y no debe recalcularse desde cero solo
        // porque se ha corregido un typo en otro campo (p.ej. la marca).
        DateTime? proximoMantenimiento;
        if (intervaloMeses == widget.existente!.intervaloMantenimientoMeses) {
          proximoMantenimiento = widget.existente!.proximoMantenimiento;
        } else {
          final base = _fechaInstalacion ?? DateTime.now();
          proximoMantenimiento = intervaloMeses == null ? null : DateTime(base.year, base.month + intervaloMeses, base.day);
        }
        await ElementoService.actualizar(
          widget.casa.id,
          widget.existente!.id,
          Elemento(
            id: widget.existente!.id,
            nombre: nombre,
            habitacionId: _habitacionId,
            marca: _marcaCtrl.text.trim().isEmpty ? null : _marcaCtrl.text.trim(),
            modelo: _modeloCtrl.text.trim().isEmpty ? null : _modeloCtrl.text.trim(),
            fechaInstalacion: _fechaInstalacion,
            coste: coste,
            profesionalNombre: profesional,
            garantiaHasta: _garantiaHasta,
            intervaloMantenimientoMeses: intervaloMeses,
            proximoMantenimiento: proximoMantenimiento,
          ),
        );
      } else {
        final base = _fechaInstalacion ?? DateTime.now();
        final proximoMantenimiento =
            intervaloMeses == null ? null : DateTime(base.year, base.month + intervaloMeses, base.day);
        final elemento = Elemento(
          id: '',
          nombre: nombre,
          habitacionId: _habitacionId,
          marca: _marcaCtrl.text.trim().isEmpty ? null : _marcaCtrl.text.trim(),
          modelo: _modeloCtrl.text.trim().isEmpty ? null : _modeloCtrl.text.trim(),
          fechaInstalacion: _fechaInstalacion,
          coste: coste,
          profesionalNombre: profesional,
          garantiaHasta: _garantiaHasta,
          intervaloMantenimientoMeses: intervaloMeses,
          proximoMantenimiento: proximoMantenimiento,
        );
        final registro = Registro(
          id: '',
          elementoNombre: nombre,
          tipo: _tipo,
          esConProfesional: _esConProfesional,
          titulo: '${nombreTipoRegistro(_tipo)} de $nombre',
          estado: _esConProfesional ? EstadoRegistro.nuevo : EstadoRegistro.terminado,
          fecha: base,
          garantiaHasta: _garantiaHasta,
          coste: coste,
          profesionalNombre: profesional,
        );
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        await ElementoService.crearConRegistroFundacional(
          casaId: widget.casa.id,
          elemento: elemento,
          registroFundacional: registro,
          createdBy: uid,
        );
        unawaited(AnalyticsService.firstElementCreated());
      }
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) AppError.show(context, 'No se pudo guardar el elemento.', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _elegirFecha({required bool esGarantia}) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (elegida == null) return;
    setState(() {
      if (esGarantia) {
        _garantiaHasta = elegida;
      } else {
        _fechaInstalacion = elegida;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.existente != null;
    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar elemento' : 'Nuevo elemento')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!editando) ...[
            Text('Tipo', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: context.colors.brand)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TipoRegistro.values
                  .map((t) => ChoiceChip(
                        label: Text(nombreTipoRegistro(t)),
                        selected: _tipo == t,
                        onSelected: (_) => setState(() => _tipo = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('¿Lo hace un profesional?'),
              subtitle: const Text('Activa presupuesto, pagos e invitación de profesional'),
              value: _esConProfesional,
              onChanged: (v) => setState(() => _esConProfesional = v),
            ),
            const Divider(height: 32),
          ],
          TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre (p.ej. Aire acondicionado)')),
          const SizedBox(height: 12),
          StreamBuilder<List<Habitacion>>(
            stream: HabitacionService.streamHabitaciones(widget.casa.id),
            builder: (context, snapshot) {
              final habitaciones = snapshot.data ?? [];
              return DropdownButtonFormField<String?>(
                initialValue: _habitacionId,
                decoration: const InputDecoration(labelText: 'Ubicación'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin ubicación concreta')),
                  ...habitaciones.map((h) => DropdownMenuItem(value: h.id, child: Text(h.nombre))),
                ],
                onChanged: (v) => setState(() => _habitacionId = v),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _marcaCtrl, decoration: const InputDecoration(labelText: 'Marca'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _modeloCtrl, decoration: const InputDecoration(labelText: 'Modelo'))),
            ],
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
                child: RawAutocomplete<Contacto>(
                  textEditingController: _profesionalCtrl,
                  focusNode: _profesionalFocusNode,
                  displayStringForOption: (c) => c.nombre,
                  // Vacío (campo recién tocado) -> todos los contactos
                  // guardados, no solo los que coinciden con lo tecleado.
                  optionsBuilder: (value) => value.text.isEmpty
                      ? _contactos
                      : _contactos.where((c) => c.nombre.toLowerCase().contains(value.text.toLowerCase())),
                  onSelected: (c) => _profesionalCtrl.text = c.nombre,
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Profesional (opcional)'),
                  ),
                  optionsViewBuilder: (context, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220, minWidth: 220),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, i) {
                            final c = options.elementAt(i);
                            return ListTile(
                              dense: true,
                              title: Text(c.nombre),
                              subtitle: c.especialidad != null ? Text(c.especialidad!) : null,
                              onTap: () => onSelected(c),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _elegirFecha(esGarantia: false),
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(_fechaInstalacion == null
                ? 'Fecha'
                : '${_fechaInstalacion!.day}/${_fechaInstalacion!.month}/${_fechaInstalacion!.year}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _elegirFecha(esGarantia: true),
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: Text(_garantiaHasta == null
                ? 'Garantía hasta (opcional)'
                : '${_garantiaHasta!.day}/${_garantiaHasta!.month}/${_garantiaHasta!.year}'),
          ),
          const SizedBox(height: 20),
          Text('Revisión periódica (opcional)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: context.colors.brand)),
          const SizedBox(height: 4),
          Text(
            'Repara te avisará cuando toque revisarlo. Puedes escribir el número a mano o pedirle una sugerencia a la IA según el tipo de elemento.',
            style: TextStyle(fontSize: 12, color: context.colors.inkMuted),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _intervaloCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Revisar cada cuántos meses'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _sugiriendo ? null : _sugerirIntervalo,
                icon: _sugiriendo
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('Sugerir con IA'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(editando ? 'Guardar cambios' : 'Guardar elemento'),
          ),
        ],
      ),
    );
  }
}
