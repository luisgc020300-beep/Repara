// lib/screens/pro/trabajos_pro_tab.dart
import 'package:flutter/material.dart';

import '../../models/profesional.dart';
import '../../services/profesional_service.dart';
import '../../theme/design_tokens.dart';
import 'trabajo_pro_detail_screen.dart';

class TrabajosProTab extends StatelessWidget {
  const TrabajosProTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajos')),
      body: StreamBuilder<List<TrabajoProRef>>(
        stream: ProfesionalService.streamTrabajosProRefs(),
        builder: (context, snapshot) {
          final trabajos = snapshot.data ?? [];
          if (trabajos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Todavía no tienes trabajos asignados.\nAparecerán aquí cuando aceptes una invitación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.inkMuted),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trabajos.length,
            itemBuilder: (context, i) {
              final t = trabajos[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.build_outlined),
                  title: Text(t.trabajoTitulo),
                  subtitle: Text(t.casaNombre),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TrabajoProDetailScreen(casaId: t.casaId, trabajoId: t.trabajoId)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
