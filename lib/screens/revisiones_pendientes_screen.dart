// lib/screens/revisiones_pendientes_screen.dart
//
// Lista de elementos con revisión periódica próxima o atrasada -- se abre
// al tocar el aviso de Inicio, mismo patrón que garantias_proximas_screen.dart.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../theme/design_tokens.dart';
import '../widgets/ios_list.dart';
import 'elemento_detail_screen.dart';

class RevisionesPendientesScreen extends StatelessWidget {
  const RevisionesPendientesScreen({required this.casa, required this.elementos, this.titulo = 'Revisiones pendientes', super.key});

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
                child: Text('Ningún elemento tiene un calendario de mantenimiento configurado todavía.', style: TextStyle(color: context.colors.inkMuted)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                IosSection(
                  rows: elementos.map((e) {
                    final dias = e.proximoMantenimiento!.difference(DateTime.now()).inDays;
                    final atrasada = dias < 0;
                    return IosRow(
                      icon: Icons.build_circle_outlined,
                      iconColor: atrasada ? context.colors.error : context.colors.brand,
                      title: e.nombre,
                      subtitle: atrasada
                          ? 'Revisión atrasada desde el ${DateFormat('d MMMM yyyy', 'es_ES').format(e.proximoMantenimiento!)}'
                          : 'Próxima revisión: ${DateFormat('d MMMM yyyy', 'es_ES').format(e.proximoMantenimiento!)}',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: e.id)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}
