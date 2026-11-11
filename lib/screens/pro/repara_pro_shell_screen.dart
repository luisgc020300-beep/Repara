// lib/screens/pro/repara_pro_shell_screen.dart
//
// Shell de REPARA Pro (sección 40 del spec de producto). Se abre como una
// pantalla normal desde el Perfil de REPARA Hogar -- misma cuenta, misma
// sesión, mismo proyecto Firebase; no es una app aparte ni cambia la
// navegación de Hogar.
//
// 5 pestañas (ampliación funcional, Fase 2 y 4 -- CEO, noviembre 2026):
// Inicio, Trabajos, Clientes, Agenda, Control económico -- el objetivo de
// navegación final del encargo. "Presupuestos" se retiró como pestaña
// propia en la Fase 2 (su contenido, agrupado por estado, se mudó dentro
// de Control económico) para no crecer a 6 pestañas al añadir Agenda aquí.
import 'package:flutter/material.dart';

import 'agenda_pro_tab.dart';
import 'clientes_pro_tab.dart';
import 'control_economico_pro_tab.dart';
import 'inicio_pro_tab.dart';
import 'trabajos_pro_tab.dart';

class ReparaProShellScreen extends StatefulWidget {
  const ReparaProShellScreen({this.initialIndex = 0, super.key});

  /// Pestaña con la que arranca (0 = Inicio) -- usado al llegar desde una
  /// notificación que debe abrir directamente Trabajos/Clientes (ver
  /// notificacion_router.dart).
  final int initialIndex;

  @override
  State<ReparaProShellScreen> createState() => _ReparaProShellScreenState();
}

class _ReparaProShellScreenState extends State<ReparaProShellScreen> {
  late int _index = widget.initialIndex;
  // Mismo patrón que CasaShellScreen (Hogar) y Convive: deslizar con el
  // dedo entre pestañas, no solo tocar la barra de abajo.
  late final _pageController = PageController(initialPage: widget.initialIndex);

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
      _KeepAlivePage(child: ClientesProTab()),
      _KeepAlivePage(child: AgendaProTab()),
      _KeepAlivePage(child: ControlEconomicoProTab()),
    ];
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: _cambiarPestana,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build),
            label: 'Trabajos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            activeIcon: Icon(Icons.pie_chart),
            label: 'Económico',
          ),
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

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
