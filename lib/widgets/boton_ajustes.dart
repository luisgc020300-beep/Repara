// lib/widgets/boton_ajustes.dart
import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';

class BotonAjustes extends StatelessWidget {
  const BotonAjustes({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ajustes',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
    );
  }
}
