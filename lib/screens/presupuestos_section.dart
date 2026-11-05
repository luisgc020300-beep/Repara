// lib/screens/presupuestos_section.dart
//
// Sección de presupuestos formales (secciones 15-18 del spec), reutilizada
// tanto en la ficha de registro de Hogar (rol propietario: aceptar/rechazar)
// como en la de Pro (rol profesional: crear, enviar, versionar). Los totales
// mostrados aquí son solo para revisión visual -- los que cuentan de verdad
// son los que calcula el servidor en Cloud Functions.
//
// Rediseño de fidelidad visual (octubre 2026), misma identidad "REPARA
// Professional" que pagos_section.dart/cambio_alcance_section.dart (la
// pantalla hermana recién revisada): espaciados y radio de la hoja
// tokenizados, mismo padding de tarjeta (ReparaSpace.s4) que _CambioCard.
// _PresupuestoCard se mantiene como Card (no IosRow): título+estado,
// líneas de detalle, divisor, subtotal/IVA/total y botones de enviar o
// aceptar/rechazar -- mucho más contenido del que un IosRow (icono+título+
// subtítulo+trailing) puede representar; mismo criterio ya aplicado a
// _CambioCard en cambio_alcance_section.dart.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:repara_core/presupuesto.dart';
import 'package:repara_core/presupuesto_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import '../services/conceptos_frecuentes_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';
import '../widgets/presupuesto_pdf.dart';

// Plantilla de presupuesto (auditoría de producto, octubre 2026): recuerda
// en este dispositivo las líneas del último presupuesto creado desde cero
// por este profesional, para no volver a teclear lo mismo en cada trabajo
// parecido. Local, no por Firestore -- evita abrir una vía de lectura
// entre casas distintas solo para esto.
const _claveUltimaPlantilla = 'repara_ultima_plantilla_presupuesto';

enum RolEnTrabajo { propietario, profesional }

class PresupuestosSection extends StatelessWidget {
  const PresupuestosSection({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
    required this.rol,
    this.registroTitulo,
    this.elementoNombre,
    this.casaNombre,
    this.profesionalNombre,
    super.key,
  });

  final String casaId;
  final String elementoId;
  final String registroId;
  final RolEnTrabajo rol;

  /// Contexto para "Descargar PDF" (ampliación Fase 3, noviembre 2026) --
  /// opcionales porque el lado profesional no tiene acceso de lectura a la
  /// casa (ver registro_pro_detail_screen.dart), así que [casaNombre] no
  /// siempre está disponible. Un PDF sin alguno de estos campos simplemente
  /// omite esa línea, nunca inventa un valor de relleno.
  final String? registroTitulo;
  final String? elementoNombre;
  final String? casaNombre;
  final String? profesionalNombre;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Presupuesto>>(
      stream: PresupuestoService.streamPresupuestos(
        casaId,
        elementoId,
        registroId,
      ),
      builder: (context, snapshot) {
        final presupuestos = snapshot.data ?? [];
        final ultimo = presupuestos.isEmpty ? null : presupuestos.first;
        final puedeCrearNuevo =
            rol == RolEnTrabajo.profesional &&
            (ultimo == null || ultimo.estado == EstadoPresupuesto.rechazado);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Presupuestos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (puedeCrearNuevo)
                  TextButton.icon(
                    onPressed: () => _abrirEditor(
                      context,
                      presupuestoAnteriorId:
                          ultimo?.estado == EstadoPresupuesto.rechazado
                          ? ultimo!.id
                          : null,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      ultimo != null ? 'Nueva versión' : 'Crear presupuesto',
                    ),
                  ),
              ],
            ),
            if (presupuestos.isEmpty)
              const EmptyHint(
                message: 'Sin presupuestos todavía.',
                icon: Icons.request_quote_outlined,
              )
            else
              ...presupuestos.map(
                (p) => _PresupuestoCard(
                  casaId: casaId,
                  elementoId: elementoId,
                  registroId: registroId,
                  presupuesto: p,
                  rol: rol,
                  registroTitulo: registroTitulo,
                  elementoNombre: elementoNombre,
                  casaNombre: casaNombre,
                  profesionalNombre: profesionalNombre,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _abrirEditor(
    BuildContext context, {
    String? presupuestoAnteriorId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ReparaRadius.lg),
        ),
      ),
      builder: (_) => _EditorPresupuestoSheet(
        casaId: casaId,
        elementoId: elementoId,
        registroId: registroId,
        presupuestoAnteriorId: presupuestoAnteriorId,
      ),
    );
  }
}

class _PresupuestoCard extends StatefulWidget {
  const _PresupuestoCard({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
    required this.presupuesto,
    required this.rol,
    this.registroTitulo,
    this.elementoNombre,
    this.casaNombre,
    this.profesionalNombre,
  });

  final String casaId;
  final String elementoId;
  final String registroId;
  final Presupuesto presupuesto;
  final RolEnTrabajo rol;
  final String? registroTitulo;
  final String? elementoNombre;
  final String? casaNombre;
  final String? profesionalNombre;

  @override
  State<_PresupuestoCard> createState() => _PresupuestoCardState();
}

class _PresupuestoCardState extends State<_PresupuestoCard> {
  // Sin esto, un doble toque en una conexión lenta podía disparar dos
  // llamadas a responderPresupuesto/enviarPresupuesto antes de que el
  // StreamBuilder de arriba repintara con el nuevo estado y ocultara estos
  // botones -- el servidor ya lo bloquea (transacción con comprobación de
  // estado), pero la segunda llamada le enseñaba al usuario un error
  // confuso por una acción que en realidad ya se había completado bien.
  bool _procesando = false;

  // warningText, no warning -- el ámbar base no llega a 4.5:1 de contraste
  // como texto (auditoría de accesibilidad, octubre 2026), solo vale como
  // icono o como fondo tenue.
  Color _colorEstado(BuildContext context) =>
      switch (widget.presupuesto.estado) {
        EstadoPresupuesto.borrador => context.colors.inkMuted,
        EstadoPresupuesto.enviado => context.colors.warningText,
        EstadoPresupuesto.aceptado => context.colors.successText,
        EstadoPresupuesto.rechazado => context.colors.errorText,
        EstadoPresupuesto.cancelado => context.colors.inkMuted,
      };

  Future<void> _responder(BuildContext context, bool aceptar) async {
    setState(() => _procesando = true);
    try {
      await PresupuestoService.responder(
        casaId: widget.casaId,
        elementoId: widget.elementoId,
        registroId: widget.registroId,
        presupuestoId: widget.presupuesto.id,
        aceptar: aceptar,
      );
      unawaited(
        aceptar
            ? AnalyticsService.quoteAccepted()
            : AnalyticsService.quoteRejected(),
      );
    } on FirebaseFunctionsException catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          e.message ?? 'No se pudo responder al presupuesto.',
          error: e,
          stackTrace: st,
        );
      }
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo responder al presupuesto.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _enviar(BuildContext context) async {
    setState(() => _procesando = true);
    try {
      await PresupuestoService.enviar(
        casaId: widget.casaId,
        elementoId: widget.elementoId,
        registroId: widget.registroId,
        presupuestoId: widget.presupuesto.id,
      );
      if (context.mounted) {
        AppError.showSuccess(context, 'Presupuesto enviado.');
      }
    } on FirebaseFunctionsException catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          e.message ?? 'No se pudo enviar el presupuesto.',
          error: e,
          stackTrace: st,
        );
      }
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo enviar el presupuesto.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _descargarPdf(BuildContext context) async {
    try {
      await PresupuestoPdf.descargar(
        context,
        presupuesto: widget.presupuesto,
        registroTitulo: widget.registroTitulo ?? 'Presupuesto',
        elementoNombre: widget.elementoNombre,
        casaNombre: widget.casaNombre,
        profesionalNombre: widget.profesionalNombre,
      );
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo generar el PDF.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final presupuesto = widget.presupuesto;
    final fecha = presupuesto.fechaEnvio ?? presupuesto.fechaCreacion;
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
                    'Presupuesto #${presupuesto.numero} · v${presupuesto.version}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Descargar PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _descargarPdf(context),
                ),
                Container(
                  // Mismas dimensiones (10/4) que la píldora gemela de
                  // cambio_alcance_section.dart y estado_registro_chip.dart --
                  // no se tokenizan a propósito para que las tres píldoras
                  // de estado de la app sigan midiendo exactamente lo mismo.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _colorEstado(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(ReparaRadius.pill),
                  ),
                  child: Text(
                    _nombreEstado(presupuesto.estado).toUpperCase(),
                    style: TextStyle(
                      color: _colorEstado(context),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            if (fecha != null) ...[
              const SizedBox(height: 2),
              Text(
                DateFormat('d MMM yyyy', 'es_ES').format(fecha),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: ReparaSpace.s3),
            ...presupuesto.lineas.map(
              (l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: ReparaSpace.s1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${l.descripcion} (${l.cantidad.toStringAsFixed(l.cantidad == l.cantidad.roundToDouble() ? 0 : 1)})',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(width: ReparaSpace.s2),
                    Text(
                      '${l.importeSinIva.toStringAsFixed(2)} €',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ReparaSpace.s3),
              child: Divider(height: 1, color: context.colors.border),
            ),
            Text(
              'Subtotal ${presupuesto.subtotal.toStringAsFixed(2)} € · IVA ${presupuesto.iva.toStringAsFixed(2)} €',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: ReparaSpace.s1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.colors.inkMuted,
                  ),
                ),
                Text(
                  '${presupuesto.total.toStringAsFixed(2)} €',
                  style: ReparaText.amount(context, large: true),
                ),
              ],
            ),
            if (presupuesto.notas != null &&
                presupuesto.notas!.trim().isNotEmpty) ...[
              const SizedBox(height: ReparaSpace.s3),
              Text(
                'Observaciones',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.inkMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                presupuesto.notas!.trim(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (presupuesto.estado == EstadoPresupuesto.borrador &&
                widget.rol == RolEnTrabajo.profesional) ...[
              const SizedBox(height: ReparaSpace.s3),
              FilledButton(
                onPressed: _procesando ? null : () => _enviar(context),
                child: _procesando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar al propietario'),
              ),
            ],
            if (presupuesto.estado == EstadoPresupuesto.enviado &&
                widget.rol == RolEnTrabajo.propietario) ...[
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
                          : const Text('Aceptar'),
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
}

class _EditorPresupuestoSheet extends StatefulWidget {
  const _EditorPresupuestoSheet({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
    this.presupuestoAnteriorId,
  });

  final String casaId;
  final String elementoId;
  final String registroId;
  final String? presupuestoAnteriorId;

  @override
  State<_EditorPresupuestoSheet> createState() =>
      _EditorPresupuestoSheetState();
}

class _LineaEnEdicion {
  final descripcionCtrl = TextEditingController();
  final cantidadCtrl = TextEditingController(text: '1');
  final precioCtrl = TextEditingController();
  final ivaCtrl = TextEditingController(text: '21');
}

class _EditorPresupuestoSheetState extends State<_EditorPresupuestoSheet> {
  final _notasCtrl = TextEditingController();
  final List<_LineaEnEdicion> _lineas = [_LineaEnEdicion()];
  bool _guardando = false;
  bool _desdePlantilla = false;
  List<ConceptoFrecuente> _conceptos = const [];

  @override
  void initState() {
    super.initState();
    // Solo tiene sentido ofrecer la plantilla en un presupuesto desde cero
    // -- una nueva versión ya parte de las líneas del anterior.
    if (widget.presupuestoAnteriorId == null) _cargarPlantilla();
    // Los conceptos frecuentes, en cambio, son útiles siempre -- también al
    // crear una nueva versión tras un rechazo.
    _cargarConceptos();
  }

  Future<void> _cargarConceptos() async {
    final conceptos = await ConceptosFrecuentesService.listar();
    if (mounted) setState(() => _conceptos = conceptos);
  }

  void _insertarConcepto(ConceptoFrecuente c) {
    setState(
      () => _lineas.add(
        _LineaEnEdicion()
          ..descripcionCtrl.text = c.nombre
          ..precioCtrl.text = c.precioUnitario.toStringAsFixed(2)
          ..ivaCtrl.text = c.ivaPorcentaje.toStringAsFixed(0),
      ),
    );
  }

  Future<void> _eliminarConcepto(ConceptoFrecuente c) async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Quitar "${c.nombre}" de tus conceptos frecuentes?',
      confirmLabel: 'Quitar',
      destructive: true,
    );
    if (!confirmar) return;
    await ConceptosFrecuentesService.eliminar(c.nombre);
    await _cargarConceptos();
  }

  Future<void> _abrirNuevoConcepto() async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final ivaCtrl = TextEditingController(text: '21');
    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: AppDialog.shape(),
        title: const Text('Nuevo concepto frecuente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre (p.ej. Desplazamiento)',
              ),
            ),
            const SizedBox(height: ReparaSpace.s2),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: precioCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Precio (€)'),
                  ),
                ),
                const SizedBox(width: ReparaSpace.s2),
                Expanded(
                  child: TextField(
                    controller: ivaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'IVA %'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardado != true || nombreCtrl.text.trim().isEmpty) return;
    await ConceptosFrecuentesService.guardar(
      ConceptoFrecuente(
        nombre: nombreCtrl.text.trim(),
        precioUnitario:
            double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0,
        ivaPorcentaje: double.tryParse(ivaCtrl.text.replaceAll(',', '.')) ?? 21,
      ),
    );
    await _cargarConceptos();
  }

  Future<void> _cargarPlantilla() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_claveUltimaPlantilla);
      if (json == null || !mounted) return;
      final lineas = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      if (lineas.isEmpty) return;
      setState(() {
        _lineas
          ..clear()
          ..addAll(
            lineas.map(
              (l) => _LineaEnEdicion()
                ..descripcionCtrl.text = l['descripcion'] as String? ?? ''
                ..cantidadCtrl.text = l['cantidad'] as String? ?? '1'
                ..precioCtrl.text = l['precio'] as String? ?? ''
                ..ivaCtrl.text = l['iva'] as String? ?? '21',
            ),
          );
        _desdePlantilla = true;
      });
    } catch (e) {
      // Plantilla local corrupta o ausente -- se sigue con una línea vacía,
      // nunca bloquea la creación de un presupuesto por esto.
    }
  }

  Future<void> _guardarPlantilla(List<_LineaEnEdicion> lineas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(
        lineas
            .map(
              (l) => {
                'descripcion': l.descripcionCtrl.text.trim(),
                'cantidad': l.cantidadCtrl.text.trim(),
                'precio': l.precioCtrl.text.trim(),
                'iva': l.ivaCtrl.text.trim(),
              },
            )
            .toList(),
      );
      await prefs.setString(_claveUltimaPlantilla, json);
    } catch (e) {
      // Guardar la plantilla es una comodidad, no algo crítico -- un fallo
      // aquí nunca debe impedir que el presupuesto ya guardado se vea bien.
    }
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  double get _totalEstimado {
    var total = 0.0;
    for (final l in _lineas) {
      final cantidad =
          double.tryParse(l.cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
      final precio =
          double.tryParse(l.precioCtrl.text.replaceAll(',', '.')) ?? 0;
      final iva = double.tryParse(l.ivaCtrl.text.replaceAll(',', '.')) ?? 0;
      total += cantidad * precio * (1 + iva / 100);
    }
    return total;
  }

  Future<void> _guardarYEnviar() async {
    final lineasValidas = _lineas
        .where((l) => l.descripcionCtrl.text.trim().isNotEmpty)
        .toList();
    if (lineasValidas.isEmpty) {
      AppError.show(context, 'Añade al menos una línea con descripción.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final lineas = lineasValidas
          .map(
            (l) => (
              descripcion: l.descripcionCtrl.text.trim(),
              cantidad:
                  double.tryParse(l.cantidadCtrl.text.replaceAll(',', '.')) ??
                  1,
              precioUnitario:
                  double.tryParse(l.precioCtrl.text.replaceAll(',', '.')) ?? 0,
              ivaPorcentaje:
                  double.tryParse(l.ivaCtrl.text.replaceAll(',', '.')) ?? 21,
            ),
          )
          .toList();
      if (widget.presupuestoAnteriorId != null) {
        await PresupuestoService.crearNuevaVersion(
          casaId: widget.casaId,
          elementoId: widget.elementoId,
          registroId: widget.registroId,
          presupuestoAnteriorId: widget.presupuestoAnteriorId!,
          lineas: lineas
              .map(
                (l) => LineaPresupuesto(
                  descripcion: l.descripcion,
                  cantidad: l.cantidad,
                  precioUnitario: l.precioUnitario,
                  ivaPorcentaje: l.ivaPorcentaje,
                ),
              )
              .toList(),
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
      } else {
        await PresupuestoService.crear(
          casaId: widget.casaId,
          elementoId: widget.elementoId,
          registroId: widget.registroId,
          lineas: lineas
              .map(
                (l) => LineaPresupuesto(
                  descripcion: l.descripcion,
                  cantidad: l.cantidad,
                  precioUnitario: l.precioUnitario,
                  ivaPorcentaje: l.ivaPorcentaje,
                ),
              )
              .toList(),
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
      }
      unawaited(AnalyticsService.quoteCreated(numLineas: lineasValidas.length));
      if (widget.presupuestoAnteriorId == null) {
        await _guardarPlantilla(lineasValidas);
      }
      if (mounted) {
        AppError.showSuccess(context, 'Presupuesto guardado como borrador.');
        Navigator.pop(context);
      }
    } on FirebaseFunctionsException catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          e.message ?? 'No se pudo guardar el presupuesto.',
          error: e,
          stackTrace: st,
        );
      }
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo guardar el presupuesto.',
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
    // GestureDetector para poder cerrar el teclado tocando en cualquier hueco
    // vacío de la hoja (auditoría de producto, octubre 2026): el teclado
    // numérico de Cant./Precio/IVA no siempre trae un botón visible para
    // cerrarlo, y sin esto se quedaba tapando el botón de guardar sin forma
    // de quitarlo salvo cerrando la hoja entera.
    return GestureDetector(
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
                'Nuevo presupuesto',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              if (_desdePlantilla) ...[
                const SizedBox(height: ReparaSpace.s1),
                Row(
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 14,
                      color: context.colors.inkMuted,
                    ),
                    const SizedBox(width: ReparaSpace.s1),
                    Expanded(
                      child: Text(
                        'Rellenado con las líneas de tu último presupuesto -- edítalas o bórralas libremente.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: ReparaSpace.s3),
              Text(
                'Conceptos frecuentes',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.inkMuted,
                ),
              ),
              const SizedBox(height: ReparaSpace.s1),
              Wrap(
                spacing: ReparaSpace.s2,
                runSpacing: ReparaSpace.s1,
                children: [
                  for (final c in _conceptos)
                    InputChip(
                      label: Text(c.nombre),
                      onPressed: () => _insertarConcepto(c),
                      onDeleted: () => _eliminarConcepto(c),
                      deleteIconColor: context.colors.inkMuted,
                    ),
                  ActionChip(
                    avatar: Icon(
                      Icons.add,
                      size: 16,
                      color: context.colors.brand,
                    ),
                    label: const Text('Nuevo'),
                    onPressed: _abrirNuevoConcepto,
                  ),
                ],
              ),
              const SizedBox(height: ReparaSpace.s4),
              ..._lineas.asMap().entries.map((entry) {
                final i = entry.key;
                final l = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: ReparaSpace.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: l.descripcionCtrl,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Descripción',
                              ),
                            ),
                          ),
                          if (_lineas.length > 1)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Quitar línea',
                              onPressed: () =>
                                  setState(() => _lineas.removeAt(i)),
                            ),
                        ],
                      ),
                      const SizedBox(height: ReparaSpace.s2),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: l.cantidadCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Cant.',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: ReparaSpace.s2),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: l.precioCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Precio (€)',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: ReparaSpace.s2),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: l.ivaCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'IVA %',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _lineas.add(_LineaEnEdicion())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Añadir línea'),
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
              const SizedBox(height: ReparaSpace.s3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Total estimado: ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${_totalEstimado.toStringAsFixed(2)} €',
                    style: ReparaText.amount(context),
                  ),
                ],
              ),
              const SizedBox(height: ReparaSpace.s4),
              FilledButton(
                onPressed: _guardando ? null : _guardarYEnviar,
                child: _guardando
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.brandOn,
                        ),
                      )
                    : const Text('Guardar como borrador'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _nombreEstado(EstadoPresupuesto e) => switch (e) {
  EstadoPresupuesto.borrador => 'Borrador',
  EstadoPresupuesto.enviado => 'Enviado',
  EstadoPresupuesto.aceptado => 'Aceptado',
  EstadoPresupuesto.rechazado => 'Rechazado',
  EstadoPresupuesto.cancelado => 'Cancelado',
};
