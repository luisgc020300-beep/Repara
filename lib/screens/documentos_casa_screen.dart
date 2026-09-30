// lib/screens/documentos_casa_screen.dart
//
// "La sección de documentos" (sección 2 del spec) a nivel de casa completa
// -- incluye los guardados como borrador y los que no están ligados a
// ningún elemento o trabajo concreto, para que nunca queden invisibles.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../services/documento_service.dart';
import '../theme/design_tokens.dart';
import 'nuevo_documento_flow.dart';

class DocumentosCasaScreen extends StatelessWidget {
  const DocumentosCasaScreen({required this.casa, super.key});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => iniciarNuevoDocumento(context, casaId: casa.id),
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Escanear documento'),
      ),
      body: StreamBuilder<List<Documento>>(
        stream: DocumentoService.streamTodos(casa.id),
        builder: (context, snapshot) {
          final documentos = snapshot.data ?? [];
          if (documentos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open_outlined, size: 32, color: context.colors.inkMuted),
                    const SizedBox(height: 10),
                    Text(
                      'Todavía no has guardado ningún documento.\nFotografía una factura, garantía o presupuesto para empezar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.inkMuted),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documentos.length,
            itemBuilder: (context, i) {
              final d = documentos[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(_iconoTipo(d.tipo)),
                  title: Text(d.proveedor ?? d.nombreArchivo),
                  subtitle: Text([
                    if (d.fecha != null) DateFormat('d MMM yyyy', 'es_ES').format(d.fecha!),
                    if (d.estadoIA == EstadoIA.pendiente) 'Borrador',
                  ].join(' · ')),
                  trailing: d.importe != null ? Text('${d.importe!.toStringAsFixed(0)} €') : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

IconData _iconoTipo(TipoDocumento t) => switch (t) {
      TipoDocumento.factura => Icons.receipt_long_outlined,
      TipoDocumento.presupuesto => Icons.request_quote_outlined,
      TipoDocumento.garantia => Icons.shield_outlined,
      TipoDocumento.manual => Icons.menu_book_outlined,
      TipoDocumento.contrato => Icons.description_outlined,
      TipoDocumento.otro => Icons.insert_drive_file_outlined,
    };
