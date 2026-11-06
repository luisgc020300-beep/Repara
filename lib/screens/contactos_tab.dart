// lib/screens/contactos_tab.dart
//
// Libreta de profesionales de confianza de la casa (decisión del CEO: nunca
// un listado público ni un buscador de gente nueva -- solo tus contactos).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/casa.dart';
import '../models/contacto.dart';
import '../services/contacto_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_dialog.dart';
import 'package:repara_ui/app_error.dart';
import '../widgets/boton_ajustes.dart';
import 'package:repara_ui/ios_list.dart';
import 'contacto_acciones.dart';
import 'importar_contactos_screen.dart';
import 'nuevo_contacto_sheet.dart';

class ContactosTab extends StatefulWidget {
  const ContactosTab({required this.casa, super.key});

  final Casa casa;

  @override
  State<ContactosTab> createState() => _ContactosTabState();
}

class _ContactosTabState extends State<ContactosTab> {
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casa = widget.casa;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('AGENDA', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, color: Colors.white70)),
            Text('Contactos', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Importar de tus contactos',
            icon: const Icon(Icons.contact_phone_outlined),
            onPressed: () => abrirImportarContactos(context, casaId: casa.id),
          ),
          BotonAjustes(casa: casa),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarNuevoContactoSheet(context, casaId: casa.id),
        icon: const Icon(Icons.add),
        label: const Text('Contacto'),
      ),
      body: StreamBuilder<List<Contacto>>(
        stream: ContactoService.streamContactos(casa.id),
        builder: (context, snapshot) {
          final contactos = snapshot.data ?? [];
          if (contactos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: context.colors.brandTint, shape: BoxShape.circle),
                      child: Icon(Icons.contact_phone_outlined, size: 32, color: context.colors.brand),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Guarda aquí a tu fontanero, electricista o cualquier profesional de confianza.\nLlamarlo o avisarle será mucho más rápido.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.inkMuted),
                    ),
                  ],
                ),
              ),
            );
          }
          // Filtro en memoria, mismo patrón que home_tab.dart -- la agenda
          // nunca busca gente nueva (ver cabecera del archivo), solo filtra
          // los contactos que ya tienes cuando la lista crece (CEO,
          // noviembre 2026).
          final filtrados = _busqueda.isEmpty
              ? contactos
              : contactos
                    .where(
                      (c) =>
                          c.nombre.toLowerCase().contains(_busqueda) ||
                          (c.especialidad?.toLowerCase().contains(_busqueda) ?? false),
                    )
                    .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, ReparaSpace.s4, 16, 90),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _busquedaCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Buscar contacto',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
                ),
              ),
              if (filtrados.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Ningún contacto coincide con "$_busqueda".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.inkMuted),
                  ),
                )
              else
                IosSection(rows: filtrados.map((c) => _ContactoRow(casa: casa, contacto: c)).toList()),
            ],
          );
        },
      ),
    );
  }
}

/// Fila de un contacto dentro de la agenda -- no usa IosRow porque el
/// avatar circular con inicial (en vez de la insignia cuadrada de icono)
/// es el único rasgo distintivo de una libreta de contactos; agrupadas por
/// IosSection, no cada una en su propia tarjeta flotante.
class _ContactoRow extends StatelessWidget {
  const _ContactoRow({required this.casa, required this.contacto});

  final Casa casa;
  final Contacto contacto;

  // Icono de teléfono = llamar ya, con una confirmación de un toque -- más
  // rápido que abrir el menú completo de acciones cuando lo único que quieres
  // es llamar (CEO, octubre 2026). El resto de la tarjeta sigue abriendo ese
  // menú completo (chat, foto, editar...).
  Future<void> _confirmarLlamada(BuildContext context) async {
    final confirmar = await AppDialog.confirm(context, title: '¿Llamar a ${contacto.nombre}?', message: contacto.telefono, confirmLabel: 'Llamar');
    if (!confirmar || !context.mounted) return;
    final abierto = await launchUrl(Uri(scheme: 'tel', path: contacto.telefono));
    if (!abierto && context.mounted) AppError.show(context, 'No se pudo iniciar la llamada.');
  }

  @override
  Widget build(BuildContext context) {
    final esEmpresa = contacto.tipo == TipoContacto.empresa;
    final inicial = contacto.nombre.isNotEmpty ? contacto.nombre[0].toUpperCase() : '?';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => mostrarAccionesContacto(context, casaId: casa.id, contacto: contacto),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: context.colors.brandTint, shape: BoxShape.circle),
                child: esEmpresa
                    ? Icon(Icons.store_outlined, size: 20, color: context.colors.brand)
                    : Center(
                        child: Text(inicial, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.colors.brand)),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contacto.nombre, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      contacto.especialidad ?? contacto.telefono,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.call_outlined, color: context.colors.brand),
                tooltip: 'Llamar a ${contacto.nombre}',
                onPressed: () => _confirmarLlamada(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
