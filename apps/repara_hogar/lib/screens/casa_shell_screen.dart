// lib/screens/casa_shell_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../services/casa_service.dart';
import '../services/fcm_service.dart';
import 'contactos_tab.dart';
import 'casa_tab.dart';
import 'home_tab.dart';

class CasaShellScreen extends StatefulWidget {
  const CasaShellScreen({required this.casaId, super.key});

  final String casaId;

  @override
  State<CasaShellScreen> createState() => _CasaShellScreenState();
}

class _CasaShellScreenState extends State<CasaShellScreen> {
  int _index = 0;
  // Controla el PageView del cuerpo -- permite deslizar entre pestañas con
  // el dedo, no solo tocando la barra de abajo (mismo patrón que Convive).
  final _pageController = PageController();
  // "En curso"/garantías/revisiones de Inicio usan Future.wait (lectura
  // puntual), no Stream -- un registro vive en la subcolección de su
  // elemento, cambiarlo (p.ej. terminar un trabajo al cobrarlo del todo)
  // nunca dispara el stream de elementos que ya escucha Inicio. Sin esto,
  // _KeepAlivePage mantiene HomeTab montado al cambiar de pestaña (a
  // propósito, para no perder la posición de scroll) y ese Future.wait no
  // se repetía nunca más -- el usuario tenía que cerrar y reabrir la app
  // entera para verlo actualizado (CEO, octubre 2026). Incrementar esto
  // cada vez que se vuelve a Inicio hace que _ResumenCasa relance esa
  // lectura sin necesidad de un stream combinado de todas las
  // subcolecciones de registros de la casa.
  final _homeRefreshTick = ValueNotifier<int>(0);

  @override
  void dispose() {
    _pageController.dispose();
    _homeRefreshTick.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Aquí y no en main.dart (auditoría de producto, octubre 2026): el
    // usuario ya ha nombrado/unido su casa y está viendo la app de verdad --
    // mejor momento para pedir el permiso de notificaciones que nada más
    // iniciar sesión, antes de que haya visto nada.
    unawaited(FcmService.inicializar());
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    if (i == 0) _homeRefreshTick.value++;
  }

  void _cambiarPestana(int i) {
    // Salto directo, sin animación -- deslizar con el dedo ya tiene su
    // propia animación nativa del PageView; tocar una pestaña lejana no
    // debería sobrevolar visualmente las de en medio.
    _pageController.jumpToPage(i);
  }

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
          _KeepAlivePage(
            child: HomeTab(casa: casa, refreshTick: _homeRefreshTick),
          ),
          _KeepAlivePage(child: CasaTab(casa: casa)),
          _KeepAlivePage(child: ContactosTab(casa: casa)),
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
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.house_outlined), activeIcon: Icon(Icons.house), label: 'Casa'),
              BottomNavigationBarItem(icon: Icon(Icons.contact_phone_outlined), activeIcon: Icon(Icons.contact_phone), label: 'Contactos'),
            ],
          ),
        );
      },
    );
  }
}

// Sin esto, el PageView desmonta cada pestaña en cuanto sale de la pantalla
// al deslizar (a diferencia del IndexedStack de antes, que las mantenía
// todas montadas) -- reconstruiría HomeTab/CasaTab/etc. desde cero cada vez
// que vuelves a ella, perdiendo la posición de scroll y re-suscribiendo sus
// streams sin necesidad.
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
