// packages/repara_ui/lib/cita_section.dart
//
// "Cita" del trabajo (CEO, noviembre 2026: "que el propietario pueda
// responder de verdad, no solo aceptar la fecha que ponga el profesional,
// y que tenga más protagonismo que una línea del historial"). Mismo
// espíritu que cambio_alcance_section.dart: el profesional propone (desde
// su agenda, ver agenda_pro_tab.dart -- esa pantalla no vive en este
// paquete compartido), el propietario confirma, rechaza o propone otra
// fecha/hora -- y esta vez sí puede, a diferencia de antes. Las tres
// acciones del propietario son Cloud Functions
// (CitaService.responderComoPropietario/proponerOtraFecha) porque cruzan
// de su cuenta a un documento del profesional; aceptar o no la
// contrapropuesta es escritura directa del profesional sobre su propio
// documento (CitaService.responderContrapropuesta).
//
// Puede haber varias citas por trabajo (visitas repetidas) -- una tarjeta
// por cada una, igual que CambiosAlcanceSection lista varios cambios.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:repara_core/cita.dart';
import 'package:repara_core/cita_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/registro.dart' show RolEnTrabajo;

import 'app_error.dart';

class CitaSeccion extends StatelessWidget {
  const CitaSeccion({
    required this.profesionalUid,
    required this.registroId,
    required this.rol,
    this.registroCerrado = false,
    super.key,
  });

  final String profesionalUid;
  final String registroId;
  final RolEnTrabajo rol;

  /// Mismo criterio que CambiosAlcanceSection: un registro cerrado no
  /// admite nuevas respuestas -- el servidor ya lo bloquearía, esto solo
  /// evita mostrar un botón que terminaría en un error evitable.
  final bool registroCerrado;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cita>>(
      stream: CitaService.streamCitasCompartidas(
        profesionalUid: profesionalUid,
        registroId: registroId,
      ),
      builder: (context, snapshot) {
        final citas = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cita', style: Theme.of(context).textTheme.headlineSmall),
            if (citas.isEmpty)
              const EmptyHint(
                message: 'Sin citas programadas para este trabajo.',
                icon: Icons.event_outlined,
              )
            else
              ...citas.map(
                (c) => _CitaCard(
                  profesionalUid: profesionalUid,
                  cita: c,
                  rol: rol,
                  registroCerrado: registroCerrado,
                ),
              ),
          ],
        );
      },
    );
  }
}

String _nombreEstado(EstadoCita e) => switch (e) {
  EstadoCita.pendienteConfirmacion => 'Pendiente de confirmar',
  EstadoCita.confirmada => 'Confirmada',
  EstadoCita.rechazada => 'Rechazada',
  EstadoCita.contrapropuestaPropietario => 'Propones otra fecha',
};

String _formatoFecha(DateTime fecha, bool todoElDia) => todoElDia
    ? DateFormat('d MMM yyyy', 'es_ES').format(fecha)
    : DateFormat('d MMM yyyy · HH:mm', 'es_ES').format(fecha);

class _CitaCard extends StatefulWidget {
  const _CitaCard({
    required this.profesionalUid,
    required this.cita,
    required this.rol,
    this.registroCerrado = false,
  });

  final String profesionalUid;
  final Cita cita;
  final RolEnTrabajo rol;
  final bool registroCerrado;

  @override
  State<_CitaCard> createState() => _CitaCardState();
}

class _CitaCardState extends State<_CitaCard> {
  // Mismo motivo que _CambioCardState: el servidor ya bloquea una segunda
  // respuesta, pero sin este guard un doble toque en una conexión lenta
  // enseñaba un error confuso por una acción ya completada.
  bool _procesando = false;

  Color _color(BuildContext context) => switch (widget.cita.estado) {
    EstadoCita.pendienteConfirmacion => context.colors.warningText,
    EstadoCita.confirmada => context.colors.successText,
    EstadoCita.rechazada => context.colors.errorText,
    EstadoCita.contrapropuestaPropietario => context.colors.warningText,
  };

  // BuildContext explícito como parámetro, no el getter heredado de
  // State -- mismo motivo que _responder(BuildContext, bool)/_cancelar
  // (BuildContext) en cambio_alcance_section.dart: el análisis de "no uses
  // un BuildContext tras un await" promueve una variable local comprobada
  // con `.mounted`, pero NO un getter que se vuelve a invocar cada vez.
  Future<void> _confirmarORechazar(BuildContext context, bool confirmar) async {
    setState(() => _procesando = true);
    try {
      await CitaService.responderComoPropietario(
        profesionalUid: widget.profesionalUid,
        citaId: widget.cita.id,
        confirmar: confirmar,
      );
    } on FirebaseFunctionsException catch (e, st) {
      if (context.mounted) {
        AppError.show(context, e.message ?? 'No se pudo completar la acción.', error: e, stackTrace: st);
      }
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(context, 'No se pudo completar la acción.', error: e, stackTrace: st);
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _proponerOtraFecha(BuildContext context) async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: widget.cita.fecha.isAfter(ahora) ? widget.cita.fecha : ahora,
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365)),
    );
    if (fecha == null || !context.mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.cita.fecha),
    );
    if (hora == null || !context.mounted) return;
    final fechaHora = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);

    setState(() => _procesando = true);
    try {
      await CitaService.proponerOtraFecha(
        profesionalUid: widget.profesionalUid,
        citaId: widget.cita.id,
        fecha: fechaHora,
      );
      if (context.mounted) AppError.showSuccess(context, 'Propuesta enviada al profesional.');
    } on FirebaseFunctionsException catch (e, st) {
      if (context.mounted) {
        AppError.show(context, e.message ?? 'No se pudo enviar la propuesta.', error: e, stackTrace: st);
      }
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(context, 'No se pudo enviar la propuesta.', error: e, stackTrace: st);
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /// El profesional no edita la fecha desde aquí (esta tarjeta vive en el
  /// paquete compartido, sin acceso al editor de su agenda) -- declinar
  /// solo limpia el estado y le deja claro que tiene que proponer la fecha
  /// nueva desde su agenda.
  Future<void> _responderContrapropuesta(BuildContext context, bool aceptar) async {
    setState(() => _procesando = true);
    try {
      await CitaService.responderContrapropuesta(citaId: widget.cita.id, aceptar: aceptar);
      if (context.mounted) {
        AppError.showSuccess(
          context,
          aceptar ? 'Cita confirmada con la nueva fecha.' : 'Ahora puedes proponer otra fecha desde tu agenda.',
        );
      }
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(context, 'No se pudo completar la acción.', error: e, stackTrace: st);
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cita = widget.cita;
    final puedeActuar = !widget.registroCerrado && !_procesando;
    return Card(
      margin: const EdgeInsets.only(bottom: ReparaSpace.s2),
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(cita.titulo, style: Theme.of(context).textTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _color(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(ReparaRadius.pill),
                  ),
                  child: Text(
                    _nombreEstado(cita.estado).toUpperCase(),
                    style: TextStyle(color: _color(context), fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s1),
            Text(_formatoFecha(cita.fecha, cita.todoElDia), style: Theme.of(context).textTheme.bodyLarge),
            if (cita.descripcion != null) ...[
              const SizedBox(height: ReparaSpace.s1),
              Text(cita.descripcion!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (cita.estado == EstadoCita.contrapropuestaPropietario && cita.fechaPropuestaPropietario != null) ...[
              const SizedBox(height: ReparaSpace.s2),
              Text(
                widget.rol == RolEnTrabajo.propietario
                    ? 'Esperando respuesta del profesional sobre: ${_formatoFecha(cita.fechaPropuestaPropietario!, false)}'
                    : 'El propietario propone: ${_formatoFecha(cita.fechaPropuestaPropietario!, false)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.warningText),
              ),
            ],
            if (cita.estado == EstadoCita.pendienteConfirmacion && widget.rol == RolEnTrabajo.propietario && !widget.registroCerrado) ...[
              const SizedBox(height: ReparaSpace.s3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: puedeActuar ? () => _confirmarORechazar(context, false) : null,
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: ReparaSpace.s2),
                  Expanded(
                    child: FilledButton(
                      onPressed: puedeActuar ? () => _confirmarORechazar(context, true) : null,
                      child: _procesando
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Confirmar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ReparaSpace.s2),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: puedeActuar ? () => _proponerOtraFecha(context) : null,
                  child: const Text('Proponer otra fecha'),
                ),
              ),
            ],
            if (cita.estado == EstadoCita.contrapropuestaPropietario && widget.rol == RolEnTrabajo.profesional && !widget.registroCerrado) ...[
              const SizedBox(height: ReparaSpace.s3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: puedeActuar ? () => _responderContrapropuesta(context, false) : null,
                      child: const Text('No, proponer otra'),
                    ),
                  ),
                  const SizedBox(width: ReparaSpace.s2),
                  Expanded(
                    child: FilledButton(
                      onPressed: puedeActuar ? () => _responderContrapropuesta(context, true) : null,
                      child: _procesando
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Aceptar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
