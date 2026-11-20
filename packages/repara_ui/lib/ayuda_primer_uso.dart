// lib/ayuda_primer_uso.dart
//
// Aviso explicativo de una acción, mostrado solo la primera vez que se
// pulsa en este dispositivo (CEO, noviembre 2026: "quiero que un usuario
// que se descarga esta app sepa lo que tiene que hacer aunque no la haya
// usado nunca", sin depender de aprender a base de prueba y error). Cada
// [clave] se recuerda vía PrimerUsoService -- la segunda vez que se llame
// con la misma clave, no hace nada (ni abre el diálogo ni introduce ningún
// retraso perceptible).
import 'package:flutter/material.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/primer_uso_service.dart';

/// Se llama justo antes de ejecutar la acción real (navegar a la pantalla,
/// abrir el formulario...) -- si es la primera vez, espera a que el usuario
/// pulse "Entendido" antes de devolver el control a quien llama.
Future<void> mostrarAyudaPrimerUso(
  BuildContext context, {
  required String clave,
  required IconData icon,
  required String titulo,
  required String mensaje,
}) async {
  if (await PrimerUsoService.yaVisto(clave) || !context.mounted) return;
  await PrimerUsoService.marcarVisto(clave);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ReparaRadius.md),
      ),
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: ctx.colors.brandTint,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: ctx.colors.brand, size: 28),
      ),
      title: Text(titulo, textAlign: TextAlign.center),
      content: Text(
        mensaje,
        textAlign: TextAlign.center,
        style: TextStyle(color: ctx.colors.inkMuted),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
