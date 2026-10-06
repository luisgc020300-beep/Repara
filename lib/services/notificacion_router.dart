// lib/services/notificacion_router.dart
//
// Navegación compartida al abrir una notificación -- la misma lógica sirve
// tanto para la lista interna (notificaciones_screen.dart) como para tocar
// una notificación push de FCM (fcm_service.dart), para no duplicarla.
import 'package:flutter/material.dart';

import '../models/notificacion.dart';
import '../screens/pago_detail_screen.dart';
import '../screens/pro/trabajo_pro_detail_screen.dart';
import '../screens/trabajo_detail_screen.dart';
import 'casa_service.dart';
import 'pago_service.dart';
import 'trabajo_service.dart';

Future<void> abrirDestinoNotificacion(
  BuildContext context, {
  required String tipo,
  String? casaId,
  String? trabajoId,
  String? pagoId,
}) async {
  if (casaId == null || trabajoId == null || !context.mounted) return;
  final modoPro = tipoEsParaProfesional(tipo);

  // "Te han registrado un pago" lleva directo al detalle de ESE pago, no
  // solo al trabajo -- es lo que el profesional quiere ver primero.
  if (tipo == 'pago_registrado' && pagoId != null) {
    final trabajo = await TrabajoService.streamTrabajo(casaId, trabajoId).first;
    final pago = await PagoService.obtenerPago(casaId, trabajoId, pagoId);
    if (!context.mounted || trabajo == null || pago == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PagoDetailScreen(
          casaId: casaId,
          trabajoId: trabajoId,
          trabajoTitulo: trabajo.titulo,
          presupuesto: trabajo.presupuesto,
          editable: false,
          pago: pago,
        ),
      ),
    );
    return;
  }

  if (modoPro) {
    // El profesional no es miembro de la casa (ver firestore.rules) -- solo
    // tiene acceso al trabajo concreto, no hace falta ni se puede leer la
    // casa entera.
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => TrabajoProDetailScreen(casaId: casaId, trabajoId: trabajoId)),
    );
    return;
  }
  final casa = await CasaService.streamCasa(casaId).first;
  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => TrabajoDetailScreen(casa: casa, trabajoId: trabajoId)),
  );
}
