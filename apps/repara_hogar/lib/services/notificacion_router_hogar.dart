// apps/repara_hogar/lib/services/notificacion_router_hogar.dart
//
// Version Hogar de lib/services/notificacion_router.dart (monolito) -- no
// se puede compartir entre apps porque cada una importa pantallas
// exclusivas de su lado (alli RegistroProDetailScreen de Pro, aqui
// RegistroDetailScreen de Hogar). Solo cubre los destinos de REPARA Hogar.
import 'package:flutter/material.dart';
import 'package:repara_core/documento_gate.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_ui/pago_detail_screen.dart';

import '../screens/registro_detail_screen.dart';
import 'casa_service.dart';

Future<void> abrirDestinoNotificacionHogar(
  BuildContext context, {
  required String tipo,
  String? casaId,
  String? elementoId,
  String? registroId,
  String? pagoId,
}) async {
  if (!context.mounted) return;
  // Todavia no hay ningun registro real al que ir -- la solicitud de
  // vinculacion ya se ve en la seccion de Inicio. Basta con volver ahi.
  if (tipo == 'invitacion_hogar_recibida') {
    Navigator.popUntil(context, (route) => route.isFirst);
    return;
  }
  if (casaId == null || elementoId == null || registroId == null) return;

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

  final casa = await CasaService.streamCasa(casaId).first;
  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => RegistroDetailScreen(casa: casa, elementoId: elementoId, registroId: registroId)),
  );
}
