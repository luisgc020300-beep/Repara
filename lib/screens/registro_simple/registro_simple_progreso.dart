// lib/screens/registro_simple/registro_simple_progreso.dart
//
// Línea de progreso de 3 pasos (CEO, octubre 2026) -- SOLO para un
// registro simple (sin profesional). Los pasos se derivan siempre de
// Registro.estado real, nunca se marca nada por su cuenta: un registro
// simple solo vive en pendientePago o terminado/archivado (ver
// estadoInicialRegistroSimple/estadoTrasCambioDePago en registro.dart/
// functions/index.js) -- "trabajo realizado" está completo siempre (un
// evento simple se anota cuando el trabajo ya ha pasado), "cobro
// pendiente" es el paso actual mientras el registro siga en
// pendientePago, y "terminado" solo se alcanza cuando el propio estado
// real ya es terminado/archivado (es decir, cuando el pago real lo cubre
// del todo, ver estadoTrasCambioDePago).
import 'package:flutter/material.dart';

import '../../models/registro.dart';
import '../../theme/design_tokens.dart';

enum _PasoEstado { completado, actual, pendiente }

class RegistroSimpleProgreso extends StatelessWidget {
  const RegistroSimpleProgreso({required this.registro, super.key});

  final Registro registro;

  @override
  Widget build(BuildContext context) {
    final cobrado =
        registro.estado == EstadoRegistro.terminado ||
        registro.estado == EstadoRegistro.archivado;
    final pasos = <(String, _PasoEstado)>[
      ('Trabajo realizado', _PasoEstado.completado),
      (
        'Cobro pendiente',
        cobrado ? _PasoEstado.completado : _PasoEstado.actual,
      ),
      ('Terminado', cobrado ? _PasoEstado.actual : _PasoEstado.pendiente),
    ];
    // Color de la línea entre el paso i y el i+1: verde si el paso i ya
    // está completado, gris si no. Se reparte en dos mitades simétricas
    // (ver _Paso) para que el círculo quede centrado sobre su texto en
    // vez de empujado hacia la izquierda por una línea que solo salía a
    // su derecha (CEO, octubre 2026).
    Color colorConexion(int i) => pasos[i].$2 == _PasoEstado.completado
        ? context.colors.success
        : context.colors.surfaceSunken;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          for (var i = 0; i < pasos.length; i++) ...[
            Expanded(
              child: _Paso(
                titulo: pasos[i].$1,
                estado: pasos[i].$2,
                colorLineaIzquierda: i == 0 ? null : colorConexion(i - 1),
                colorLineaDerecha: i == pasos.length - 1
                    ? null
                    : colorConexion(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.titulo,
    required this.estado,
    required this.colorLineaIzquierda,
    required this.colorLineaDerecha,
  });

  final String titulo;
  final _PasoEstado estado;
  // null = sin línea (extremo de la secuencia), pero sigue ocupando el
  // mismo espacio que la de enfrente para que el círculo quede centrado.
  final Color? colorLineaIzquierda;
  final Color? colorLineaDerecha;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (estado) {
      _PasoEstado.completado => context.colors.success,
      _PasoEstado.actual => context.colors.warningText,
      _PasoEstado.pendiente => context.colors.inkFaint,
    };
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 2,
                color: colorLineaIzquierda ?? Colors.transparent,
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: estado == _PasoEstado.pendiente
                    ? Colors.transparent
                    : color.withValues(
                        alpha: estado == _PasoEstado.actual ? 0.15 : 1,
                      ),
                border: Border.all(color: color, width: 2),
              ),
              child: estado == _PasoEstado.completado
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            Expanded(
              child: Container(
                height: 2,
                color: colorLineaDerecha ?? Colors.transparent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: estado == _PasoEstado.pendiente
                  ? context.colors.inkFaint
                  : context.colors.ink,
              fontWeight: estado == _PasoEstado.actual
                  ? FontWeight.w700
                  : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
