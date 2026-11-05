// lib/widgets/selector_profesional_field.dart
//
// Selector múltiple de profesionales para un evento (CEO, noviembre 2026:
// "un trabajo lo pueden estar haciendo más de un profesional, quiero poder
// seleccionar más de uno de mis contactos"). Muestra los contactos guardados
// de la casa con casillas, más un pequeño formulario para añadir a mano a
// alguien que no esté en la libreta.
//
// [SelectorProfesionalesField] es el campo de formulario que lo abre (lo usan
// nuevo_registro_screen.dart y editar_registro_sheet.dart). Los contactos se
// cargan al pulsarlo, una sola vez, no con un stream abierto todo el rato.
import 'package:flutter/material.dart';
import 'package:repara_core/registro.dart';

import '../models/contacto.dart';
import '../services/contacto_service.dart';
import '../theme/design_tokens.dart';

/// Nombres de todos los profesionales unidos con coma, o null si no hay
/// ninguno -- es lo que se guarda en el campo heredado
/// [Registro.profesionalNombre] para que listados y notificaciones sigan
/// mostrando algo coherente.
String? nombresProfesionales(List<ProfesionalRegistro> lista) =>
    lista.isEmpty ? null : lista.map((p) => p.nombre).join(', ');

/// Teléfono del primer profesional (el heredado
/// [Registro.profesionalContacto] solo admite uno), o null si no tiene.
String? telefonoPrincipalProfesionales(List<ProfesionalRegistro> lista) {
  if (lista.isEmpty) return null;
  final t = lista.first.telefono;
  return (t == null || t.isEmpty) ? null : t;
}

/// Devuelve la lista elegida, o null si se cierra sin pulsar "Listo".
Future<List<ProfesionalRegistro>?> elegirProfesionales(
  BuildContext context, {
  required List<Contacto> contactos,
  required List<ProfesionalRegistro> seleccionados,
}) {
  return showModalBottomSheet<List<ProfesionalRegistro>>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _SelectorSheet(contactos: contactos, seleccionados: seleccionados),
  );
}

/// Campo de formulario: muestra los profesionales elegidos y, al pulsarlo,
/// abre el selector múltiple.
class SelectorProfesionalesField extends StatefulWidget {
  const SelectorProfesionalesField({
    required this.casaId,
    required this.seleccionados,
    required this.onChanged,
    super.key,
  });

  final String casaId;
  final List<ProfesionalRegistro> seleccionados;
  final ValueChanged<List<ProfesionalRegistro>> onChanged;

  @override
  State<SelectorProfesionalesField> createState() =>
      _SelectorProfesionalesFieldState();
}

class _SelectorProfesionalesFieldState
    extends State<SelectorProfesionalesField> {
  bool _cargando = false;

  Future<void> _abrir() async {
    setState(() => _cargando = true);
    var contactos = const <Contacto>[];
    try {
      contactos = await ContactoService.streamContactos(widget.casaId).first;
    } catch (e) {
      // Sin acceso a la libreta -- se sigue pudiendo añadir a mano.
      debugPrint(
        'SelectorProfesionalesField: no se pudo leer la libreta de contactos: $e',
      );
    }
    if (!mounted) return;
    setState(() => _cargando = false);
    final elegidos = await elegirProfesionales(
      context,
      contactos: contactos,
      seleccionados: widget.seleccionados,
    );
    if (elegidos != null) widget.onChanged(elegidos);
  }

  @override
  Widget build(BuildContext context) {
    final texto = nombresProfesionales(widget.seleccionados);
    return InkWell(
      onTap: _cargando ? null : _abrir,
      borderRadius: BorderRadius.circular(ReparaRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Profesionales (opcional)',
          suffixIcon: _cargando
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          texto ?? 'Elegir de tus contactos',
          style: TextStyle(
            color: texto == null ? context.colors.inkMuted : null,
          ),
        ),
      ),
    );
  }
}

class _SelectorSheet extends StatefulWidget {
  const _SelectorSheet({required this.contactos, required this.seleccionados});

  final List<Contacto> contactos;
  final List<ProfesionalRegistro> seleccionados;

  @override
  State<_SelectorSheet> createState() => _SelectorSheetState();
}

class _SelectorSheetState extends State<_SelectorSheet> {
  late final List<ProfesionalRegistro> _sel = List.of(widget.seleccionados);
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  void _alternar(Contacto c) {
    setState(() {
      final i = _sel.indexWhere((p) => p.contactoId == c.id);
      if (i >= 0) {
        _sel.removeAt(i);
      } else {
        _sel.add(
          ProfesionalRegistro(
            nombre: c.nombre,
            telefono: c.telefono,
            contactoId: c.id,
          ),
        );
      }
    });
  }

  void _anadirAMano() {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() {
      _sel.add(
        ProfesionalRegistro(
          nombre: nombre,
          telefono: _telefonoCtrl.text.trim(),
        ),
      );
      _nombreCtrl.clear();
      _telefonoCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final manuales = _sel.where((p) => p.contactoId == null).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Profesionales de este evento',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in widget.contactos)
                      CheckboxListTile(
                        value: _sel.any((p) => p.contactoId == c.id),
                        onChanged: (_) => _alternar(c),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(c.nombre),
                        subtitle: Text(
                          [c.especialidad, c.telefono]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                        ),
                      ),
                    for (final p in manuales)
                      ListTile(
                        leading: Icon(
                          Icons.person_outline,
                          color: context.colors.brand,
                        ),
                        title: Text(p.nombre),
                        subtitle: (p.telefono ?? '').isEmpty
                            ? null
                            : Text(p.telefono!),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _sel.remove(p)),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Otro que no está en tus contactos',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: context.colors.inkMuted),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nombreCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _telefonoCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono (opcional)',
                              isDense: true,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _anadirAMano,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Añadir'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _sel),
                    child: const Text('Listo'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
