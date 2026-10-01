// lib/widgets/boton_notificaciones.dart
import 'package:flutter/material.dart';

import '../models/notificacion.dart';
import '../screens/notificaciones_screen.dart';
import '../services/notificacion_service.dart';

class BotonNotificaciones extends StatelessWidget {
  const BotonNotificaciones({required this.modoPro, super.key});

  /// true en las pestañas de Repara Pro, false en las de Hogar -- así cada
  /// lado solo ve (y cuenta como no leídas) sus propias notificaciones.
  final bool modoPro;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Notificacion>>(
      stream: NotificacionService.streamMisNotificaciones(),
      builder: (context, snapshot) {
        final mias = (snapshot.data ?? []).where((n) => n.esParaProfesional == modoPro);
        final noLeidas = mias.where((n) => !n.leida).length;
        return IconButton(
          tooltip: 'Notificaciones',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificacionesScreen(modoPro: modoPro))),
          icon: Badge(
            label: Text('$noLeidas'),
            isLabelVisible: noLeidas > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}
