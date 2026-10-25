// lib/screens/documentos_casa_screen.dart
//
// "La sección de documentos" (sección 2 del spec) a nivel de casa completa
// -- incluye los guardados como borrador y los que no están ligados a
// ningún elemento o registro concreto, para que nunca queden invisibles.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/service_locator.dart';
import '../models/casa.dart';
import '../models/documento.dart';
import '../services/documento_service.dart';
import '../services/security/biometric_service.dart';
import '../services/security/security_preferences_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';
import 'elemento_detail_screen.dart';
import 'nuevo_documento_flow.dart';
import 'registro_detail_screen.dart';

class DocumentosCasaScreen extends StatelessWidget {
  const DocumentosCasaScreen({required this.casa, super.key});

  final Casa casa;

  // Breadcrumb tocable al elemento/registro de origen (auditoría de
  // producto, octubre 2026) -- si no tiene ninguno de los dos, se abre el
  // propio archivo en vez de no hacer nada al tocarlo.
  Future<void> _abrir(BuildContext context, Documento d) async {
    if (d.registroId != null && d.elementoId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RegistroDetailScreen(casa: casa, elementoId: d.elementoId!, registroId: d.registroId!)));
      return;
    }
    if (d.elementoId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: d.elementoId!)));
      return;
    }
    // Abrir el archivo en sí (factura, garantía...) es el contenido sensible
    // -- a diferencia de navegar al elemento/registro de origen, que solo
    // enseña metadatos (sección 6 de la misión de seguridad local).
    if (await SecurityPreferencesService.instance.isDocumentProtectionEnabled()) {
      final verificado = await sl<BiometricService>().authenticate('Verifica tu identidad para abrir este documento') ==
          BiometricAuthResult.success;
      if (!verificado) return;
    }
    if (!context.mounted) return;
    final uri = Uri.tryParse(d.url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) AppError.show(context, 'No se pudo abrir el documento.');
    }
  }

  // Mantener pulsado para eliminar -- mismo gesto que el resto de listas
  // de iOS cuando no hay sitio para un botón de borrar permanente en cada
  // fila (aquí el "trailing" ya está ocupado por el importe/BORRADOR).
  Future<void> _eliminar(BuildContext context, Documento d) async {
    final confirmar = await AppDialog.confirmText(
      context,
      title: '¿Eliminar este documento?',
      message: 'Se borrará de forma permanente. No afecta al elemento ni al registro de origen.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmar || !context.mounted) return;
    try {
      await DocumentoService.eliminar(casa.id, d.id);
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(context, 'No se pudo eliminar el documento.', error: e, stackTrace: st);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('CASA', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, color: context.colors.inkMuted)),
            Text('Documentos', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26)),
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
                  return GestureDetector(
                    onLongPress: () => _eliminar(context, d),
                    child: IosRow(
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
                      onTap: () => _abrir(context, d),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Mantén pulsado un documento para eliminarlo.',
                  style: TextStyle(fontSize: 12, color: context.colors.inkMuted),
                ),
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
