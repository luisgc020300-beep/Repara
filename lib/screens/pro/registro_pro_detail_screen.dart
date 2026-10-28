// lib/screens/pro/registro_pro_detail_screen.dart
//
// Vista de un registro desde el lado del profesional (sección 12 del spec).
// El profesional gestiona estado, presupuestos formales, cambios de alcance
// y documentos -- pero solo de ESTE registro, nunca del resto de la casa ni
// del elemento padre (ver firestore.rules: el acceso está condicionado a
// profesionalUid == su uid, y Registro.elementoNombre va denormalizado para
// no necesitar leer el elemento).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/documento.dart';
import '../../models/registro.dart';
import '../../services/documento_service.dart';
import '../../services/pago_service.dart';
import '../../services/registro_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_error.dart';
import '../../widgets/estado_registro_chip.dart';
import '../../widgets/ios_list.dart';
import '../../widgets/progreso_pago.dart';
import '../cambio_alcance_section.dart';
import '../nuevo_documento_flow.dart';
import '../pagos_section.dart';
import '../presupuestos_section.dart';

class RegistroProDetailScreen extends StatelessWidget {
  const RegistroProDetailScreen({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
    super.key,
  });

  final String casaId;
  final String elementoId;
  final String registroId;

  Future<void> _finalizar(BuildContext context, Registro registro) async {
    final confirmar = await AppDialog.confirm(
      context,
      title: 'Marcar como finalizado',
      message:
          'Se le pedirá al propietario que confirme que el evento está terminado -- todavía no se cierra hasta que lo haga.',
      confirmLabel: 'Marcar como finalizado',
    );
    if (!confirmar) return;

    // Mismo aviso no bloqueante que en el lado del propietario: al
    // profesional también le interesa no perder de vista un cobro
    // pendiente, pero no se le impide cerrar el registro por ello.
    if (registro.presupuesto != null) {
      final pagado = await PagoService.totalPagado(
        casaId,
        elementoId,
        registroId,
      );
      if (pagado < registro.presupuesto! && context.mounted) {
        final seguir = await AppDialog.confirm(
          context,
          title: 'El cliente todavía no ha pagado del todo',
          message:
              'Lleva pagado ${pagado.toStringAsFixed(2)} € de ${registro.presupuesto!.toStringAsFixed(2)} €. '
              '¿Quieres finalizar igualmente?',
          confirmLabel: 'Finalizar igualmente',
        );
        if (!seguir) return;
      }
    }
    if (!context.mounted) return;
    try {
      await RegistroService.marcarFinalizadoProfesional(
        casaId,
        elementoId,
        registroId,
      );
      if (context.mounted) {
        AppError.showSuccess(
          context,
          'Esperando a que el propietario lo confirme.',
        );
      }
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo marcar el evento como finalizado.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Registro?>(
      stream: RegistroService.streamRegistro(casaId, elementoId, registroId),
      builder: (context, snapshot) {
        // Mismo fix que elemento_detail_screen.dart/registro_detail_screen.
        // dart (auditoría R3/R4, octubre 2026) -- ver el comentario completo
        // en registro_detail_screen.dart. Aquí importa igual o más: el
        // profesional pierde el acceso de lectura (permission-denied) en
        // cuanto esMiembroCasa/profesionalUid deja de cumplirse (p.ej. si el
        // propietario revoca la asignación), y eso no debe confundirse con
        // "el registro ya no existe".
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('No se pudo cargar este evento.'),
            ),
          );
        }
        final registro = snapshot.data;
        if (registro == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Este evento ya no existe.')),
          );
        }
        return Scaffold(
          // Una sola línea, mismo patrón que registro_detail_screen.dart
          // (icono + Flexible), pero con "elementoNombre · tipo" en vez de
          // casa.nombre -- el profesional no tiene acceso de lectura a la
          // casa (ver nota de cabecera del archivo), así que elementoNombre
          // (ya denormalizado en el propio registro) es el único contexto
          // identificativo disponible sin tocar permisos ni consultas.
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconoTipoRegistro(registro.tipo),
                  size: 14,
                  color: context.colors.inkMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    registro.elementoNombre.isEmpty
                        ? nombreTipoRegistro(registro.tipo)
                        : '${registro.elementoNombre} · ${nombreTipoRegistro(registro.tipo)}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
              // Título completo aquí, no en el AppBar -- mismo criterio que
              // registro_detail_screen.dart (el AppBar ya muestra el
              // contexto breve de elemento+tipo, el título grande vive en
              // el cuerpo para no duplicarlo en dos sitios a la vez).
              Text(
                registro.titulo,
                style: Theme.of(context).textTheme.displaySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  EstadoRegistroChip(estado: registro.estado),
                  const SizedBox(width: 8),
                  Text(
                    '· ${DateFormat('d MMM yyyy', 'es_ES').format(registro.fecha)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (registro.estado == EstadoRegistro.pendienteConfirmacion) ...[
                const AvisoRegistro(
                  mensaje:
                      'Esperando a que el propietario confirme que está terminado.',
                ),
                const SizedBox(height: 16),
              ],
              if (registro.descripcion != null) ...[
                Text(
                  registro.descripcion!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
              ],
              // "Terminado"/"Archivado"/"PendienteConfirmacion" nunca son una
              // opción aquí -- solo se alcanzan a través de "Finalizar"
              // (auditoría de seguridad, octubre 2026). El servidor ya lo
              // bloquea aunque se fuerce desde fuera de la app, pero antes el
              // desplegable seguía mostrando las opciones como tocables en un
              // registro ya cerrado (auditoría de producto, octubre 2026).
              // Ahora, si ya está en un estado controlado, el campo se
              // deshabilita del todo. Autocontenido por el propio
              // InputDecorationTheme, sin Card envolvente (mismo criterio que
              // el lado de Hogar).
              if (_estadoControlado(registro.estado))
                TextFormField(
                  key: ValueKey(registro.estado),
                  initialValue: nombreEstadoRegistro(registro.estado),
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Estado',
                    helperText: switch (registro.estado) {
                      EstadoRegistro.pendienteConfirmacion =>
                        'Esperando confirmación del propietario',
                      _ => 'Ya está finalizado',
                    },
                  ),
                )
              else
                DropdownButtonFormField<EstadoRegistro>(
                  initialValue: registro.estado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: _estadosEditables
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(nombreEstadoRegistro(e)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      RegistroService.actualizarEstado(
                        casaId,
                        elementoId,
                        registroId,
                        v,
                      );
                    }
                  },
                ),
              if (registro.presupuesto != null) ...[
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Presupuesto acordado',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.colors.inkMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${registro.presupuesto!.toStringAsFixed(0)} €',
                          style: ReparaText.amount(context, large: true),
                        ),
                        const SizedBox(height: 14),
                        ProgresoPago(
                          casaId: casaId,
                          elementoId: elementoId,
                          registroId: registroId,
                          presupuesto: registro.presupuesto!,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              PresupuestosSection(
                casaId: casaId,
                elementoId: elementoId,
                registroId: registroId,
                rol: RolEnTrabajo.profesional,
              ),
              const SizedBox(height: 20),
              CambiosAlcanceSection(
                casaId: casaId,
                elementoId: elementoId,
                registroId: registroId,
                rol: RolEnTrabajo.profesional,
                registroCerrado:
                    registro.estado == EstadoRegistro.terminado ||
                    registro.estado == EstadoRegistro.archivado,
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
                  Text(
                    'Documentos',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  TextButton.icon(
                    onPressed: () => iniciarNuevoDocumento(
                      context,
                      casaId: casaId,
                      elementoId: elementoId,
                      registroId: registroId,
                    ),
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    label: const Text('Añadir'),
                  ),
                ],
              ),
              StreamBuilder<List<Documento>>(
                stream: DocumentoService.streamDocumentos(
                  casaId,
                  registroId: registroId,
                ),
                builder: (context, snapshot) {
                  final documentos = snapshot.data ?? [];
                  if (documentos.isEmpty) {
                    return const EmptyHint(
                      message: 'Sin documentos todavía.',
                      icon: Icons.description_outlined,
                    );
                  }
                  return IosSection(
                    rows: documentos
                        .map(
                          (d) => IosRow(
                            icon: Icons.insert_drive_file_outlined,
                            iconColor: context.colors.brand,
                            title: d.proveedor ?? d.nombreArchivo,
                            trailing: d.importe != null
                                ? Text(
                                    '${d.importe!.toStringAsFixed(0)} €',
                                    style: ReparaText.amount(context),
                                  )
                                : null,
                            showChevron: false,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Solo ves este evento -- no tienes acceso al resto de la casa ni a su historial completo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _estadoControlado(EstadoRegistro e) =>
    e == EstadoRegistro.terminado ||
    e == EstadoRegistro.archivado ||
    e == EstadoRegistro.pendienteConfirmacion;

const _estadosEditables = [
  EstadoRegistro.nuevo,
  EstadoRegistro.presupuestado,
  EstadoRegistro.enCurso,
];
