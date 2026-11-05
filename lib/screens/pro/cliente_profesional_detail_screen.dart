// lib/screens/pro/cliente_profesional_detail_screen.dart
//
// Ficha de un cliente PRIVADO del profesional (Fase 1, noviembre 2026):
// datos de contacto + lista de sus trabajos privados + botón para crear
// uno nuevo. Distinta de ClienteProDetailScreen, que es la ficha de un
// cliente derivado de trabajos compartidos con REPARA Hogar -- aquí no hay
// ninguna casa ni propietario detrás todavía (eso es la vinculación de una
// fase futura, no implementada en esta).
import 'package:flutter/material.dart';

import '../../models/cliente_profesional.dart';
import '../../models/trabajo_profesional.dart';
import '../../services/cliente_profesional_service.dart';
import '../../services/trabajo_profesional_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_error.dart';
import '../../widgets/ios_list.dart';
import 'cliente_profesional_sheet.dart';
import 'trabajo_profesional_sheet.dart';

class ClienteProfesionalDetailScreen extends StatelessWidget {
  const ClienteProfesionalDetailScreen({required this.cliente, super.key});

  final ClienteProfesional cliente;

  Future<void> _editar(BuildContext context) async {
    await mostrarEditorClienteProfesional(context, existente: cliente);
  }

  Future<void> _eliminar(BuildContext context) async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Eliminar este cliente?',
      message:
          'Sus trabajos privados no se borran, pero dejarán de estar agrupados bajo este cliente.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmar) return;
    try {
      await ClienteProfesionalService.eliminar(cliente.id);
      if (context.mounted) Navigator.pop(context);
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo eliminar el cliente.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _nuevoTrabajo(BuildContext context) async {
    await mostrarEditorTrabajoProfesional(
      context,
      clienteId: cliente.id,
      clienteNombre: cliente.nombre,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(cliente.nombre),
        actions: [
          IconButton(
            tooltip: 'Editar cliente',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editar(context),
          ),
          IconButton(
            tooltip: 'Eliminar cliente',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _eliminar(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nuevoTrabajo(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo trabajo'),
      ),
      body: StreamBuilder<List<TrabajoProfesional>>(
        stream: TrabajoProfesionalService.streamTrabajosDeCliente(cliente.id),
        builder: (context, snapshot) {
          final trabajos = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, ReparaSpace.s4, 16, 90),
            children: [
              IosSection(
                rows: [
                  if (cliente.telefono != null)
                    IosRow(
                      icon: Icons.call_outlined,
                      iconColor: context.colors.brand,
                      title: cliente.telefono!,
                      subtitle: 'Teléfono',
                      showChevron: false,
                    ),
                  if (cliente.email != null)
                    IosRow(
                      icon: Icons.email_outlined,
                      iconColor: context.colors.brand,
                      title: cliente.email!,
                      subtitle: 'Email',
                      showChevron: false,
                    ),
                  if (cliente.direccion != null)
                    IosRow(
                      icon: Icons.place_outlined,
                      iconColor: context.colors.brand,
                      title: cliente.direccion!,
                      subtitle: 'Dirección',
                      showChevron: false,
                    ),
                  if (cliente.notas != null)
                    IosRow(
                      icon: Icons.notes_outlined,
                      iconColor: context.colors.brand,
                      title: cliente.notas!,
                      subtitle: 'Notas',
                      showChevron: false,
                    ),
                ],
              ),
              const SizedBox(height: ReparaSpace.s5),
              Text(
                'Trabajos',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (trabajos.isEmpty)
                const EmptyHint(
                  message: 'Sin trabajos todavía con este cliente.',
                  icon: Icons.build_outlined,
                )
              else
                IosSection(
                  rows: trabajos
                      .map(
                        (t) => IosRow(
                          icon: Icons.build_outlined,
                          iconColor: context.colors.brand,
                          title: t.titulo,
                          subtitle: nombreEstadoTrabajoProfesional(t.estado),
                          trailing: t.presupuestoEstimado != null
                              ? Text(
                                  '${t.presupuestoEstimado!.toStringAsFixed(0)} €',
                                  style: ReparaText.amount(context),
                                )
                              : null,
                          onTap: () => mostrarEditorTrabajoProfesional(
                            context,
                            existente: t,
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
