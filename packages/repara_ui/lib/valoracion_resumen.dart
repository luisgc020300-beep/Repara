// lib/valoracion_resumen.dart
//
// Resumen de valoración (nota media + nº de valoraciones) -- único widget
// de formato para las cuatro pantallas que lo muestran (unificación del
// sistema de valoraciones, noviembre 2026): Contactos de REPARA Hogar
// (Agregados/Recientes/Favoritos/Cercanos) y la reputación de REPARA Pro.
// Todas leen el mismo agregado (profesionalesPublico/{uid}), y todas lo
// enseñan igual -- para que la cifra nunca se vea "distinta" de una
// pantalla a otra solo por un formato distinto.
import 'package:flutter/material.dart';
import 'package:repara_core/design_tokens.dart';

class ValoracionResumen extends StatelessWidget {
  const ValoracionResumen({
    required this.valoracionMedia,
    required this.numValoraciones,
    this.tamanoEstrella = 14,
    super.key,
  });

  /// Null (o numValoraciones <= 0) -- nunca se inventa una puntuación.
  final double? valoracionMedia;
  final int numValoraciones;
  final double tamanoEstrella;

  @override
  Widget build(BuildContext context) {
    final estiloTexto = TextStyle(
      fontSize: tamanoEstrella - 2,
      color: context.colors.inkMuted,
    );
    if (valoracionMedia == null || numValoraciones <= 0) {
      return Text('Sin valoraciones', style: estiloTexto);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          size: tamanoEstrella,
          color: context.colors.warning,
        ),
        const SizedBox(width: 2),
        Text(
          '${valoracionMedia!.toStringAsFixed(1)} ($numValoraciones)',
          style: estiloTexto.copyWith(
            color: context.colors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
