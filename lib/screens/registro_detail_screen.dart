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

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:repara_core/analytics_service.dart';
import 'package:repara_core/cita.dart';
import 'package:repara_core/cita_service.dart';
import 'package:repara_core/documento.dart';
import 'package:repara_core/documento_service.dart';
import 'package:repara_core/historial_evento.dart';
import 'package:repara_core/historial_service.dart';
import 'package:repara_core/invitacion.dart';
import 'package:repara_core/invitacion_service.dart';
import 'package:repara_core/pago.dart';
import 'package:repara_core/registro.dart';
import 'package:share_plus/share_plus.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../services/elemento_service.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_core/design_tokens.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';
import '../widgets/boton_ajustes.dart';
import '../widgets/documento_abrir.dart';
import '../widgets/estado_registro_chip.dart';
import '../widgets/historial_timeline.dart';
import '../widgets/ios_list.dart';
import 'cambio_alcance_section.dart';
import 'contacto_acciones.dart';
import 'editar_registro_sheet.dart';
import 'elemento_detail_screen.dart';
import 'nuevo_documento_flow.dart';
import 'pagos_section.dart';
import 'presupuestos_section.dart';
import 'registro_simple/registro_cabecera.dart';
import 'registro_simple/registro_resumen_pdf.dart';
import 'registro_simple/registro_simple_acciones.dart';
import 'registro_simple/registro_simple_progreso.dart';

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
    } else if (registro.coste != null) {
      // Un registro simple no tiene presupuesto -- su coste es el importe
      // de referencia equivalente (mismo criterio que montoDebidoRegistro).
      partes.add('Coste: ${_formatoImporte(registro.coste!)} €');
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
            body: const Center(child: Text('No se pudo cargar este evento.')),
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
                const Icon(
                  Icons.home_outlined,
                  size: 14,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    casa.nombre,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
              BotonAjustes(casa: casa),
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
                  onCompartirResumen: (pagado) =>
                      _compartirResumen(context, registro, pagado),
                  onFinalizar: () => _finalizar(context, registro),
                ),
        );
      },
    );
  }
}

/// Tarjeta económica de 3 columnas (presupuesto/pagado/saldo o completado) --
/// combina la composición de la referencia visual con el tratamiento de
/// importes de pago_detail_screen.dart. Recibe [pagado] ya calculado por el
/// padre (un único `StreamBuilder<List<Pago>>` compartido con la pestaña de
/// Pagos -- nunca una segunda suscripción a la misma colección).
class _TarjetaEconomica extends StatelessWidget {
  const _TarjetaEconomica({
    required this.presupuesto,
    required this.pagado,
    this.etiquetaTotal = 'Presupuesto',
    super.key,
  });

  final double presupuesto;
  final double pagado;
  // "Coste" en un registro simple, "Presupuesto" en uno con profesional --
  // mismo número al fin y al cabo (lo que hay que cubrir), solo cambia
  // cómo se llama (CEO, octubre 2026: pidió la misma barra de progreso
  // para los registros simples con pago pendiente).
  final String etiquetaTotal;

  @override
  Widget build(BuildContext context) {
    final saldo = (presupuesto - pagado).clamp(0, double.infinity).toDouble();
    final completo = pagado >= presupuesto;
    final porcentaje = presupuesto <= 0
        ? 0.0
        : (pagado / presupuesto).clamp(0, 1).toDouble();

    // Caja más "estado de cuenta" que "tarjeta de stat" (CEO, octubre
    // 2026): importes a 15px en vez de los 17/32px de ReparaText.amount
    // (ese token se reutiliza en toda la app -- presupuestos, pagos,
    // documentos -- así que se ajusta solo aquí, por composición, en vez
    // de tocar el token global), caja más baja y alargada, y un fondo
    // sutilmente distinto al resto de la pantalla en vez de un simple
    // borde, para que lea como un resumen y no como un stat card suelto.
    TextStyle importeStyle({Color? color}) => ReparaText.amount(
      context,
    ).copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: color);

    Widget etiqueta(String texto) => Text(
      texto.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.colors.inkMuted,
        fontSize: 9.5,
        letterSpacing: 0.8,
      ),
    );

    Widget columna(String texto, Widget valor) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [etiqueta(texto), const SizedBox(height: 5), valor],
      ),
    );

    Widget divisor() => Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: context.colors.border.withValues(alpha: 0.6),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.surfaceSunken.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(ReparaRadius.md),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              columna(
                etiquetaTotal,
                Text(
                  '${_formatoImporte(presupuesto)} €',
                  style: importeStyle(),
                ),
              ),
              divisor(),
              columna(
                'Pagado',
                Text(
                  '${_formatoImporte(pagado)} €',
                  style: importeStyle(color: context.colors.successText),
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
                            size: 14,
                            color: context.colors.success,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Completado',
                              style: importeStyle(
                                color: context.colors.successText,
                              ),
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
                        style: importeStyle(),
                      ),
                    ),
            ],
          ),
          if (!completo) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: porcentaje,
                minHeight: 5,
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

class _CuerpoConProfesional extends StatefulWidget {
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
  State<_CuerpoConProfesional> createState() => _CuerpoConProfesionalState();
}

class _CuerpoConProfesionalState extends State<_CuerpoConProfesional> {
  // "Descargar PDF" junto a "Compartir resumen" (CEO, octubre 2026) --
  // mismo RegistroResumenPdf que ya usaba el registro simple, aquí con los
  // pagos/totalPagado que ya calcula este cuerpo para la tarjeta económica.
  bool _generandoPdf = false;

  Future<void> _descargarPdf(List<Pago> pagos, double totalPagado) async {
    setState(() => _generandoPdf = true);
    try {
      await RegistroResumenPdf.descargar(
        context,
        registro: widget.registro,
        casa: widget.casa,
        pagos: pagos,
        totalPagado: totalPagado,
      );
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo generar el PDF.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final casa = widget.casa;
    final elementoId = widget.elementoId;
    final registro = widget.registro;
    final onFinalizar = widget.onFinalizar;
    final onConfirmarFinalizacion = widget.onConfirmarFinalizacion;
    final onRechazarFinalizacion = widget.onRechazarFinalizacion;
    final onCompartirResumen = widget.onCompartirResumen;
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
                  RegistroCabecera(
                    key: const ValueKey('cabecera'),
                    casa: casa,
                    elementoId: elementoId,
                    registro: registro,
                    elemento: elemento,
                  ),
                  // Keys explícitas desde aquí hasta el pie de página --
                  // mismo motivo que en _ResumenTab: los dos avisos y la
                  // tarjeta económica de más abajo son condicionales (el
                  // estado del registro o si ya tiene presupuesto pueden
                  // cambiar mientras la pantalla está abierta, vía el
                  // StreamBuilder<Registro?> de arriba), y sin clave
                  // desplazarían -- y podrían hacer perder el estado de
                  // -- el TabBarView de más abajo, con los 4 streams de
                  // sus pestañas.
                  if (registro.estado == EstadoRegistro.pendienteConfirmacion)
                    Padding(
                      key: const ValueKey('aviso-pendiente-confirmacion'),
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
                      key: const ValueKey('aviso-pendiente-pago'),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: AvisoRegistro(
                        mensaje:
                            'El trabajo está hecho, pero todavía falta cobrarlo del todo. '
                            'Apunta el pago en la pestaña Pagos para cerrarlo.',
                      ),
                    ),
                  if (registro.presupuesto != null)
                    _TarjetaEconomica(
                      key: const ValueKey('tarjeta-economica'),
                      presupuesto: registro.presupuesto!,
                      pagado: totalPagado,
                    ),
                  Container(
                    key: const ValueKey('tab-bar'),
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
                    key: const ValueKey('tab-bar-view'),
                    child: TabBarView(
                      children: [
                        _ResumenTab(
                          key: const ValueKey('tab-resumen'),
                          casa: casa,
                          elementoId: elementoId,
                          registro: registro,
                          elemento: elemento,
                        ),
                        SingleChildScrollView(
                          key: const ValueKey('tab-cambios'),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: CambiosAlcanceSection(
                            casaId: casa.id,
                            elementoId: elementoId,
                            registroId: registro.id,
                            rol: RolEnTrabajo.propietario,
                            registroCerrado:
                                registro.estado == EstadoRegistro.terminado ||
                                registro.estado == EstadoRegistro.archivado ||
                                registro.estado == EstadoRegistro.pendientePago,
                          ),
                        ),
                        SingleChildScrollView(
                          key: const ValueKey('tab-pagos'),
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
                          key: const ValueKey('tab-documentos'),
                          casa: casa,
                          elementoId: elementoId,
                          registro: registro,
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    key: const ValueKey('pie-acciones'),
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      // Antes había además un FloatingActionButton
                      // "Finalizar" flotando sobre esta misma barra -- se
                      // solapaban visualmente. Una sola barra con las dos
                      // acciones evita el choque y mantiene ambas alcanzables.
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_estadoControlado(registro.estado))
                            SizedBox(
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
                          else
                            Row(
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
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _generandoPdf
                                  ? null
                                  : () => _descargarPdf(pagos, totalPagado),
                              icon: _generandoPdf
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.picture_as_pdf_outlined,
                                      size: 18,
                                    ),
                              label: const Text('Descargar PDF'),
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
    super.key,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;
  final Elemento? elemento;

  @override
  Widget build(BuildContext context) {
    // Profesionales de contacto del evento (CEO, noviembre 2026). Si ya hay un
    // profesional vinculado por cuenta (profesionalUid), solo se listan los
    // de la lista nueva -- el heredado profesionalNombre es justo ese mismo
    // profesional y ya lo muestra _SeccionInvitarProfesional, así que
    // listaProfesionales lo duplicaría.
    final contactosPro = registro.profesionalUid == null
        ? registro.listaProfesionales
        : registro.profesionales;
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
            key: const ValueKey('resumen-descripcion'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
        ],
        Text(
          'Profesional',
          key: const ValueKey('resumen-titulo-profesional'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        // Cada sección de aquí abajo lleva su propia Key explícita --
        // auditoría de estabilidad (noviembre 2026): sin ella, en cuanto
        // cualquiera de los bloques condicionales de más arriba (este
        // `descripcion`, `contactosPro`, `profesionalUid`...) cambia de
        // presente a ausente (o al revés) mientras la pantalla está
        // abierta, la lista cambia de longitud y Flutter -- al no tener
        // forma de distinguir estos widgets sin clave más que por su
        // posición -- reconcilia mal: cada StreamBuilder de estas
        // secciones puede acabar reconstruido desde cero (perdiendo su
        // suscripción en marcha) o, peor, "heredando" por error el
        // estado de otra sección vecina. Con clave, Flutter siempre
        // encuentra el Element correcto sin importar cuánto se desplace
        // en la lista.
        if (contactosPro.isNotEmpty) ...[
          _SeccionProfesionales(
            key: const ValueKey('resumen-profesionales'),
            lista: contactosPro,
            mostrarTitulo: false,
          ),
          const SizedBox(height: 12),
        ],
        _SeccionInvitarProfesional(
          key: const ValueKey('resumen-invitar-profesional'),
          casa: casa,
          elementoId: elementoId,
          registro: registro,
        ),
        if (registro.profesionalUid != null) ...[
          const SizedBox(height: 20),
          _SeccionProximaVisita(
            key: const ValueKey('resumen-proxima-visita'),
            profesionalUid: registro.profesionalUid!,
            registroId: registro.id,
          ),
        ],
        const SizedBox(height: 20),
        PresupuestosSection(
          key: const ValueKey('resumen-presupuestos'),
          casaId: casa.id,
          elementoId: elementoId,
          registroId: registro.id,
          rol: RolEnTrabajo.propietario,
          registroTitulo: registro.titulo,
          elementoNombre: registro.elementoNombre,
          casaNombre: casa.nombre,
          profesionalNombre: registro.listaProfesionales.isNotEmpty
              ? registro.listaProfesionales.map((p) => p.nombre).join(', ')
              : null,
        ),
        const SizedBox(height: 20),
        _TarjetaMantenimiento(
          key: const ValueKey('resumen-mantenimiento'),
          casa: casa,
          elementoId: elementoId,
          elemento: elemento,
        ),
        const SizedBox(height: 20),
        _SeccionHistorial(
          key: const ValueKey('resumen-historial'),
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
    super.key,
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
enum _FiltroHistorial { todo, presupuestos, cambios, pagos, documentos, finalizacion, citas }

String _nombreFiltroHistorial(_FiltroHistorial f) => switch (f) {
  _FiltroHistorial.todo => 'Todo',
  _FiltroHistorial.presupuestos => 'Presupuestos',
  _FiltroHistorial.cambios => 'Cambios',
  _FiltroHistorial.pagos => 'Pagos',
  _FiltroHistorial.documentos => 'Documentos',
  _FiltroHistorial.finalizacion => 'Finalización',
  _FiltroHistorial.citas => 'Citas',
};

class _SeccionHistorial extends StatefulWidget {
  const _SeccionHistorial({
    required this.casa,
    required this.elementoId,
    required this.registro,
    this.mostrarTitulo = true,
    super.key,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;
  // false cuando ya vive dentro de un ExpansionTile con su propio título
  // "Historial" (CEO, noviembre 2026: "que sea un desplegable abajo del
  // todo") -- evita el "Historial" del desplegable seguido de "Historial de
  // la reparación" repitiéndose justo debajo.
  final bool mostrarTitulo;

  @override
  State<_SeccionHistorial> createState() => _SeccionHistorialState();
}

class _SeccionHistorialState extends State<_SeccionHistorial> {
  _FiltroHistorial _filtro = _FiltroHistorial.todo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.mostrarTitulo) ...[
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
        ],
        StreamBuilder<List<HistorialEvento>>(
          stream: HistorialService.streamHistorial(
            widget.casa.id,
            widget.elementoId,
            widget.registro.id,
          ),
          builder: (context, snapshot) {
            final eventos = snapshot.data ?? [];
            // Finalización/archivado se sintetizan a partir del estado
            // actual SOLO para registros antiguos que se cerraron antes de
            // que estas transiciones empezaran a dejar su propio evento en
            // el historial (noviembre 2026) -- si ya existe un evento real
            // de entidad "registro", se confía en él y no se duplica.
            final yaTieneEventoDeRegistro = eventos.any(
              (e) => e.entidad == EntidadHistorial.registro,
            );
            final todos = <TimelineItem>[
              if (!yaTieneEventoDeRegistro &&
                  (widget.registro.estado == EstadoRegistro.terminado ||
                      widget.registro.estado == EstadoRegistro.archivado))
                TimelineItem(
                  titulo: widget.registro.estado == EstadoRegistro.archivado
                      ? 'Evento archivado'
                      : 'Trabajo finalizado',
                  subtitulo: 'Marcado como terminado',
                  icono: Icons.task_alt,
                  color: context.colors.success,
                  categoria: 'finalizacion',
                ),
              if (!yaTieneEventoDeRegistro &&
                  widget.registro.estado == EstadoRegistro.pendientePago)
                TimelineItem(
                  titulo: 'Trabajo confirmado',
                  subtitulo: 'Pendiente de cobrar del todo',
                  icono: Icons.hourglass_top_outlined,
                  color: context.colors.warningText,
                  categoria: 'finalizacion',
                ),
              ...eventos.map((e) => _eventoATimelineItem(context, e)),
            ];
            if (todos.isEmpty) {
              return const EmptyHint(
                message: 'Sin actividad registrada todavía.',
                icon: Icons.show_chart,
              );
            }
            final items = _filtro == _FiltroHistorial.todo
                ? todos
                : todos
                    .where((i) => i.categoria == _filtro.name)
                    .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _FiltroHistorial.values) ...[
                        ChoiceChip(
                          label: Text(_nombreFiltroHistorial(f)),
                          selected: _filtro == f,
                          onSelected: (_) => setState(() => _filtro = f),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  EmptyHint(
                    message: 'Nada en "${_nombreFiltroHistorial(_filtro)}" todavía.',
                    icon: Icons.filter_alt_off_outlined,
                  )
                else
                  HistorialTimeline(items: items),
              ],
            );
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
          subtitulo: e.motivo ?? importeTexto,
          fechaTexto: fecha,
          fecha: e.timestamp,
          autor: e.actorNombre,
          icono: Icons.request_quote_outlined,
          color: e.accion == 'rechazado'
              ? context.colors.errorText
              : context.colors.success,
          categoria: 'presupuestos',
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
          fecha: e.timestamp,
          autor: e.actorNombre,
          icono: Icons.rule_outlined,
          color: (e.accion == 'rechazado' || e.accion == 'cancelado')
              ? context.colors.errorText
              : context.colors.success,
          categoria: 'cambios',
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
          fecha: e.timestamp,
          autor: e.actorNombre,
          icono: Icons.payments_outlined,
          color: e.accion == 'eliminado'
              ? context.colors.errorText
              : context.colors.success,
          categoria: 'pagos',
        );
      case EntidadHistorial.registro:
        final titulo = switch (e.accion) {
          'confirmado' => 'Trabajo confirmado',
          'pendienteConfirmacion' => 'Profesional marca como terminado',
          'finalizacionRechazada' => 'Finalización rechazada',
          'elementoArchivado' => 'Elemento archivado',
          'elementoRestaurado' => 'Elemento restaurado',
          _ => 'Trabajo actualizado',
        };
        return TimelineItem(
          titulo: titulo,
          fechaTexto: fecha,
          fecha: e.timestamp,
          autor: e.actorNombre,
          icono: e.accion == 'finalizacionRechazada'
              ? Icons.undo_outlined
              : Icons.task_alt,
          color: e.accion == 'finalizacionRechazada'
              ? context.colors.errorText
              : context.colors.success,
          categoria: 'finalizacion',
        );
      case EntidadHistorial.invitacion:
        final titulo = e.accion == 'aceptada'
            ? 'Invitación aceptada'
            : 'Invitación rechazada';
        return TimelineItem(
          titulo: titulo,
          fechaTexto: fecha,
          fecha: e.timestamp,
          autor: e.actorNombre,
          icono: Icons.person_add_alt_outlined,
          color: e.accion == 'aceptada'
              ? context.colors.success
              : context.colors.errorText,
          categoria: 'cambios',
        );
      case EntidadHistorial.documento:
        return TimelineItem(
          titulo: 'Documento añadido',
          fechaTexto: fecha,
          fecha: e.timestamp,
          autor: e.actorNombre,
          icono: Icons.description_outlined,
          color: context.colors.brand,
          categoria: 'documentos',
        );
      case EntidadHistorial.cita:
        final titulo = switch (e.accion) {
          'modificada' => 'Cita modificada',
          'cancelada' => 'Cita cancelada',
          _ => 'Cita programada',
        };
        return TimelineItem(
          titulo: titulo,
          fechaTexto: fecha,
          fecha: e.timestamp,
          autor: e.actorNombre,
          icono: Icons.event_outlined,
          color: e.accion == 'cancelada'
              ? context.colors.errorText
              : context.colors.success,
          categoria: 'citas',
        );
      case EntidadHistorial.desconocida:
        return TimelineItem(
          titulo: e.accion,
          fechaTexto: fecha,
          fecha: e.timestamp,
          autor: e.actorNombre,
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
    super.key,
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
                      onTap: () => mostrarAccionesDocumento(
                        context,
                        casaId: casa.id,
                        documento: d,
                      ),
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
    required this.onCompartirResumen,
    required this.onFinalizar,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;
  final void Function(double? pagado) onCompartirResumen;
  // "Marcar como realizado" (CEO, noviembre 2026: "a veces el trabajo no
  // está hecho al registrarlo") -- solo se usa cuando estado == enCurso;
  // reutiliza _finalizar/finalizarTrabajoPropietario tal cual, que ya era
  // genérico (nunca comprobaba esConProfesional) y ya decide terminado vs.
  // pendientePago según si el coste está cubierto por los pagos.
  final VoidCallback onFinalizar;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Elemento?>(
      stream: ElementoService.streamElemento(casa.id, elementoId),
      builder: (context, elementoSnap) {
        return StreamBuilder<List<Pago>>(
          // Un único stream de pagos para toda esta pantalla (igual que
          // _CuerpoConProfesional) -- alimenta la barra de progreso de
          // abajo y el "próximo pago estimado" del plan a plazos; la
          // pestaña Pagos (PagosSection) mantiene su propia suscripción
          // porque es un widget reutilizable independiente (igual que en
          // el lado con profesional).
          stream: PagoService.streamPagos(casa.id, elementoId, registro.id),
          builder: (context, pagosSnap) {
            final pagos = pagosSnap.data ?? const <Pago>[];
            final totalPagado = pagos.fold<double>(
              0,
              (acc, p) => acc + p.importe,
            );
            final coste = registro.coste;
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                RegistroCabecera(
                  casa: casa,
                  elementoId: elementoId,
                  registro: registro,
                  elemento: elementoSnap.data,
                ),
                RegistroSimpleProgreso(registro: registro),
                if (registro.estado == EstadoRegistro.enCurso)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: AvisoRegistro(
                      mensaje: 'Todavía no se ha realizado este trabajo.',
                      acciones: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onFinalizar,
                          child: const Text('Marcar como realizado'),
                        ),
                      ),
                    ),
                  )
                else if (registro.estado == EstadoRegistro.pendientePago)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: AvisoRegistro(
                      mensaje:
                          'El trabajo está hecho, pero todavía falta cobrarlo del todo. '
                          'Apunta el pago más abajo para cerrarlo.',
                    ),
                  ),
                Padding(
                  key: const ValueKey('simple-cuerpo'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (registro.descripcion != null) ...[
                        Text(
                          key: const ValueKey('simple-descripcion'),
                          registro.descripcion!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Barra de progreso de cobro (CEO, octubre 2026),
                      // igual que ya existía para un registro con
                      // profesional (_TarjetaEconomica/presupuesto) --
                      // "Coste" en vez de "Presupuesto" es la única
                      // diferencia real.
                      // Keys explícitas de aquí en adelante -- mismo
                      // motivo que en _ResumenTab/_CuerpoConProfesional:
                      // `coste`/`listaProfesionales` pueden pasar de
                      // ausentes a presentes mientras la pantalla está
                      // abierta, y sin clave eso desplazaría y podría
                      // romper el StreamBuilder de Documentos y
                      // PagosSection de más abajo.
                      if (coste != null && coste > 0) ...[
                        _TarjetaEconomica(
                          key: const ValueKey('simple-tarjeta-economica'),
                          presupuesto: coste,
                          pagado: totalPagado,
                          etiquetaTotal: 'Coste',
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (registro.listaProfesionales.isNotEmpty) ...[
                        _SeccionProfesionales(
                          key: const ValueKey('simple-profesionales'),
                          lista: registro.listaProfesionales,
                        ),
                        const SizedBox(height: 20),
                      ],
                      // 3 categorías en vez de "Pagos"/"Documentos" sueltos
                      // (CEO, noviembre 2026): Presupuestos y Facturas/Notas
                      // son la misma colección de Documentos de siempre,
                      // separada por su campo `tipo` -- un presupuesto que
                      // te ha dado un profesional ajeno a la app entra aquí
                      // igual, a mano o escaneado, nunca solo por invitación
                      // real (eso sigue siendo exclusivo del registro CON
                      // profesional, ver presupuestos_section.dart).
                      StreamBuilder<List<Documento>>(
                        key: const ValueKey('simple-documentos'),
                        stream: DocumentoService.streamDocumentos(
                          casa.id,
                          registroId: registro.id,
                        ),
                        builder: (context, snapshot) {
                          final documentos =
                              snapshot.data ?? const <Documento>[];
                          final presupuestos = documentos
                              .where((d) => d.tipo == TipoDocumento.presupuesto)
                              .toList();
                          final facturasNotas = documentos
                              .where((d) => d.tipo != TipoDocumento.presupuesto)
                              .toList();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SeccionCategoriaDocumentos(
                                casaId: casa.id,
                                titulo: 'Presupuestos',
                                documentos: presupuestos,
                                emptyMensaje: 'Sin presupuestos todavía.',
                                onAnadir: () => elegirFormaDeAnadirDocumento(
                                  context,
                                  casaId: casa.id,
                                  elementoId: elementoId,
                                  registroId: registro.id,
                                  tipoInicial: TipoDocumento.presupuesto,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _SeccionCategoriaDocumentos(
                                casaId: casa.id,
                                titulo: 'Facturas/Notas',
                                documentos: facturasNotas,
                                emptyMensaje: 'Sin facturas ni notas todavía.',
                                onAnadir: () => elegirFormaDeAnadirDocumento(
                                  context,
                                  casaId: casa.id,
                                  elementoId: elementoId,
                                  registroId: registro.id,
                                  tipoInicial: TipoDocumento.factura,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      // Un registro simple no tiene presupuesto formal
                      // (nunca se fija en esta vía, ver nuevo_registro_
                      // screen.dart/nuevo_elemento_screen.dart) -- el nuevo
                      // apartado "Presupuestos" de arriba es solo Documentos
                      // de ese tipo, así que PagosSection sigue recibiendo
                      // presupuesto: null -- ya está preparada para eso (ver
                      // pago_detail_screen.dart: el tope contra el
                      // presupuesto solo se aplica si no es null), igual
                      // que registrarPago en servidor. No hace falta ningún
                      // cambio de Cloud Function ni de reglas:
                      // registrarPago ya nunca ha exigido esConProfesional,
                      // solo lo usaba quien construía la pantalla.
                      PagosSection(
                        key: const ValueKey('simple-pagos'),
                        casaId: casa.id,
                        elementoId: elementoId,
                        registroId: registro.id,
                        registroTitulo: registro.titulo,
                        presupuesto: null,
                        rol: RolEnTrabajo.propietario,
                      ),
                      if (registro.plazoFrecuenciaMeses != null) ...[
                        const SizedBox(height: 20),
                        _PlanDePagos(registro: registro, pagos: pagos),
                      ],
                      const SizedBox(height: 24),
                      // Acciones rápidas antes del historial (CEO, octubre
                      // 2026): solo compartir/exportar -- "Añadir pago" y
                      // "Añadir"/"Escanear" ya tienen su propio botón en las
                      // cabeceras de arriba, repetirlos aquí era la misma
                      // acción dos veces.
                      RegistroSimpleAcciones(
                        casa: casa,
                        registro: registro,
                        pagos: pagos,
                        totalPagado: totalPagado,
                        onCompartir: () => onCompartirResumen(totalPagado),
                      ),
                      const SizedBox(height: 20),
                      // Historial como desplegable cerrado por defecto, al
                      // final de todo (CEO, noviembre 2026: "si el usuario
                      // quiere verlo lo despliegue, si no, no") -- antes
                      // siempre visible entre la tarjeta económica y Pagos.
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Icon(
                                Icons.show_chart,
                                size: 16,
                                color: context.colors.inkMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Historial',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                          children: [
                            _SeccionHistorial(
                              casa: casa,
                              elementoId: elementoId,
                              registro: registro,
                              mostrarTitulo: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Categoría de Documentos dentro de un evento simple (CEO, noviembre 2026:
/// "Presupuestos, Facturas/Notas y Pagos, cada una con su total y su botón
/// de añadir a mano o escaneando"). [documentos] ya viene filtrado por el
/// padre (por `tipo`) -- este widget solo pinta la lista y suma el total,
/// no decide qué pertenece a qué categoría.
class _SeccionCategoriaDocumentos extends StatelessWidget {
  const _SeccionCategoriaDocumentos({
    required this.casaId,
    required this.titulo,
    required this.documentos,
    required this.emptyMensaje,
    required this.onAnadir,
  });

  final String casaId;
  final String titulo;
  final List<Documento> documentos;
  final String emptyMensaje;
  final VoidCallback onAnadir;

  @override
  Widget build(BuildContext context) {
    final total = documentos.fold<double>(
      0,
      (acc, d) => acc + (d.importe ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
                if (total > 0) ...[
                  const SizedBox(width: 12),
                  Text(
                    '(${total.toStringAsFixed(0)} €)',
                    style: ReparaText.amount(context).copyWith(fontSize: 15),
                  ),
                ],
              ],
            ),
            TextButton.icon(
              onPressed: onAnadir,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir'),
            ),
          ],
        ),
        if (documentos.isEmpty)
          EmptyHint(message: emptyMensaje, icon: Icons.description_outlined)
        else
          IosSection(
            rows: documentos
                .map(
                  (d) => IosRow(
                    icon: Icons.insert_drive_file_outlined,
                    iconColor: context.colors.brand,
                    title: d.proveedor ?? d.nombreArchivo,
                    subtitle: d.fecha != null
                        ? DateFormat('d MMM yyyy', 'es_ES').format(d.fecha!)
                        : null,
                    trailing: d.importe != null
                        ? Text(
                            '${d.importe!.toStringAsFixed(0)} €',
                            style: ReparaText.amount(context),
                          )
                        : null,
                    showChevron: false,
                    onTap: () => mostrarAccionesDocumento(
                      context,
                      casaId: casaId,
                      documento: d,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

/// Profesionales de contacto de un evento (CEO, noviembre 2026: "que
/// aparezca el nombre del profesional, como 'Fontanero', y que al pulsarlo
/// salgan todas las opciones"). Cada fila muestra nombre y teléfono; al
/// pulsarla se despliegan sus acciones (llamar, WhatsApp, reportar un
/// problema...) -- las mismas filas de contacto_acciones.dart que usaba el
/// antiguo _SeccionProfesionalSimple, ahora para cada profesional por
/// separado. Solo aparece la flecha de despliegue si tiene teléfono, porque
/// sin número no hay nada que llamar/escribir. No son Contactos de la
/// libreta (nunca se editan desde aquí), así que no hay Editar/Eliminar.
/// "Tienes una visita programada" (sección 2.2 del encargo de avisos
/// inteligentes, noviembre 2026) -- la única cita que el propietario puede
/// ver es la que el propio profesional marcó compartida=true (ver
/// firestore.rules); esta sección desaparece sola si no hay ninguna futura,
/// nunca muestra una pasada ni una cancelada.
class _SeccionProximaVisita extends StatelessWidget {
  const _SeccionProximaVisita({
    required this.profesionalUid,
    required this.registroId,
    super.key,
  });

  final String profesionalUid;
  final String registroId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cita>>(
      stream: CitaService.streamCitasCompartidas(
        profesionalUid: profesionalUid,
        registroId: registroId,
      ),
      builder: (context, snapshot) {
        final ahora = DateTime.now();
        final proxima = (snapshot.data ?? [])
            .where((c) => c.fecha.isAfter(ahora))
            .toList();
        if (proxima.isEmpty) return const SizedBox.shrink();
        final cita = proxima.first;
        final fechaTexto = cita.todoElDia
            ? DateFormat('d MMM yyyy', 'es_ES').format(cita.fecha)
            : DateFormat('d MMM yyyy · HH:mm', 'es_ES').format(cita.fecha);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Próxima visita', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.event_outlined, color: context.colors.brand),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cita.titulo,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(fechaTexto, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeccionProfesionales extends StatefulWidget {
  const _SeccionProfesionales({
    required this.lista,
    this.mostrarTitulo = true,
    super.key,
  });

  final List<ProfesionalRegistro> lista;
  final bool mostrarTitulo;

  @override
  State<_SeccionProfesionales> createState() => _SeccionProfesionalesState();
}

class _SeccionProfesionalesState extends State<_SeccionProfesionales> {
  int? _abierto;

  @override
  Widget build(BuildContext context) {
    final lista = widget.lista;
    if (lista.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.mostrarTitulo) ...[
          Text(
            lista.length > 1 ? 'Profesionales' : 'Profesional',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
        ],
        IosSection(
          rows: [
            for (var i = 0; i < lista.length; i++) ...[
              IosRow(
                icon: Icons.person_outline,
                iconColor: context.colors.brand,
                title: lista[i].nombre,
                subtitle: lista[i].telefono,
                showChevron: false,
                trailing: (lista[i].telefono ?? '').isEmpty
                    ? null
                    : Icon(
                        _abierto == i ? Icons.expand_less : Icons.expand_more,
                        color: context.colors.inkMuted,
                      ),
                onTap: (lista[i].telefono ?? '').isEmpty
                    ? null
                    : () => setState(() => _abierto = _abierto == i ? null : i),
              ),
              if (_abierto == i)
                ...filasInteraccionTelefono(
                  context: context,
                  nombre: lista[i].nombre,
                  telefono: lista[i].telefono ?? '',
                ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Plan de pago a plazos (CEO, octubre 2026) -- puramente informativo:
/// muestra la frecuencia/importe guardados y calcula un "próximo pago
/// estimado" a partir del último pago real de Pagos (o de la fecha del
/// registro si todavía no hay ninguno). Nunca cambia por su cuenta cuándo
/// el registro pasa a terminado -- eso sigue dependiendo solo de que los
/// pagos reales cubran coste/presupuesto (ver estadoTrasCambioDePago en
/// functions/index.js). [pagos] ya viene calculado del padre -- mismo
/// único `StreamBuilder<List<Pago>>` que alimenta _TarjetaEconomica, nunca
/// una segunda suscripción a la misma colección.
class _PlanDePagos extends StatelessWidget {
  const _PlanDePagos({required this.registro, required this.pagos});

  final Registro registro;
  final List<Pago> pagos;

  @override
  Widget build(BuildContext context) {
    final ultimoPago = pagos.isEmpty ? null : pagos.first.fecha;
    final proximo = registro.proximoPagoEstimado(ultimoPago);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(ReparaRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.event_repeat_outlined, color: context.colors.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pago a plazos · cada ${registro.plazoFrecuenciaMeses} '
                  '${registro.plazoFrecuenciaMeses == 1 ? 'mes' : 'meses'} · '
                  '${registro.plazoImporte!.toStringAsFixed(2)} €',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (proximo != null)
                  Text(
                    'Próximo pago estimado: ${DateFormat('d MMM yyyy', 'es_ES').format(proximo)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
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
    super.key,
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

const _estadosEditables = [
  EstadoRegistro.nuevo,
  EstadoRegistro.presupuestado,
  EstadoRegistro.enCurso,
];
