// packages/repara_ui/lib/scroll_to_top_button.dart
//
// Acceso rápido para volver al principio de una lista larga (pulido
// visual, noviembre 2026) -- aparece solo tras desplazarse una distancia
// mínima y desaparece cerca del principio, para no estorbar en pantallas
// cortas ni quedarse siempre visible. Pensado para colocarse dentro de un
// Stack junto al ListView/CustomScrollView que controla, con [bottom]/
// [right] ajustables para no chocar con el FAB u otros botones ya
// existentes de cada pantalla.
import 'package:flutter/material.dart';

import 'package:repara_core/design_tokens.dart';

class ScrollToTopButton extends StatefulWidget {
  const ScrollToTopButton({
    required this.scrollController,
    this.bottom = 16,
    this.right = 16,
    this.left,
    super.key,
  });

  final ScrollController scrollController;
  final double bottom;

  /// Ignorado si [left] no es nulo -- una pantalla con el FAB principal ya
  /// en la esquina inferior derecha pasa [left] para anclar este botón al
  /// lado contrario y no superponerse con él.
  final double right;
  final double? left;

  @override
  State<ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<ScrollToTopButton> {
  // Umbral en vez de "offset > 0" -- que aparezca solo cuando de verdad
  // hace falta desplazarse para volver arriba, no al primer píxel.
  static const _umbral = 400.0;

  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ScrollToTopButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final visible = widget.scrollController.offset > _umbral;
    if (visible != _visible) setState(() => _visible = visible);
  }

  Future<void> _volverArriba() {
    return widget.scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: widget.bottom,
      right: widget.left == null ? widget.right : null,
      left: widget.left,
      child: IgnorePointer(
        ignoring: !_visible,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, 0.3),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton.small(
              // Puede convivir con el FAB principal de la pantalla -- sin
              // esto, dos FloatingActionButton con el mismo heroTag por
              // defecto (el tipo del widget) hacen que Flutter lance un
              // error de Hero duplicado en cuanto los dos están montados
              // a la vez.
              heroTag: null,
              tooltip: 'Volver arriba',
              onPressed: _volverArriba,
              backgroundColor: context.colors.brandStrong,
              foregroundColor: context.colors.brandOn,
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
          ),
        ),
      ),
    );
  }
}
