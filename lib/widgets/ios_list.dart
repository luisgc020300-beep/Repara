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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.inkMuted),
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
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              // Expanded (no Spacer + Flexible): con los dos a la vez, el
              // espacio libre se repartía al 50% entre ambos, y el texto del
              // valor -- al ser más corto que esa mitad -- quedaba pegado a
              // la izquierda de SU propia caja en vez de al borde derecho
              // real de la fila. Se notaba más cuanto más corta era la
              // etiqueta (p.ej. "Coste") porque dejaba más hueco de sobra
              // (CEO, octubre 2026: "120 € está más a la izquierda que el
              // resto"). Expanded fuerza al valor a ocupar TODO el espacio
              // restante, así textAlign.right sí alinea contra el borde real.
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  // warningText, no warning -- el ámbar base no llega a
                  // 4.5:1 de contraste como texto (auditoría de
                  // accesibilidad, octubre 2026).
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: destacado ? context.colors.warningText : context.colors.inkMuted,
                        fontWeight: destacado ? FontWeight.w600 : FontWeight.w400,
                      ),
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
    this.subtitleColor,
    this.showChevron = true,
    this.dense = false,
    this.selected,
    this.imageUrl,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;

  /// Sobrescribe el color por defecto (inkMuted) del subtítulo -- para
  /// cuando el propio subtítulo lleva una señal de estado (p.ej. "Termina
  /// el..." en ámbar frente a "Vigente hasta..." en el azul normal).
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  /// Si se pasa, sustituye la insignia de icono por esta miniatura (p.ej. la
  /// foto real de un elemento) -- null en el resto de filas, que se quedan
  /// con el icono de siempre.
  final String? imageUrl;

  /// false en filas de acción (cerrar sesión, eliminar, aceptar/rechazar...)
  /// que no navegan a ningún sitio -- el chevron de iOS solo aparece cuando
  /// tocar la fila SÍ te lleva a otra pantalla.
  final bool showChevron;

  /// Filas más compactas (menos padding vertical) para listas largas donde
  /// cada fila no necesita tanto aire -- p.ej. el expediente de la vivienda.
  final bool dense;

  /// Para filas de una lista de opciones (p.ej. Claro/Oscuro/Sistema en
  /// Apariencia) que marcan la elegida con un check visual -- sin esto, un
  /// lector de pantalla no tiene forma de saber cuál está seleccionada,
  /// solo ve tres filas idénticas (auditoría de accesibilidad, octubre 2026).
  /// null en filas que no son parte de un grupo de opciones.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final fila = Material(
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
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(7)),
                child: imageUrl != null ? Image.network(imageUrl!, fit: BoxFit.cover) : Icon(icon, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: titleColor ?? context.colors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: subtitleColor, fontWeight: subtitleColor != null ? FontWeight.w600 : null),
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
    return selected == null ? fila : Semantics(selected: selected, child: fila);
  }
}
