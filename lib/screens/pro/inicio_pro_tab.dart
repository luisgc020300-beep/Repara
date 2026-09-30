// lib/screens/pro/inicio_pro_tab.dart
//
// Home del profesional (sección 40 del spec): resumen operativo, no una
// lista de funciones. En esta primera pasada el dato central son las
// invitaciones pendientes -- es la única acción que de verdad requiere
// atención inmediata en el flujo actual.
import 'package:flutter/material.dart';

import '../../models/invitacion.dart';
import '../../models/profesional.dart';
import '../../services/invitacion_service.dart';
import '../../services/profesional_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';

class InicioProTab extends StatelessWidget {
  const InicioProTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repara Pro')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Invitaciones pendientes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StreamBuilder<List<Invitacion>>(
            stream: InvitacionService.streamPendientesParaMi(),
            builder: (context, snapshot) {
              final invitaciones = snapshot.data ?? [];
              if (invitaciones.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('No tienes invitaciones nuevas.', style: TextStyle(color: context.colors.inkMuted)),
                  ),
                );
              }
              return Column(children: invitaciones.map((i) => _InvitacionCard(invitacion: i)).toList());
            },
          ),
          const SizedBox(height: 24),
          StreamBuilder<List<TrabajoProRef>>(
            stream: ProfesionalService.streamTrabajosProRefs(),
            builder: (context, snapshot) {
              final total = snapshot.data?.length ?? 0;
              return Card(
                child: ListTile(
                  leading: Icon(Icons.build_outlined, color: context.colors.brand),
                  title: Text('$total trabajo${total == 1 ? '' : 's'} activo${total == 1 ? '' : 's'}'),
                  subtitle: const Text('Revisa la pestaña Trabajos para ver el detalle'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InvitacionCard extends StatefulWidget {
  const _InvitacionCard({required this.invitacion});

  final Invitacion invitacion;

  @override
  State<_InvitacionCard> createState() => _InvitacionCardState();
}

class _InvitacionCardState extends State<_InvitacionCard> {
  bool _respondiendo = false;

  Future<void> _responder(bool aceptar) async {
    setState(() => _respondiendo = true);
    try {
      await InvitacionService.responder(widget.invitacion.id, aceptar: aceptar);
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo responder a la invitación.');
    } finally {
      if (mounted) setState(() => _respondiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.invitacion.trabajoTitulo, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('en ${widget.invitacion.casaNombre}', style: TextStyle(color: context.colors.inkMuted)),
            const SizedBox(height: 10),
            _respondiendo
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => _responder(false), child: const Text('Rechazar')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(onPressed: () => _responder(true), child: const Text('Aceptar')),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
