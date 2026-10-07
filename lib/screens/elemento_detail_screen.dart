// lib/screens/elemento_detail_screen.dart
//
// Ficha de un elemento (sección 11 del spec) -- una de las seis pantallas
// que el spec marca como "estrella" porque representan la propuesta de
// valor: convertir un aparato suelto en una identidad digital con su propio
// historial y documentación.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../models/elemento.dart';
import '../models/evento.dart';
import '../services/documento_service.dart';
import '../services/elemento_service.dart';
import '../services/evento_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';
import 'nuevo_documento_flow.dart';
import 'nuevo_evento_sheet.dart';
import 'trabajo_detail_screen.dart';

class ElementoDetailScreen extends StatelessWidget {
  const ElementoDetailScreen({required this.casa, required this.elementoId, super.key});

  final Casa casa;
  final String elementoId;

  Future<void> _editarMantenimiento(BuildContext context, Elemento elemento) async {
    final intervaloCtrl = TextEditingController(text: elemento.intervaloMantenimientoMeses?.toString() ?? '');
    DateTime? proxima = elemento.proximoMantenimiento;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Revisión periódica'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: intervaloCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Revisar cada cuántos meses'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final elegida = await showDatePicker(
                    context: ctx,
                    initialDate: proxima ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (elegida != null) setStateDialog(() => proxima = elegida);
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(proxima == null ? 'Próxima revisión' : '${proxima!.day}/${proxima!.month}/${proxima!.year}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (guardar != true) return;
    try {
      await ElementoService.actualizarMantenimiento(
        casa.id,
        elemento.id,
        intervaloMeses: int.tryParse(intervaloCtrl.text.trim()),
        proximoMantenimiento: proxima,
      );
    } catch (e) {
      if (context.mounted) AppError.show(context, 'No se pudo guardar la revisión periódica.');
    }
  }

  Future<void> _marcarRevisionHecha(BuildContext context, Elemento elemento) async {
    final intervalo = elemento.intervaloMantenimientoMeses;
    if (intervalo == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await EventoService.crear(
        casa.id,
        Evento(
          id: '',
          tipo: TipoEvento.revision,
          titulo: 'Revisión periódica · ${elemento.nombre}',
          elementoId: elemento.id,
          habitacionId: elemento.habitacionId,
          fecha: DateTime.now(),
        ),
        createdBy: uid,
      );
      await ElementoService.marcarRevisionHecha(casa.id, elemento.id, intervalo);
      if (context.mounted) AppError.showSuccess(context, 'Revisión registrada. Próxima en $intervalo meses.');
    } catch (e) {
      if (context.mounted) AppError.show(context, 'No se pudo registrar la revisión.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Elemento?>(
      stream: ElementoService.streamElemento(casa.id, elementoId),
      builder: (context, snapshot) {
        final elemento = snapshot.data;
        if (elemento == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(elemento.nombre),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Eliminar elemento?'),
                      content: const Text('Se eliminará la ficha, no su historial ya registrado.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
                      ],
                    ),
                  );
                  if (confirmar == true) {
                    await ElementoService.eliminar(casa.id, elemento.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => mostrarNuevoEventoSheet(context, casaId: casa.id, elementoId: elemento.id),
            icon: const Icon(Icons.add),
            label: const Text('Registrar mantenimiento'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _FichaCard(elemento: elemento, onEditarMantenimiento: () => _editarMantenimiento(context, elemento)),
              if (elemento.intervaloMantenimientoMeses != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _marcarRevisionHecha(context, elemento),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Marcar revisión como hecha'),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Historial', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Evento>>(
                stream: EventoService.streamHistorial(casa.id, elementoId: elemento.id),
                builder: (context, snapshot) {
                  final eventos = snapshot.data ?? [];
                  if (eventos.isEmpty) {
                    return Text('Sin eventos todavía.', style: TextStyle(color: context.colors.inkMuted));
                  }
                  return IosSection(
                    rows: eventos
                        .map((e) => IosRow(
                              icon: Icons.fact_check_outlined,
                              iconColor: context.colors.brand,
                              title: e.titulo,
                              subtitle: DateFormat('d MMM yyyy', 'es_ES').format(e.fecha),
                              showChevron: e.trabajoId != null,
                              trailing: e.coste != null
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${e.coste!.toStringAsFixed(0)} €'),
                                        if (e.trabajoId != null) ...[
                                          const SizedBox(width: 6),
                                          Icon(Icons.chevron_right, color: context.colors.inkMuted, size: 20),
                                        ],
                                      ],
                                    )
                                  : null,
                              // Breadcrumb tocable al trabajo de origen, si lo
                              // tiene (auditoría de producto, octubre 2026) --
                              // no hace falta enlazar a este mismo elemento.
                              onTap: e.trabajoId != null
                                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrabajoDetailScreen(casa: casa, trabajoId: e.trabajoId!)))
                                  : null,
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Documentos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  TextButton.icon(
                    onPressed: () => iniciarNuevoDocumento(
                      context,
                      casaId: casa.id,
                      elementoId: elemento.id,
                      habitacionId: elemento.habitacionId,
                    ),
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    label: const Text('Escanear documento'),
                  ),
                ],
              ),
              StreamBuilder<List<Documento>>(
                stream: DocumentoService.streamDocumentos(casa.id, elementoId: elemento.id),
                builder: (context, snapshot) {
                  final documentos = snapshot.data ?? [];
                  if (documentos.isEmpty) {
                    return Text('Sin documentos todavía.', style: TextStyle(color: context.colors.inkMuted));
                  }
                  return IosSection(rows: documentos.map((d) => _DocumentoTile(documento: d)).toList());
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FichaCard extends StatelessWidget {
  const _FichaCard({required this.elemento, required this.onEditarMantenimiento});

  final Elemento elemento;
  final VoidCallback onEditarMantenimiento;

  @override
  Widget build(BuildContext context) {
    return IosSection(
      rows: [
        if (elemento.marca != null)
          IosValueRow(label: 'Marca / modelo', value: '${elemento.marca} ${elemento.modelo ?? ''}'.trim()),
        if (elemento.fechaInstalacion != null)
          IosValueRow(label: 'Instalado', value: DateFormat('d MMMM yyyy', 'es_ES').format(elemento.fechaInstalacion!)),
        if (elemento.coste != null) IosValueRow(label: 'Coste', value: '${elemento.coste!.toStringAsFixed(0)} €'),
        if (elemento.profesionalNombre != null) IosValueRow(label: 'Profesional', value: elemento.profesionalNombre!),
        if (elemento.garantiaHasta != null)
          IosValueRow(
            label: 'Garantía hasta',
            value: DateFormat('d MMMM yyyy', 'es_ES').format(elemento.garantiaHasta!),
            destacado: elemento.garantiaProximaAVencer,
          ),
        IosValueRow(
          label: 'Próxima revisión',
          value: elemento.proximoMantenimiento != null
              ? DateFormat('d MMMM yyyy', 'es_ES').format(elemento.proximoMantenimiento!)
              : 'Sin configurar',
          destacado: elemento.revisionPendiente,
          onTap: onEditarMantenimiento,
        ),
      ],
    );
  }
}

class _DocumentoTile extends StatelessWidget {
  const _DocumentoTile({required this.documento});

  final Documento documento;

  IconData get _icono => switch (documento.tipo) {
        TipoDocumento.factura => Icons.receipt_long_outlined,
        TipoDocumento.presupuesto => Icons.request_quote_outlined,
        TipoDocumento.garantia => Icons.shield_outlined,
        TipoDocumento.manual => Icons.menu_book_outlined,
        TipoDocumento.contrato => Icons.description_outlined,
        TipoDocumento.otro => Icons.insert_drive_file_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return IosRow(
      icon: _icono,
      iconColor: Colors.blue,
      title: documento.proveedor ?? documento.nombreArchivo,
      subtitle: documento.fecha != null ? DateFormat('d MMM yyyy', 'es_ES').format(documento.fecha!) : null,
      trailing: documento.importe != null ? Text('${documento.importe!.toStringAsFixed(0)} €') : null,
      showChevron: false,
    );
  }
}
