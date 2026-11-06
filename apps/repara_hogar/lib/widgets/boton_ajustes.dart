// lib/widgets/boton_ajustes.dart
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../screens/ajustes_hogar_screen.dart';

class BotonAjustes extends StatelessWidget {
  const BotonAjustes({this.casa, this.modoPro = false, super.key});

  /// Se pasa para que Ajustes muestre la sección "Tu casa".
  final Casa? casa;

  /// Sin uso en esta app (solo existía para el selector Hogar/Pro del
  /// monolito) -- se mantiene el parámetro para no tocar los call sites.
  final bool modoPro;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ajustes',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AjustesHogarScreen(casa: casa)),
      ),
    );
  }
}
