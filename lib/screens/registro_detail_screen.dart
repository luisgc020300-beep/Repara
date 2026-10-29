// lib/screens/registro_detail_screen.dart
//
// Expediente de un registro (sección 13 del spec). Rediseño de fidelidad a
// referencia visual (octubre 2026): cabecera con miniatura, tarjeta
// económica de 3 columnas, pestañas Resumen/Cambios/Pagos/Documentos e
// historial real de la reparación -- ver lib/models/historial_evento.dart.
// Un registro con profesional (esConProfesional) despliega presupuesto/
// pagos/cambios/invitación; uno simple (una compra, una nota) solo muestra
// sus datos con editar/eliminar, con la misma cabecera para que se sienta
// el mismo producto.
import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../models/elemento.dart';
import '../models/historial_evento.dart';
import '../models/invitacion.dart';
import '../models/pago.dart';
import '../models/registro.dart';
import '../services/analytics_service.dart';
import '../services/documento_service.dart';
import '../services/elemento_service.dart';
import '../services/historial_service.dart';
import '../services/invitacion_service.dart';
import '../services/pago_service.dart';
import '../services/registro_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';
import '../widgets/estado_registro_chip.dart';
import '../widgets/foto_ampliada_screen.dart';
import '../widgets/historial_timeline.dart';
import '../widgets/ios_list.dart';
import 'cambio_alcance_section.dart';
import 'editar_registro_sheet.dart';
import 'elemento_detail_screen.dart';
import 'nuevo_documento_flow.dart';
import 'pagos_section.dart';
import 'presupuestos_section.dart';

String _formatoImporte(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class RegistroDetailScreen extends StatelessWidget {
  const RegistroDetailScreen({
    required this.casa,
    required this.elementoId,
    required this.registroId,
    super.key,
  });

  final Casa casa;
  final String elementoId;
  final String registroId;

  Future<void> _finalizar(BuildContext context, Registro registro) async {
    final confirmar = await AppDialog.confirm(
      context,
      title: 'Finalizar evento',
      message:
          'Se marcará como terminado y quedará guardado en el historial de la casa.',
      confirmLabel: 'Finalizar',
    );
    if (!confirmar || !context.mounted) return;
    await _confirmarFinalizacion(context, registro);
  }

  /// Compartido entre "Finalizar" (el propietario cierra directamente) y
  /// "Confirmar" (el propietario da por buena la finalización que dice
  /// haber hecho el profesional) -- en ambos casos el resultado final es
  /// el mismo, lo único que cambia es si hubo o no un paso previo del
  /// profesional (modelo de dos pasos, auditoría de producto, octubre 2026).
  Future<void> _confirmarFinalizacion(
    BuildContext context,
    Registro registro,
  ) async {
    // Aviso, no bloqueo (decisión del CEO): que falte pago no debe impedir
    // cerrar un registro si el cobro llega más tarde (transferencia,
    // financiación...), pero sí se avisa para no perderlo de vista.
    var pagadoDelTodo = false;
    if (registro.presupuesto != null) {
      final pagado = await PagoService.totalPagado(
        casa.id,
        elementoId,
        registro.id,
      );
      pagadoDelTodo = pagado >= registro.presupuesto!;
      if (!pagadoDelTodo && context.mounted) {
        final seguir = await AppDialog.confirm(
          context,
          title: 'Todavía no está pagado del todo',
          message:
              'Llevas pagado ${pagado.toStringAsFixed(2)} € de ${registro.presupuesto!.toStringAsFixed(2)} €. '
              '¿Quieres finalizar igualmente?',
          confirmLabel: 'Finalizar igualmente',
        );
        if (!seguir) return;
      }
    }
    if (!context.mounted) return;
    try {
      // Cloud Function, no escritura directa (auditoría de seguridad,
      // octubre 2026): estado=terminado se escribe atómicamente en servidor
      // -- las reglas de Firestore ya bloquean marcar un registro como
      // terminado por una escritura directa.
      await RegistroService.finalizar(casa.id, elementoId, registro.id);
      unawaited(AnalyticsService.workCompleted(pagadoDelTodo: pagadoDelTodo));
      if (context.mounted) {
        AppError.showSuccess(context, 'Evento archivado en el historial.');
      }

      // Bucle viral en UN solo momento (auditoría de producto, octubre
      // 2026): justo cuando el registro ha ido bien de verdad -- terminado Y
      // pagado del todo, con un profesional real de Repara de por medio.
      // Nunca en ningún otro sitio, nunca con descuentos artificiales.
      if (pagadoDelTodo && registro.profesionalUid != null && context.mounted) {
        await _ofrecerCompartir(context, registro);
      }
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo finalizar el evento.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  /// El propietario dice que, en realidad, todavía no está terminado --
  /// devuelve el registro a como estaba antes de que el profesional lo
  /// marcara, y le avisa para que siga con él.
  Future<void> _rechazarFinalizacion(
    BuildContext context,
    Registro registro,
  ) async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Todavía no está terminado?',
      message: 'Se avisará al profesional para que lo siga revisando.',
      confirmLabel: 'Todavía no',
    );
    if (!confirmar || !context.mounted) return;
    try {
      await RegistroService.rechazarFinalizacionProfesional(
        casa.id,
        elementoId,
        registro.id,
      );
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo actualizar el evento.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _ofrecerCompartir(
    BuildContext context,
    Registro registro,
  ) async {
    final compartir = await AppDialog.confirm(
      context,
      title: '¿Te ha ido bien?',
      message:
          '${registro.profesionalNombre ?? 'Tu profesional'} también puede recibir más clientes como tú a través de Repara.',
      cancelLabel: 'Ahora no',
      confirmLabel: 'Compartir',
    );
    if (!compartir || !context.mounted) return;
    try {
      // sharePositionOrigin obligatorio en iOS -- ver nota en
      // contacto_acciones.dart.
      await Share.share(
        'He usado Repara para gestionar "${registro.titulo}"${registro.profesionalNombre != null ? ' con ${registro.profesionalNombre}' : ''} '
        '-- presupuesto, cambios y pagos, todo en un sitio. Pruébalo tú también.',
        sharePositionOrigin: Offset.zero & MediaQuery.of(context).size,
      );
    } catch (e) {
      // Decorativo -- que falle el selector de compartir no debe parecer
      // que el registro no se finalizó bien.
    }
  }

  /// Eliminación real (CEO, octubre 2026, cierre de R7/R8): la Cloud
  /// Function limpia también la foto del registro en Storage y los
  /// documentos (con sus archivos) que lo referencian -- RegistroService.
  /// eliminar() ya no hace la escritura insegura que esto deshabilitaba (ver
  /// esa función). Solo disponible para un registro simple -- un registro
  /// con profesional nunca llega a ofrecer esta opción (ver el menú más
  /// abajo), y el servidor la rechaza de todos modos si se intentara saltar
  /// la UI.
  Future<void> _eliminar(BuildContext context, Registro registro) async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Eliminar este evento?',
      message:
          'Se eliminará para siempre, junto con su foto y los documentos '
          'que tenga asociados. Esto no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmar || !context.mounted) return;
    try {
      await RegistroService.eliminar(casa.id, elementoId, registro.id);
      if (context.mounted) Navigator.pop(context);
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo eliminar el evento.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  /// Sustituye al "Descargar expediente (PDF)" de la referencia visual --
  /// REPARA no genera un PDF real todavía (ver CLAUDE.md: "Exportación del
  /// Expediente de la vivienda a PDF real... hoy es resumen en pantalla +
  /// compartir como texto"), así que un botón con esa etiqueta prometería
  /// algo que no existe. Reutiliza el mismo patrón de Share.share ya usado
  /// en _ofrecerCompartir, con un resumen de texto real de este registro.
  Future<void> _compartirResumen(
    BuildContext context,
    Registro registro,
    double? pagado,
  ) async {
    final partes = <String>[
      'Expediente de "${registro.titulo}" -- ${casa.nombre}',
    ];
    if (registro.presupuesto != null) {
      partes.add('Presupuesto: ${_formatoImporte(registro.presupuesto!)} €');
    }
    if (pagado != null) partes.add('Pagado: ${_formatoImporte(pagado)} €');
    partes.add('Estado: ${nombreEstadoRegistro(registro.estado)}');
    partes.add('Gestionado con Repara.');
    try {
      await Share.share(
        partes.join('\n'),
        sharePositionOrigin: Offset.zero & MediaQuery.of(context).size,
      );
    } catch (e) {
      // Decorativo -- un fallo del selector de compartir no debe parecer un
      // error de guardado, no hay nada que guardar aquí.
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Registro?>(
      stream: RegistroService.streamRegistro(casa.id, elementoId, registroId),
      builder: (context, snapshot) {
        // Mismo fix que elemento_detail_screen.dart (auditoría R3/R4, octubre
        // 2026): snapshot.data == null por sí solo es ambiguo entre "todavía
        // no ha llegado el primer snapshot", "el registro ya no existe" y
        // "el stream terminó en error" (p.ej. permission-denied si deja de
        // haber acceso mientras la ficha está abierta -- streamRegistro()
        // relanza cualquier fallo de lectura, ver conRegistroDeErrores). Sin
        // distinguir los tres casos, el segundo y el tercero se quedaban
        // enseñando el spinner para siempre, sin botón de volver.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('No se pudo cargar este evento.'),
            ),
          );
        }
        final registro = snapshot.data;
        if (registro == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Este evento ya no existe.')),
          );
        }
        return Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 14,
                  color: context.colors.inkMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    casa.nombre,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  if (v == 'editar') {
                    mostrarEditarRegistroSheet(
                      context,
                      casaId: casa.id,
                      elementoId: elementoId,
                      registro: registro,
                    );
                  } else if (v == 'eliminar') {
                    _eliminar(context, registro);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: context.colors.inkMuted,
                        ),
                        const SizedBox(width: 10),
                        const Text('Editar evento'),
                      ],
                    ),
                  ),
                  // "Eliminar evento" se mantiene solo para el registro
                  // simple -- un registro con profesional (un trabajo
                  // contratado, con posible presupuesto/pagos detrás) no
                  // debe poder borrarse de un toque ni aunque el borrado
                  // en sí esté deshabilitado (ver _eliminar más arriba).
                  if (!registro.esConProfesional)
                    PopupMenuItem(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: context.colors.inkMuted,
                          ),
                          const SizedBox(width: 10),
                          const Text('Eliminar evento'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: registro.esConProfesional
              ? _CuerpoConProfesional(
                  casa: casa,
                  elementoId: elementoId,
                  registro: registro,
                  onFinalizar: () => _finalizar(context, registro),
                  onConfirmarFinalizacion: () =>
                      _confirmarFinalizacion(context, registro),
                  onRechazarFinalizacion: () =>
                      _rechazarFinalizacion(context, registro),
                  onCompartirResumen: (pagado) =>
                      _compartirResumen(context, registro, pagado),
                )
              : _CuerpoSimple(
                  casa: casa,
                  elementoId: elementoId,
                  registro: registro,
                ),
        );
      },
    );
  }
}

/// Cabecera compartida entre el cuerpo con profesional y el simple -- mismo
/// producto, mismo lenguaje visual (auditoría de craft, octubre 2026).
/// [elemento] es opcional porque su stream vive en el widget padre
/// (compartido con la tarjeta de mantenimiento cuando aplica, para no abrir
/// dos suscripciones a la misma colección).
class _CabeceraRegistro extends StatelessWidget {
  const _CabeceraRegistro({
    required this.casa,
    required this.elementoId,
    required this.registro,
    this.elemento,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;
  final Elemento? elemento;

  @override
  Widget build(BuildContext context) {
    final fotoUrl = registro.fotoUrl ?? elemento?.fotoUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      iconoTipoRegistro(registro.tipo),
                      size: 12,
                      color: context.colors.inkMuted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${registro.elementoNombre} · ${nombreTipoRegistro(registro.tipo)}'
                            .toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: context.colors.inkMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  registro.titulo,
                  style: Theme.of(context).textTheme.displaySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    EstadoRegistroChip(estado: registro.estado),
                    const SizedBox(width: 8),
                    Text(
                      '· ${DateFormat('d MMM yyyy', 'es_ES').format(registro.fecha)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            // Igual que _FotoElemento en elemento_detail_screen.dart: con
            // foto, tocarla la amplía a pantalla completa -- cambiarla es
            // el lápiz pequeño de la esquina, con su propio toque aparte
            // (antes compartían el mismo GestureDetector y tocar en
            // cualquier punto, lápiz incluido, abría la cámara/galería).
            onTap: fotoUrl == null
                ? () => _cambiarFotoRegistro(context, casa, elementoId, registro)
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FotoAmpliadaScreen(url: fotoUrl)),
                  ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ReparaRadius.md),
              child: Stack(
                children: [
                  fotoUrl != null
                      ? Image.network(
                          fotoUrl,
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          // URL de foto rota -- cae a un icono claro en vez
                          // de dejar un hueco en blanco.
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 92,
                                height: 92,
                                color: context.colors.surfaceMuted,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 24,
                                  color: context.colors.inkFaint,
                                ),
                              ),
                        )
                      : Container(
                          width: 92,
                          height: 92,
                          color: context.colors.surfaceMuted,
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 24,
                            color: context.colors.inkFaint,
                          ),
                        ),
                  if (fotoUrl != null)
                    Positioned(
                      right: 3,
                      bottom: 3,
                      child: GestureDetector(
                        onTap: () => _cambiarFotoRegistro(
                          context,
                          casa,
                          elementoId,
                          registro,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mismo flujo que _cambiarFoto en elemento_detail_screen.dart (cámara o
/// galería), pero escribe en [Registro.fotoUrl] -- nunca toca la foto del
/// elemento padre, aunque sea la que se esté mostrando como respaldo.
Future<void> _cambiarFotoRegistro(
  BuildContext context,
  Casa casa,
  String elementoId,
  Registro registro,
) async {
  final picker = ImagePicker();
  final foto = await showModalBottomSheet<XFile?>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: IosSection(
          rows: [
            IosRow(
              icon: Icons.photo_camera_outlined,
              iconColor: ctx.colors.brand,
              title: 'Hacer una foto',
              onTap: () async {
                final navigator = Navigator.of(ctx);
                final imagen = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                  maxWidth: 1600,
                  maxHeight: 1600,
                );
                if (!ctx.mounted) return;
                navigator.pop(imagen);
              },
            ),
            IosRow(
              icon: Icons.photo_library_outlined,
              iconColor: ctx.colors.brand,
              title: 'Elegir de la galería',
              onTap: () async {
                final navigator = Navigator.of(ctx);
                final imagen = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 1600,
                  maxHeight: 1600,
                );
                if (!ctx.mounted) return;
                navigator.pop(imagen);
              },
            ),
          ],
        ),
      ),
    ),
  );
  if (foto == null || !context.mounted) return;
  try {
    final url = await RegistroService.subirFoto(
      casa.id,
      elementoId,
      registro.id,
      File(foto.path),
    );
    await RegistroService.actualizarFoto(casa.id, elementoId, registro.id, url);
  } catch (e, st) {
    if (context.mounted) {
      AppError.show(
        context,
        'No se pudo guardar la foto.',
        error: e,
        stackTrace: st,
      );
    }
  }
}

/// Tarjeta económica de 3 columnas (presupuesto/pagado/saldo o completado) --
/// combina la composición de la referencia visual con el tratamiento de
/// importes de pago_detail_screen.dart. Recibe [pagado] ya calculado por el
/// padre (un único `StreamBuilder<List<Pago>>` compartido con la pestaña de
/// Pagos -- nunca una segunda suscripción a la misma colección).
class _TarjetaEconomica extends StatelessWidget {
  const _TarjetaEconomica({required this.presupuesto, required this.pagado});

  final double presupuesto;
  final double pagado;

  @override
  Widget build(BuildContext context) {
    final saldo = (presupuesto - pagado).clamp(0, double.infinity).toDouble();
    final completo = pagado >= presupuesto;
    final porcentaje = presupuesto <= 0
        ? 0.0
        : (pagado / presupuesto).clamp(0, 1).toDouble();

    Widget etiqueta(String texto) => Text(
      texto.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.colors.inkMuted,
        fontSize: 10,
      ),
    );

    Widget columna(String texto, Widget valor) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [etiqueta(texto), const SizedBox(height: 4), valor],
      ),
    );

    Widget divisor() => Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: context.colors.border,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(ReparaRadius.md),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              columna(
                'Presupuesto',
                Text(
                  '${_formatoImporte(presupuesto)} €',
                  style: ReparaText.amount(context),
                ),
              ),
              divisor(),
              columna(
                'Pagado',
                Text(
                  '${_formatoImporte(pagado)} €',
                  style: ReparaText.amount(
                    context,
                  ).copyWith(color: context.colors.success),
                ),
              ),
              divisor(),
              completo
                  ? columna(
                      'Estado',
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: context.colors.success,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Completado',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: context.colors.success),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  : columna(
                      'Saldo',
                      Text(
                        '${_formatoImporte(saldo)} €',
                        style: ReparaText.amount(context),
                      ),
                    ),
            ],
          ),
          if (!completo) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: porcentaje,
                minHeight: 6,
                backgroundColor: context.colors.surfaceSunken,
                color: context.colors.brand,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila de pestañas tipo "pill" (indicador relleno, no subrayado) -- mismo
/// TabBar/TabBarView de Material, solo con un indicador personalizado; evita
/// construir un control a medida para algo que el framework ya resuelve.
const _tabs = ['Resumen', 'Cambios', 'Pagos', 'Documentos'];
const _tabIcons = [
  Icons.summarize_outlined,
  Icons.swap_horiz,
  Icons.payments_outlined,
  Icons.description_outlined,
];

class _CuerpoConProfesional extends StatelessWidget {
  const _CuerpoConProfesional({
    required this.casa,
    required this.elementoId,
    required this.registro,
    required this.onFinalizar,
    required this.onConfirmarFinalizacion,
    required this.onRechazarFinalizacion,
    required this.onCompartirResumen,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;
  final VoidCallback onFinalizar;
  final VoidCallback onConfirmarFinalizacion;
  final VoidCallback onRechazarFinalizacion;
  final void Function(double? pagado) onCompartirResumen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Elemento?>(
      stream: ElementoService.streamElemento(casa.id, elementoId),
      builder: (context, elementoSnap) {
        final elemento = elementoSnap.data;
        return StreamBuilder<List<Pago>>(
          stream: PagoService.streamPagos(casa.id, elementoId, registro.id),
          builder: (context, pagosSnap) {
            final pagos = pagosSnap.data ?? [];
            final totalPagado = pagos.fold<double>(
              0,
              (acc, p) => acc + p.importe,
            );
            return DefaultTabController(
              length: _tabs.length,
              child: Column(
                children: [
                  _CabeceraRegistro(
                    casa: casa,
                    elementoId: elementoId,
                    registro: registro,
                    elemento: elemento,
                  ),
                  if (registro.estado == EstadoRegistro.pendienteConfirmacion)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: AvisoRegistro(
                        mensaje:
                            'El profesional dice que ha terminado este evento. ¿Lo confirmas?',
                        acciones: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: onRechazarFinalizacion,
                                child: const Text('Todavía no'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: onConfirmarFinalizacion,
                                child: const Text('Confirmar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Trabajo confirmado pero sin cobrar del todo (CEO, octubre
                  // 2026): se pasa a "Terminado" solo cuando los pagos de la
                  // pestaña Pagos cubran el total -- aquí solo se avisa, sin
                  // botones, para no duplicar la acción real de apuntar el
                  // pago.
                  if (registro.estado == EstadoRegistro.pendientePago)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: AvisoRegistro(
                        mensaje:
                            'El trabajo está hecho, pero todavía falta cobrarlo del todo. '
                            'Apunta el pago en la pestaña Pagos para cerrarlo.',
                      ),
                    ),
                  if (registro.presupuesto != null)
                    _TarjetaEconomica(
                      presupuesto: registro.presupuesto!,
                      pagado: totalPagado,
                    ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: context.colors.border),
                      ),
                    ),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicator: BoxDecoration(
                        color: context.colors.brandStrong,
                        borderRadius: BorderRadius.circular(ReparaRadius.pill),
                      ),
                      indicatorSize: TabBarIndicatorSize.label,
                      indicatorPadding: const EdgeInsets.symmetric(vertical: 6),
                      dividerColor: Colors.transparent,
                      labelColor: context.colors.brandOn,
                      unselectedLabelColor: context.colors.inkMuted,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: [
                        for (var i = 0; i < _tabs.length; i++)
                          Tab(
                            height: 36,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_tabIcons[i], size: 15),
                                  const SizedBox(width: 6),
                                  Text(_tabs[i]),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _ResumenTab(
                          casa: casa,
                          elementoId: elementoId,
                          registro: registro,
                          elemento: elemento,
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: CambiosAlcanceSection(
                            casaId: casa.id,
                            elementoId: elementoId,
                            registroId: registro.id,
                            rol: RolEnTrabajo.propietario,
                            registroCerrado:
                                registro.estado == EstadoRegistro.terminado ||
                                registro.estado ==
                                    EstadoRegistro.archivado ||
                                registro.estado ==
                                    EstadoRegistro.pendientePago,
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: PagosSection(
                            casaId: casa.id,
                            elementoId: elementoId,
                            registroId: registro.id,
                            registroTitulo: registro.titulo,
                            presupuesto: registro.presupuesto,
                            rol: RolEnTrabajo.propietario,
                          ),
                        ),
                        _DocumentosTab(
                          casa: casa,
                          elementoId: elementoId,
                          registro: registro,
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      // Antes había además un FloatingActionButton
                      // "Finalizar" flotando sobre esta misma barra -- se
                      // solapaban visualmente. Una sola barra con las dos
                      // acciones evita el choque y mantiene ambas alcanzables.
                      child: _estadoControlado(registro.estado)
                          ? SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => onCompartirResumen(
                                  pagos.isEmpty ? null : totalPagado,
                                ),
                                icon: const Icon(
                                  Icons.ios_share_outlined,
                                  size: 18,
                                ),
                                label: const Text('Compartir resumen'),
                              ),
                            )
                          : Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () => onCompartirResumen(
                                    pagos.isEmpty ? null : totalPagado,
                                  ),
                                  child: const Icon(
                                    Icons.ios_share_outlined,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: onFinalizar,
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Finalizar'),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ResumenTab extends StatelessWidget {
  const _ResumenTab({
    required this.casa,
    required this.elementoId,
    required this.registro,
    this.elemento,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;
  final Elemento? elemento;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // "terminado"/"archivado"/"pendienteConfirmacion" nunca son opción
        // de este desplegable (auditoría de seguridad, octubre 2026):
        // "Finalizar"/"Confirmar"/"Todavía no" son las únicas puertas -- el
        // servidor ya lo bloquea aunque se fuerce desde fuera de la app. El
        // chip de la cabecera ya muestra el estado en ese caso, así que el
        // desplegable solo aparece cuando de verdad es editable.
        if (!_estadoControlado(registro.estado)) ...[
          DropdownButtonFormField<EstadoRegistro>(
            initialValue: registro.estado,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: _estadosEditables
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(nombreEstadoRegistro(e)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                RegistroService.actualizarEstado(
                  casa.id,
                  elementoId,
                  registro.id,
                  v,
                );
              }
            },
          ),
          const SizedBox(height: 20),
        ],
        if (registro.descripcion != null) ...[
          Text(
            registro.descripcion!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
        ],
        Text('Profesional', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        _SeccionInvitarProfesional(
          casa: casa,
          elementoId: elementoId,
          registro: registro,
        ),
        const SizedBox(height: 20),
        PresupuestosSection(
          casaId: casa.id,
          elementoId: elementoId,
          registroId: registro.id,
          rol: RolEnTrabajo.propietario,
        ),
        const SizedBox(height: 20),
        _TarjetaMantenimiento(
          casa: casa,
          elementoId: elementoId,
          elemento: elemento,
        ),
        const SizedBox(height: 20),
        _SeccionHistorial(
          casa: casa,
          elementoId: elementoId,
          registro: registro,
        ),
      ],
    );
  }
}

/// Tarjeta de mantenimiento del Elemento padre (p.ej. "la caldera"), no del
/// registro -- el intervalo/próxima revisión es un dato del aparato, vive en
/// Elemento (ver models/elemento.dart), no se inventa aquí. Reutiliza la
/// pantalla ya existente para editarlo en vez de duplicar el diálogo de
/// elemento_detail_screen.dart.
class _TarjetaMantenimiento extends StatelessWidget {
  const _TarjetaMantenimiento({
    required this.casa,
    required this.elementoId,
    required this.elemento,
  });

  final Casa casa;
  final String elementoId;
  final Elemento? elemento;

  String? _textoProximaRevision() {
    final fecha = elemento?.proximoMantenimiento;
    if (fecha == null) return null;
    final dias = fecha.difference(DateTime.now()).inDays;
    if (dias < 0) {
      return 'Atrasada desde el ${DateFormat('d MMM yyyy', 'es_ES').format(fecha)}';
    }
    if (dias < 45) return 'En $dias días';
    return 'En ${(dias / 30).round()} meses';
  }

  @override
  Widget build(BuildContext context) {
    if (elemento == null) return const SizedBox.shrink();
    final texto = _textoProximaRevision();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(ReparaRadius.md),
      ),
      // Fila de icono+texto arriba, botón a todo lo ancho debajo -- en vez de
      // los tres en una sola fila: con el botón al lado, el texto se quedaba
      // con tan poco ancho que "Próximo mantenimiento" y el propio valor se
      // partían palabra a palabra (CEO, octubre 2026: "se ve pegado a la
      // izquierda, no se ve limpio").
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_outlined, color: context.colors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Próximo mantenimiento',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      texto ?? 'Sin recordatorio configurado todavía',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ElementoDetailScreen(casa: casa, elementoId: elementoId),
              ),
            ),
            icon: const Icon(Icons.calendar_month_outlined, size: 16),
            label: Text(
              texto != null ? 'Editar recordatorio' : 'Añadir recordatorio',
            ),
          ),
        ],
      ),
    );
  }
}

/// Historial real de la reparación: combina el único suceso que no tiene
/// evento propio en Firestore (el cierre del registro -- ver
/// firestore.rules, "el propio registro es el historial") con los eventos
/// reales de presupuestos/cambios/pagos (historial_service.dart). El cierre
/// nunca lleva fecha porque no existe ningún timestamp real de cuándo
/// ocurrió -- se muestra sin inventar una.
class _SeccionHistorial extends StatelessWidget {
  const _SeccionHistorial({
    required this.casa,
    required this.elementoId,
    required this.registro,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart, size: 16, color: context.colors.inkMuted),
            const SizedBox(width: 6),
            Text(
              'Historial de la reparación',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<HistorialEvento>>(
          stream: HistorialService.streamHistorial(
            casa.id,
            elementoId,
            registro.id,
          ),
          builder: (context, snapshot) {
            final eventos = snapshot.data ?? [];
            final items = <TimelineItem>[
              if (registro.estado == EstadoRegistro.terminado ||
                  registro.estado == EstadoRegistro.archivado)
                TimelineItem(
                  titulo: registro.estado == EstadoRegistro.archivado
                      ? 'Evento archivado'
                      : 'Trabajo finalizado',
                  subtitulo: 'Marcado como terminado',
                  icono: Icons.task_alt,
                  color: context.colors.success,
                ),
              if (registro.estado == EstadoRegistro.pendientePago)
                TimelineItem(
                  titulo: 'Trabajo confirmado',
                  subtitulo: 'Pendiente de cobrar del todo',
                  icono: Icons.hourglass_top_outlined,
                  color: context.colors.warningText,
                ),
              ...eventos.map((e) => _eventoATimelineItem(context, e)),
            ];
            if (items.isEmpty) {
              return const EmptyHint(
                message: 'Sin actividad registrada todavía.',
                icon: Icons.show_chart,
              );
            }
            return HistorialTimeline(items: items);
          },
        ),
      ],
    );
  }

  TimelineItem _eventoATimelineItem(BuildContext context, HistorialEvento e) {
    final fecha = e.timestamp != null
        ? DateFormat('d MMM yyyy · HH:mm', 'es_ES').format(e.timestamp!)
        : null;
    final importeTexto = e.importe != null
        ? '${_formatoImporte(e.importe!)} €'
        : null;
    switch (e.entidad) {
      case EntidadHistorial.presupuesto:
        final titulo = switch (e.accion) {
          'aceptado' => 'Presupuesto aceptado',
          'rechazado' => 'Presupuesto rechazado',
          'enviado' => 'Presupuesto enviado',
          'nueva_version' => 'Nueva versión de presupuesto',
          'editado' => 'Presupuesto editado',
          _ => 'Presupuesto creado',
        };
        return TimelineItem(
          titulo: titulo,
          subtitulo: importeTexto,
          fechaTexto: fecha,
          icono: Icons.request_quote_outlined,
          color: e.accion == 'rechazado'
              ? context.colors.errorText
              : context.colors.success,
        );
      case EntidadHistorial.cambioAlcance:
        final titulo = switch (e.accion) {
          'aprobado' => 'Cambio de alcance aprobado',
          'rechazado' => 'Cambio de alcance rechazado',
          'cancelado' => 'Cambio de alcance cancelado',
          _ => 'Cambio de alcance solicitado',
        };
        return TimelineItem(
          titulo: titulo,
          subtitulo: e.motivo ?? importeTexto,
          fechaTexto: fecha,
          icono: Icons.rule_outlined,
          color: (e.accion == 'rechazado' || e.accion == 'cancelado')
              ? context.colors.errorText
              : context.colors.success,
        );
      case EntidadHistorial.pago:
        final titulo = switch (e.accion) {
          'eliminado' => 'Pago eliminado',
          'editado' => 'Pago editado',
          _ => 'Pago registrado',
        };
        return TimelineItem(
          titulo: titulo,
          subtitulo: importeTexto,
          fechaTexto: fecha,
          icono: Icons.payments_outlined,
          color: e.accion == 'eliminado'
              ? context.colors.errorText
              : context.colors.success,
        );
      case EntidadHistorial.desconocida:
        return TimelineItem(
          titulo: e.accion,
          fechaTexto: fecha,
          icono: Icons.circle_outlined,
          color: context.colors.inkMuted,
        );
    }
  }
}

class _DocumentosTab extends StatelessWidget {
  const _DocumentosTab({
    required this.casa,
    required this.elementoId,
    required this.registro,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Documentos',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextButton.icon(
              onPressed: () => iniciarNuevoDocumento(
                context,
                casaId: casa.id,
                elementoId: elementoId,
                registroId: registro.id,
              ),
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              label: const Text('Escanear documento'),
            ),
          ],
        ),
        StreamBuilder<List<Documento>>(
          stream: DocumentoService.streamDocumentos(
            casa.id,
            registroId: registro.id,
          ),
          builder: (context, snapshot) {
            final documentos = snapshot.data ?? [];
            if (documentos.isEmpty) {
              return const EmptyHint(
                message: 'Sin documentos todavía.',
                icon: Icons.description_outlined,
              );
            }
            return IosSection(
              rows: documentos
                  .map(
                    (d) => IosRow(
                      icon: Icons.insert_drive_file_outlined,
                      iconColor: context.colors.brand,
                      title: d.proveedor ?? d.nombreArchivo,
                      trailing: d.importe != null
                          ? Text(
                              '${d.importe!.toStringAsFixed(0)} €',
                              style: ReparaText.amount(context),
                            )
                          : null,
                      showChevron: false,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

/// Cuerpo de un registro simple (sin profesional): misma cabecera que el
/// cuerpo con profesional, sin pestañas ni tarjeta económica de 3 columnas
/// -- no hay presupuesto, cambios de alcance ni pagos que mostrar aquí.
class _CuerpoSimple extends StatelessWidget {
  const _CuerpoSimple({
    required this.casa,
    required this.elementoId,
    required this.registro,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Elemento?>(
      stream: ElementoService.streamElemento(casa.id, elementoId),
      builder: (context, elementoSnap) {
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _CabeceraRegistro(
              casa: casa,
              elementoId: elementoId,
              registro: registro,
              elemento: elementoSnap.data,
            ),
            if (registro.estado == EstadoRegistro.pendientePago)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: AvisoRegistro(
                  mensaje:
                      'El trabajo está hecho, pero todavía falta cobrarlo del todo. '
                      'Apunta el pago más abajo para cerrarlo.',
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: _nombreEstadoSimple(registro),
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Estado'),
                  ),
                  const SizedBox(height: 16),
                  if (registro.descripcion != null) ...[
                    Text(
                      registro.descripcion!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _ResumenEconomico(
                    casa: casa,
                    elementoId: elementoId,
                    registro: registro,
                  ),
                  const SizedBox(height: 20),
                  // "Coste" (arriba, en _ResumenEconomico) es solo lo que
                  // costó -- un número informativo, nunca un registro de lo
                  // que de verdad se ha pagado. Un registro simple no tiene
                  // presupuesto (nunca se fija en esta vía, ver
                  // nuevo_registro_sheet.dart/nuevo_elemento_screen.dart),
                  // así que PagosSection recibe presupuesto: null -- ya está
                  // preparada para eso (ver pago_detail_screen.dart: el
                  // tope contra el presupuesto solo se aplica si no es
                  // null), igual que registrarPago en servidor. No hace
                  // falta ningún cambio de Cloud Function ni de reglas:
                  // registrarPago ya nunca ha exigido esConProfesional,
                  // solo lo usaba quien construía la pantalla.
                  PagosSection(
                    casaId: casa.id,
                    elementoId: elementoId,
                    registroId: registro.id,
                    registroTitulo: registro.titulo,
                    presupuesto: null,
                    rol: RolEnTrabajo.propietario,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Documentos',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      TextButton.icon(
                        onPressed: () => iniciarNuevoDocumento(
                          context,
                          casaId: casa.id,
                          elementoId: elementoId,
                          registroId: registro.id,
                        ),
                        icon: const Icon(
                          Icons.document_scanner_outlined,
                          size: 18,
                        ),
                        label: const Text('Escanear documento'),
                      ),
                    ],
                  ),
                  StreamBuilder<List<Documento>>(
                    stream: DocumentoService.streamDocumentos(
                      casa.id,
                      registroId: registro.id,
                    ),
                    builder: (context, snapshot) {
                      final documentos = snapshot.data ?? [];
                      if (documentos.isEmpty) {
                        return const EmptyHint(
                          message: 'Sin documentos todavía.',
                          icon: Icons.description_outlined,
                        );
                      }
                      return IosSection(
                        rows: documentos
                            .map(
                              (d) => IosRow(
                                icon: Icons.insert_drive_file_outlined,
                                iconColor: context.colors.brand,
                                title: d.proveedor ?? d.nombreArchivo,
                                trailing: d.importe != null
                                    ? Text(
                                        '${d.importe!.toStringAsFixed(0)} €',
                                        style: ReparaText.amount(context),
                                      )
                                    : null,
                                showChevron: false,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Invitar a un profesional que ya tiene cuenta en Repara (sección 15 del
/// spec, simplificado a solo email -- ver decisión del CEO). Si ya hay un
/// profesional vinculado, muestra quién es en vez del formulario.
class _SeccionInvitarProfesional extends StatefulWidget {
  const _SeccionInvitarProfesional({
    required this.casa,
    required this.elementoId,
    required this.registro,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;

  @override
  State<_SeccionInvitarProfesional> createState() =>
      _SeccionInvitarProfesionalState();
}

class _SeccionInvitarProfesionalState
    extends State<_SeccionInvitarProfesional> {
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  bool _enviando = false;
  // El código abierto no se guarda en Firestore para mostrarlo aquí -- el
  // propietario ya lo tiene compartido; esto solo evita que desaparezca de
  // la pantalla en cuanto se genera, mientras sigue en esta ficha.
  String? _ultimoCodigoGenerado;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _invitar() async {
    final email = _emailCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();
    if (email.isEmpty && telefono.isEmpty) return;
    setState(() => _enviando = true);
    try {
      final resultado = await InvitacionService.invitarProfesional(
        casaId: widget.casa.id,
        elementoId: widget.elementoId,
        registroId: widget.registro.id,
        emailProfesional: email.isEmpty ? null : email,
        telefonoProfesional: telefono.isEmpty ? null : telefono,
      );
      _emailCtrl.clear();
      _telefonoCtrl.clear();
      unawaited(
        AnalyticsService.professionalInvited(
          metodo: resultado.esDirecta ? 'email' : 'codigo',
        ),
      );
      if (resultado.esDirecta) {
        if (mounted) AppError.showSuccess(context, 'Invitación enviada.');
      } else if (mounted) {
        setState(() => _ultimoCodigoGenerado = resultado.codigo);
        await _compartirCodigo(resultado.codigo!);
      }
    } on FirebaseFunctionsException catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          e.message ?? 'No se pudo enviar la invitación.',
          error: e,
          stackTrace: st,
        );
      }
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo enviar la invitación.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  bool _cancelando = false;

  Future<void> _cancelarInvitacion(String invitacionId) async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Cancelar invitación?',
      message: 'Podrás invitar a otro profesional para este evento.',
      cancelLabel: 'Seguir esperando',
      confirmLabel: 'Cancelar invitación',
    );
    if (!confirmar || !mounted) return;
    setState(() => _cancelando = true);
    try {
      await InvitacionService.cancelar(invitacionId);
    } on FirebaseFunctionsException catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          e.message ?? 'No se pudo cancelar la invitación.',
          error: e,
          stackTrace: st,
        );
      }
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo cancelar la invitación.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  Future<void> _compartirCodigo(String codigo) async {
    final mensaje =
        'Te invito a "${widget.registro.titulo}" en Repara.\n'
        'Descárgate la app, crea tu cuenta y activa el modo profesional, y luego introduce este código de invitación: $codigo';
    if (!mounted) return;
    try {
      // sharePositionOrigin obligatorio en iOS -- ver nota en
      // contacto_acciones.dart.
      await Share.share(
        mensaje,
        sharePositionOrigin: Offset.zero & MediaQuery.of(context).size,
      );
    } catch (e) {
      // El código ya se generó y se muestra en pantalla -- que falle el
      // selector de compartir no debe parecer que la invitación falló.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.registro.profesionalUid != null) {
      return IosSection(
        rows: [
          IosRow(
            icon: Icons.verified_user_outlined,
            iconColor: context.colors.success,
            title: widget.registro.profesionalNombre ?? 'Profesional vinculado',
            subtitle: 'Puede ver este evento y actualizar su estado',
            showChevron: false,
          ),
        ],
      );
    }

    return StreamBuilder<Invitacion?>(
      stream: InvitacionService.streamUltimaInvitacionDe(widget.registro.id),
      builder: (context, snapshot) {
        final invitacion = snapshot.data;
        if (invitacion != null &&
            invitacion.estado == EstadoInvitacion.pendiente) {
          return IosSection(
            rows: [
              IosRow(
                icon: Icons.hourglass_top_outlined,
                iconColor: context.colors.warning,
                title: 'Invitación enviada a ${invitacion.profesionalEmail}',
                subtitle: 'Esperando respuesta',
                showChevron: false,
                trailing: _cancelando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => _cancelarInvitacion(invitacion.id),
                        child: const Text('Cancelar'),
                      ),
              ),
            ],
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_ultimoCodigoGenerado != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code_2_outlined,
                        color: context.colors.brand,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Código para compartir: $_ultimoCodigoGenerado',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(letterSpacing: 1),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 20),
                        tooltip: 'Compartir código',
                        onPressed: () =>
                            _compartirCodigo(_ultimoCodigoGenerado!),
                      ),
                    ],
                  ),
                  Text(
                    'Esa persona no tiene todavía cuenta profesional en Repara. Cuando se registre, introduce este código para vincularse a este evento.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: context.colors.border),
                  ),
                ],
                if (invitacion != null &&
                    invitacion.estado == EstadoInvitacion.rechazada) ...[
                  Text(
                    '${invitacion.profesionalEmail} rechazó la invitación anterior.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.errorText,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Invita a tu profesional de confianza -- si ya tiene cuenta en Repara, le llega directo; si no, te doy un código para que se lo mandes tú.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo del profesional (opcional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _enviando ? null : _invitar,
                    child: _enviando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Invitar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Resumen económico en una sola tarjeta para el registro SIMPLE (sin
/// profesional) -- el coste de una compra o el profesional de texto libre.
/// Ningún dato nuevo, ningún saldo inventado: el profesional de texto libre
/// solo se repite aquí cuando NO hay sección "Profesional" propia
/// (esConProfesional == false).
class _ResumenEconomico extends StatelessWidget {
  const _ResumenEconomico({
    required this.casa,
    required this.elementoId,
    required this.registro,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;

  @override
  Widget build(BuildContext context) {
    final mostrarCoste = registro.coste != null && !registro.esConProfesional;
    final mostrarPresupuesto = registro.presupuesto != null;
    final mostrarProfesional =
        !registro.esConProfesional && registro.profesionalNombre != null;
    if (!mostrarCoste && !mostrarPresupuesto && !mostrarProfesional) {
      return const SizedBox.shrink();
    }

    Widget divisor() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, color: context.colors.border),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mostrarCoste) ...[
              Text(
                'Coste',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.inkMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${registro.coste!.toStringAsFixed(0)} €',
                style: ReparaText.amount(context, large: true),
              ),
            ],
            if (mostrarCoste && (mostrarPresupuesto || mostrarProfesional))
              divisor(),
            if (mostrarPresupuesto) ...[
              Text(
                'Presupuesto',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.inkMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${registro.presupuesto!.toStringAsFixed(0)} €',
                style: ReparaText.amount(context, large: true),
              ),
            ],
            if (mostrarPresupuesto && mostrarProfesional) divisor(),
            if (mostrarProfesional)
              Row(
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    size: 18,
                    color: context.colors.brand,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${registro.profesionalNombre}${registro.profesionalContacto != null ? ' · ${registro.profesionalContacto}' : ''}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// terminado/archivado/pendienteConfirmacion/pendientePago nunca son
// editables por esta vía directa -- "Finalizar"/"Confirmar"/"Todavía no" son
// las únicas puertas (modelo de dos pasos, auditoría de producto, octubre
// 2026); pendientePago, además, solo lo escribe la Cloud Function al
// registrar/editar/borrar un pago (CEO, octubre 2026 -- ver
// estadoTrasCambioDePago en functions/index.js), nunca a mano.
bool _estadoControlado(EstadoRegistro e) =>
    e == EstadoRegistro.terminado ||
    e == EstadoRegistro.archivado ||
    e == EstadoRegistro.pendienteConfirmacion ||
    e == EstadoRegistro.pendientePago;

// Un registro simple (sin profesional) nace directamente "terminado" (o
// "pendientePago" si tiene coste sin cobrar, CEO octubre 2026) -- no tiene
// el ciclo de vida nuevo/presupuestado/en curso, así que aquí solo se
// distingue archivado/pago pendiente de "registrado" en vez de reutilizar
// los nombres del flujo con profesional.
String _nombreEstadoSimple(Registro r) => switch (r.estado) {
  EstadoRegistro.archivado => 'Archivado',
  EstadoRegistro.pendientePago => 'Pago pendiente',
  _ => 'Registrado',
};

const _estadosEditables = [
  EstadoRegistro.nuevo,
  EstadoRegistro.presupuestado,
  EstadoRegistro.enCurso,
];
