// lib/screens/documentos_casa_screen.dart
//
// "La sección de documentos" (sección 2 del spec) a nivel de casa completa
// -- incluye los guardados como borrador y los que no están ligados a
// ningún elemento o trabajo concreto, para que nunca queden invisibles.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../services/documento_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';
import 'elemento_detail_screen.dart';
import 'nuevo_documento_flow.dart';
import 'trabajo_detail_screen.dart';

class DocumentosCasaScreen extends StatelessWidget {
  const DocumentosCasaScreen({required this.casa, super.key});

  final Casa casa;

  // Breadcrumb tocable al elemento/trabajo de origen (auditoría de
  // producto, octubre 2026) -- si no tiene ninguno de los dos, se abre el
  // propio archivo en vez de no hacer nada al tocarlo.
  Future<void> _abrir(BuildContext context, Documento d) async {
    if (d.elementoId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: d.elementoId!)));
      return;
    }
    if (d.trabajoId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TrabajoDetailScreen(casa: casa, trabajoId: d.trabajoId!)));
      return;
    }
    final uri = Uri.tryParse(d.url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) AppError.show(context, 'No se pudo abrir el documento.');
    }
  }

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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              IosSection(
                rows: documentos
                    .map((d) => IosRow(
                          icon: _iconoTipo(d.tipo),
                          iconColor: Colors.blue,
                          title: d.proveedor ?? d.nombreArchivo,
                          subtitle: [
                            if (d.fecha != null) DateFormat('d MMM yyyy', 'es_ES').format(d.fecha!),
                            if (d.estadoIA == EstadoIA.pendiente) 'Borrador',
                          ].join(' · '),
                          trailing: d.importe != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${d.importe!.toStringAsFixed(0)} €'),
                                    const SizedBox(width: 6),
                                    Icon(Icons.chevron_right, color: context.colors.inkMuted, size: 20),
                                  ],
                                )
                              : null,
                          onTap: () => _abrir(context, d),
                        ))
                    .toList(),
              ),
            ],
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
