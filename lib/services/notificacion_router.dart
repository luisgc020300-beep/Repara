// lib/services/notificacion_router.dart
//
// Navegación compartida al abrir una notificación -- la misma lógica sirve
// tanto para la lista interna (notificaciones_screen.dart) como para tocar
// una notificación push de FCM (fcm_service.dart), para no duplicarla.
import 'package:flutter/material.dart';
import 'package:repara_core/notificacion.dart';

import '../screens/elemento_detail_screen.dart';
import '../screens/pro/registro_pro_detail_screen.dart';
import '../screens/pro/repara_pro_shell_screen.dart';
import '../screens/registro_detail_screen.dart';
import 'casa_service.dart';
import 'package:repara_core/documento_gate.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_ui/pago_detail_screen.dart';

Future<void> abrirDestinoNotificacion(
  BuildContext context, {
  required String tipo,
  String? casaId,
  String? elementoId,
  String? registroId,
  String? pagoId,
}) async {
  if (!context.mounted) return;
  // Todavía no hay ningún registro real al que ir -- la invitación está
  // pendiente, y ya se ve de forma prominente en la nueva sección
  // "Solicitudes de profesionales" de Inicio. Basta con volver ahí.
  if (tipo == 'invitacion_hogar_recibida') {
    Navigator.popUntil(context, (route) => route.isFirst);
    return;
  }
  // El propietario ha rechazado la vinculación -- no hay ningún registro
  // real al que ir (el vínculo nunca llegó a crearse), así que se lleva al
  // profesional a la pestaña Trabajos, donde sigue viendo su trabajo
  // privado (ahora ya no pendiente de vincular).
  if (tipo == 'invitacion_hogar_rechazada') {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const ReparaProShellScreen(initialIndex: 1),
      ),
    );
    return;
  }
  if (casaId == null || elementoId == null) return;

  // Avisos a nivel de elemento, sin un trabajo concreto detrás (garantía,
  // mantenimiento, elemento archivado/restaurado, sistema de
  // notificaciones activas de noviembre 2026) -- siempre del lado
  // propietario (ninguno de estos tipos es "para profesional"), así que va
  // directo a la ficha del elemento sin mirar modoPro.
  if (registroId == null) {
    final casa = await CasaService.streamCasa(casaId).first;
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: elementoId)),
    );
    return;
  }
  final modoPro = tipoEsParaProfesional(tipo);

  // "Te han registrado un pago" lleva directo al detalle de ESE pago, no
  // solo al registro -- es lo que el profesional quiere ver primero.
  if (tipo == 'pago_registrado' && pagoId != null) {
    final registro = await RegistroService.streamRegistro(casaId, elementoId, registroId).first;
    final pago = await PagoService.obtenerPago(casaId, elementoId, registroId, pagoId);
    if (!context.mounted || registro == null || pago == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PagoDetailScreen(
          casaId: casaId,
          elementoId: elementoId,
          registroId: registroId,
          registroTitulo: registro.titulo,
          presupuesto: registro.presupuesto,
          editable: false,
          pago: pago,
          verificarAcceso: verificarAccesoDocumento,
        ),
      ),
    );
    return;
  }

  if (modoPro) {
    // El profesional no es miembro de la casa (ver firestore.rules) -- solo
    // tiene acceso al registro concreto, no hace falta ni se puede leer la
    // casa entera.
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => RegistroProDetailScreen(casaId: casaId, elementoId: elementoId, registroId: registroId)),
    );
    return;
  }
  final casa = await CasaService.streamCasa(casaId).first;
  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => RegistroDetailScreen(casa: casa, elementoId: elementoId, registroId: registroId)),
  );
}
