// lib/widgets/seccion_formulario.dart
//
// Tarjeta con título de sección para formularios largos (CEO, noviembre
// 2026: "la pantalla de añadir evento a mano y la de revisar un documento
// escaneado deberían ser prácticamente iguales") -- antes nuevo_elemento_
// screen.dart y nuevo_documento_flow.dart tenían cada uno su propia copia
// idéntica de este mismo contenedor (Card + título en brand + hijos);
// compartido aquí para que los tres formularios de "crear algo" de la app
// (elemento, evento a mano, documento escaneado) se vean exactamente igual.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class SeccionFormulario extends StatelessWidget {
  const SeccionFormulario({
    required this.titulo,
    required this.children,
    this.subtitulo,
    super.key,
  });

  final String titulo;
  final String? subtitulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.brand,
              ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: ReparaSpace.s1),
              Text(subtitulo!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: ReparaSpace.s3),
            ...children,
          ],
        ),
      ),
    );
  }
}
