// lib/screens/pro/clientes_pro_tab.dart
//
// "Clientes" (sección 18 del spec) simplificado en esta primera pasada: cada
// casa en la que el profesional tiene al menos un trabajo aceptado es un
// cliente. No hay ficha de cliente con historial completo todavía -- el
// profesional no tiene permiso de lectura sobre la casa entera, solo sobre
// los trabajos concretos que le han asignado (ver auditoría de permisos).
import 'package:flutter/material.dart';

import '../../models/profesional.dart';
import '../../services/profesional_service.dart';
import '../../theme/design_tokens.dart';

class ClientesProTab extends StatelessWidget {
  const ClientesProTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: StreamBuilder<List<TrabajoProRef>>(
        stream: ProfesionalService.streamTrabajosProRefs(),
        builder: (context, snapshot) {
          final trabajos = snapshot.data ?? [];
          if (trabajos.isEmpty) {
            return Center(
              child: Text('Todavía no tienes clientes.', style: TextStyle(color: context.colors.inkMuted)),
            );
          }
          final porCasa = <String, List<TrabajoProRef>>{};
          for (final t in trabajos) {
            porCasa.putIfAbsent(t.casaId, () => []).add(t);
          }
          final casas = porCasa.entries.toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: casas.length,
            itemBuilder: (context, i) {
              final entry = casas[i];
              final trabajosDeEstaCasa = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.house_outlined, color: context.colors.brand),
                  title: Text(trabajosDeEstaCasa.first.casaNombre),
                  subtitle: Text('${trabajosDeEstaCasa.length} trabajo${trabajosDeEstaCasa.length == 1 ? '' : 's'}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
