// lib/screens/nuevo_trabajo_screen.dart
//
// Crear trabajo (sección 14 del spec, simplificado): qué ocurre, dónde,
// descripción y quién lo va a hacer -- el profesional es texto libre en v1
// (ver nota en models/trabajo.dart sobre por qué no hay invitación por
// enlace todavía).
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../models/contacto.dart';
import '../models/habitacion.dart';
import '../models/trabajo.dart';
import '../services/analytics_service.dart';
import '../services/contacto_service.dart';
import '../services/habitacion_service.dart';
import '../services/trabajo_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';

class NuevoTrabajoScreen extends StatefulWidget {
  const NuevoTrabajoScreen({required this.casa, super.key});

  final Casa casa;

  @override
  State<NuevoTrabajoScreen> createState() => _NuevoTrabajoScreenState();
}

class _NuevoTrabajoScreenState extends State<NuevoTrabajoScreen> {
  TipoTrabajo _tipo = TipoTrabajo.averia;
  String? _habitacionId;
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _profesionalNombreCtrl = TextEditingController();
  final _profesionalContactoCtrl = TextEditingController();
  final _presupuestoCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _profesionalNombreCtrl.dispose();
    _profesionalContactoCtrl.dispose();
    _presupuestoCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirDeContactos() async {
    final contacto = await showModalBottomSheet<Contacto>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SelectorContactos(casaId: widget.casa.id),
    );
    if (contacto == null) return;
    setState(() {
      _profesionalNombreCtrl.text = contacto.nombre;
      _profesionalContactoCtrl.text = contacto.telefono;
    });
  }

  Future<void> _guardar() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) return;
    setState(() => _guardando = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await TrabajoService.crear(
        widget.casa.id,
        Trabajo(
          id: '',
          titulo: titulo,
          tipo: _tipo,
          estado: EstadoTrabajo.nuevo,
          descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
          habitacionId: _habitacionId,
          profesionalNombre: _profesionalNombreCtrl.text.trim().isEmpty ? null : _profesionalNombreCtrl.text.trim(),
          profesionalContacto: _profesionalContactoCtrl.text.trim().isEmpty ? null : _profesionalContactoCtrl.text.trim(),
          presupuesto: double.tryParse(_presupuestoCtrl.text.replaceAll(',', '.')),
        ),
        createdBy: uid,
      );
      unawaited(AnalyticsService.workCreated(tipo: _tipo.name));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo crear el trabajo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo trabajo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('¿Qué ocurre?', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: TipoTrabajo.values.map((t) {
              return ChoiceChip(label: Text(_nombreTipoTrabajo(t)), selected: _tipo == t, onSelected: (_) => setState(() => _tipo = t));
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: 'Título (p.ej. Fuga en el baño)')),
          const SizedBox(height: 12),
          TextField(
            controller: _descripcionCtrl,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Habitacion>>(
            stream: HabitacionService.streamHabitaciones(widget.casa.id),
            builder: (context, snapshot) {
              final habitaciones = snapshot.data ?? [];
              return DropdownButtonFormField<String?>(
                initialValue: _habitacionId,
                decoration: const InputDecoration(labelText: '¿Dónde? (opcional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin especificar')),
                  ...habitaciones.map((h) => DropdownMenuItem(value: h.id, child: Text(h.nombre))),
                ],
                onChanged: (v) => setState(() => _habitacionId = v),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('¿Quién lo va a hacer?', style: TextStyle(fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: _elegirDeContactos,
                icon: const Icon(Icons.contacts_outlined, size: 18),
                label: const Text('De mis contactos'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: _profesionalNombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del profesional')),
          const SizedBox(height: 12),
          TextField(controller: _profesionalContactoCtrl, decoration: const InputDecoration(labelText: 'Teléfono o contacto')),
          const SizedBox(height: 12),
          TextField(
            controller: _presupuestoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Presupuesto estimado (€)'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Crear trabajo'),
          ),
        ],
      ),
    );
  }
}

String _nombreTipoTrabajo(TipoTrabajo t) => switch (t) {
      TipoTrabajo.averia => 'Avería',
      TipoTrabajo.reparacion => 'Reparación',
      TipoTrabajo.mantenimiento => 'Mantenimiento',
      TipoTrabajo.reforma => 'Reforma',
      TipoTrabajo.instalacion => 'Instalación',
      TipoTrabajo.otro => 'Otro',
    };

class _SelectorContactos extends StatelessWidget {
  const _SelectorContactos({required this.casaId});

  final String casaId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Elige un contacto', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: StreamBuilder<List<Contacto>>(
                stream: ContactoService.streamContactos(casaId),
                builder: (context, snapshot) {
                  final contactos = snapshot.data ?? [];
                  if (contactos.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Todavía no tienes contactos guardados. Añádelos desde la pestaña Contactos.',
                        style: TextStyle(color: context.colors.inkMuted),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: contactos.length,
                    itemBuilder: (context, i) {
                      final c = contactos[i];
                      return ListTile(
                        leading: Icon(
                          c.tipo == TipoContacto.empresa ? Icons.business_outlined : Icons.person_outline,
                          color: context.colors.brand,
                        ),
                        title: Text(c.nombre),
                        subtitle: Text(c.especialidad?.isNotEmpty == true ? '${c.especialidad} · ${c.telefono}' : c.telefono),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
