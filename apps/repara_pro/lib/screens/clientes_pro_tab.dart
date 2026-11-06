// apps/repara_pro/lib/screens/clientes_pro_tab.dart
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
//
// Fase 1 (noviembre 2026, corrección de la auditoría funcional): esta
// lista ahora combina esos clientes DERIVADOS (de trabajos compartidos ya
// aceptados) con los clientes PRIVADOS que el propio profesional puede
// crear por iniciativa propia (ClienteProfesionalService) -- antes era
// imposible registrar un cliente sin que el propietario iniciara el
// proceso desde REPARA Hogar. Se distinguen con una insignia "Privado" vs.
// el nombre de la casa vinculada; el FAB "+" solo crea clientes privados
// (los derivados nunca se crean a mano, nacen de aceptar una invitación).
import 'package:flutter/material.dart';

import '../models/cliente_profesional.dart';
import '../services/cliente_profesional_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_error.dart';
import '../widgets/boton_ajustes_pro.dart';
import 'package:repara_ui/ios_list.dart';
import 'cliente_pro_detail_screen.dart';
import 'cliente_profesional_detail_screen.dart';
import 'cliente_profesional_sheet.dart';
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
        actions: const [BotonAjustesPro()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => mostrarEditorClienteProfesional(context),
        tooltip: 'Nuevo cliente privado',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<ClienteProfesional>>(
        stream: ClienteProfesionalService.streamClientes(),
        builder: (context, clientesSnapshot) {
          final privados = clientesSnapshot.data ?? const [];
          return TrabajosProAgregadosBuilder(
            builder: (context, trabajos, cargando) {
              if (!cargando && trabajos.isEmpty && privados.isEmpty) {
                return const EmptyHint(
                  message:
                      'Todavía no tienes clientes -- crea uno nuevo o acepta una invitación.',
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
              final derivados = porCasa.values.toList()
                ..sort((a, b) => a.casaNombre.compareTo(b.casaNombre));
              final privadosOrdenados = [...privados]
                ..sort((a, b) => a.nombre.compareTo(b.nombre));

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, ReparaSpace.s4, 16, 90),
                children: [
                  if (privadosOrdenados.isNotEmpty) ...[
                    IosSection(
                      rows: privadosOrdenados
                          .map(
                            (c) => IosRow(
                              icon: Icons.person_outline,
                              iconColor: context.colors.brand,
                              title: c.nombre,
                              subtitle: c.telefono ?? c.email,
                              trailing: const _InsigniaPrivado(),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ClienteProfesionalDetailScreen(
                                        cliente: c,
                                      ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: ReparaSpace.s4),
                  ],
                  if (derivados.isNotEmpty)
                    IosSection(
                      rows: derivados
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
          );
        },
      ),
    );
  }
}

/// Insignia "Privado" -- único rasgo visual que distingue un cliente creado
/// por el propio profesional de uno derivado de un trabajo compartido
/// (que en vez de esto muestra el importe pendiente de cobro).
class _InsigniaPrivado extends StatelessWidget {
  const _InsigniaPrivado();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.sand.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(ReparaRadius.pill),
      ),
      child: Text(
        'PRIVADO',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: context.colors.ink,
        ),
      ),
    );
  }
}
