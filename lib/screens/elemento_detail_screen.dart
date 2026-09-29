// lib/screens/elemento_detail_screen.dart
//
// Ficha de un elemento (sección 11 del spec) -- una de las seis pantallas
// que el spec marca como "estrella" porque representan la propuesta de
// valor: convertir un aparato suelto en una identidad digital con su propio
// historial y documentación.
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
import 'nuevo_documento_flow.dart';
import 'nuevo_evento_sheet.dart';

class ElementoDetailScreen extends StatelessWidget {
  const ElementoDetailScreen({required this.casa, required this.elementoId, super.key});

  final Casa casa;
  final String elementoId;

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
              _FichaCard(elemento: elemento),
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
                  return Column(
                    children: eventos
                        .map((e) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(e.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(DateFormat('d MMM yyyy', 'es_ES').format(e.fecha)),
                                trailing: e.coste != null ? Text('${e.coste!.toStringAsFixed(0)} €') : null,
                              ),
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
                    onPressed: () => iniciarNuevoDocumento(context, casaId: casa.id, elementoId: elemento.id),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir'),
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
                  return Column(
                    children: documentos.map((d) => _DocumentoTile(documento: d)).toList(),
                  );
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
  const _FichaCard({required this.elemento});

  final Elemento elemento;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (elemento.marca != null)
              _Fila(label: 'Marca / modelo', valor: '${elemento.marca} ${elemento.modelo ?? ''}'.trim()),
            if (elemento.fechaInstalacion != null)
              _Fila(label: 'Instalado', valor: DateFormat('d MMMM yyyy', 'es_ES').format(elemento.fechaInstalacion!)),
            if (elemento.coste != null) _Fila(label: 'Coste', valor: '${elemento.coste!.toStringAsFixed(0)} €'),
            if (elemento.profesionalNombre != null) _Fila(label: 'Profesional', valor: elemento.profesionalNombre!),
            if (elemento.garantiaHasta != null)
              _Fila(
                label: 'Garantía hasta',
                valor: DateFormat('d MMMM yyyy', 'es_ES').format(elemento.garantiaHasta!),
                destacado: elemento.garantiaProximaAVencer,
              ),
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.label, required this.valor, this.destacado = false});

  final String label;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(color: context.colors.inkMuted))),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: destacado ? context.colors.warning : context.colors.ink,
              ),
            ),
          ),
        ],
      ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_icono),
        title: Text(documento.proveedor ?? documento.nombreArchivo),
        subtitle: documento.fecha != null ? Text(DateFormat('d MMM yyyy', 'es_ES').format(documento.fecha!)) : null,
        trailing: documento.importe != null ? Text('${documento.importe!.toStringAsFixed(0)} €') : null,
      ),
    );
  }
}
