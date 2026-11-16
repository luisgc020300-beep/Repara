// lib/screens/casa_gate_screen.dart
//
// Decide qué pantalla mostrar tras el login: onboarding si el usuario no
// tiene ninguna casa activa todavía, o el shell principal si ya la tiene.
// Mismo rol que HouseholdGateScreen en Convive.
import 'package:flutter/material.dart';
import 'package:repara_core/design_tokens.dart';

import '../core/casa_context.dart';
import '../models/casa.dart';
import '../services/casa_service.dart';
import 'casa_shell_screen.dart';
import 'home_tab.dart'
    show
        alturaCabeceraExpandida,
        fondoCabeceraInicio,
        nombreUsuarioActualEnCasa;
import 'onboarding_casa_screen.dart';

class CasaGateScreen extends StatelessWidget {
  const CasaGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: CasaService.streamActiveCasaId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final casaId = snapshot.data;
        if (casaId == null) return const OnboardingCasaScreen();
        CasaContext.instance.setCasaActiva(casaId);
        // "La foto del login vuela hasta la cabecera" (noviembre 2026): en
        // vez de ir directo al shell, se ve primero esta transición -- su
        // primer fotograma es la MISMA foto a pantalla completa que ya se
        // veía en el login (mismo asset, mismo BoxFit.cover), así que el
        // cambio desde LoginScreen (instantáneo, StreamBuilder de sesión en
        // main.dart, sin ninguna animación) no se nota. Se reproduce cada
        // vez que se abre la app con sesión ya iniciada, no solo la primera
        // vez que se rellena el formulario (decisión del CEO: más simple y
        // fiable que inventar una señal de "vengo de loguearme ahora mismo"
        // que sobreviva a reinicios de la app).
        return _TransicionFotoCabecera(casaId: casaId);
      },
    );
  }
}

/// Encoge la foto de fondo del login hasta el tamaño/forma exactos de
/// `_CabeceraNavy` (home_tab.dart) -- transición hecha a medida, sin `Hero`
/// ni tocar el `StreamBuilder` de sesión de `main.dart` (decisión del CEO,
/// noviembre 2026: ese mecanismo lo usa todo el mundo al abrir la app, no
/// se toca). Usa las mismas funciones de geometría que `_CabeceraNavy` --
/// nunca números repetidos a mano -- para que el último fotograma de esta
/// animación y el primero de la cabecera real coincidan exactamente y el
/// cambio a `CasaShellScreen` tampoco se note.
class _TransicionFotoCabecera extends StatefulWidget {
  const _TransicionFotoCabecera({required this.casaId});

  final String casaId;

  @override
  State<_TransicionFotoCabecera> createState() =>
      _TransicionFotoCabecheraState();
}

class _TransicionFotoCabecheraState extends State<_TransicionFotoCabecera>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  Casa? _casa;
  bool _lista = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _cargarCasaYArrancar();
  }

  // La propia carga de datos hace de "espera" antes de empezar a encoger --
  // nunca un temporizador inventado, así que en redes lentas la foto
  // simplemente se queda estática un poco más, nunca se nota como una
  // espera de más.
  Future<void> _cargarCasaYArrancar() async {
    final casa = await CasaService.streamCasa(widget.casaId).first;
    if (!mounted) return;
    setState(() => _casa = casa);
    await _controller.forward();
    if (!mounted) return;
    setState(() => _lista = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lista) return CasaShellScreen(casaId: widget.casaId);

    final casa = _casa;
    final mq = MediaQuery.of(context);
    final anchoPantalla = mq.size.width;
    final altoPantalla = mq.size.height;
    final topPadding = mq.padding.top;
    final conNombre =
        casa != null && (nombreUsuarioActualEnCasa(casa)?.isNotEmpty ?? false);
    final alturaDestino = casa == null
        ? altoPantalla
        : alturaCabeceraExpandida(
            topPadding: topPadding,
            textScaler: mq.textScaler,
            conNombre: conNombre,
          );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final t = casa == null ? 0.0 : _t.value;
          final alto = altoPantalla - (altoPantalla - alturaDestino) * t;
          final ancho = anchoPantalla; // la cabecera ya ocupa todo el ancho
          final radio = Radius.circular(28 * t);
          // El velo pasa de invisible (foto a pantalla completa, igual que
          // el login) a translúcido -- mismo valor que _CabeceraNavy en
          // t=0 (expandida) para que el aterrizaje sea idéntico.
          final alphaVeloArriba = 0.35 * t;
          final alphaVeloAbajo = 0.75 * t;
          final brandStrong = context.colors.brandStrong;
          final brand = Theme.of(context).brightness == Brightness.dark
              ? Color.lerp(
                  context.colors.brandStrong,
                  context.colors.brand,
                  0.3,
                )!
              : context.colors.brand;

          return Align(
            alignment: Alignment.topCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: radio),
              child: SizedBox(
                width: ancho,
                height: alto,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      fondoCabeceraInicio,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [brandStrong, brand],
                              ),
                            ),
                          ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            brandStrong.withValues(alpha: alphaVeloArriba),
                            brand.withValues(alpha: alphaVeloAbajo),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
