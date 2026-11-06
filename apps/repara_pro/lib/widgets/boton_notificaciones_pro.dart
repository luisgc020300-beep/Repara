// apps/repara_pro/lib/widgets/boton_notificaciones_pro.dart
//
// Versión Pro de lib/widgets/boton_notificaciones.dart (monolito) -- sin el
// parámetro `casa` (exclusivo de Hogar) y siempre filtrando por
// esParaProfesional, ya que en esta app nunca hay otro rol.
import 'package:flutter/material.dart';
import 'package:repara_core/notificacion.dart';
import 'package:repara_core/notificacion_service.dart';

import '../screens/notificaciones_pro_screen.dart';

class BotonNotificacionesPro extends StatelessWidget {
  const BotonNotificacionesPro({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Notificacion>>(
      stream: NotificacionService.streamMisNotificaciones(),
      builder: (context, snapshot) {
        final mias = (snapshot.data ?? []).where((n) => n.esParaProfesional);
        final noLeidas = mias.where((n) => !n.leida).length;
        return IconButton(
          tooltip: 'Notificaciones',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificacionesProScreen()),
          ),
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
