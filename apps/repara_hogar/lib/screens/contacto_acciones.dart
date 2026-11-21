// lib/screens/contacto_acciones.dart
//
// El objetivo de esta pantalla (pedido explícitamente por el CEO): que
// avisar a tu profesional de confianza sea más rápido que buscarlo en la
// agenda del teléfono, llamarlo y explicarle de palabra qué le pasa.
//
// Límite técnico real, no evitable: WhatsApp no permite abrir un chat con
// un número concreto Y adjuntar una foto en una sola acción automática (es
// una restricción de la propia app, en iOS y Android). Por eso hay dos
// acciones distintas en vez de una: abrir el chat con texto ya escrito, o
// compartir foto+texto por el selector nativo (donde WhatsApp es una opción
// más, junto a SMS/email/etc.).
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:repara_core/analytics_service.dart';
import 'package:repara_core/invitacion.dart';
import 'package:repara_core/invitacion_service.dart';
import 'package:repara_core/registro.dart';
import 'package:repara_core/registro_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/contacto.dart';
import '../services/contacto_service.dart';
import '../services/elemento_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_dialog.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/ios_list.dart';
import 'nuevo_contacto_sheet.dart';

Future<void> mostrarAccionesContacto(BuildContext context, {required String casaId, required Contacto contacto}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(ReparaSpace.s4, ReparaSpace.s2, ReparaSpace.s4, ReparaSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: ReparaSpace.s4),
              decoration: BoxDecoration(color: ctx.colors.inkMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: ctx.colors.brandTint,
                  child: Icon(contacto.tipo == TipoContacto.empresa ? Icons.store_outlined : Icons.person_outline, color: ctx.colors.brand),
                ),
                const SizedBox(width: ReparaSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contacto.nombre, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      if (contacto.especialidad != null) Text(contacto.especialidad!, style: TextStyle(color: ctx.colors.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            IosSection(
              rows: filasInteraccionTelefono(
                context: context,
                nombre: contacto.nombre,
                telefono: contacto.telefono,
                antesDeCadaAccion: () => Navigator.pop(ctx),
              ),
            ),
            // Invitar a una cuenta real de Repara (distinto de "compartir un
            // evento" con el selector de profesionales, y distinto de
            // "agregar un contacto" de arriba -- CEO, noviembre 2026: dejar
            // claras las tres cosas). Reutiliza exactamente el mismo
            // mecanismo que ya usa la ficha del evento
            // (InvitacionService.invitarProfesional), solo que entrando
            // desde el contacto en vez de desde el evento.
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.person_add_alt_outlined,
                  iconColor: context.colors.brand,
                  title: 'Invitar a un evento de Repara',
                  subtitle: 'Vincula su cuenta a uno de tus eventos abiertos',
                  onTap: () {
                    Navigator.pop(ctx);
                    _invitarAUnEvento(context, casaId: casaId, contacto: contacto);
                  },
                ),
              ],
            ),
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.edit_outlined,
                  iconColor: ctx.colors.inkMuted,
                  title: 'Editar contacto',
                  onTap: () {
                    Navigator.pop(ctx);
                    mostrarNuevoContactoSheet(context, casaId: casaId, existente: contacto);
                  },
                ),
              ],
            ),
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.delete_outline,
                  iconColor: ctx.colors.errorText,
                  title: 'Eliminar contacto',
                  titleColor: ctx.colors.errorText,
                  showChevron: false,
                  onTap: () {
                    Navigator.pop(ctx);
                    _eliminarContacto(context, casaId: casaId, contacto: contacto);
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

Future<void> _eliminarContacto(BuildContext context, {required String casaId, required Contacto contacto}) async {
  final confirmar = await AppDialog.confirmText(
    context,
    title: '¿Eliminar a ${contacto.nombre}?',
    message: 'Se borrará de tu lista de contactos. No afecta a los registros ni documentos ya guardados.',
    confirmLabel: 'Eliminar',
  );
  if (!confirmar || !context.mounted) return;
  try {
    await ContactoService.eliminar(casaId, contacto.id);
  } catch (e, st) {
    if (context.mounted) {
      AppError.show(context, 'No se pudo eliminar el contacto.', error: e, stackTrace: st);
    }
  }
}

// -----------------------------------------------------------------------
// Invitar un contacto a una cuenta real de Repara, para un evento concreto
// (noviembre 2026, mejora de Contactos/invitaciones). Reutiliza tal cual
// InvitacionService.invitarProfesional -- el mismo mecanismo de
// _SeccionInvitarProfesional en registro_detail_screen.dart, solo que el
// punto de entrada es el contacto, no el evento, y el teléfono ya viene
// relleno de la libreta.
// -----------------------------------------------------------------------

/// Eventos "con profesional" de la casa que siguen activos y todavía no
/// tienen ninguna cuenta vinculada -- candidatos reales a invitación, mismo
/// criterio (RegistroService.esTrabajoActivo) que ya usa el resto de la app
/// para decidir qué sigue abierto. Mismo patrón de recorrido en memoria que
/// ElementoService.registrosConTrabajoPendiente -- sin collectionGroup ni
/// índice nuevo.
///
/// Pública (noviembre 2026, Cercanos): mismo candidato que necesita
/// cercanos_screen.dart para invitar a un profesional encontrado por
/// proximidad a uno de tus eventos abiertos -- no duplicar este recorrido.
Future<
  List<({String elementoId, String elementoNombre, Registro registro})>
>
eventosDisponiblesParaInvitar(String casaId) async {
  final elementos = await ElementoService.streamElementos(casaId).first;
  final resultado =
      <({String elementoId, String elementoNombre, Registro registro})>[];
  for (final elemento in elementos) {
    final registros = await RegistroService.streamRegistros(
      casaId,
      elemento.id,
    ).first;
    for (final r in registros) {
      if (r.esConProfesional &&
          r.profesionalUid == null &&
          RegistroService.esTrabajoActivo(r)) {
        // Evitar invitaciones duplicadas (noviembre 2026, mejora de
        // invitaciones): sin esto, un evento con una invitación ya
        // pendiente (mandada desde su propia ficha, ver
        // _SeccionInvitarProfesional en registro_detail_screen.dart)
        // seguía apareciendo aquí -- invitarProfesional no comprueba en
        // servidor si ya hay una pendiente, así que se podía acabar con
        // dos invitaciones activas a la vez para el mismo evento, una desde
        // cada camino (Contactos/Cercanos y la propia ficha del evento).
        final ultima = await InvitacionService.streamUltimaInvitacionDe(
          r.id,
        ).first;
        if (ultima != null && ultima.estado == EstadoInvitacion.pendiente) {
          continue;
        }
        resultado.add((
          elementoId: elemento.id,
          elementoNombre: elemento.nombre,
          registro: r,
        ));
      }
    }
  }
  return resultado;
}

/// Muestra el selector "¿a qué evento invitas a X?" y devuelve el elegido (o
/// null si no había ninguno disponible -- ya se avisa aquí mismo -- o si se
/// cerró sin elegir). Pública (noviembre 2026, Cercanos): mismo selector que
/// usa cercanos_screen.dart al invitar a un profesional encontrado por
/// proximidad, solo cambia el nombre que se muestra en el título.
Future<({String elementoId, String elementoNombre, Registro registro})?>
elegirEventoParaInvitar(
  BuildContext context, {
  required String casaId,
  required String nombrePersona,
}) async {
  final eventos = await eventosDisponiblesParaInvitar(casaId);
  if (!context.mounted) return null;
  if (eventos.isEmpty) {
    AppError.show(
      context,
      'No tienes ningún evento abierto a un profesional que aún esté sin asignar. '
      'Crea uno nuevo o edita uno existente para poder invitar desde aquí.',
    );
    return null;
  }
  return showModalBottomSheet<
    ({String elementoId, String elementoNombre, Registro registro})
  >(
    context: context,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: ReparaSpace.s2),
              child: Text(
                '¿A qué evento invitas a $nombrePersona?',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
            ),
            IosSection(
              rows: eventos
                  .map(
                    (e) => IosRow(
                      icon: Icons.build_outlined,
                      iconColor: ctx.colors.brand,
                      title: e.registro.titulo,
                      subtitle: e.elementoNombre,
                      onTap: () => Navigator.pop(ctx, e),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _invitarAUnEvento(
  BuildContext context, {
  required String casaId,
  required Contacto contacto,
}) async {
  // Mismo bug real que en cercanos_screen.dart (CEO, noviembre 2026): sin
  // este try/catch, un fallo de eventosDisponiblesParaInvitar() quedaba sin
  // capturar y el botón de invitar parecía no hacer nada.
  final elegido = await (() async {
    try {
      return await elegirEventoParaInvitar(
        context,
        casaId: casaId,
        nombrePersona: contacto.nombre,
      );
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo comprobar tus eventos abiertos a un profesional.',
          error: e,
          stackTrace: st,
        );
      }
      return null;
    }
  })();
  if (elegido == null || !context.mounted) return;

  try {
    final resultado = await InvitacionService.invitarProfesional(
      casaId: casaId,
      elementoId: elegido.elementoId,
      registroId: elegido.registro.id,
      telefonoProfesional: contacto.telefono,
      contactoId: contacto.id,
    );
    unawaited(
      AnalyticsService.professionalInvited(
        metodo: resultado.esDirecta ? 'telefono' : 'codigo',
      ),
    );
    if (!context.mounted) return;
    if (resultado.esDirecta) {
      AppError.showSuccess(context, 'Invitación enviada a ${contacto.nombre}.');
    } else if (resultado.codigo != null) {
      final mensaje =
          'Te invito a "${elegido.registro.titulo}" en Repara.\n'
          'Descárgate la app, crea tu cuenta y activa el modo profesional, y luego introduce este código de invitación: ${resultado.codigo}';
      try {
        await Share.share(
          mensaje,
          sharePositionOrigin: Offset.zero & MediaQuery.of(context).size,
        );
      } catch (_) {
        // La invitación ya se generó -- que falle el selector de compartir
        // no debe parecer que la invitación falló.
      }
    }
  } on FirebaseFunctionsException catch (e, st) {
    if (context.mounted) {
      AppError.show(
        context,
        e.message ?? 'No se pudo enviar la invitación.',
        error: e,
        stackTrace: st,
      );
    }
  } catch (e, st) {
    if (context.mounted) {
      AppError.show(
        context,
        'No se pudo enviar la invitación.',
        error: e,
        stackTrace: st,
      );
    }
  }
}

// Filas de interacción por teléfono (CEO, noviembre 2026: "las mismas
// opciones que hay en Contactos" también para el profesional de texto libre
// de un evento, que no vive en la libreta de Contactos -- por eso recibe
// nombre/teléfono sueltos, no un Contacto entero). Compartidas entre
// mostrarAccionesContacto (aquí, dentro de una hoja modal -- [antesDeCadaAccion]
// la cierra antes de cada acción) y la sección de profesional de
// registro_detail_screen.dart (ya en la propia pantalla, sin hoja que cerrar
// -- ahí no se pasa [antesDeCadaAccion]).
List<Widget> filasInteraccionTelefono({
  required BuildContext context,
  required String nombre,
  required String telefono,
  VoidCallback? antesDeCadaAccion,
}) => [
      IosRow(
        icon: Icons.call_outlined,
        iconColor: context.colors.brand,
        title: 'Llamar',
        onTap: () async {
          antesDeCadaAccion?.call();
          await launchUrl(Uri(scheme: 'tel', path: telefono));
        },
      ),
      IosRow(
        icon: Icons.chat_outlined,
        iconColor: Colors.green,
        title: 'Abrir chat de WhatsApp',
        subtitle: 'Sin foto, solo para escribir',
        onTap: () async {
          antesDeCadaAccion?.call();
          final numero = telefono.replaceAll(RegExp(r'[^0-9]'), '');
          await launchUrl(Uri.parse('https://wa.me/$numero'), mode: LaunchMode.externalApplication);
        },
      ),
      IosRow(
        icon: Icons.camera_alt_outlined,
        iconColor: context.colors.brand,
        title: 'Reportar un problema con foto',
        subtitle: 'Foto + descripción, listo para enviar por WhatsApp',
        onTap: () {
          antesDeCadaAccion?.call();
          iniciarReporteConFoto(context, nombre: nombre);
        },
      ),
    ];

Future<void> iniciarReporteConFoto(BuildContext context, {required String nombre}) async {
  final picker = ImagePicker();
  final foto = await showModalBottomSheet<XFile?>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(ReparaSpace.s4, ReparaSpace.s2, ReparaSpace.s4, ReparaSpace.s4),
        child: IosSection(
          rows: [
            IosRow(
              icon: Icons.photo_camera_outlined,
              iconColor: ctx.colors.brand,
              title: 'Hacer una foto',
              onTap: () async {
                final navigator = Navigator.of(ctx);
                final imagen = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
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
                final imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
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

  final descripcion = await AppDialog.promptText(
    context,
    title: '¿Qué le pasa? (para $nombre)',
    hint: 'p.ej. Gotea el grifo del baño desde ayer',
    confirmLabel: 'Enviar',
    minLines: 2,
    maxLines: 4,
  );
  if (descripcion == null || descripcion.isEmpty || !context.mounted) return;

  try {
    // sharePositionOrigin es obligatorio en iOS (ancla del popover en
    // iPad, y share_plus valida que no sea el rect vacío por defecto ni
    // en iPhone) -- sin esto, Share.share/shareXFiles revienta siempre
    // con PlatformException "must be non-zero" (CEO, octubre 2026).
    await Share.shareXFiles([XFile(foto.path)], text: descripcion, sharePositionOrigin: Offset.zero & MediaQuery.of(context).size);
  } catch (e) {
    if (context.mounted) AppError.show(context, 'No se pudo abrir el selector para compartir.');
  }
}
