// lib/screens/pro/repara_pro_shell_screen.dart
//
// Shell de REPARA Pro (sección 40 del spec de producto). Se abre como una
// pantalla normal desde el Perfil de REPARA Hogar -- misma cuenta, misma
// sesión, mismo proyecto Firebase; no es una app aparte ni cambia la
// navegación de Hogar.
import 'package:flutter/material.dart';

import 'inicio_pro_tab.dart';
import 'presupuestos_pro_tab.dart';
import 'trabajos_pro_tab.dart';

class ReparaProShellScreen extends StatefulWidget {
  const ReparaProShellScreen({super.key});

  @override
  State<ReparaProShellScreen> createState() => _ReparaProShellScreenState();
}

class _ReparaProShellScreenState extends State<ReparaProShellScreen> {
  int _index = 0;
  // Mismo patrón que CasaShellScreen (Hogar) y Convive: deslizar con el
  // dedo entre pestañas, no solo tocar la barra de abajo.
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) => setState(() => _index = i);

  void _cambiarPestana(int i) => _pageController.jumpToPage(i);

  @override
  Widget build(BuildContext context) {
    const tabs = [
      _KeepAlivePage(child: InicioProTab()),
      _KeepAlivePage(child: TrabajosProTab()),
      _KeepAlivePage(child: PresupuestosProTab()),
    ];
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _cambiarPestana,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Inicio Pro'),
          BottomNavigationBarItem(icon: Icon(Icons.build_outlined), activeIcon: Icon(Icons.build), label: 'Trabajos'),
          BottomNavigationBarItem(icon: Icon(Icons.request_quote_outlined), activeIcon: Icon(Icons.request_quote), label: 'Presupuestos'),
        ],
      ),
    );
  }
}

// Sin esto, el PageView desmonta cada pestaña al deslizar y las reconstruye
// desde cero al volver -- ver la misma nota en casa_shell_screen.dart.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
