// lib/screens/pro/trabajos_pro_tab.dart
//
// "Por trabajo" (lista plana) o "Por cliente" (agrupado por casa) con el
// mismo selector -- antes "Clientes" era una pestaña aparte que mostraba
// exactamente estos mismos datos sin ninguna acción propia (auditoría de
// producto, octubre 2026): se fusiona aquí como un filtro, no como una
// pantalla distinta.
//
// Rediseño de fidelidad visual (octubre 2026): la vista "Por cliente"
// (_ListaPorCliente) sigue usando Card+ExpansionTile -- igual que
// casa_tab.dart con _HabitacionCard (agrupar por un padre expandible con
// filas IosRow dentro no encaja en IosSection, pensado para una lista
// plana bajo una única cabecera fija) -- pero ahora tokenizada y alineada
// con esa misma referencia: margen, radio del icono, indentado y color del
// divisor idénticos. Se corrige además un divisor que aparecía también
// ANTES del primer trabajo de cada cliente (sin guarda `i > 0`), visible
// pegado justo debajo de la cabecera del cliente.
import 'package:flutter/material.dart';

import '../../models/profesional.dart';
import '../../services/profesional_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/boton_ajustes.dart';
import '../../widgets/ios_list.dart';
import 'registro_pro_detail_screen.dart';

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
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'MODO PROFESIONAL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: context.colors.inkMuted,
              ),
            ),
            Text(
              'Trabajos',
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(fontSize: 26),
            ),
          ],
        ),
        actions: const [BotonAjustes(modoPro: true)],
      ),
      body: StreamBuilder<List<RegistroProRef>>(
        stream: ProfesionalService.streamRegistrosProRefs(),
        builder: (context, snapshot) {
          final trabajos = snapshot.data ?? [];
          if (trabajos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(ReparaSpace.s6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: context.colors.brandTint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.build_outlined,
                        size: 32,
                        color: context.colors.brand,
                      ),
                    ),
                    const SizedBox(height: ReparaSpace.s4),
                    Text(
                      'Aquí gestionas cada trabajo entero (presupuesto, cambios, pagos, documentos) en cuanto aceptes una invitación.\nPara ver solo el estado de tus presupuestos de todos los trabajos a la vez, ve a la pestaña Presupuestos.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ReparaSpace.s4,
                  ReparaSpace.s3,
                  ReparaSpace.s4,
                  ReparaSpace.s1,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Por trabajo'),
                        selected: _vista == _VistaTrabajosPro.porTrabajo,
                        onSelected: (_) => setState(
                          () => _vista = _VistaTrabajosPro.porTrabajo,
                        ),
                      ),
                    ),
                    const SizedBox(width: ReparaSpace.s2),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Por cliente'),
                        selected: _vista == _VistaTrabajosPro.porCliente,
                        onSelected: (_) => setState(
                          () => _vista = _VistaTrabajosPro.porCliente,
                        ),
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

  final List<RegistroProRef> trabajos;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ReparaSpace.s4,
        0,
        ReparaSpace.s4,
        ReparaSpace.s4,
      ),
      children: [
        IosSection(
          rows: trabajos
              .map(
                (t) => IosRow(
                  icon: Icons.build_outlined,
                  iconColor: context.colors.brand,
                  title: t.registroTitulo,
                  subtitle: t.casaNombre,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegistroProDetailScreen(
                        casaId: t.casaId,
                        elementoId: t.elementoId,
                        registroId: t.registroId,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ListaPorCliente extends StatelessWidget {
  const _ListaPorCliente({required this.trabajos});

  final List<RegistroProRef> trabajos;

  @override
  Widget build(BuildContext context) {
    final porCasa = <String, List<RegistroProRef>>{};
    for (final t in trabajos) {
      porCasa.putIfAbsent(t.casaId, () => []).add(t);
    }
    final casas = porCasa.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        ReparaSpace.s4,
        0,
        ReparaSpace.s4,
        ReparaSpace.s4,
      ),
      itemCount: casas.length,
      itemBuilder: (context, i) {
        final entry = casas[i];
        final trabajosDeEstaCasa = entry.value;
        return Card(
          margin: const EdgeInsets.only(bottom: ReparaSpace.s2),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.colors.brandTint,
                  borderRadius: BorderRadius.circular(ReparaRadius.sm),
                ),
                child: Icon(
                  Icons.house_outlined,
                  size: 19,
                  color: context.colors.brand,
                ),
              ),
              title: Text(
                trabajosDeEstaCasa.first.casaNombre,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                '${trabajosDeEstaCasa.length} trabajo${trabajosDeEstaCasa.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              childrenPadding: const EdgeInsets.only(bottom: ReparaSpace.s2),
              children: [
                for (var i = 0; i < trabajosDeEstaCasa.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: context.colors.inkMuted.withValues(alpha: 0.14),
                    ),
                  IosRow(
                    icon: Icons.build_outlined,
                    iconColor: context.colors.brand,
                    title: trabajosDeEstaCasa[i].registroTitulo,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RegistroProDetailScreen(
                          casaId: trabajosDeEstaCasa[i].casaId,
                          elementoId: trabajosDeEstaCasa[i].elementoId,
                          registroId: trabajosDeEstaCasa[i].registroId,
                        ),
                      ),
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
