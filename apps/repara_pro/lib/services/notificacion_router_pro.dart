// apps/repara_pro/lib/services/notificacion_router_pro.dart
//
// Versión Pro de lib/services/notificacion_router.dart (monolito) -- no se
// puede compartir entre apps porque cada una importa pantallas exclusivas
// de su lado (allí RegistroDetailScreen de Hogar, aquí RegistroProDetailScreen).
// Solo cubre los destinos que existen en REPARA Pro.
import 'package:flutter/material.dart';
import 'package:repara_core/documento_gate.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_ui/pago_detail_screen.dart';

import '../screens/registro_pro_detail_screen.dart';
import '../screens/repara_pro_shell_screen.dart';

Future<void> abrirDestinoNotificacionPro(
  BuildContext context, {
  required String tipo,
  String? casaId,
  String? elementoId,
  String? registroId,
  String? pagoId,
}) async {
  if (!context.mounted) return;
  // El propietario ha rechazado la vinculación -- no hay ningún registro
  // real al que ir (el vínculo nunca llegó a crearse), así que se lleva al
  // profesional a la pestaña Trabajos, donde sigue viendo su trabajo
  // privado (ahora ya no pendiente de vincular). pushAndRemoveUntil en vez
  // de push: aquí el shell es la app entera, no una pantalla a la que se
  // entra -- evita apilar un segundo shell encima del que ya está montado.
  if (tipo == 'invitacion_hogar_rechazada') {
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute(
        builder: (_) => const ReparaProShellScreen(initialIndex: 1),
      ),
      (route) => false,
    );
    return;
  }
  if (casaId == null || elementoId == null || registroId == null) return;

  // "Te han registrado un pago" lleva directo al detalle de ESE pago, no
  // solo al registro -- mismo criterio que notificacion_router.dart.
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

  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => RegistroProDetailScreen(casaId: casaId, elementoId: elementoId, registroId: registroId),
    ),
  );
}
