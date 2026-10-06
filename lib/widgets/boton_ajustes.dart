// lib/widgets/boton_ajustes.dart
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../screens/settings_screen.dart';

class BotonAjustes extends StatelessWidget {
  const BotonAjustes({this.casa, this.modoPro = false, super.key});

  /// Se pasa desde las pestañas de Hogar para que Ajustes muestre la
  /// sección "Tu casa". Se omite desde Pro.
  final Casa? casa;

  /// true desde las pestañas de Repara Pro -- Ajustes muestra "Tu perfil
  /// profesional" y "Volver a modo propietario" en vez de la sección de casa.
  final bool modoPro;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ajustes',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SettingsScreen(casa: casa, modoPro: modoPro)),
      ),
    );
  }
}
