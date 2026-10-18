// lib/screens/registro_detail_screen.dart
//
// Expediente de un registro (sección 13 del spec, simplificado para v1: sin
// ScopeGuard/cambios de alcance todavía más allá de lo ya construido). Un
// registro con profesional (esConProfesional) despliega presupuesto/pagos/
// invitación igual que el antiguo TrabajoDetailScreen; uno simple (una
// compra, una nota) solo muestra sus datos con editar/eliminar.
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../models/invitacion.dart';
import '../models/registro.dart';
import '../services/analytics_service.dart';
import '../services/documento_service.dart';
import '../services/invitacion_service.dart';
import '../services/pago_service.dart';
import '../services/registro_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';
import '../widgets/boton_sobre_imagen.dart';
import '../widgets/estado_registro_chip.dart';
import '../widgets/ios_list.dart';
import '../widgets/progreso_pago.dart';
import 'cambio_alcance_section.dart';
import 'nuevo_documento_flow.dart';
import 'pagos_section.dart';
import 'presupuestos_section.dart';

class RegistroDetailScreen extends StatelessWidget {
  const RegistroDetailScreen({required this.casa, required this.elementoId, required this.registroId, super.key});

  final Casa casa;
  final String elementoId;
  final String registroId;

  Future<void> _finalizar(BuildContext context, Registro registro) async {
    final confirmar = await AppDialog.confirm(
      context,
      title: 'Finalizar registro',
      message: 'Se marcará como terminado y quedará guardado en el historial de la casa.',
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
  Future<void> _confirmarFinalizacion(BuildContext context, Registro registro) async {
    // Aviso, no bloqueo (decisión del CEO): que falte pago no debe impedir
    // cerrar un registro si el cobro llega más tarde (transferencia,
    // financiación...), pero sí se avisa para no perderlo de vista.
    var pagadoDelTodo = false;
    if (registro.presupuesto != null) {
      final pagado = await PagoService.totalPagado(casa.id, elementoId, registro.id);
      pagadoDelTodo = pagado >= registro.presupuesto!;
      if (!pagadoDelTodo && context.mounted) {
        final seguir = await AppDialog.confirm(
          context,
          title: 'Todavía no está pagado del todo',
          message: 'Llevas pagado ${pagado.toStringAsFixed(2)} € de ${registro.presupuesto!.toStringAsFixed(2)} €. '
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
      if (context.mounted) AppError.showSuccess(context, 'Registro archivado en el historial.');

      // Bucle viral en UN solo momento (auditoría de producto, octubre
      // 2026): justo cuando el registro ha ido bien de verdad -- terminado Y
      // pagado del todo, con un profesional real de Repara de por medio.
      // Nunca en ningún otro sitio, nunca con descuentos artificiales.
      if (pagadoDelTodo && registro.profesionalUid != null && context.mounted) {
        await _ofrecerCompartir(context, registro);
      }
    } catch (e, st) {
      if (context.mounted) AppError.show(context, 'No se pudo finalizar el registro.', error: e, stackTrace: st);
    }
  }

  /// El propietario dice que, en realidad, todavía no está terminado --
  /// devuelve el registro a como estaba antes de que el profesional lo
  /// marcara, y le avisa para que siga con él.
  Future<void> _rechazarFinalizacion(BuildContext context, Registro registro) async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Todavía no está terminado?',
      message: 'Se avisará al profesional para que lo siga revisando.',
      confirmLabel: 'Todavía no',
    );
    if (!confirmar || !context.mounted) return;
    try {
      await RegistroService.rechazarFinalizacionProfesional(casa.id, elementoId, registro.id);
    } catch (e, st) {
      if (context.mounted) AppError.show(context, 'No se pudo actualizar el registro.', error: e, stackTrace: st);
    }
  }

  Future<void> _ofrecerCompartir(BuildContext context, Registro registro) async {
    final compartir = await AppDialog.confirm(
      context,
      title: '¿Te ha ido bien?',
      message: '${registro.profesionalNombre ?? 'Tu profesional'} también puede recibir más clientes como tú a través de Repara.',
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

  Future<void> _eliminar(BuildContext context, Registro registro) async {
    final confirmar = await AppDialog.confirmText(context, title: '¿Eliminar este registro?', confirmLabel: 'Eliminar');
    if (!confirmar || !context.mounted) return;
    try {
      await RegistroService.eliminar(casa.id, elementoId, registro.id);
      if (context.mounted) Navigator.pop(context);
    } catch (e, st) {
      if (context.mounted) AppError.show(context, 'No se pudo eliminar el registro.', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Registro?>(
      stream: RegistroService.streamRegistro(casa.id, elementoId, registroId),
      builder: (context, snapshot) {
        final registro = snapshot.data;
        if (registro == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          extendBodyBehindAppBar: true,
          // Botones sobre un fondo propio (no iconTheme blanco a secas): el
          // hueco de foto es gris claro, así que un icono blanco sin más se
          // veía prácticamente invisible encima -- mismo respaldo circular
          // ya usado para el lápiz de editar foto en elemento_detail_screen.
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: BotonSobreImagen(icon: Icons.arrow_back, tooltip: 'Volver', onPressed: () => Navigator.pop(context)),
            actions: [
              if (!registro.esConProfesional)
                BotonSobreImagen(icon: Icons.delete_outline, tooltip: 'Eliminar registro', onPressed: () => _eliminar(context, registro)),
            ],
          ),
          floatingActionButton: !registro.esConProfesional || _estadoControlado(registro.estado)
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _finalizar(context, registro),
                  icon: const Icon(Icons.check),
                  label: const Text('Finalizar'),
                ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Sin foto real todavía -- un marcador es mejor que fingir una
              // (auditoría de craft, octubre 2026): avisa de que es un
              // hueco, no un dato. Relleno plano, no degradado (briefing
              // "REPARA Professional": sin degradados decorativos).
              Container(
                height: 156,
                width: double.infinity,
                decoration: BoxDecoration(color: context.colors.surfaceMuted),
                child: Center(
                  child: Icon(Icons.image_outlined, size: 34, color: context.colors.inkFaint),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(iconoTipoRegistro(registro.tipo), size: 13, color: context.colors.inkMuted),
                        const SizedBox(width: 5),
                        Text(
                          '${registro.elementoNombre} · ${nombreTipoRegistro(registro.tipo)}'.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, color: context.colors.inkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(registro.titulo, style: Theme.of(context).textTheme.displaySmall),
                    if (registro.esConProfesional) ...[
                      const SizedBox(height: 10),
                      EstadoRegistroChip(estado: registro.estado),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              if (registro.esConProfesional && registro.estado == EstadoRegistro.pendienteConfirmacion) ...[
                AvisoRegistro(
                  mensaje: 'El profesional dice que ha terminado este registro. ¿Lo confirmas?',
                  acciones: Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => _rechazarFinalizacion(context, registro), child: const Text('Todavía no'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton(onPressed: () => _confirmarFinalizacion(context, registro), child: const Text('Confirmar'))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (registro.descripcion != null) ...[
                Text(registro.descripcion!, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
              ],
              // Campo de estado -- autocontenido por el propio
              // InputDecorationTheme (fondo + radio ya vienen del tema), no
              // necesita una Card envolvente alrededor para parecer "un
              // campo"; antes vivía apretado dentro de la misma tarjeta que
              // el dinero, sin relación real entre ambos.
              if (!registro.esConProfesional)
                // Registro simple -- sin presupuesto/pagos/invitación, igual
                // que una compra o una nota. Sin chip arriba (eso es solo
                // para esConProfesional), así que aquí sí hace falta mostrar
                // el estado.
                TextFormField(
                  initialValue: _nombreEstadoSimple(registro),
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Estado'),
                )
              // "Terminado"/"Archivado"/"PendienteConfirmacion" nunca son una
              // opción de este desplegable (auditoría de seguridad, octubre
              // 2026): "Finalizar" (y, en el modelo de dos pasos, "Confirmar"/
              // "Todavía no") son las únicas vías, porque además archivan el
              // registro en el historial y avisan a los demás. El servidor ya
              // lo bloquea aunque se fuerce desde fuera de la app. El chip de
              // la cabecera ya muestra el estado en ese caso -- este
              // desplegable solo aparece cuando es editable.
              else if (!_estadoControlado(registro.estado))
                DropdownButtonFormField<EstadoRegistro>(
                  initialValue: registro.estado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: _estadosEditables.map((e) => DropdownMenuItem(value: e, child: Text(nombreEstadoRegistro(e)))).toList(),
                  onChanged: (v) {
                    if (v != null) RegistroService.actualizarEstado(casa.id, elementoId, registro.id, v);
                  },
                ),
              if (!registro.esConProfesional || !_estadoControlado(registro.estado)) const SizedBox(height: 16),
              _ResumenEconomico(casa: casa, elementoId: elementoId, registro: registro),
              if (registro.esConProfesional) ...[
                const SizedBox(height: 20),
                Text('Profesional', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                _SeccionInvitarProfesional(casa: casa, elementoId: elementoId, registro: registro),
                const SizedBox(height: 20),
                PresupuestosSection(casaId: casa.id, elementoId: elementoId, registroId: registro.id, rol: RolEnTrabajo.propietario),
                const SizedBox(height: 20),
                CambiosAlcanceSection(
                  casaId: casa.id,
                  elementoId: elementoId,
                  registroId: registro.id,
                  rol: RolEnTrabajo.propietario,
                  registroCerrado: registro.estado == EstadoRegistro.terminado || registro.estado == EstadoRegistro.archivado,
                ),
                const SizedBox(height: 20),
                PagosSection(
                  casaId: casa.id,
                  elementoId: elementoId,
                  registroId: registro.id,
                  registroTitulo: registro.titulo,
                  presupuesto: registro.presupuesto,
                  rol: RolEnTrabajo.propietario,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Documentos', style: Theme.of(context).textTheme.headlineSmall),
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
                stream: DocumentoService.streamDocumentos(casa.id, registroId: registro.id),
                builder: (context, snapshot) {
                  final documentos = snapshot.data ?? [];
                  if (documentos.isEmpty) {
                    return const EmptyHint(message: 'Sin documentos todavía.', icon: Icons.description_outlined);
                  }
                  return IosSection(
                    rows: documentos
                        .map((d) => IosRow(
                              icon: Icons.insert_drive_file_outlined,
                              iconColor: context.colors.brand,
                              title: d.proveedor ?? d.nombreArchivo,
                              trailing: d.importe != null ? Text('${d.importe!.toStringAsFixed(0)} €', style: ReparaText.amount(context)) : null,
                              showChevron: false,
                            ))
                        .toList(),
                  );
                },
              ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Invitar a un profesional que ya tiene cuenta en Repara (sección 15 del
/// spec, simplificado a solo email -- ver decisión del CEO). Si ya hay un
/// profesional vinculado, muestra quién es en vez del formulario.
class _SeccionInvitarProfesional extends StatefulWidget {
  const _SeccionInvitarProfesional({required this.casa, required this.elementoId, required this.registro});

  final Casa casa;
  final String elementoId;
  final Registro registro;

  @override
  State<_SeccionInvitarProfesional> createState() => _SeccionInvitarProfesionalState();
}

class _SeccionInvitarProfesionalState extends State<_SeccionInvitarProfesional> {
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
      unawaited(AnalyticsService.professionalInvited(metodo: resultado.esDirecta ? 'email' : 'codigo'));
      if (resultado.esDirecta) {
        if (mounted) AppError.showSuccess(context, 'Invitación enviada.');
      } else if (mounted) {
        setState(() => _ultimoCodigoGenerado = resultado.codigo);
        await _compartirCodigo(resultado.codigo!);
      }
    } on FirebaseFunctionsException catch (e, st) {
      if (mounted) AppError.show(context, e.message ?? 'No se pudo enviar la invitación.', error: e, stackTrace: st);
    } catch (e, st) {
      if (mounted) AppError.show(context, 'No se pudo enviar la invitación.', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  bool _cancelando = false;

  Future<void> _cancelarInvitacion(String invitacionId) async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Cancelar invitación?',
      message: 'Podrás invitar a otro profesional para este registro.',
      cancelLabel: 'Seguir esperando',
      confirmLabel: 'Cancelar invitación',
    );
    if (!confirmar || !mounted) return;
    setState(() => _cancelando = true);
    try {
      await InvitacionService.cancelar(invitacionId);
    } on FirebaseFunctionsException catch (e, st) {
      if (mounted) AppError.show(context, e.message ?? 'No se pudo cancelar la invitación.', error: e, stackTrace: st);
    } catch (e, st) {
      if (mounted) AppError.show(context, 'No se pudo cancelar la invitación.', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  Future<void> _compartirCodigo(String codigo) async {
    final mensaje = 'Te invito a "${widget.registro.titulo}" en Repara.\n'
        'Descárgate la app, crea tu cuenta y activa el modo profesional, y luego introduce este código de invitación: $codigo';
    if (!mounted) return;
    try {
      // sharePositionOrigin obligatorio en iOS -- ver nota en
      // contacto_acciones.dart.
      await Share.share(mensaje, sharePositionOrigin: Offset.zero & MediaQuery.of(context).size);
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
            subtitle: 'Puede ver este registro y actualizar su estado',
            showChevron: false,
          ),
        ],
      );
    }

    return StreamBuilder<Invitacion?>(
      stream: InvitacionService.streamUltimaInvitacionDe(widget.registro.id),
      builder: (context, snapshot) {
        final invitacion = snapshot.data;
        if (invitacion != null && invitacion.estado == EstadoInvitacion.pendiente) {
          return IosSection(
            rows: [
              IosRow(
                icon: Icons.hourglass_top_outlined,
                iconColor: context.colors.warning,
                title: 'Invitación enviada a ${invitacion.profesionalEmail}',
                subtitle: 'Esperando respuesta',
                showChevron: false,
                trailing: _cancelando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(onPressed: () => _cancelarInvitacion(invitacion.id), child: const Text('Cancelar')),
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
                      Icon(Icons.qr_code_2_outlined, color: context.colors.brand),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Código para compartir: $_ultimoCodigoGenerado',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 1),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 20),
                        tooltip: 'Compartir código',
                        onPressed: () => _compartirCodigo(_ultimoCodigoGenerado!),
                      ),
                    ],
                  ),
                  Text(
                    'Esa persona no tiene todavía cuenta profesional en Repara. Cuando se registre, introduce este código para vincularse a este registro.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: context.colors.border)),
                ],
                if (invitacion != null && invitacion.estado == EstadoInvitacion.rechazada) ...[
                  Text(
                    '${invitacion.profesionalEmail} rechazó la invitación anterior.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.errorText),
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
                  decoration: const InputDecoration(labelText: 'Correo del profesional (opcional)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _enviando ? null : _invitar,
                    child: _enviando
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

/// Resumen económico en una sola tarjeta -- antes el presupuesto, el coste,
/// el profesional de texto libre y la barra de pago vivían como líneas
/// sueltas dentro de la misma tarjeta genérica que la descripción y el
/// desplegable de estado, sin relación visual entre ellos. Mismas
/// condiciones exactas que antes (ningún dato nuevo, ningún saldo inventado):
/// el profesional de texto libre solo se repite aquí cuando NO hay sección
/// "Profesional" propia (esConProfesional == false) -- para evitar
/// duplicarlo con _SeccionInvitarProfesional, que ya lo muestra.
class _ResumenEconomico extends StatelessWidget {
  const _ResumenEconomico({required this.casa, required this.elementoId, required this.registro});

  final Casa casa;
  final String elementoId;
  final Registro registro;

  @override
  Widget build(BuildContext context) {
    final mostrarCoste = registro.coste != null && !registro.esConProfesional;
    final mostrarPresupuesto = registro.presupuesto != null;
    final mostrarProfesional = !registro.esConProfesional && registro.profesionalNombre != null;
    if (!mostrarCoste && !mostrarPresupuesto && !mostrarProfesional) return const SizedBox.shrink();

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
              Text('Coste', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.inkMuted)),
              const SizedBox(height: 2),
              Text('${registro.coste!.toStringAsFixed(0)} €', style: ReparaText.amount(context, large: true)),
            ],
            if (mostrarCoste && (mostrarPresupuesto || mostrarProfesional)) divisor(),
            if (mostrarPresupuesto) ...[
              Text('Presupuesto', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.inkMuted)),
              const SizedBox(height: 2),
              Text('${registro.presupuesto!.toStringAsFixed(0)} €', style: ReparaText.amount(context, large: true)),
              const SizedBox(height: 14),
              ProgresoPago(casaId: casa.id, elementoId: elementoId, registroId: registro.id, presupuesto: registro.presupuesto!),
            ],
            if (mostrarPresupuesto && mostrarProfesional) divisor(),
            if (mostrarProfesional)
              Row(
                children: [
                  Icon(Icons.engineering_outlined, size: 18, color: context.colors.brand),
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

// terminado/archivado/pendienteConfirmacion nunca son editables por esta vía
// directa -- "Finalizar"/"Confirmar"/"Todavía no" son las únicas puertas
// (modelo de dos pasos, auditoría de producto, octubre 2026).
bool _estadoControlado(EstadoRegistro e) =>
    e == EstadoRegistro.terminado || e == EstadoRegistro.archivado || e == EstadoRegistro.pendienteConfirmacion;

// Un registro simple (sin profesional) nace directamente "terminado" -- no
// tiene el ciclo de vida nuevo/presupuestado/en curso, así que aquí solo se
// distingue archivado de "registrado" en vez de reutilizar los nombres del
// flujo con profesional.
String _nombreEstadoSimple(Registro r) => r.estado == EstadoRegistro.archivado ? 'Archivado' : 'Registrado';

const _estadosEditables = [EstadoRegistro.nuevo, EstadoRegistro.presupuestado, EstadoRegistro.enCurso];
