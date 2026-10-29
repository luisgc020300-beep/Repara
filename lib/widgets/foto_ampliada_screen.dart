// lib/widgets/foto_ampliada_screen.dart
//
// Foto a pantalla completa, con zoom (pellizcar para ampliar) --
// InteractiveViewer basta, sin necesidad de ningún paquete nuevo. Movido
// aquí desde elemento_detail_screen.dart (era privado de esa pantalla)
// para que registro_detail_screen.dart pueda reutilizarlo tal cual en la
// foto de un evento, en vez de duplicar la pantalla.
import 'package:flutter/material.dart';

class FotoAmpliadaScreen extends StatelessWidget {
  const FotoAmpliadaScreen({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
