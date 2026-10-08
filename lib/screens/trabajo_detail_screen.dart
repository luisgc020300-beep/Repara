// lib/screens/trabajo_detail_screen.dart
//
// Expediente de un trabajo (sección 13 del spec, simplificado para v1: sin
// ScopeGuard/cambios de alcance todavía). Al finalizar, se ofrece volcar el
// trabajo como un evento permanente en el historial de la casa (sección 21:
// "¿Qué quieres guardar en el historial de la vivienda?").
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../models/invitacion.dart';
import '../models/trabajo.dart';
import '../services/analytics_service.dart';
import '../services/documento_service.dart';
import '../services/invitacion_service.dart';
import '../services/pago_service.dart';
import '../services/trabajo_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import '../widgets/progreso_pago.dart';
import 'cambio_alcance_section.dart';
import 'nuevo_documento_flow.dart';
import 'pagos_section.dart';
import 'presupuestos_section.dart';

class TrabajoDetailScreen extends StatelessWidget {
  const TrabajoDetailScreen({required this.casa, required this.trabajoId, super.key});

  final Casa casa;
  final String trabajoId;

  Future<void> _finalizar(BuildContext context, Trabajo trabajo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar trabajo'),
        content: const Text('Se marcará como terminado y quedará guardado en el historial de la casa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    await _confirmarFinalizacion(context, trabajo);
  }

  /// Compartido entre "Finalizar" (el propietario cierra directamente) y
  /// "Confirmar" (el propietario da por buena la finalización que dice
  /// haber hecho el profesional) -- en ambos casos el resultado final es
  /// el mismo, lo único que cambia es si hubo o no un paso previo del
  /// profesional (modelo de dos pasos, auditoría de producto, octubre 2026).
  Future<void> _confirmarFinalizacion(BuildContext context, Trabajo trabajo) async {
    // Aviso, no bloqueo (decisión del CEO): que falte pago no debe impedir
    // cerrar un trabajo si el cobro llega más tarde (transferencia,
    // financiación...), pero sí se avisa para no perderlo de vista.
    var pagadoDelTodo = false;
    if (trabajo.presupuesto != null) {
      final pagado = await PagoService.totalPagado(casa.id, trabajo.id);
      pagadoDelTodo = pagado >= trabajo.presupuesto!;
      if (!pagadoDelTodo && context.mounted) {
        final seguir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Todavía no está pagado del todo'),
            content: Text(
              'Llevas pagado ${pagado.toStringAsFixed(2)} € de ${trabajo.presupuesto!.toStringAsFixed(2)} €. '
              '¿Quieres finalizar igualmente?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar igualmente')),
            ],
          ),
        );
        if (seguir != true) return;
      }
    }
    if (!context.mounted) return;
    try {
      // Cloud Function, no escritura directa (auditoría de seguridad,
      // octubre 2026): estado=terminado y el evento de historial se crean
      // atómicamente en servidor -- las reglas de Firestore ya bloquean
      // marcar un trabajo como terminado por una escritura directa.
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('finalizarTrabajoPropietario');
      await callable.call<Map<String, dynamic>>({'casaId': casa.id, 'trabajoId': trabajo.id});
      unawaited(AnalyticsService.workCompleted(pagadoDelTodo: pagadoDelTodo));
      if (context.mounted) AppError.showSuccess(context, 'Trabajo archivado en el historial.');

      // Bucle viral en UN solo momento (auditoría de producto, octubre
      // 2026): justo cuando el trabajo ha ido bien de verdad -- terminado Y
      // pagado del todo, con un profesional real de Repara de por medio.
      // Nunca en ningún otro sitio, nunca con descuentos artificiales.
      if (pagadoDelTodo && trabajo.profesionalUid != null && context.mounted) {
        await _ofrecerCompartir(context, trabajo);
      }
    } catch (e, st) {
      if (context.mounted) AppError.show(context, 'No se pudo finalizar el trabajo.', error: e, stackTrace: st);
    }
  }

  /// El propietario dice que, en realidad, todavía no está terminado --
  /// devuelve el trabajo a como estaba antes de que el profesional lo
  /// marcara, y le avisa para que siga con él.
  Future<void> _rechazarFinalizacion(BuildContext context, Trabajo trabajo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Todavía no está terminado?'),
        content: const Text('Se avisará al profesional para que lo siga revisando.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Todavía no')),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    try {
      await TrabajoService.rechazarFinalizacionProfesional(casa.id, trabajo.id);
    } catch (e, st) {
      if (context.mounted) AppError.show(context, 'No se pudo actualizar el trabajo.', error: e, stackTrace: st);
    }
  }

  Future<void> _ofrecerCompartir(BuildContext context, Trabajo trabajo) async {
    final compartir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Te ha ido bien?'),
        content: Text(
          '${trabajo.profesionalNombre ?? 'Tu profesional'} también puede recibir más clientes como tú a través de Repara.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Compartir')),
        ],
      ),
    );
    if (compartir != true) return;
    try {
      await Share.share(
        'He usado Repara para gestionar "${trabajo.titulo}"${trabajo.profesionalNombre != null ? ' con ${trabajo.profesionalNombre}' : ''} '
        '-- presupuesto, cambios y pagos, todo en un sitio. Pruébalo tú también.',
      );
    } catch (e) {
      // Decorativo -- que falle el selector de compartir no debe parecer
      // que el trabajo no se finalizó bien.
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trabajo?>(
      stream: TrabajoService.streamTrabajo(casa.id, trabajoId),
      builder: (context, snapshot) {
        final trabajo = snapshot.data;
        if (trabajo == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(title: Text(trabajo.titulo)),
          floatingActionButton: _estadoControlado(trabajo.estado)
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _finalizar(context, trabajo),
                  icon: const Icon(Icons.check),
                  label: const Text('Finalizar'),
                ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (trabajo.estado == EstadoTrabajo.pendienteConfirmacion) ...[
                Card(
                  color: context.colors.warning.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.hourglass_top_outlined, color: context.colors.warning),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'El profesional dice que ha terminado este trabajo. ¿Lo confirmas?',
                                style: TextStyle(color: context.colors.ink, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _rechazarFinalizacion(context, trabajo),
                                child: const Text('Todavía no'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _confirmarFinalizacion(context, trabajo),
                                child: const Text('Confirmar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (trabajo.descripcion != null) ...[
                        Text(trabajo.descripcion!),
                        const SizedBox(height: 12),
                      ],
                      // "Terminado"/"Archivado"/"PendienteConfirmacion" nunca
                      // son una opción de este desplegable (auditoría de
                      // seguridad, octubre 2026): "Finalizar" (y, en el modelo
                      // de dos pasos, "Confirmar"/"Todavía no") son las únicas
                      // vías, porque además archivan el evento en el
                      // historial y avisan a los demás. Elegirlos aquí antes
                      // se saltaba todo eso en silencio -- ahora ni siquiera
                      // aparecen, y el servidor también lo bloquea aunque se
                      // fuerce desde fuera de la app.
                      DropdownButtonFormField<EstadoTrabajo>(
                        initialValue: _estadoControlado(trabajo.estado) ? null : trabajo.estado,
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          helperText: switch (trabajo.estado) {
                            EstadoTrabajo.terminado || EstadoTrabajo.archivado => 'Ya está finalizado',
                            EstadoTrabajo.pendienteConfirmacion => 'Esperando tu confirmación',
                            _ => null,
                          },
                        ),
                        items: _estadosEditables
                            .map((e) => DropdownMenuItem(value: e, child: Text(_nombreEstado(e))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) TrabajoService.actualizarEstado(casa.id, trabajo.id, v);
                        },
                      ),
                      if (trabajo.profesionalNombre != null) ...[
                        const SizedBox(height: 8),
                        Text('Profesional: ${trabajo.profesionalNombre}${trabajo.profesionalContacto != null ? ' · ${trabajo.profesionalContacto}' : ''}'),
                      ],
                      if (trabajo.presupuesto != null) ...[
                        const SizedBox(height: 4),
                        Text('Presupuesto: ${trabajo.presupuesto!.toStringAsFixed(0)} €'),
                        const SizedBox(height: 10),
                        ProgresoPago(casaId: casa.id, trabajoId: trabajo.id, presupuesto: trabajo.presupuesto!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Profesional', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _SeccionInvitarProfesional(casa: casa, trabajo: trabajo),
              const SizedBox(height: 20),
              PresupuestosSection(casaId: casa.id, trabajoId: trabajo.id, rol: RolEnTrabajo.propietario),
              const SizedBox(height: 20),
              CambiosAlcanceSection(
                casaId: casa.id,
                trabajoId: trabajo.id,
                rol: RolEnTrabajo.propietario,
                trabajoCerrado: trabajo.estado == EstadoTrabajo.terminado || trabajo.estado == EstadoTrabajo.archivado,
              ),
              const SizedBox(height: 20),
              PagosSection(
                casaId: casa.id,
                trabajoId: trabajo.id,
                trabajoTitulo: trabajo.titulo,
                presupuesto: trabajo.presupuesto,
                rol: RolEnTrabajo.propietario,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Documentos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  TextButton.icon(
                    onPressed: () => iniciarNuevoDocumento(
                      context,
                      casaId: casa.id,
                      trabajoId: trabajo.id,
                      habitacionId: trabajo.habitacionId,
                    ),
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    label: const Text('Escanear documento'),
                  ),
                ],
              ),
              StreamBuilder<List<Documento>>(
                stream: DocumentoService.streamDocumentos(casa.id, trabajoId: trabajo.id),
                builder: (context, snapshot) {
                  final documentos = snapshot.data ?? [];
                  if (documentos.isEmpty) {
                    return Text('Sin documentos todavía.', style: TextStyle(color: context.colors.inkMuted));
                  }
                  return Column(
                    children: documentos
                        .map((d) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.insert_drive_file_outlined),
                                title: Text(d.proveedor ?? d.nombreArchivo),
                                trailing: d.importe != null ? Text('${d.importe!.toStringAsFixed(0)} €') : null,
                              ),
                            ))
                        .toList(),
                  );
                },
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
  const _SeccionInvitarProfesional({required this.casa, required this.trabajo});

  final Casa casa;
  final Trabajo trabajo;

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
        trabajoId: widget.trabajo.id,
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
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar invitación?'),
        content: const Text('Podrás invitar a otro profesional para este trabajo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir esperando')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar invitación')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
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
    final mensaje = 'Te invito a "${widget.trabajo.titulo}" en Repara.\n'
        'Descárgate la app, crea tu cuenta y activa el modo profesional, y luego introduce este código de invitación: $codigo';
    try {
      await Share.share(mensaje);
    } catch (e) {
      // El código ya se generó y se muestra en pantalla -- que falle el
      // selector de compartir no debe parecer que la invitación falló.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trabajo.profesionalUid != null) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.verified_user_outlined, color: context.colors.success),
          title: Text(widget.trabajo.profesionalNombre ?? 'Profesional vinculado'),
          subtitle: const Text('Puede ver este trabajo y actualizar su estado'),
        ),
      );
    }

    return StreamBuilder<Invitacion?>(
      stream: InvitacionService.streamUltimaInvitacionDe(widget.trabajo.id),
      builder: (context, snapshot) {
        final invitacion = snapshot.data;
        if (invitacion != null && invitacion.estado == EstadoInvitacion.pendiente) {
          return Card(
            child: ListTile(
              leading: Icon(Icons.hourglass_top_outlined, color: context.colors.warning),
              title: Text('Invitación enviada a ${invitacion.profesionalEmail}'),
              subtitle: const Text('Esperando respuesta'),
              trailing: _cancelando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: () => _cancelarInvitacion(invitacion.id),
                      child: const Text('Cancelar'),
                    ),
            ),
          );
        }
        return Card(
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
                          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 20),
                        onPressed: () => _compartirCodigo(_ultimoCodigoGenerado!),
                      ),
                    ],
                  ),
                  Text(
                    'Esa persona no tiene todavía cuenta profesional en Repara. Cuando se registre, introduce este código para vincularse a este trabajo.',
                    style: TextStyle(color: context.colors.inkMuted, fontSize: 12),
                  ),
                  const Divider(height: 20),
                ],
                if (invitacion != null && invitacion.estado == EstadoInvitacion.rechazada) ...[
                  Text('${invitacion.profesionalEmail} rechazó la invitación anterior.', style: TextStyle(color: context.colors.error)),
                  const SizedBox(height: 8),
                ],
                const Text('Invita a tu profesional de confianza -- si ya tiene cuenta en Repara, le llega directo; si no, te doy un código para que se lo mandes tú.'),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo del profesional (opcional)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: _enviando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : FilledButton(onPressed: _invitar, child: const Text('Invitar')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// terminado/archivado/pendienteConfirmacion nunca son editables por esta vía
// directa -- "Finalizar"/"Confirmar"/"Todavía no" son las únicas puertas
// (modelo de dos pasos, auditoría de producto, octubre 2026).
bool _estadoControlado(EstadoTrabajo e) =>
    e == EstadoTrabajo.terminado || e == EstadoTrabajo.archivado || e == EstadoTrabajo.pendienteConfirmacion;

String _nombreEstado(EstadoTrabajo e) => switch (e) {
      EstadoTrabajo.nuevo => 'Nuevo',
      EstadoTrabajo.presupuestado => 'Presupuestado',
      EstadoTrabajo.enCurso => 'En curso',
      EstadoTrabajo.pendienteConfirmacion => 'Pendiente de confirmación',
      EstadoTrabajo.terminado => 'Terminado',
      EstadoTrabajo.archivado => 'Archivado',
    };

const _estadosEditables = [EstadoTrabajo.nuevo, EstadoTrabajo.presupuestado, EstadoTrabajo.enCurso];
