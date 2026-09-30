// lib/widgets/boton_notificaciones.dart
import 'package:flutter/material.dart';

import '../models/notificacion.dart';
import '../screens/notificaciones_screen.dart';
import '../services/notificacion_service.dart';

class BotonNotificaciones extends StatelessWidget {
  const BotonNotificaciones({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Notificacion>>(
      stream: NotificacionService.streamMisNotificaciones(),
      builder: (context, snapshot) {
        final noLeidas = (snapshot.data ?? []).where((n) => !n.leida).length;
        return IconButton(
          tooltip: 'Notificaciones',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen())),
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
