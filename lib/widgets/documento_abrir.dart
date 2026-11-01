// lib/widgets/documento_abrir.dart
//
// Abrir el archivo real de un documento (CEO, noviembre 2026: "no lee
// documentos ni deja entrar a ellos") -- compartido entre la ficha de
// elemento, la pestaña Documentos de un registro y el listado de Documentos
// de la casa (Ajustes), que antes tenían cada una su propio trozo de lógica
// (o, en el caso de las dos primeras, ninguna -- las filas no tenían onTap).
// El gate biométrico es el mismo para los tres sitios: abrir el archivo en sí
// es el contenido sensible (sección 6 de la misión de seguridad local).
//
// [mostrarAccionesDocumento] (CEO, noviembre 2026: "cada documento debería
// poder ser editable y eliminable -- por si subo uno donde no era o me
// equivoco en algo") sustituye el onTap directo a abrirDocumento() en los
// tres sitios de arriba por un menú corto -- mismo patrón que
// mostrarAccionesContacto() en contacto_acciones.dart. Antes, borrar un
// documento solo existía (sin ningún indicio visual) como gesto de mantener
// pulsado en el listado de la casa; editar no existía en ningún sitio.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/service_locator.dart';
import '../models/documento.dart';
import '../screens/editar_documento_sheet.dart';
import '../services/documento_service.dart';
import '../services/security/biometric_service.dart';
import '../services/security/security_preferences_service.dart';
import '../theme/design_tokens.dart';
import 'app_dialog.dart';
import 'app_error.dart';
import 'ios_list.dart';

Future<void> mostrarAccionesDocumento(
  BuildContext context, {
  required String casaId,
  required Documento documento,
}) {
  return showModalBottomSheet<void>(
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
                if (documento.url.isNotEmpty)
                  IosRow(
                    icon: Icons.open_in_new,
                    iconColor: ctx.colors.brand,
                    title: 'Abrir documento',
                    onTap: () {
                      Navigator.pop(ctx);
                      abrirDocumento(context, documento);
                    },
                  ),
                IosRow(
                  icon: Icons.edit_outlined,
                  iconColor: ctx.colors.inkMuted,
                  title: 'Editar datos',
                  onTap: () {
                    Navigator.pop(ctx);
                    mostrarEditarDocumentoSheet(context, casaId: casaId, documento: documento);
                  },
                ),
              ],
            ),
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.delete_outline,
                  iconColor: ctx.colors.errorText,
                  title: 'Eliminar documento',
                  titleColor: ctx.colors.errorText,
                  showChevron: false,
                  onTap: () {
                    Navigator.pop(ctx);
                    _eliminarDocumento(context, casaId: casaId, documento: documento);
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

Future<void> _eliminarDocumento(
  BuildContext context, {
  required String casaId,
  required Documento documento,
}) async {
  final confirmar = await AppDialog.confirmText(
    context,
    title: '¿Eliminar este documento?',
    message: 'Se borrará de forma permanente. No afecta al elemento ni al registro de origen.',
    confirmLabel: 'Eliminar',
  );
  if (!confirmar || !context.mounted) return;
  try {
    await DocumentoService.eliminar(casaId, documento.id);
  } catch (e, st) {
    if (context.mounted) {
      AppError.show(context, 'No se pudo eliminar el documento.', error: e, stackTrace: st);
    }
  }
}

Future<void> abrirDocumento(BuildContext context, Documento documento) async {
  // Un documento rellenado a mano (Presupuestos/Facturas-Notas sin escanear
  // nada, CEO noviembre 2026) nunca tiene archivo -- url vacía es la señal,
  // no un fallo de subida. Nada que abrir, así que ni siquiera se pide el
  // gate biométrico.
  if (documento.url.isEmpty) {
    AppError.show(context, 'Este documento se guardó solo con datos, sin ningún archivo adjunto.');
    return;
  }
  await abrirArchivoProtegido(context, documento.url);
}

/// Mismo gate biométrico de arriba, pero recibiendo la url suelta en vez de
/// un Documento entero -- lo reutiliza MiniaturaDocumento (CEO, noviembre
/// 2026) para el comprobante de un Pago, que no es un Documento de la
/// colección de siempre.
Future<void> abrirArchivoProtegido(BuildContext context, String url) async {
  if (await SecurityPreferencesService.instance.isDocumentProtectionEnabled()) {
    final verificado = await sl<BiometricService>().authenticate('Verifica tu identidad para abrir este documento') ==
        BiometricAuthResult.success;
    if (!verificado) return;
  }
  if (!context.mounted) return;
  final uri = Uri.tryParse(url);
  if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) AppError.show(context, 'No se pudo abrir el documento.');
  }
}
