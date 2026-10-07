// lib/widgets/ios_list.dart
//
// Lista agrupada estilo iOS (Ajustes, octubre 2026): cabecera opcional en
// mayúsculas + una única tarjeta redondeada con las filas separadas por un
// divisor fino e indentado (alineado tras el icono), en vez de una Card
// suelta por fila -- el look que pidió el CEO para toda la app, no solo
// Ajustes. Icono en una insignia de color (como los ajustes nativos de
// iOS), chevron a la derecha solo cuando la fila navega a otro sitio.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class IosSection extends StatelessWidget {
  const IosSection({this.header, this.footer, required this.rows, super.key});

  final String? header;
  final String? footer;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(fontSize: 12, letterSpacing: 0.6, fontWeight: FontWeight.w600, color: context.colors.inkMuted),
              ),
            ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 56, color: context.colors.inkMuted.withValues(alpha: 0.14)),
                  rows[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6),
              child: Text(footer!, style: TextStyle(fontSize: 12.5, color: context.colors.inkMuted)),
            ),
        ],
      ),
    );
  }
}

/// Fila "etiqueta: valor" sin icono -- el otro patrón clásico de iOS para
/// fichas de información (Wi-Fi > detalles de una red, Ajustes > Información),
/// a diferencia de IosRow (que siempre lleva una insignia de icono de color,
/// pensada para navegación). Útil para pantallas de ficha/detalle.
class IosValueRow extends StatelessWidget {
  const IosValueRow({
    required this.label,
    required this.value,
    this.destacado = false,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final bool destacado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Text(label, style: TextStyle(fontSize: 15, color: context.colors.ink)),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 15, color: destacado ? context.colors.warning : context.colors.inkMuted, fontWeight: destacado ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.edit_outlined, size: 15, color: context.colors.inkMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class IosRow extends StatelessWidget {
  const IosRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.showChevron = true,
    this.dense = false,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  /// false en filas de acción (cerrar sesión, eliminar, aceptar/rechazar...)
  /// que no navegan a ningún sitio -- el chevron de iOS solo aparece cuando
  /// tocar la fila SÍ te lleva a otra pantalla.
  final bool showChevron;

  /// Filas más compactas (menos padding vertical) para listas largas donde
  /// cada fila no necesita tanto aire -- p.ej. el expediente de la vivienda.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 7 : 11),
          child: Row(
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(7)),
                child: Icon(icon, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 15.5, color: titleColor ?? context.colors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: context.colors.inkMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing!
              else if (onTap != null && showChevron)
                Icon(Icons.chevron_right, color: context.colors.inkMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
