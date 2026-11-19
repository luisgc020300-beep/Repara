// packages/repara_ui/lib/editor_foto_perfil.dart
//
// Elegir/subir/borrar una foto de perfil (mejora de perfiles, noviembre
// 2026) -- mismo patrón ya usado por ElementoService.subirFoto/
// actualizarFoto (apps/repara_hogar/lib/services/elemento_service.dart):
// nombre de archivo fijo en Storage (una foto nueva sustituye a la
// anterior, nunca se acumulan archivos sueltos) y la persistencia del
// campo la decide quien llama, nunca este archivo -- aquí solo se
// pick+sube+devuelve la URL (o null si se eligió "Eliminar foto"), para
// que CuentaScreen (FirebaseAuth.updateProfile) y Ajustes Pro
// (ProfesionalService.actualizarFoto) puedan guardarla cada uno donde le
// corresponde sin duplicar el flujo de selección/subida.
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:repara_core/design_tokens.dart';
import 'app_dialog.dart';
import 'app_error.dart';
import 'ios_list.dart';

/// Abre la hoja "Hacer una foto / Elegir de la galería" (+ "Eliminar foto"
/// si [tieneFotoActual]), sube lo elegido a Storage en [storagePath] y
/// llama a [onGuardar] con la nueva URL (o null al eliminar). No hace nada
/// si el usuario cancela la hoja o el selector de imagen.
Future<void> editarFotoPerfil(
  BuildContext context, {
  required String storagePath,
  required bool tieneFotoActual,
  required Future<void> Function(String? url) onGuardar,
}) async {
  final picker = ImagePicker();
  final foto = await showModalBottomSheet<XFile?>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ReparaSpace.s4,
          ReparaSpace.s2,
          ReparaSpace.s4,
          ReparaSpace.s4,
        ),
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
            if (tieneFotoActual)
              IosRow(
                icon: Icons.delete_outline,
                iconColor: ctx.colors.errorText,
                titleColor: ctx.colors.errorText,
                title: 'Eliminar foto',
                showChevron: false,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmarEliminar(context, onGuardar);
                },
              ),
          ],
        ),
      ),
    ),
  );
  if (foto == null || !context.mounted) return;
  try {
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    await ref.putFile(File(foto.path));
    final url = await ref.getDownloadURL();
    await onGuardar(url);
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

Future<void> _confirmarEliminar(
  BuildContext context,
  Future<void> Function(String? url) onGuardar,
) async {
  final confirmar = await AppDialog.confirmText(
    context,
    title: '¿Eliminar la foto?',
    confirmLabel: 'Eliminar',
  );
  if (!confirmar || !context.mounted) return;
  try {
    await onGuardar(null);
  } catch (e, st) {
    if (context.mounted) {
      AppError.show(
        context,
        'No se pudo eliminar la foto.',
        error: e,
        stackTrace: st,
      );
    }
  }
}
