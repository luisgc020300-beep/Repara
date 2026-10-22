// lib/screens/cambio_alcance_section.dart
//
// ScopeGuard (secciones 19-21 del spec): "Cambios del registro" de cara al
// usuario. El profesional solicita, el propietario aprueba o rechaza --
// nunca al revés, y la Cloud Function responderCambioAlcance lo impone
// aunque alguien manipule el cliente.
//
// Rediseño de fidelidad visual (octubre 2026), misma identidad "REPARA
// Professional" que pagos_section.dart/presupuestos_section.dart/nuevo_
// documento_flow.dart: espaciados y radios tokenizados, foto con borde
// consistente, hoja de cámara/galería migrada al mismo patrón IosSection
// que ya usan menu_anadir.dart y nuevo_documento_flow.dart para la misma
// elección (cámara vs. galería), en vez de un Wrap de ListTile sin esquinas
// redondeadas. _CambioCard se mantiene como Card (no IosRow): mezcla
// título+estado, descripción opcional, coste adicional, tira de fotos y
// botones de aprobar/rechazar -- más contenido del que un IosRow (icono +
// título + subtítulo + trailing) puede representar; mismo criterio ya
// aplicado a _PresupuestoCard en presupuestos_section.dart, que es la
// pantalla hermana explícita de esta sección y tampoco usa IosRow.
import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/idempotency.dart';
import '../models/cambio_alcance.dart';
import '../screens/presupuestos_section.dart' show RolEnTrabajo;
import '../services/analytics_service.dart';
import '../services/cambio_alcance_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';

class CambiosAlcanceSection extends StatelessWidget {
  const CambiosAlcanceSection({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
    required this.rol,
    this.registroCerrado = false,
    super.key,
  });

  final String casaId;
  final String elementoId;
  final String registroId;
  final RolEnTrabajo rol;

  /// true si el registro ya está terminado/archivado (auditoría de
  /// producto, octubre 2026): un registro cerrado no admite nuevas
  /// solicitudes ni respuestas a las pendientes -- la Cloud Function ya lo
  /// bloquea, esto solo evita mostrar un botón que terminaría en un error
  /// evitable.
  final bool registroCerrado;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CambioAlcance>>(
      stream: CambioAlcanceService.streamCambios(
        casaId,
        elementoId,
        registroId,
      ),
      builder: (context, snapshot) {
        final cambios = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cambios del evento',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (rol == RolEnTrabajo.profesional && !registroCerrado)
                  TextButton.icon(
                    onPressed: () => _abrirFormulario(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Solicitar cambio'),
                  ),
              ],
            ),
            if (cambios.isEmpty)
              const EmptyHint(
                message: 'Sin cambios solicitados.',
                icon: Icons.rule_outlined,
              )
            else
              ...cambios.map(
                (c) => _CambioCard(
                  casaId: casaId,
                  elementoId: elementoId,
                  registroId: registroId,
                  cambio: c,
                  rol: rol,
                  registroCerrado: registroCerrado,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _abrirFormulario(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ReparaRadius.lg),
        ),
      ),
      builder: (_) => _FormularioCambioSheet(
        casaId: casaId,
        elementoId: elementoId,
        registroId: registroId,
      ),
    );
  }
}

class _CambioCard extends StatefulWidget {
  const _CambioCard({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
    required this.cambio,
    required this.rol,
    this.registroCerrado = false,
  });

  final String casaId;
  final String elementoId;
  final String registroId;
  final CambioAlcance cambio;
  final RolEnTrabajo rol;
  final bool registroCerrado;

  @override
  State<_CambioCard> createState() => _CambioCardState();
}

class _CambioCardState extends State<_CambioCard> {
  // Mismo motivo que _PresupuestoCardState en presupuestos_section.dart: el
  // servidor ya bloquea una segunda respuesta (transacción con comprobación
  // de estado), pero sin este guard un doble toque en una conexión lenta
  // enseñaba un error confuso por una acción que ya se había completado.
  bool _procesando = false;

  // warningText, no warning -- el ámbar base no llega a 4.5:1 de contraste
  // como texto (auditoría de accesibilidad, octubre 2026).
  Color _color(BuildContext context) => switch (widget.cambio.estado) {
    EstadoCambioAlcance.pendiente => context.colors.warningText,
    EstadoCambioAlcance.aprobado => context.colors.success,
    EstadoCambioAlcance.rechazado => context.colors.errorText,
    EstadoCambioAlcance.cancelado => context.colors.inkMuted,
  };

  Future<void> _responder(BuildContext context, bool aprobar) async {
    setState(() => _procesando = true);
    try {
      await CambioAlcanceService.responder(
        casaId: widget.casaId,
        elementoId: widget.elementoId,
        registroId: widget.registroId,
        cambioAlcanceId: widget.cambio.id,
        aprobar: aprobar,
      );
      unawaited(
        aprobar
            ? AnalyticsService.scopeChangeAccepted()
            : AnalyticsService.scopeChangeRejected(),
      );
    } on FirebaseFunctionsException catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          e.message ?? 'No se pudo responder a la solicitud.',
          error: e,
          stackTrace: st,
        );
      }
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo responder a la solicitud.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cambio = widget.cambio;
    return Card(
      margin: const EdgeInsets.only(bottom: ReparaSpace.s2),
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cambio.titulo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  // Mismas dimensiones (10/4) que la píldora gemela de
                  // presupuestos_section.dart y estado_registro_chip.dart --
                  // no se tokenizan a propósito para que las tres píldoras
                  // de estado de la app sigan midiendo exactamente lo mismo.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _color(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(ReparaRadius.pill),
                  ),
                  child: Text(
                    _nombreEstado(cambio.estado).toUpperCase(),
                    style: TextStyle(
                      color: _color(context),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            if (cambio.descripcion != null) ...[
              const SizedBox(height: ReparaSpace.s1),
              Text(
                cambio.descripcion!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            if (cambio.importeAdicional != null) ...[
              const SizedBox(height: ReparaSpace.s2),
              Row(
                children: [
                  Text(
                    'Coste adicional ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '+${cambio.importeAdicional!.toStringAsFixed(2)} €',
                    style: ReparaText.amount(context),
                  ),
                ],
              ),
            ],
            if (cambio.fotos.isNotEmpty) ...[
              const SizedBox(height: ReparaSpace.s3),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cambio.fotos.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: ReparaSpace.s2),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _verFotoCompleta(context, cambio.fotos[i]),
                    child: Container(
                      width: 70,
                      height: 70,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ReparaRadius.xs),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Image.network(cambio.fotos[i], fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ],
            if (cambio.estado == EstadoCambioAlcance.pendiente &&
                widget.rol == RolEnTrabajo.propietario &&
                !widget.registroCerrado) ...[
              const SizedBox(height: ReparaSpace.s3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _procesando
                          ? null
                          : () => _responder(context, false),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: ReparaSpace.s2),
                  Expanded(
                    child: FilledButton(
                      onPressed: _procesando
                          ? null
                          : () => _responder(context, true),
                      child: _procesando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Aprobar'),
                    ),
                  ),
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
      builder: (ctx) =>
          Dialog(child: InteractiveViewer(child: Image.network(url))),
    );
  }
}

class _LineaFoto {
  const _LineaFoto(this.archivo);
  final File archivo;
}

class _FormularioCambioSheet extends StatefulWidget {
  const _FormularioCambioSheet({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
  });

  final String casaId;
  final String elementoId;
  final String registroId;

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

  /// Generado una sola vez por instancia de esta hoja (no en cada tap de
  /// "Enviar") -- si el envío falla y el usuario reintenta sobre esta misma
  /// hoja, reutiliza el mismo valor para que un reintento de red no pueda
  /// duplicar la solicitud en servidor (ver lib/core/idempotency.dart).
  late final String _clientRequestId = generarIdempotencyKey();

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ReparaRadius.lg),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ReparaSpace.s4,
            ReparaSpace.s2,
            ReparaSpace.s4,
            ReparaSpace.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: ReparaSpace.s4),
                decoration: BoxDecoration(
                  color: ctx.colors.inkMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              IosSection(
                rows: [
                  IosRow(
                    icon: Icons.photo_camera_outlined,
                    iconColor: ctx.colors.brand,
                    title: 'Hacer una foto',
                    onTap: () async {
                      final navigator = Navigator.of(ctx);
                      final foto = await picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 85,
                      );
                      if (!mounted) return;
                      navigator.pop();
                      if (foto != null) {
                        setState(() => _fotos.add(_LineaFoto(File(foto.path))));
                      }
                    },
                  ),
                  IosRow(
                    icon: Icons.photo_library_outlined,
                    iconColor: ctx.colors.brand,
                    title: 'Elegir de la galería',
                    onTap: () async {
                      final navigator = Navigator.of(ctx);
                      final fotos = await picker.pickMultiImage(
                        imageQuality: 85,
                      );
                      if (!mounted) return;
                      navigator.pop();
                      if (fotos.isNotEmpty) {
                        setState(
                          () => _fotos.addAll(
                            fotos.map((f) => _LineaFoto(File(f.path))),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enviar() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      AppError.show(context, 'Escribe un título para la solicitud.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final urls = <String>[];
      for (final f in _fotos) {
        urls.add(
          await CambioAlcanceService.subirFoto(
            widget.casaId,
            widget.elementoId,
            widget.registroId,
            f.archivo,
            f.archivo.path.split(Platform.pathSeparator).last,
          ),
        );
      }
      await CambioAlcanceService.crear(
        casaId: widget.casaId,
        elementoId: widget.elementoId,
        registroId: widget.registroId,
        titulo: titulo,
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        motivo: _motivoCtrl.text.trim().isEmpty
            ? null
            : _motivoCtrl.text.trim(),
        importeAdicional: double.tryParse(
          _importeCtrl.text.replaceAll(',', '.'),
        ),
        fotos: urls,
        clientRequestId: _clientRequestId,
      );
      unawaited(AnalyticsService.scopeChangeCreated());
      if (mounted) {
        AppError.showSuccess(context, 'Solicitud enviada al propietario.');
        Navigator.pop(context);
      }
    } on FirebaseFunctionsException catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          e.message ?? 'No se pudo enviar la solicitud.',
          error: e,
          stackTrace: st,
        );
      }
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo enviar la solicitud.',
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
              'Solicitar cambio del evento',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: ReparaSpace.s4),
            TextField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(
                labelText: 'Título (p.ej. Sustituir válvula adicional)',
              ),
            ),
            const SizedBox(height: ReparaSpace.s3),
            TextField(
              controller: _motivoCtrl,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
            const SizedBox(height: ReparaSpace.s3),
            TextField(
              controller: _descripcionCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: ReparaSpace.s3),
            TextField(
              controller: _importeCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Coste adicional (€)',
              ),
            ),
            const SizedBox(height: ReparaSpace.s3),
            if (_fotos.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _fotos.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: ReparaSpace.s2),
                  itemBuilder: (context, i) => Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ReparaRadius.sm),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Image.file(_fotos[i].archivo, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          // Colors.black54/white deliberado -- insignia sobre
                          // una foto arbitraria, no una superficie del tema;
                          // necesita contraste garantizado independientemente
                          // de lo que haya en la foto y del modo claro/oscuro
                          // (mismo criterio que nuevo_documento_flow.dart).
                          onTap: () => setState(() => _fotos.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: ReparaSpace.s2),
            OutlinedButton.icon(
              onPressed: _anadirFotos,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(_fotos.isEmpty ? 'Añadir fotos' : 'Añadir más fotos'),
            ),
            const SizedBox(height: ReparaSpace.s4),
            FilledButton(
              onPressed: _guardando ? null : _enviar,
              child: _guardando
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.brandOn,
                      ),
                    )
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
