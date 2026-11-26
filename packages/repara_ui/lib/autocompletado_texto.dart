// lib/autocompletado_texto.dart
//
// Generaliza a texto libre el mismo patrón visual que ya usaba el campo
// "Profesional" de nuevo_elemento_screen.dart (RawAutocomplete sobre
// Contactos, con el mismo desplegable Material elevado) -- aquí sobre
// sugerencias de texto plano (marca, modelo, proveedor de un documento...)
// en vez de objetos [Contacto], para no construir un segundo mecanismo de
// autocompletado en paralelo (CEO, noviembre 2026, Fase 1 de reutilización
// de datos).
//
// Quien llama decide de dónde vienen las sugerencias y en qué orden (ya
// sin duplicados, ya de más reciente a más antigua -- ver
// sugerencias_recientes.dart en repara_core); este widget solo filtra por
// coincidencia de texto mientras se escribe y pinta el desplegable. Nunca
// modifica lo que el usuario está tecleando -- seleccionar una sugerencia
// es la única forma de que el texto cambie.
import 'package:flutter/material.dart';
import 'package:repara_core/sugerencias_recientes.dart';

class AutocompletadoTexto extends StatelessWidget {
  const AutocompletadoTexto({
    required this.controller,
    required this.focusNode,
    required this.labelText,
    required this.sugerencias,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelText;

  /// Ya en el orden en que deben mostrarse (más reciente primero) y sin
  /// duplicados -- ver [valoresRecientesSinDuplicados].
  final List<String> sugerencias;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (value) => filtrarSugerencias(sugerencias, value.text),
      onSelected: (s) => controller.text = s,
      fieldViewBuilder: (context, fieldController, fieldFocusNode, _) =>
          TextField(
            controller: fieldController,
            focusNode: fieldFocusNode,
            decoration: InputDecoration(labelText: labelText),
          ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, minWidth: 220),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, i) {
                final s = options.elementAt(i);
                return ListTile(
                  dense: true,
                  title: Text(s),
                  onTap: () => onSelected(s),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
