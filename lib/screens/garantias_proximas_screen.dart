// lib/screens/garantias_proximas_screen.dart
//
// Lista de elementos cuya garantía vence en los próximos 30 días -- se abre
// al tocar el aviso de Inicio, para comprobar de un vistazo la fecha exacta
// de cada uno antes de entrar al detalle completo del elemento.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../theme/design_tokens.dart';
import '../widgets/ios_list.dart';
import 'elemento_detail_screen.dart';

class GarantiasProximasScreen extends StatelessWidget {
  const GarantiasProximasScreen({required this.casa, required this.elementos, this.titulo = 'Garantías a punto de terminar', super.key});

  final Casa casa;
  final List<Elemento> elementos;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: elementos.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Ningún elemento tiene una garantía guardada todavía.', style: TextStyle(color: context.colors.inkMuted)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                IosSection(
                  rows: elementos
                      .map((e) => IosRow(
                            icon: Icons.shield_outlined,
                            iconColor: context.colors.warning,
                            title: e.nombre,
                            subtitle: e.garantiaHasta != null
                                ? 'Garantía hasta ${DateFormat('d MMMM yyyy', 'es_ES').format(e.garantiaHasta!)}'
                                : null,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: e.id)),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
    );
  }
}
