// lib/services/notificacion_router.dart
//
// Navegación compartida al abrir una notificación -- la misma lógica sirve
// tanto para la lista interna (notificaciones_screen.dart) como para tocar
// una notificación push de FCM (fcm_service.dart), para no duplicarla.
import 'package:flutter/material.dart';

import '../models/notificacion.dart';
import '../screens/pago_detail_screen.dart';
import '../screens/pro/registro_pro_detail_screen.dart';
import '../screens/registro_detail_screen.dart';
import 'casa_service.dart';
import 'pago_service.dart';
import 'registro_service.dart';

Future<void> abrirDestinoNotificacion(
  BuildContext context, {
  required String tipo,
  String? casaId,
  String? elementoId,
  String? registroId,
  String? pagoId,
}) async {
  if (casaId == null || elementoId == null || registroId == null || !context.mounted) return;
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
