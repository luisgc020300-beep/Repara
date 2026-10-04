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
import 'elemento_detail_screen.dart';

class GarantiasProximasScreen extends StatelessWidget {
  const GarantiasProximasScreen({required this.casa, required this.elementos, super.key});

  final Casa casa;
  final List<Elemento> elementos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Garantías a punto de terminar')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: elementos.length,
        separatorBuilder: (context, i) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final e = elementos[i];
          return Card(
            child: ListTile(
              leading: Icon(Icons.shield_outlined, color: context.colors.warning),
              title: Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: e.garantiaHasta != null
                  ? Text('Garantía hasta ${DateFormat('d MMMM yyyy', 'es_ES').format(e.garantiaHasta!)}')
                  : null,
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
