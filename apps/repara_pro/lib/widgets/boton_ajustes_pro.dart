// apps/repara_pro/lib/widgets/boton_ajustes_pro.dart
//
// Versión Pro de lib/widgets/boton_ajustes.dart (monolito) -- sin el
// selector Hogar/Pro ni el parámetro `casa`, exclusivos de Hogar. Abre
// AjustesProScreen en vez del SettingsScreen compartido del monolito.
import 'package:flutter/material.dart';

import '../screens/ajustes_pro_screen.dart';

class BotonAjustesPro extends StatelessWidget {
  const BotonAjustesPro({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ajustes',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AjustesProScreen()),
      ),
    );
  }
}
