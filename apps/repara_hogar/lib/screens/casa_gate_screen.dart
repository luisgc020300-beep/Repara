// lib/screens/casa_gate_screen.dart
//
// Decide qué pantalla mostrar tras el login: onboarding si el usuario no
// tiene ninguna casa activa todavía, o el shell principal si ya la tiene.
// Mismo rol que HouseholdGateScreen en Convive.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:repara_core/design_tokens.dart';

import '../core/casa_context.dart';
import '../models/casa.dart';
import '../services/casa_service.dart';
import '../services/fcm_service.dart';
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
        // veía en el login (mismo asset, mismo BoxFit.cover, mismo velo
        // oscuro), así que el cambio desde LoginScreen (instantáneo,
        // StreamBuilder de sesión en main.dart, sin ninguna animación) no se
        // nota. Se reproduce cada vez que se abre la app con sesión ya
        // iniciada, no solo la primera vez que se rellena el formulario
        // (decisión del CEO: más simple y fiable que inventar una señal de
        // "vengo de loguearme ahora mismo" que sobreviva a reinicios).
        return _TransicionFotoCabecera(casaId: casaId);
      },
    );
  }
}

/// Encoge la foto de fondo del login hasta el tamaño/forma exactos de
/// `_CabeceraNavy` (home_tab.dart) -- transición hecha a medida, sin `Hero`
/// ni tocar el `StreamBuilder` de sesión de `main.dart`. Usa las mismas
/// funciones de geometría que `_CabeceraNavy` -- nunca números repetidos a
/// mano -- para que el último fotograma coincida exactamente con la
/// cabecera real.
///
/// Tres fases:
///  1. Espera: foto a pantalla completa con el velo oscuro del login,
///     mientras se carga la casa (sin temporizadores inventados).
///  2. Encoger: el shell real ya está montado DEBAJO; la foto sube y se
///     encoge hasta la cabecera, destapando el listado y la barra inferior,
///     y el velo del login se funde en el velo azul de la cabecera.
///  3. Fundido: con la foto ya en su sitio (idéntica al fondo de la
///     cabecera real), la capa se desvanece y aparecen por debajo el
///     saludo, el nombre, la casa y los botones -- sin ningún salto.
/// Al terminar se quita la capa; el shell sigue en la misma posición del
/// árbol, así que no se reconstruye ni pierde estado.
class _TransicionFotoCabecera extends StatefulWidget {
  const _TransicionFotoCabecera({required this.casaId});

  final String casaId;

  @override
  State<_TransicionFotoCabecera> createState() =>
      _TransicionFotoCabeceraState();
}

class _TransicionFotoCabeceraState extends State<_TransicionFotoCabecera>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _encoger;
  late final Animation<double> _fundido;
  Casa? _casa;
  bool _terminada = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    // ~580 ms encogiendo, ~220 ms de fundido final.
    _encoger = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.72, curve: Curves.easeInOutCubic),
    );
    _fundido = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1.0, curve: Curves.easeOut),
    );
    _cargarCasaYArrancar();
  }

  // La propia carga de datos hace de "espera" antes de empezar a encoger --
  // en redes lentas la foto simplemente se queda estática un poco más.
  Future<void> _cargarCasaYArrancar() async {
    final casa = await CasaService.streamCasa(widget.casaId).first;
    if (!mounted) return;
    setState(() => _casa = casa);
    // Un fotograma para que el shell recién montado debajo se pinte antes
    // de empezar a destaparlo.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _controller.forward();
    if (!mounted) return;
    setState(() => _terminada = true);
    // Permiso de notificaciones (el shell se montó con
    // pedirNotificacionesAlMontar: false): un respiro tras la animación
    // para que el usuario vea Inicio antes de que salga el aviso del
    // sistema, nunca encima de la foto en movimiento. Solo se ve la
    // primera vez; en las siguientes aperturas el sistema ya no pregunta y
    // esto solo refresca el token.
    await Future<void>.delayed(_esperaAvisoNotificaciones);
    if (!mounted) return;
    unawaited(FcmService.inicializar());
  }

  static const _esperaAvisoNotificaciones = Duration(milliseconds: 1200);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casa = _casa;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Siempre el primer hijo una vez montado -- al quitar la capa de
        // encima no cambia de posición y conserva todo su estado.
        if (casa != null)
          CasaShellScreen(
            casaId: widget.casaId,
            pedirNotificacionesAlMontar: false,
          ),
        if (!_terminada)
          Positioned.fill(
            // Mientras dura la transición no se puede tocar nada de debajo.
            child: AbsorbPointer(child: _capaFoto(context, casa)),
          ),
      ],
    );
  }

  Widget _capaFoto(BuildContext context, Casa? casa) {
    final mq = MediaQuery.of(context);
    final altoPantalla = mq.size.height;
    final conNombre =
        casa != null && (nombreUsuarioActualEnCasa(casa)?.isNotEmpty ?? false);
    final alturaDestino = casa == null
        ? altoPantalla
        : alturaCabeceraExpandida(
            topPadding: mq.padding.top,
            textScaler: mq.textScaler,
            conNombre: conNombre,
          );

    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final ink = context.colors.ink;
    final brandStrong = context.colors.brandStrong;
    final brand = esOscuro
        ? Color.lerp(context.colors.brandStrong, context.colors.brand, 0.3)!
        : context.colors.brand;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final e = casa == null ? 0.0 : _encoger.value;
        final f = casa == null ? 0.0 : _fundido.value;
        final alto = altoPantalla - (altoPantalla - alturaDestino) * e;
        final radio = Radius.circular(28 * e);

        return Opacity(
          opacity: 1 - f,
          child: Align(
            alignment: Alignment.topCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: radio),
              child: SizedBox(
                width: double.infinity,
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
                    // Velo del login (mismos valores que
                    // LoginScreen._buildConFondo) -- se va apagando...
                    Opacity(
                      opacity: 1 - e,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              ink.withValues(alpha: esOscuro ? 0.55 : 0.35),
                              ink.withValues(alpha: 0.9),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // ...mientras aparece el velo azul de _CabeceraNavy
                    // expandida (t = 0 allí: 0.35 / 0.75).
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            brandStrong.withValues(alpha: 0.35 * e),
                            brand.withValues(alpha: 0.75 * e),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}