// lib/screens/cambio_alcance_section.dart
//
// ScopeGuard (secciones 19-21 del spec): "Cambios del trabajo" de cara al
// usuario. El profesional solicita, el propietario aprueba o rechaza --
// nunca al revés, y la Cloud Function responderCambioAlcance lo impone
// aunque alguien manipule el cliente.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/cambio_alcance.dart';
import '../screens/presupuestos_section.dart' show RolEnTrabajo;
import '../services/analytics_service.dart';
import '../services/cambio_alcance_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';

class CambiosAlcanceSection extends StatelessWidget {
  const CambiosAlcanceSection({required this.casaId, required this.trabajoId, required this.rol, super.key});

  final String casaId;
  final String trabajoId;
  final RolEnTrabajo rol;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CambioAlcance>>(
      stream: CambioAlcanceService.streamCambios(casaId, trabajoId),
      builder: (context, snapshot) {
        final cambios = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cambios del trabajo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (rol == RolEnTrabajo.profesional)
                  TextButton.icon(
                    onPressed: () => _abrirFormulario(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Solicitar cambio'),
                  ),
              ],
            ),
            if (cambios.isEmpty)
              Text('Sin cambios solicitados.', style: TextStyle(color: context.colors.inkMuted))
            else
              ...cambios.map((c) => _CambioCard(casaId: casaId, trabajoId: trabajoId, cambio: c, rol: rol)),
          ],
        );
      },
    );
  }

  Future<void> _abrirFormulario(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FormularioCambioSheet(casaId: casaId, trabajoId: trabajoId),
    );
  }
}

class _CambioCard extends StatelessWidget {
  const _CambioCard({required this.casaId, required this.trabajoId, required this.cambio, required this.rol});

  final String casaId;
  final String trabajoId;
  final CambioAlcance cambio;
  final RolEnTrabajo rol;

  Color _color(BuildContext context) => switch (cambio.estado) {
        EstadoCambioAlcance.pendiente => context.colors.warning,
        EstadoCambioAlcance.aprobado => context.colors.success,
        EstadoCambioAlcance.rechazado => context.colors.error,
        EstadoCambioAlcance.cancelado => context.colors.inkMuted,
      };

  Future<void> _responder(BuildContext context, bool aprobar) async {
    try {
      await CambioAlcanceService.responder(casaId: casaId, trabajoId: trabajoId, cambioAlcanceId: cambio.id, aprobar: aprobar);
      if (aprobar) unawaited(AnalyticsService.scopeChangeAccepted());
    } catch (e) {
      if (context.mounted) AppError.show(context, 'No se pudo responder a la solicitud.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(cambio.titulo, style: const TextStyle(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _color(context).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(_nombreEstado(cambio.estado), style: TextStyle(color: _color(context), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (cambio.descripcion != null) ...[
              const SizedBox(height: 4),
              Text(cambio.descripcion!),
            ],
            if (cambio.importeAdicional != null) ...[
              const SizedBox(height: 4),
              Text('Coste adicional: +${cambio.importeAdicional!.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            if (cambio.fotos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cambio.fotos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _verFotoCompleta(context, cambio.fotos[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(cambio.fotos[i], width: 70, height: 70, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ],
            if (cambio.estado == EstadoCambioAlcance.pendiente && rol == RolEnTrabajo.propietario) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => _responder(context, false), child: const Text('Rechazar'))),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(onPressed: () => _responder(context, true), child: const Text('Aprobar'))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _verFotoCompleta(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }
}

class _LineaFoto {
  const _LineaFoto(this.archivo);
  final File archivo;
}

class _FormularioCambioSheet extends StatefulWidget {
  const _FormularioCambioSheet({required this.casaId, required this.trabajoId});

  final String casaId;
  final String trabajoId;

  @override
  State<_FormularioCambioSheet> createState() => _FormularioCambioSheetState();
}

class _FormularioCambioSheetState extends State<_FormularioCambioSheet> {
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _importeCtrl = TextEditingController();
  final List<_LineaFoto> _fotos = [];
  bool _guardando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _motivoCtrl.dispose();
    _importeCtrl.dispose();
    super.dispose();
  }

  Future<void> _anadirFotos() async {
    final picker = ImagePicker();
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Hacer una foto'),
            onTap: () async {
              final navigator = Navigator.of(ctx);
              final foto = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
              navigator.pop();
              if (foto != null) setState(() => _fotos.add(_LineaFoto(File(foto.path))));
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () async {
              final navigator = Navigator.of(ctx);
              final fotos = await picker.pickMultiImage(imageQuality: 85);
              navigator.pop();
              if (fotos.isNotEmpty) setState(() => _fotos.addAll(fotos.map((f) => _LineaFoto(File(f.path)))));
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _enviar() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) return;
    setState(() => _guardando = true);
    try {
      final urls = <String>[];
      for (final f in _fotos) {
        urls.add(await CambioAlcanceService.subirFoto(widget.casaId, f.archivo, f.archivo.path.split(Platform.pathSeparator).last));
      }
      await CambioAlcanceService.crear(
        casaId: widget.casaId,
        trabajoId: widget.trabajoId,
        titulo: titulo,
        descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
        motivo: _motivoCtrl.text.trim().isEmpty ? null : _motivoCtrl.text.trim(),
        importeAdicional: double.tryParse(_importeCtrl.text.replaceAll(',', '.')),
        fotos: urls,
      );
      unawaited(AnalyticsService.scopeChangeCreated());
      if (mounted) {
        AppError.showSuccess(context, 'Solicitud enviada al propietario.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo enviar la solicitud.');
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
            Text('Solicitar cambio del trabajo', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: 'Título (p.ej. Sustituir válvula adicional)')),
            const SizedBox(height: 12),
            TextField(controller: _motivoCtrl, minLines: 1, maxLines: 2, decoration: const InputDecoration(labelText: 'Motivo')),
            const SizedBox(height: 12),
            TextField(controller: _descripcionCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción')),
            const SizedBox(height: 12),
            TextField(
              controller: _importeCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Coste adicional (€)'),
            ),
            const SizedBox(height: 12),
            if (_fotos.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _fotos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_fotos[i].archivo, width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          onTap: () => setState(() => _fotos.removeAt(i)),
                          child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _anadirFotos,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(_fotos.isEmpty ? 'Añadir fotos' : 'Añadir más fotos'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _guardando ? null : _enviar,
              child: _guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enviar al propietario'),
            ),
          ],
        ),
      ),
    );
  }
}

String _nombreEstado(EstadoCambioAlcance e) => switch (e) {
      EstadoCambioAlcance.pendiente => 'Pendiente',
      EstadoCambioAlcance.aprobado => 'Aprobado',
      EstadoCambioAlcance.rechazado => 'Rechazado',
      EstadoCambioAlcance.cancelado => 'Cancelado',
    };
