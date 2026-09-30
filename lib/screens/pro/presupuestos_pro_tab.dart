// lib/screens/pro/presupuestos_pro_tab.dart
//
// Presupuestos simplificado en esta primera pasada: no hay entidad
// "presupuesto" con líneas/estado/aceptación todavía (queda para una fase
// posterior, ver auditoría) -- esta pestaña muestra el importe simple de
// cada trabajo y deja editarlo, priorizando los que aún no tienen uno.
import 'package:flutter/material.dart';

import '../../models/profesional.dart';
import '../../services/profesional_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/boton_ajustes.dart';
import 'trabajo_pro_detail_screen.dart';

class PresupuestosProTab extends StatelessWidget {
  const PresupuestosProTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Presupuestos'), actions: const [BotonAjustes()]),
      body: StreamBuilder<List<TrabajoProRef>>(
        stream: ProfesionalService.streamTrabajosProRefs(),
        builder: (context, snapshot) {
          final trabajos = snapshot.data ?? [];
          if (trabajos.isEmpty) {
            return Center(
              child: Text('Todavía no tienes trabajos para presupuestar.', style: TextStyle(color: context.colors.inkMuted)),
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
                  leading: const Icon(Icons.request_quote_outlined),
                  title: Text(t.trabajoTitulo),
                  subtitle: Text(t.casaNombre),
                  trailing: const Icon(Icons.chevron_right),
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
