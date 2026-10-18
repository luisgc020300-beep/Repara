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
      appBar: AppBar(title: Text(titulo, style: Theme.of(context).textTheme.displaySmall)),
      body: elementos.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: context.colors.brandTint, shape: BoxShape.circle),
                      child: Icon(Icons.build_circle_outlined, size: 32, color: context.colors.brand),
                    ),
                    const SizedBox(height: 16),
                    Text('Ningún elemento tiene un calendario de mantenimiento configurado todavía.', textAlign: TextAlign.center, style: TextStyle(color: context.colors.inkMuted)),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                IosSection(
                  rows: elementos.map((e) {
                    final dias = e.proximoMantenimiento!.difference(DateTime.now()).inDays;
                    final atrasada = dias < 0;
                    final color = atrasada ? context.colors.error : context.colors.brand;
                    final colorTexto = atrasada ? context.colors.errorText : null;
                    return IosRow(
                      icon: Icons.build_circle_outlined,
                      iconColor: color,
                      title: e.nombre,
                      subtitle: atrasada
                          ? 'Atrasada desde el ${DateFormat('d MMMM yyyy', 'es_ES').format(e.proximoMantenimiento!)}'
                          : 'Próxima: ${DateFormat('d MMMM yyyy', 'es_ES').format(e.proximoMantenimiento!)}',
                      subtitleColor: colorTexto,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: e.id))),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}
