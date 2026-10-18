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
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/contacto.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';
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
              rows: [
                IosRow(
                  icon: Icons.call_outlined,
                  iconColor: ctx.colors.brand,
                  title: 'Llamar',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await launchUrl(Uri(scheme: 'tel', path: contacto.telefono));
                  },
                ),
                IosRow(
                  icon: Icons.chat_outlined,
                  iconColor: Colors.green,
                  title: 'Abrir chat de WhatsApp',
                  subtitle: 'Sin foto, solo para escribir',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final numero = contacto.telefono.replaceAll(RegExp(r'[^0-9]'), '');
                    await launchUrl(Uri.parse('https://wa.me/$numero'), mode: LaunchMode.externalApplication);
                  },
                ),
                IosRow(
                  icon: Icons.camera_alt_outlined,
                  iconColor: ctx.colors.brand,
                  title: 'Reportar un problema con foto',
                  subtitle: 'Foto + descripción, listo para enviar por WhatsApp',
                  onTap: () {
                    Navigator.pop(ctx);
                    _iniciarReporte(context, casaId: casaId, contacto: contacto);
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
          ],
        ),
      ),
    ),
  );
}

Future<void> _iniciarReporte(BuildContext context, {required String casaId, required Contacto contacto}) async {
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
    title: '¿Qué le pasa? (para ${contacto.nombre})',
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
