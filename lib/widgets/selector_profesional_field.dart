// lib/widgets/selector_profesional_field.dart
//
// Campo "Profesional" con autocompletado contra la libreta de Contactos de
// la casa (CEO, noviembre 2026: "deberían salir los contactos que tengo
// agregados en la app, con el número ya asociado para poder llamar o
// escribir por WhatsApp directamente desde el evento"). Mismo patrón
// RawAutocomplete<Contacto> que ya usaba nuevo_elemento_screen.dart, pero
// ahí el campo es puramente informativo (sobre el elemento, sin teléfono
// que rellenar); aquí, al elegir un contacto, además del nombre se rellena
// [telefonoCtrl] -- es lo que permite que registro_detail_screen.dart
// (_SeccionProfesionalSimple) muestre después "Llamar"/"WhatsApp" sin que
// el usuario tenga que teclear el número a mano. Sigue admitiendo texto
// libre (un profesional que no está en la libreta) -- nunca obliga a elegir
// de la lista.
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/contacto.dart';
import '../services/contacto_service.dart';

class ProfesionalAutocompleteField extends StatefulWidget {
  const ProfesionalAutocompleteField({
    required this.casaId,
    required this.nombreCtrl,
    this.telefonoCtrl,
    this.labelText = 'Profesional',
    super.key,
  });

  final String casaId;
  final TextEditingController nombreCtrl;

  /// Null cuando el formulario no tiene campo de teléfono propio (p.ej.
  /// nuevo_elemento_screen.dart, donde el profesional es un dato informativo
  /// del elemento, no de un evento con el que se pueda contactar).
  final TextEditingController? telefonoCtrl;

  final String labelText;

  @override
  State<ProfesionalAutocompleteField> createState() =>
      _ProfesionalAutocompleteFieldState();
}

class _ProfesionalAutocompleteFieldState
    extends State<ProfesionalAutocompleteField> {
  List<Contacto> _contactos = const [];
  StreamSubscription<List<Contacto>>? _contactosSub;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _contactosSub = ContactoService.streamContactos(widget.casaId).listen((c) {
      if (mounted) setState(() => _contactos = c);
    });
  }

  @override
  void dispose() {
    _contactosSub?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _elegir(Contacto c) {
    widget.nombreCtrl.text = c.nombre;
    // Solo pisa el teléfono si el contacto elegido tiene uno guardado --
    // nunca borra un teléfono que el usuario ya hubiera escrito a mano.
    if (widget.telefonoCtrl != null && c.telefono.isNotEmpty) {
      widget.telefonoCtrl!.text = c.telefono;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Contacto>(
      textEditingController: widget.nombreCtrl,
      focusNode: _focusNode,
      displayStringForOption: (c) => c.nombre,
      // Vacío (campo recién tocado) -> todos los contactos guardados, no
      // solo los que coinciden con lo tecleado.
      optionsBuilder: (value) => value.text.isEmpty
          ? _contactos
          : _contactos.where(
              (c) => c.nombre.toLowerCase().contains(value.text.toLowerCase()),
            ),
      onSelected: _elegir,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
          TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(labelText: widget.labelText),
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
                final c = options.elementAt(i);
                return ListTile(
                  dense: true,
                  title: Text(c.nombre),
                  subtitle: c.telefono.isNotEmpty ? Text(c.telefono) : null,
                  onTap: () => onSelected(c),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
