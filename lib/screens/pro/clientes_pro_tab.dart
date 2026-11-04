// lib/screens/pro/clientes_pro_tab.dart
//
// Clientes (ampliación funcional REPARA Pro, Fase 2 -- CEO, noviembre
// 2026): un "cliente" del profesional es, de hecho, una vivienda (casaId)
// con uno o más trabajos -- ya se agrupaban así en la vista "Por cliente"
// de Trabajos; aquí se convierte en su propia pestaña, con un resumen por
// cliente, y de cada fila se entra a la ficha completa
// (cliente_pro_detail_screen.dart).
//
// Decisión del CEO (noviembre 2026): esta ficha NO muestra teléfono ni
// email del propietario -- se mantiene la privacidad actual (el
// profesional solo ve el nombre de la casa y el historial/importes del
// trabajo; el contacto real sigue viviendo en WhatsApp). Cero cambios de
// reglas de Firestore por esto.
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';
import '../../widgets/boton_ajustes.dart';
import '../../widgets/ios_list.dart';
import 'cliente_pro_detail_screen.dart';
import 'trabajo_pro_agregado.dart';

class _ResumenCliente {
  _ResumenCliente(this.casaId, this.casaNombre);

  final String casaId;
  final String casaNombre;
  int trabajos = 0;
  int activos = 0;
  double pendienteCobro = 0;
}

class ClientesProTab extends StatelessWidget {
  const ClientesProTab({super.key});

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
                color: Colors.white70,
              ),
            ),
            Text(
              'Clientes',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 26,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: const [BotonAjustes(modoPro: true)],
      ),
      body: TrabajosProAgregadosBuilder(
        builder: (context, trabajos, cargando) {
          if (!cargando && trabajos.isEmpty) {
            return const EmptyHint(
              message:
                  'Todavía no tienes clientes -- acepta una invitación para empezar.',
              icon: Icons.people_outline,
            );
          }

          final porCasa = <String, _ResumenCliente>{};
          for (final t in trabajos) {
            final resumen = porCasa.putIfAbsent(
              t.ref.casaId,
              () => _ResumenCliente(t.ref.casaId, t.ref.casaNombre),
            );
            resumen.trabajos++;
            if (t.columna != ColumnaTableroPro.terminado &&
                t.columna != ColumnaTableroPro.archivado) {
              resumen.activos++;
            }
            resumen.pendienteCobro += t.saldoPendiente ?? 0;
          }
          final clientes = porCasa.values.toList()
            ..sort((a, b) => a.casaNombre.compareTo(b.casaNombre));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, ReparaSpace.s4, 16, 24),
            children: [
              IosSection(
                rows: clientes
                    .map(
                      (c) => IosRow(
                        icon: Icons.house_outlined,
                        iconColor: context.colors.brand,
                        title: c.casaNombre,
                        subtitle:
                            '${c.trabajos} trabajo${c.trabajos == 1 ? '' : 's'} · ${c.activos} activo${c.activos == 1 ? '' : 's'}',
                        trailing: c.pendienteCobro > 0
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${c.pendienteCobro.toStringAsFixed(0)} €',
                                    style: ReparaText.amount(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    color: context.colors.inkMuted,
                                    size: 20,
                                  ),
                                ],
                              )
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClienteProDetailScreen(
                              casaId: c.casaId,
                              casaNombre: c.casaNombre,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
