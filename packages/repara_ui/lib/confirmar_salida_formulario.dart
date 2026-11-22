// packages/repara_ui/lib/confirmar_salida_formulario.dart
//
// Evita perder los datos de un formulario a medio rellenar cuando se
// navega hacia atrás por accidente -- botón atrás, gesto del sistema o
// swipe de iOS (CEO, noviembre 2026: "si deslizas para ir a la pantalla
// anterior en mitad de crear un evento/elemento/habitación, pierdes el
// proceso sin avisar"). Deliberadamente solo intercepta un intento real de
// "pop" de la ruta -- minimizar la app (botón de inicio, cambiar de app,
// bloquear la pantalla) nunca dispara esto, así que no estorba a quien
// entra y sale de la app para consultar un dato antes de rellenarlo.
import 'package:flutter/material.dart';

import 'app_dialog.dart';

/// Envuelve [child] (normalmente el `Scaffold` de un formulario) para
/// preguntar "¿Salir sin guardar?" cuando [hayCambiosSinGuardar] es true en
/// el momento exacto de intentar salir -- se evalúa dentro del propio
/// intento de pop (nunca en build), así que siempre ve el valor actual de
/// los campos aunque no haya habido ningún rebuild desde que se tecleó.
class ConfirmarSalidaFormulario extends StatelessWidget {
  const ConfirmarSalidaFormulario({
    required this.hayCambiosSinGuardar,
    required this.child,
    super.key,
  });

  final bool Function() hayCambiosSinGuardar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!hayCambiosSinGuardar()) {
          if (context.mounted) Navigator.of(context).pop();
          return;
        }
        final salir = await AppDialog.confirm(
          context,
          title: '¿Salir sin guardar?',
          message: 'Los datos que has introducido no se guardarán.',
          cancelLabel: 'Seguir editando',
          confirmLabel: 'Salir',
          destructive: true,
        );
        if (salir && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}
