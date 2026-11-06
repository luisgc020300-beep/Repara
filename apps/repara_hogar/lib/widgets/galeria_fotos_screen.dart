// lib/widgets/galeria_fotos_screen.dart
//
// Galería de varias fotos de un registro simple (CEO, octubre 2026) --
// PageView con zoom página a página (mismo InteractiveViewer que
// FotoAmpliadaScreen, que se deja intacta para el elemento y el lado con
// profesional, que nunca necesitan más de una foto). [onEliminar] es
// opcional: cuando se pasa, cada página ofrece un botón de borrar -- la
// pantalla nunca decide por sí sola qué significa "borrar" (Storage +
// Firestore), delega siempre en el llamador.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class GaleriaFotosScreen extends StatefulWidget {
  const GaleriaFotosScreen({
    required this.urls,
    this.indiceInicial = 0,
    this.onEliminar,
    super.key,
  });

  final List<String> urls;
  final int indiceInicial;
  final Future<void> Function(String url)? onEliminar;

  @override
  State<GaleriaFotosScreen> createState() => _GaleriaFotosScreenState();
}

class _GaleriaFotosScreenState extends State<GaleriaFotosScreen> {
  late final _controller = PageController(initialPage: widget.indiceInicial);
  late List<String> _urls = widget.urls;
  late int _indice = widget.indiceInicial;
  bool _eliminando = false;

  Future<void> _eliminarActual() async {
    final onEliminar = widget.onEliminar;
    if (onEliminar == null || _urls.isEmpty) return;
    setState(() => _eliminando = true);
    try {
      final url = _urls[_indice];
      await onEliminar(url);
      if (!mounted) return;
      setState(() {
        _urls = List.of(_urls)..removeAt(_indice);
        if (_urls.isEmpty) {
          Navigator.pop(context);
          return;
        }
        if (_indice >= _urls.length) _indice = _urls.length - 1;
      });
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_indice + 1} / ${_urls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (widget.onEliminar != null)
            IconButton(
              icon: _eliminando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _eliminando ? null : _eliminarActual,
            ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _urls.length,
        onPageChanged: (i) => setState(() => _indice = i),
        itemBuilder: (context, i) => Center(
          child: InteractiveViewer(
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: _urls[i],
              fit: BoxFit.contain,
              // Sin spinner animado (indeterminado): un indicador así nunca
              // deja "asentarse" un pumpAndSettle en los tests, y aquí
              // suele resolverse en el acto gracias al caché en disco.
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => const Icon(
                Icons.broken_image_outlined,
                size: 40,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
