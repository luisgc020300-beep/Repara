// lib/screens/nuevo_elemento_screen.dart
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../services/analytics_service.dart';
import '../services/elemento_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';

class NuevoElementoScreen extends StatefulWidget {
  const NuevoElementoScreen({required this.casa, required this.habitacionId, super.key});

  final Casa casa;
  final String habitacionId;

  @override
  State<NuevoElementoScreen> createState() => _NuevoElementoScreenState();
}

class _NuevoElementoScreenState extends State<NuevoElementoScreen> {
  final _nombreCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _costeCtrl = TextEditingController();
  final _profesionalCtrl = TextEditingController();
  final _intervaloCtrl = TextEditingController();
  DateTime? _fechaInstalacion;
  DateTime? _garantiaHasta;
  bool _guardando = false;
  bool _sugiriendo = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _costeCtrl.dispose();
    _profesionalCtrl.dispose();
    _intervaloCtrl.dispose();
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
    if (nombre.isEmpty) return;
    final intervaloMeses = int.tryParse(_intervaloCtrl.text.trim());
    setState(() => _guardando = true);
    try {
      final base = _fechaInstalacion ?? DateTime.now();
      final proximoMantenimiento =
          intervaloMeses == null ? null : DateTime(base.year, base.month + intervaloMeses, base.day);
      await ElementoService.crear(
        widget.casa.id,
        Elemento(
          id: '',
          nombre: nombre,
          habitacionId: widget.habitacionId,
          marca: _marcaCtrl.text.trim().isEmpty ? null : _marcaCtrl.text.trim(),
          modelo: _modeloCtrl.text.trim().isEmpty ? null : _modeloCtrl.text.trim(),
          fechaInstalacion: _fechaInstalacion,
          coste: double.tryParse(_costeCtrl.text.replaceAll(',', '.')),
          profesionalNombre: _profesionalCtrl.text.trim().isEmpty ? null : _profesionalCtrl.text.trim(),
          garantiaHasta: _garantiaHasta,
          intervaloMantenimientoMeses: intervaloMeses,
          proximoMantenimiento: proximoMantenimiento,
        ),
      );
      unawaited(AnalyticsService.firstElementCreated());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo guardar el elemento.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo elemento')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre (p.ej. Aire acondicionado)')),
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
                child: TextField(controller: _profesionalCtrl, decoration: const InputDecoration(labelText: 'Instalado por')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _elegirFecha(esGarantia: false),
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(_fechaInstalacion == null
                ? 'Fecha de instalación'
                : '${_fechaInstalacion!.day}/${_fechaInstalacion!.month}/${_fechaInstalacion!.year}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _elegirFecha(esGarantia: true),
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: Text(_garantiaHasta == null
                ? 'Garantía hasta'
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
                : const Text('Guardar elemento'),
          ),
        ],
      ),
    );
  }
}
