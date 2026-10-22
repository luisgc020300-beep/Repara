// lib/widgets/keyboard_dismiss_bar.dart
//
// Envuelve toda la app (ver main.dart, `MaterialApp.builder`): mientras el
// teclado está abierto, deja fija justo encima una barra con un botón para
// ocultarlo. Sin esto, en una pantalla con el botón de guardar pegado al
// final, el teclado puede tapar ese botón sin ninguna forma de quitarlo
// salvo adivinar dónde tocar fuera del campo.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class KeyboardDismissBar extends StatelessWidget {
  const KeyboardDismissBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tecladoAbierto = MediaQuery.of(context).viewInsets.bottom > 0;
    return Stack(
      children: [
        child,
        if (tecladoAbierto)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).viewInsets.bottom,
            child: Material(
              color: context.colors.surface,
              child: Container(
                height: 36,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: ReparaSpace.s3),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.colors.border)),
                ),
                child: TextButton.icon(
                  onPressed: () =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  icon: const Icon(Icons.keyboard_hide_outlined, size: 18),
                  label: const Text('Ocultar teclado'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
