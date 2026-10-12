// lib/screens/pro/registro_pro_detail_screen.dart
//
// Vista de un registro desde el lado del profesional (sección 12 del spec).
// El profesional gestiona estado, presupuestos formales, cambios de alcance
// y documentos -- pero solo de ESTE registro, nunca del resto de la casa ni
// del elemento padre (ver firestore.rules: el acceso está condicionado a
// profesionalUid == su uid, y Registro.elementoNombre va denormalizado para
// no necesitar leer el elemento).
import 'package:flutter/material.dart';

import '../../models/documento.dart';
import '../../models/registro.dart';
import '../../services/documento_service.dart';
import '../../services/pago_service.dart';
import '../../services/registro_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';
import '../../widgets/progreso_pago.dart';
import '../cambio_alcance_section.dart';
import '../nuevo_documento_flow.dart';
import '../pagos_section.dart';
import '../presupuestos_section.dart';

class RegistroProDetailScreen extends StatelessWidget {
  const RegistroProDetailScreen({required this.casaId, required this.elementoId, required this.registroId, super.key});

  final String casaId;
  final String elementoId;
  final String registroId;

  Future<void> _finalizar(BuildContext context, Registro registro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como finalizado'),
        content: const Text('Se le pedirá al propietario que confirme que el registro está terminado -- todavía no se cierra hasta que lo haga.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Marcar como finalizado')),
        ],
      ),
    );
    if (confirmar != true) return;

    // Mismo aviso no bloqueante que en el lado del propietario: al
    // profesional también le interesa no perder de vista un cobro
    // pendiente, pero no se le impide cerrar el registro por ello.
    if (registro.presupuesto != null) {
      final pagado = await PagoService.totalPagado(casaId, elementoId, registroId);
      if (pagado < registro.presupuesto! && context.mounted) {
        final seguir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('El cliente todavía no ha pagado del todo'),
            content: Text(
              'Lleva pagado ${pagado.toStringAsFixed(2)} € de ${registro.presupuesto!.toStringAsFixed(2)} €. '
              '¿Quieres finalizar igualmente?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar igualmente')),
            ],
          ),
        );
        if (seguir != true) return;
      }
    }
    if (!context.mounted) return;
    try {
      await RegistroService.marcarFinalizadoProfesional(casaId, elementoId, registroId);
      if (context.mounted) AppError.showSuccess(context, 'Esperando a que el propietario lo confirme.');
    } catch (e, st) {
      if (context.mounted) AppError.show(context, 'No se pudo marcar el registro como finalizado.', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Registro?>(
      stream: RegistroService.streamRegistro(casaId, elementoId, registroId),
      builder: (context, snapshot) {
        final registro = snapshot.data;
        if (registro == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 68,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  registro.elementoNombre.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.colors.inkMuted),
                ),
                Text(registro.titulo, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 22), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          floatingActionButton: _estadoControlado(registro.estado)
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _finalizar(context, registro),
                  icon: const Icon(Icons.check),
                  label: const Text('Finalizar'),
                ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (registro.estado == EstadoRegistro.pendienteConfirmacion) ...[
                Card(
                  color: context.colors.warning.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_top_outlined, color: context.colors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Esperando a que el propietario confirme que está terminado.',
                            style: TextStyle(color: context.colors.ink, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (registro.descripcion != null) ...[
                Text(registro.descripcion!),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // "Terminado"/"Archivado"/"PendienteConfirmacion" nunca
                      // son una opción aquí -- solo se alcanzan a través de
                      // "Finalizar" (auditoría de seguridad, octubre 2026).
                      // El servidor ya lo bloquea aunque se fuerce desde fuera
                      // de la app, pero antes el desplegable seguía
                      // mostrando las opciones como tocables en un registro ya
                      // cerrado (auditoría de producto, octubre 2026). Ahora,
                      // si ya está en un estado controlado, el campo se
                      // deshabilita del todo.
                      if (_estadoControlado(registro.estado))
                        TextFormField(
                          key: ValueKey(registro.estado),
                          initialValue: _nombreEstado(registro.estado),
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Estado',
                            helperText: switch (registro.estado) {
                              EstadoRegistro.pendienteConfirmacion => 'Esperando confirmación del propietario',
                              _ => 'Ya está finalizado',
                            },
                          ),
                        )
                      else
                        DropdownButtonFormField<EstadoRegistro>(
                          initialValue: registro.estado,
                          decoration: const InputDecoration(labelText: 'Estado'),
                          items: _estadosEditables
                              .map((e) => DropdownMenuItem(value: e, child: Text(_nombreEstado(e))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) RegistroService.actualizarEstado(casaId, elementoId, registroId, v);
                          },
                        ),
                      if (registro.presupuesto != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Presupuesto acordado: ', style: TextStyle(color: context.colors.inkMuted)),
                            Text('${registro.presupuesto!.toStringAsFixed(2)} €', style: ReparaText.amount(context)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ProgresoPago(casaId: casaId, elementoId: elementoId, registroId: registroId, presupuesto: registro.presupuesto!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              PresupuestosSection(casaId: casaId, elementoId: elementoId, registroId: registroId, rol: RolEnTrabajo.profesional),
              const SizedBox(height: 20),
              CambiosAlcanceSection(
                casaId: casaId,
                elementoId: elementoId,
                registroId: registroId,
                rol: RolEnTrabajo.profesional,
                registroCerrado: registro.estado == EstadoRegistro.terminado || registro.estado == EstadoRegistro.archivado,
              ),
              const SizedBox(height: 20),
              PagosSection(
                casaId: casaId,
                elementoId: elementoId,
                registroId: registroId,
                registroTitulo: registro.titulo,
                presupuesto: registro.presupuesto,
                rol: RolEnTrabajo.profesional,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Documentos', style: Theme.of(context).textTheme.headlineSmall),
                  TextButton.icon(
                    onPressed: () => iniciarNuevoDocumento(context, casaId: casaId, elementoId: elementoId, registroId: registroId),
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    label: const Text('Añadir'),
                  ),
                ],
              ),
              StreamBuilder<List<Documento>>(
                stream: DocumentoService.streamDocumentos(casaId, registroId: registroId),
                builder: (context, snapshot) {
                  final documentos = snapshot.data ?? [];
                  if (documentos.isEmpty) {
                    return Text('Sin documentos todavía.', style: TextStyle(color: context.colors.inkMuted));
                  }
                  return Column(
                    children: documentos
                        .map((d) => Card(
                              margin: const EdgeInsets.only(bottom: 9),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(color: context.colors.brandTint, borderRadius: BorderRadius.circular(ReparaRadius.sm)),
                                      child: Icon(Icons.insert_drive_file_outlined, size: 20, color: context.colors.brand),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(d.proveedor ?? d.nombreArchivo, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    if (d.importe != null) Text('${d.importe!.toStringAsFixed(0)} €', style: ReparaText.amount(context)),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Solo ves este registro -- no tienes acceso al resto de la casa ni a su historial completo.',
                style: TextStyle(color: context.colors.inkMuted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _estadoControlado(EstadoRegistro e) =>
    e == EstadoRegistro.terminado || e == EstadoRegistro.archivado || e == EstadoRegistro.pendienteConfirmacion;

String _nombreEstado(EstadoRegistro e) => switch (e) {
      EstadoRegistro.nuevo => 'Nuevo',
      EstadoRegistro.presupuestado => 'Presupuestado',
      EstadoRegistro.enCurso => 'En curso',
      EstadoRegistro.pendienteConfirmacion => 'Pendiente de confirmación',
      EstadoRegistro.terminado => 'Terminado',
      EstadoRegistro.archivado => 'Archivado',
    };

const _estadosEditables = [EstadoRegistro.nuevo, EstadoRegistro.presupuestado, EstadoRegistro.enCurso];
