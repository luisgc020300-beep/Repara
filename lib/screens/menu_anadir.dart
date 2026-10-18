// lib/screens/menu_anadir.dart
//
// Menú compartido del botón "+" (sección 9 del spec): añadir un elemento a
// mano o escanear un documento con IA. Usado desde Inicio e Historial.
// Hoja de acción estilo iOS: tirador arriba, opciones agrupadas, "Cancelar"
// aparte -- mismo patrón que el resto de la app (CEO, octubre 2026).
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../theme/design_tokens.dart';
import '../widgets/ios_list.dart';
import 'nuevo_documento_flow.dart';
import 'nuevo_elemento_screen.dart';

Future<void> mostrarMenuAnadir(BuildContext context, {required Casa casa}) {
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
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.document_scanner_outlined,
                  iconColor: ctx.colors.brand,
                  title: 'Escanear factura o documento',
                  subtitle: 'La IA rellena los datos por ti',
                  onTap: () {
                    Navigator.pop(ctx);
                    iniciarNuevoDocumento(context, casaId: casa.id);
                  },
                ),
                IosRow(
                  icon: Icons.add_circle_outline,
                  iconColor: ctx.colors.brand,
                  title: 'Añadir elemento a mano',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => NuevoElementoScreen(casa: casa)));
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
