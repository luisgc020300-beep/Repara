// lib/screens/importar_contactos_screen.dart
//
// Importar contactos del teléfono a la libreta de Contactos de la casa (CEO,
// noviembre 2026) -- solo lectura del directorio del teléfono
// (FlutterContacts.requestPermission(readonly: true)), nunca escritura ahí.
// Un contacto del teléfono sin ningún número no sirve (Contacto.telefono es
// obligatorio en el modelo), así que se descarta directamente de la lista.
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/contacto.dart';
import '../services/contacto_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_error.dart';

Future<void> abrirImportarContactos(
  BuildContext context, {
  required String casaId,
}) async {
  final permitido = await FlutterContacts.requestPermission(readonly: true);
  if (!permitido) {
    if (context.mounted) {
      AppError.show(
        context,
        'No se pudo acceder a tus contactos. Actívalo desde los ajustes del teléfono.',
      );
    }
    return;
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ImportarContactosScreen(casaId: casaId),
    ),
  );
}

class ImportarContactosScreen extends StatefulWidget {
  const ImportarContactosScreen({required this.casaId, super.key});

  final String casaId;

  @override
  State<ImportarContactosScreen> createState() =>
      _ImportarContactosScreenState();
}

class _ImportarContactosScreenState extends State<ImportarContactosScreen> {
  // null mientras carga.
  List<Contact>? _contactos;
  Set<String> _telefonosYaGuardados = const {};
  final _seleccionados = <String>{};
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';
  bool _importando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  String _normalizar(String telefono) =>
      telefono.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _cargar() async {
    try {
      // Ya guardados en la casa, para no ofrecer importar lo que ya está --
      // comparados solo por dígitos del teléfono (mismo formato que ya usa
      // contacto_acciones.dart para WhatsApp), ya que el mismo número puede
      // venir escrito con espacios/guiones distintos en cada sitio.
      final existentes = await ContactoService.streamContactos(
        widget.casaId,
      ).first;
      final guardados = existentes
          .map((c) => _normalizar(c.telefono))
          .where((t) => t.isNotEmpty)
          .toSet();
      final dispositivo = await FlutterContacts.getContacts(
        withProperties: true,
      );
      final conTelefono = dispositivo
          .where((c) => c.phones.isNotEmpty && c.displayName.trim().isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _contactos = conTelefono;
        _telefonosYaGuardados = guardados;
      });
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudieron cargar los contactos del teléfono.',
          error: e,
          stackTrace: st,
        );
        setState(() => _contactos = const []);
      }
    }
  }

  bool _yaGuardado(Contact c) =>
      c.phones.any((p) => _telefonosYaGuardados.contains(_normalizar(p.number)));

  Future<void> _importar() async {
    final contactos = _contactos;
    if (contactos == null || _seleccionados.isEmpty || _importando) return;
    setState(() => _importando = true);
    var importados = 0;
    try {
      for (final c in contactos.where((c) => _seleccionados.contains(c.id))) {
        await ContactoService.crear(
          widget.casaId,
          Contacto(
            id: '',
            nombre: c.displayName.trim(),
            telefono: c.phones.first.number.trim(),
            tipo: TipoContacto.particular,
          ),
        );
        importados++;
      }
      if (mounted) {
        AppError.showSuccess(
          context,
          importados == 1
              ? 'Contacto importado.'
              : '$importados contactos importados.',
        );
        Navigator.pop(context);
      }
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          importados == 0
              ? 'No se pudo importar ningún contacto.'
              : 'Se importaron $importados, pero el resto falló.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactos = _contactos;
    final filtrados = contactos == null
        ? null
        : (_busqueda.isEmpty
              ? contactos
              : contactos
                    .where((c) => c.displayName.toLowerCase().contains(_busqueda))
                    .toList());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar contactos'),
        actions: [
          if (_seleccionados.isNotEmpty)
            TextButton(
              onPressed: _importando ? null : _importar,
              child: _importando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Importar (${_seleccionados.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
        ],
      ),
      body: contactos == null
          ? const Center(child: CircularProgressIndicator())
          : contactos.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No hemos encontrado ningún contacto con teléfono en tu agenda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.inkMuted),
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _busquedaCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Buscar contacto',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setState(() => _busqueda = v.trim().toLowerCase()),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: filtrados!.length,
                    itemBuilder: (context, i) {
                      final c = filtrados[i];
                      final yaGuardado = _yaGuardado(c);
                      final seleccionado = _seleccionados.contains(c.id);
                      return CheckboxListTile(
                        value: yaGuardado ? true : seleccionado,
                        onChanged: yaGuardado
                            ? null
                            : (v) => setState(() {
                                if (v ?? false) {
                                  _seleccionados.add(c.id);
                                } else {
                                  _seleccionados.remove(c.id);
                                }
                              }),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(c.displayName),
                        subtitle: Text(
                          yaGuardado
                              ? 'Ya está en tus contactos'
                              : c.phones.first.number,
                          style: yaGuardado
                              ? TextStyle(color: context.colors.inkMuted)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
