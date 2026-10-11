// lib/screens/trabajos_pendientes_screen.dart
//
// Lista de elementos con al menos un registro en curso con un profesional
// -- se abre al tocar "Trabajos pendientes" en Inicio, mismo patrón que
// garantias_proximas_screen.dart y revisiones_pendientes_screen.dart.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../theme/design_tokens.dart';
import '../widgets/ios_list.dart';
import 'elemento_detail_screen.dart';

class TrabajosPendientesScreen extends StatelessWidget {
  const TrabajosPendientesScreen({required this.casa, required this.items, super.key});

  final Casa casa;
  final List<({Elemento elemento, String registroTitulo, DateTime fecha})> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajos pendientes')),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No tienes ningún trabajo en curso con un profesional.', style: TextStyle(color: context.colors.inkMuted)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                IosSection(
                  rows: items
                      .map((item) => IosRow(
                            icon: Icons.hourglass_top_outlined,
                            iconColor: context.colors.brand,
                            title: item.elemento.nombre,
                            subtitle: '${item.registroTitulo} · ${DateFormat('d MMMM yyyy', 'es_ES').format(item.fecha)}',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: item.elemento.id)),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
    );
  }
}
