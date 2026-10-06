// lib/screens/revisiones_pendientes_screen.dart
//
// Lista de elementos con revisión periódica próxima o atrasada -- se abre
// al tocar el aviso de Inicio, mismo patrón que garantias_proximas_screen.dart.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../theme/design_tokens.dart';
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
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: elementos.length,
        separatorBuilder: (context, i) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final e = elementos[i];
          final dias = e.proximoMantenimiento!.difference(DateTime.now()).inDays;
          final atrasada = dias < 0;
          return Card(
            child: ListTile(
              leading: Icon(Icons.build_circle_outlined, color: atrasada ? context.colors.error : context.colors.brand),
              title: Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                atrasada
                    ? 'Revisión atrasada desde el ${DateFormat('d MMMM yyyy', 'es_ES').format(e.proximoMantenimiento!)}'
                    : 'Próxima revisión: ${DateFormat('d MMMM yyyy', 'es_ES').format(e.proximoMantenimiento!)}',
                style: TextStyle(color: atrasada ? context.colors.error : context.colors.inkMuted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: e.id)),
              ),
            ),
          );
        },
      ),
    );
  }
}
