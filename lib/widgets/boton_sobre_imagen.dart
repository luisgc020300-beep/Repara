// lib/widgets/boton_sobre_imagen.dart
//
// Botón de icono con respaldo circular oscuro -- para cuando flota sobre una
// zona de foto/placeholder de color claro (AppBar transparente, lápiz de
// editar foto...) y un icono blanco a secas se volvería casi invisible por
// falta de contraste. Compartido entre elemento_detail_screen.dart y
// registro_detail_screen.dart (mismo problema, mismo arreglo, octubre 2026).
import 'package:flutter/material.dart';

class BotonSobreImagen extends StatelessWidget {
  const BotonSobreImagen({required this.icon, required this.tooltip, required this.onPressed, super.key});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 20),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
