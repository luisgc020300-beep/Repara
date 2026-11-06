// lib/screens/pro/cliente_pro_detail_screen.dart
//
// Ficha de cliente (ampliación funcional REPARA Pro, Fase 2 -- CEO,
// noviembre 2026): toda la relación comercial con un cliente (una
// vivienda) desde un único sitio -- resumen económico real + historial de
// trabajos, en ese orden de prioridad.
//
// Deliberadamente SIN "Notas comerciales": el encargo pedía estudiar si ya
// existe un sistema de notas/seguimiento reutilizable -- no existe
// ninguno, y construir uno de cero implicaría una colección nueva de
// Firestore más su propia regla de seguridad, fuera del alcance acordado
// para esta fase (ver informe final). No se ha fingido con una sección
// vacía ni con datos de ejemplo.
//
// Deliberadamente SIN teléfono/email del propietario -- decisión del CEO,
// noviembre 2026: se mantiene la privacidad actual.
import 'package:flutter/material.dart';
import 'package:repara_core/presupuesto.dart';

import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/ios_list.dart';
import 'registro_pro_detail_screen.dart';
import 'trabajo_pro_agregado.dart';

class ClienteProDetailScreen extends StatelessWidget {
  const ClienteProDetailScreen({
    required this.casaId,
    required this.casaNombre,
    super.key,
  });

  final String casaId;
  final String casaNombre;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(casaNombre)),
      body: TrabajosProAgregadosBuilder(
        builder: (context, todos, cargando) {
          final trabajos = todos.where((t) => t.ref.casaId == casaId).toList()
            ..sort(
              (a, b) => (b.registro?.fecha ?? DateTime(2000)).compareTo(
                a.registro?.fecha ?? DateTime(2000),
              ),
            );

          if (!cargando && trabajos.isEmpty) {
            return const EmptyHint(
              message: 'No se encuentran trabajos de este cliente.',
              icon: Icons.house_outlined,
            );
          }

          final activos = trabajos
              .where(
                (t) =>
                    t.columna != ColumnaTableroPro.terminado &&
                    t.columna != ColumnaTableroPro.archivado,
              )
              .length;
          final finalizados = trabajos
              .where((t) => t.columna == ColumnaTableroPro.terminado)
              .length;
          final presupuestosEnviados = trabajos.fold<int>(
            0,
            (acc, t) =>
                acc +
                t.presupuestos
                    .where((p) => p.estado == EstadoPresupuesto.enviado)
                    .length,
          );
          final presupuestosAceptados = trabajos
              .where((t) => t.presupuestoAceptado != null)
              .length;
          final totalAcordado = trabajos.fold<double>(
            0,
            (acc, t) => acc + (t.montoDebido ?? 0),
          );
          final totalCobrado = trabajos.fold<double>(
            0,
            (acc, t) => acc + t.totalPagado,
          );
          final pendienteCobro = trabajos.fold<double>(
            0,
            (acc, t) => acc + (t.saldoPendiente ?? 0),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              IosSection(
                rows: [
                  IosRow(
                    icon: Icons.house_outlined,
                    iconColor: context.colors.brand,
                    title: casaNombre,
                    subtitle:
                        '${trabajos.length} trabajo${trabajos.length == 1 ? '' : 's'} en total',
                    showChevron: false,
                  ),
                ],
              ),
              Text('Resumen', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              IosSection(
                rows: [
                  IosValueRow(label: 'Trabajos activos', value: '$activos'),
                  IosValueRow(
                    label: 'Trabajos finalizados',
                    value: '$finalizados',
                  ),
                  IosValueRow(
                    label: 'Presupuestos enviados',
                    value: '$presupuestosEnviados',
                  ),
                  IosValueRow(
                    label: 'Presupuestos aceptados',
                    value: '$presupuestosAceptados',
                  ),
                  IosValueRow(
                    label: 'Total acordado',
                    value: '${totalAcordado.toStringAsFixed(2)} €',
                  ),
                  IosValueRow(
                    label: 'Total cobrado',
                    value: '${totalCobrado.toStringAsFixed(2)} €',
                  ),
                  IosValueRow(
                    label: 'Pendiente de cobro',
                    value: '${pendienteCobro.toStringAsFixed(2)} €',
                    destacado: pendienteCobro > 0,
                  ),
                ],
              ),
              const SizedBox(height: ReparaSpace.s5),
              Text(
                'Historial de trabajos',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (trabajos.isEmpty)
                const EmptyHint(
                  message: 'Sin trabajos todavía.',
                  icon: Icons.build_outlined,
                )
              else
                IosSection(
                  rows: trabajos
                      .map(
                        (t) => IosRow(
                          icon: Icons.build_outlined,
                          iconColor: context.colors.brand,
                          imageUrl: t.ref.fotoUrl,
                          title: t.ref.registroTitulo,
                          subtitle: nombreColumnaTableroPro(t.columna),
                          trailing: (t.saldoPendiente ?? 0) > 0
                              ? Text(
                                  '${t.saldoPendiente!.toStringAsFixed(2)} €',
                                  style: ReparaText.amount(context),
                                )
                              : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegistroProDetailScreen(
                                casaId: t.ref.casaId,
                                elementoId: t.ref.elementoId,
                                registroId: t.ref.registroId,
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
