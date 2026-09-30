// lib/screens/pro/repara_pro_shell_screen.dart
//
// Shell de REPARA Pro (sección 40 del spec de producto). Se abre como una
// pantalla normal desde el Perfil de REPARA Hogar -- misma cuenta, misma
// sesión, mismo proyecto Firebase; no es una app aparte ni cambia la
// navegación de Hogar.
import 'package:flutter/material.dart';

import 'clientes_pro_tab.dart';
import 'inicio_pro_tab.dart';
import 'perfil_pro_tab.dart';
import 'presupuestos_pro_tab.dart';
import 'trabajos_pro_tab.dart';

class ReparaProShellScreen extends StatefulWidget {
  const ReparaProShellScreen({super.key});

  @override
  State<ReparaProShellScreen> createState() => _ReparaProShellScreenState();
}

class _ReparaProShellScreenState extends State<ReparaProShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      InicioProTab(),
      TrabajosProTab(),
      ClientesProTab(),
      PresupuestosProTab(),
      PerfilProTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Inicio Pro'),
          BottomNavigationBarItem(icon: Icon(Icons.build_outlined), activeIcon: Icon(Icons.build), label: 'Trabajos'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.request_quote_outlined), activeIcon: Icon(Icons.request_quote), label: 'Presupuestos'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
