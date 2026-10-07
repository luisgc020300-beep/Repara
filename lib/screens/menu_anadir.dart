// lib/screens/menu_anadir.dart
//
// Menú compartido del botón "+" (sección 9 del spec): registrar un evento a
// mano o escanear un documento con IA. Usado desde Inicio e Historial.
// Hoja de acción estilo iOS: tirador arriba, opciones agrupadas, "Cancelar"
// aparte -- mismo patrón que el resto de la app (CEO, octubre 2026).
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../widgets/ios_list.dart';
import 'nuevo_documento_flow.dart';
import 'nuevo_evento_sheet.dart';

Future<void> mostrarMenuAnadir(BuildContext context, {required String casaId}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: ctx.colors.inkMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.document_scanner_outlined,
                  iconColor: Colors.blue,
                  title: 'Escanear factura o documento',
                  subtitle: 'La IA rellena los datos por ti',
                  onTap: () {
                    Navigator.pop(ctx);
                    iniciarNuevoDocumento(context, casaId: casaId);
                  },
                ),
                IosRow(
                  icon: Icons.edit_note_outlined,
                  iconColor: ctx.colors.brand,
                  title: 'Registrar evento a mano',
                  onTap: () {
                    Navigator.pop(ctx);
                    mostrarNuevoEventoSheet(context, casaId: casaId);
                  },
                ),
              ],
            ),
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.close,
                  iconColor: ctx.colors.inkMuted,
                  title: 'Cancelar',
                  showChevron: false,
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
