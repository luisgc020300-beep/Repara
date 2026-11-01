// lib/screens/documentos_casa_screen.dart
//
// "La sección de documentos" (sección 2 del spec) a nivel de casa completa
// -- incluye los guardados como borrador y los que no están ligados a
// ningún elemento o registro concreto, para que nunca queden invisibles.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../services/documento_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/documento_abrir.dart';
import '../widgets/ios_list.dart';
import 'nuevo_documento_flow.dart';

class DocumentosCasaScreen extends StatelessWidget {
  const DocumentosCasaScreen({required this.casa, super.key});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('CASA', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, color: Colors.white70)),
            Text('Documentos', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26, color: Colors.white)),
          ],
        ),
      ),
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
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: context.colors.brandTint, shape: BoxShape.circle),
                      child: Icon(Icons.folder_open_outlined, size: 32, color: context.colors.brand),
                    ),
                    const SizedBox(height: 16),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            children: [
              IosSection(
                rows: documentos.map((d) {
                  final borrador = d.estadoIA == EstadoIA.pendiente;
                  return IosRow(
                    icon: _iconoTipo(d.tipo),
                    iconColor: context.colors.brand,
                    title: d.proveedor ?? d.nombreArchivo,
                    subtitle: d.fecha != null ? DateFormat('d MMM yyyy', 'es_ES').format(d.fecha!) : null,
                    showChevron: false,
                    trailing: borrador || d.importe != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (borrador)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: context.colors.sand.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(ReparaRadius.pill)),
                                  child: Text('BORRADOR', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: context.colors.ink)),
                                ),
                              if (borrador && d.importe != null) const SizedBox(height: 4),
                              if (d.importe != null) Text('${d.importe!.toStringAsFixed(0)} €', style: ReparaText.amount(context)),
                            ],
                          )
                        : null,
                    onTap: () => mostrarAccionesDocumento(context, casaId: casa.id, documento: d),
                  );
                }).toList(),
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
