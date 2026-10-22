// lib/screens/pro/inicio_pro_tab.dart
//
// Home del profesional (sección 40 del spec): resumen operativo, no una
// lista de funciones. En esta primera pasada el dato central son las
// invitaciones pendientes -- es la única acción que de verdad requiere
// atención inmediata en el flujo actual.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/invitacion.dart';
import '../../models/profesional.dart';
import '../../services/analytics_service.dart';
import '../../services/invitacion_service.dart';
import '../../services/profesional_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';
import '../../widgets/boton_ajustes.dart';
import '../../widgets/boton_notificaciones.dart';
import '../../widgets/ios_list.dart';

const _mensajeInvitarCliente =
    'Llevo el mantenimiento de tus trabajos con Repara -- así queda todo el historial, '
    'presupuestos y fotos organizados en un solo sitio, no perdido entre WhatsApps. '
    'Créate una cuenta gratis y así te puedo mandar presupuestos y avisarte de cambios directamente ahí.';

class InicioProTab extends StatelessWidget {
  const InicioProTab({super.key});

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
              'Repara Pro',
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(fontSize: 26),
            ),
          ],
        ),
        actions: const [
          BotonNotificaciones(modoPro: true),
          BotonAjustes(modoPro: true),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          StreamBuilder<List<RegistroProRef>>(
            stream: ProfesionalService.streamRegistrosProRefs(),
            builder: (context, snapshot) {
              final trabajos = snapshot.data ?? const <RegistroProRef>[];
              final totalCasas = trabajos.map((t) => t.casaId).toSet().length;
              return Card(
                margin: const EdgeInsets.only(bottom: ReparaSpace.s5),
                child: Padding(
                  padding: const EdgeInsets.all(ReparaSpace.s4),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: context.colors.brandTint,
                          borderRadius: BorderRadius.circular(ReparaRadius.sm),
                        ),
                        child: Icon(
                          Icons.build_outlined,
                          size: 22,
                          color: context.colors.brand,
                        ),
                      ),
                      const SizedBox(width: ReparaSpace.s4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${trabajos.length} trabajo${trabajos.length == 1 ? '' : 's'} activo${trabajos.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              totalCasas == 0
                                  ? 'Revisa la pestaña Trabajos para ver el detalle'
                                  : 'Repartidos en $totalCasas casa${totalCasas == 1 ? '' : 's'} distinta${totalCasas == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Text(
            'Invitaciones pendientes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Invitacion>>(
            stream: InvitacionService.streamPendientesParaMi(),
            builder: (context, snapshot) {
              final invitaciones = snapshot.data ?? [];
              if (invitaciones.isEmpty) {
                return const EmptyHint(
                  message: 'No tienes invitaciones nuevas.',
                  icon: Icons.mail_outline,
                );
              }
              return Column(
                children: invitaciones
                    .map((i) => _InvitacionCard(invitacion: i))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          IosSection(
            rows: [
              IosRow(
                icon: Icons.person_add_alt_outlined,
                iconColor: context.colors.brand,
                title: 'Invita a un cliente a Repara',
                subtitle:
                    'Para que puedas mandarle presupuestos y avisos desde aquí',
                trailing: Icon(
                  Icons.share_outlined,
                  size: 18,
                  color: context.colors.inkMuted,
                ),
                showChevron: false,
                // sharePositionOrigin obligatorio en iOS -- ver nota en
                // contacto_acciones.dart.
                onTap: () => Share.share(
                  _mensajeInvitarCliente,
                  sharePositionOrigin:
                      Offset.zero & MediaQuery.of(context).size,
                ),
              ),
            ],
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
      if (aceptar) unawaited(AnalyticsService.professionalInvitationAccepted());
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo responder a la invitación.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _respondiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: ReparaSpace.s2),
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.invitacion.registroTitulo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ReparaSpace.s1),
            Text(
              'en ${widget.invitacion.casaNombre}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: ReparaSpace.s3),
            _respondiendo
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _responder(false),
                          child: const Text('Rechazar'),
                        ),
                      ),
                      const SizedBox(width: ReparaSpace.s2),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _responder(true),
                          child: const Text('Aceptar'),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
