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
import '../widgets/ios_list.dart';
import 'contacto_acciones.dart';
import 'nuevo_contacto_sheet.dart';

class ContactosTab extends StatelessWidget {
  const ContactosTab({required this.casa, super.key});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contactos'), actions: [BotonAjustes(casa: casa)]),
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
                    Icon(Icons.contact_phone_outlined, size: 32, color: context.colors.inkMuted),
                    const SizedBox(height: 10),
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
            padding: const EdgeInsets.all(16),
            children: [
              IosSection(
                rows: contactos
                    .map((c) => IosRow(
                          icon: c.tipo == TipoContacto.empresa ? Icons.store_outlined : Icons.person_outline,
                          iconColor: context.colors.brand,
                          title: c.nombre,
                          subtitle: c.especialidad ?? c.telefono,
                          onTap: () => mostrarAccionesContacto(context, casaId: casa.id, contacto: c),
                        ))
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
