// lib/screens/notificaciones_preferencias_screen.dart
//
// Preferencias de notificación (sección 6 del encargo de avisos
// inteligentes, noviembre 2026). Cada categoría apaga tanto la notificación
// interna como la push para esos tipos; "Notificaciones push" es un
// interruptor aparte que solo afecta al envío por FCM -- desactivarlo nunca
// quita el acceso al historial interno (ver crearNotificacion en
// functions/index.js). Los avisos de seguridad/permisos (invitación
// aceptada/rechazada) no aparecen aquí: nunca se pueden silenciar.
import 'package:flutter/material.dart';
import 'package:repara_core/notificacion_service.dart';

import 'package:repara_core/design_tokens.dart';
import '../widgets/ios_list.dart';

const _categorias = [
  (clave: 'citas', titulo: 'Citas', subtitulo: 'Visitas programadas y sus recordatorios'),
  (clave: 'presupuestos', titulo: 'Presupuestos', subtitulo: 'Nuevos presupuestos y respuestas'),
  (clave: 'pagos', titulo: 'Pagos', subtitulo: 'Pagos registrados y saldo pendiente'),
  (clave: 'cambios', titulo: 'Cambios de estado', subtitulo: 'Cambios de alcance, finalización, archivado'),
  (clave: 'documentos', titulo: 'Documentos', subtitulo: 'Facturas, fotos y garantías añadidas'),
];

class NotificacionesPreferenciasScreen extends StatelessWidget {
  const NotificacionesPreferenciasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: NotificacionService.streamPreferencias(),
        builder: (context, snapshot) {
          final prefs = snapshot.data ?? const {};
          bool activada(String clave) => prefs[clave] != false;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              IosSection(
                header: 'Avisos internos y push',
                footer:
                    'Los avisos de seguridad (p.ej. que un profesional acepte o rechace una invitación) nunca se desactivan.',
                rows: [
                  for (final c in _categorias)
                    IosRow(
                      icon: _iconoCategoria(c.clave),
                      iconColor: context.colors.brand,
                      title: c.titulo,
                      subtitle: c.subtitulo,
                      showChevron: false,
                      trailing: Switch(
                        value: activada(c.clave),
                        onChanged: (v) => NotificacionService.actualizarPreferencia(c.clave, v),
                      ),
                    ),
                ],
              ),
              IosSection(
                header: 'Push',
                footer:
                    'Desactivarlo no quita el acceso a tus notificaciones dentro de la app, solo el aviso en el móvil.',
                rows: [
                  IosRow(
                    icon: Icons.notifications_active_outlined,
                    iconColor: context.colors.brand,
                    title: 'Notificaciones push',
                    subtitle: 'Avisos en el móvil aunque no tengas la app abierta',
                    showChevron: false,
                    trailing: Switch(
                      value: prefs['pushHabilitado'] != false,
                      onChanged: (v) => NotificacionService.actualizarPreferencia('pushHabilitado', v),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

IconData _iconoCategoria(String clave) => switch (clave) {
      'citas' => Icons.event_outlined,
      'presupuestos' => Icons.request_quote_outlined,
      'pagos' => Icons.payments_outlined,
      'cambios' => Icons.rule_outlined,
      'documentos' => Icons.description_outlined,
      _ => Icons.notifications_outlined,
    };
