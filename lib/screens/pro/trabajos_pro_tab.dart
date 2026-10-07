// lib/screens/pro/trabajos_pro_tab.dart
//
// "Por trabajo" (lista plana) o "Por cliente" (agrupado por casa) con el
// mismo selector -- antes "Clientes" era una pestaña aparte que mostraba
// exactamente estos mismos datos sin ninguna acción propia (auditoría de
// producto, octubre 2026): se fusiona aquí como un filtro, no como una
// pantalla distinta.
import 'package:flutter/material.dart';

import '../../models/profesional.dart';
import '../../services/profesional_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/boton_ajustes.dart';
import '../../widgets/ios_list.dart';
import 'trabajo_pro_detail_screen.dart';

enum _VistaTrabajosPro { porTrabajo, porCliente }

class TrabajosProTab extends StatefulWidget {
  const TrabajosProTab({super.key});

  @override
  State<TrabajosProTab> createState() => _TrabajosProTabState();
}

class _TrabajosProTabState extends State<TrabajosProTab> {
  _VistaTrabajosPro _vista = _VistaTrabajosPro.porTrabajo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajos'), actions: const [BotonAjustes(modoPro: true)]),
      body: StreamBuilder<List<TrabajoProRef>>(
        stream: ProfesionalService.streamTrabajosProRefs(),
        builder: (context, snapshot) {
          final trabajos = snapshot.data ?? [];
          if (trabajos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aquí gestionas cada trabajo entero (presupuesto, cambios, pagos, documentos) en cuanto aceptes una invitación.\nPara ver solo el estado de tus presupuestos de todos los trabajos a la vez, ve a la pestaña Presupuestos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.inkMuted),
                ),
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Por trabajo'),
                        selected: _vista == _VistaTrabajosPro.porTrabajo,
                        onSelected: (_) => setState(() => _vista = _VistaTrabajosPro.porTrabajo),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Por cliente'),
                        selected: _vista == _VistaTrabajosPro.porCliente,
                        onSelected: (_) => setState(() => _vista = _VistaTrabajosPro.porCliente),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _vista == _VistaTrabajosPro.porTrabajo
                    ? _ListaPorTrabajo(trabajos: trabajos)
                    : _ListaPorCliente(trabajos: trabajos),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ListaPorTrabajo extends StatelessWidget {
  const _ListaPorTrabajo({required this.trabajos});

  final List<TrabajoProRef> trabajos;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        IosSection(
          rows: trabajos
              .map((t) => IosRow(
                    icon: Icons.build_outlined,
                    iconColor: context.colors.brand,
                    title: t.trabajoTitulo,
                    subtitle: t.casaNombre,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TrabajoProDetailScreen(casaId: t.casaId, trabajoId: t.trabajoId)),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _ListaPorCliente extends StatelessWidget {
  const _ListaPorCliente({required this.trabajos});

  final List<TrabajoProRef> trabajos;

  @override
  Widget build(BuildContext context) {
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
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(Icons.house_outlined, color: context.colors.brand),
              title: Text(trabajosDeEstaCasa.first.casaNombre),
              subtitle: Text('${trabajosDeEstaCasa.length} trabajo${trabajosDeEstaCasa.length == 1 ? '' : 's'}'),
              children: [
                for (var i = 0; i < trabajosDeEstaCasa.length; i++) ...[
                  Divider(height: 1, indent: 56, color: context.colors.inkMuted.withValues(alpha: 0.14)),
                  IosRow(
                    icon: Icons.build_outlined,
                    iconColor: context.colors.brand,
                    title: trabajosDeEstaCasa[i].trabajoTitulo,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TrabajoProDetailScreen(casaId: trabajosDeEstaCasa[i].casaId, trabajoId: trabajosDeEstaCasa[i].trabajoId)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
