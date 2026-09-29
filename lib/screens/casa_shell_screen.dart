// lib/screens/casa_shell_screen.dart
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../services/casa_service.dart';
import 'historial_tab.dart';
import 'casa_tab.dart';
import 'home_tab.dart';
import 'perfil_tab.dart';
import 'trabajos_tab.dart';

class CasaShellScreen extends StatefulWidget {
  const CasaShellScreen({required this.casaId, super.key});

  final String casaId;

  @override
  State<CasaShellScreen> createState() => _CasaShellScreenState();
}

class _CasaShellScreenState extends State<CasaShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Casa>(
      stream: CasaService.streamCasa(widget.casaId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final casa = snapshot.data!;
        final tabs = [
          HomeTab(casa: casa),
          HistorialTab(casa: casa),
          CasaTab(casa: casa),
          TrabajosTab(casa: casa),
          PerfilTab(casa: casa),
        ];
        return Scaffold(
          body: IndexedStack(index: _index, children: tabs),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
              BottomNavigationBarItem(icon: Icon(Icons.house_outlined), activeIcon: Icon(Icons.house), label: 'Casa'),
              BottomNavigationBarItem(icon: Icon(Icons.build_outlined), activeIcon: Icon(Icons.build), label: 'Trabajos'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}
