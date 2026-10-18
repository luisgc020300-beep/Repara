// lib/widgets/estado_registro_chip.dart
//
// Chrome visual compartido entre la ficha de registro de Hogar
// (registro_detail_screen.dart) y la de Pro (registro_pro_detail_screen.dart)
// -- mismo registro, dos lados, debe sentirse el mismo producto. Antes cada
// pantalla llevaba su propia copia de _nombreEstado/_EstadoChip (octubre
// 2026: se consolidan aquí para no divergir con el tiempo).
import 'package:flutter/material.dart';

import '../models/registro.dart';
import '../theme/design_tokens.dart';

String nombreEstadoRegistro(EstadoRegistro e) => switch (e) {
      EstadoRegistro.nuevo => 'Nuevo',
      EstadoRegistro.presupuestado => 'Presupuestado',
      EstadoRegistro.enCurso => 'En curso',
      EstadoRegistro.pendienteConfirmacion => 'Pendiente de confirmación',
      EstadoRegistro.terminado => 'Terminado',
      EstadoRegistro.archivado => 'Archivado',
    };

IconData iconoTipoRegistro(TipoRegistro t) => switch (t) {
      TipoRegistro.compra => Icons.shopping_bag_outlined,
      TipoRegistro.averia => Icons.report_problem_outlined,
      TipoRegistro.reparacion => Icons.build_outlined,
      TipoRegistro.mantenimiento => Icons.build_circle_outlined,
      TipoRegistro.instalacion => Icons.handyman_outlined,
      TipoRegistro.reforma => Icons.home_repair_service_outlined,
      TipoRegistro.sustitucion => Icons.swap_horiz_outlined,
      TipoRegistro.nota => Icons.notes_outlined,
    };

/// Chip de estado en la cabecera (octubre 2026, pasada de craft) -- visible
/// de un vistazo sin leer nada, con el color semántico que le corresponde.
class EstadoRegistroChip extends StatelessWidget {
  const EstadoRegistroChip({required this.estado, super.key});

  final EstadoRegistro estado;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (estado) {
      EstadoRegistro.pendienteConfirmacion => (context.colors.warningText, context.colors.warning.withValues(alpha: 0.12)),
      EstadoRegistro.terminado || EstadoRegistro.archivado => (context.colors.success, context.colors.success.withValues(alpha: 0.12)),
      EstadoRegistro.nuevo || EstadoRegistro.presupuestado || EstadoRegistro.enCurso => (context.colors.brand, context.colors.brandTint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(ReparaRadius.pill)),
      child: Text(
        nombreEstadoRegistro(estado).toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }
}

/// Aviso en contenedor con borde de color en vez de Card -- para que se note
/// que es un aviso, no una tarjeta de contenido más (briefing "REPARA
/// Professional"). [acciones] es opcional: en Hogar lleva "Todavía no"/
/// "Confirmar"; en Pro es solo informativo, sin botones.
class AvisoRegistro extends StatelessWidget {
  const AvisoRegistro({required this.mensaje, this.acciones, super.key});

  final String mensaje;
  final Widget? acciones;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ReparaRadius.md),
        border: Border.all(color: context.colors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top_outlined, color: context.colors.warningText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(mensaje, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (acciones != null) ...[const SizedBox(height: 12), acciones!],
        ],
      ),
    );
  }
}
