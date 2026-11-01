// lib/screens/compartir_informacion_screen.dart
//
// Pantalla dedicada para compartir/exportar (rediseño visual, noviembre
// 2026) -- antes "Compartir resumen"/"Descargar PDF"/"Compartir código de
// invitación" vivían como botones de primer nivel sueltos dentro de Detalle
// de elemento y Detalle de trabajo. No reimplementa ninguna acción: solo
// aloja el [body] que cada pantalla ya construye con su propia lógica
// (_AccionesElemento, RegistroSimpleAcciones, el bloque de código de
// invitación...), detrás de un único punto de entrada "Compartir".
import 'package:flutter/material.dart';

class CompartirInformacionScreen extends StatelessWidget {
  const CompartirInformacionScreen({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: body,
        ),
      ),
    );
  }
}
