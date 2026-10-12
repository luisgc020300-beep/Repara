// lib/screens/contactos_tab.dart
//
// Libreta de profesionales de confianza de la casa (decisión del CEO: nunca
// un listado público ni un buscador de gente nueva -- solo tus contactos).
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../models/contacto.dart';
import '../services/contacto_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/boton_ajustes.dart';
import 'contacto_acciones.dart';
import 'nuevo_contacto_sheet.dart';

class ContactosTab extends StatelessWidget {
  const ContactosTab({required this.casa, super.key});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('AGENDA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: context.colors.inkMuted)),
            Text('Contactos', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26)),
          ],
        ),
        actions: [BotonAjustes(casa: casa)],
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            children: contactos.map((c) => _ContactoCard(casa: casa, contacto: c)).toList(),
          );
        },
      ),
    );
  }
}

class _ContactoCard extends StatelessWidget {
  const _ContactoCard({required this.casa, required this.contacto});

  final Casa casa;
  final Contacto contacto;

  @override
  Widget build(BuildContext context) {
    final esEmpresa = contacto.tipo == TipoContacto.empresa;
    final inicial = contacto.nombre.isNotEmpty ? contacto.nombre[0].toUpperCase() : '?';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(ReparaRadius.md),
        onTap: () => mostrarAccionesContacto(context, casaId: casa.id, contacto: contacto),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                onPressed: () => mostrarAccionesContacto(context, casaId: casa.id, contacto: contacto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
