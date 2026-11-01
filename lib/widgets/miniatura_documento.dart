// lib/widgets/miniatura_documento.dart
//
// Miniatura clicable de un documento/comprobante ya guardado (CEO,
// noviembre 2026: "en editar documento, ya sea factura, presupuesto o
// pagos, también quiero que aparezca una imagen del documento clicable y
// se amplíe al clicarla"). Una imagen se amplía con FotoAmpliadaScreen --
// igual que la foto de un elemento/registro, sin gate biométrico (ese gate
// es solo para abrir el ARCHIVO en sí, ver documento_abrir.dart). Un PDF no
// se puede previsualizar inline, así que se abre con el visor externo
// protegido de siempre.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'documento_abrir.dart';
import 'foto_ampliada_screen.dart';

class MiniaturaDocumento extends StatelessWidget {
  const MiniaturaDocumento({
    required this.url,
    required this.nombreArchivo,
    super.key,
  });

  final String url;
  final String nombreArchivo;

  bool get _esPdf =>
      nombreArchivo.toLowerCase().endsWith('.pdf') ||
      url.toLowerCase().contains('.pdf');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_esPdf) {
          abrirArchivoProtegido(context, url);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FotoAmpliadaScreen(url: url)),
          );
        }
      },
      child: Container(
        height: 150,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ReparaRadius.md),
          border: Border.all(color: context.colors.border),
        ),
        child: _esPdf
            ? Container(
                color: context.colors.surfaceMuted,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 32,
                      color: context.colors.inkMuted,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ver documento PDF',
                      style: TextStyle(
                        color: context.colors.inkMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: context.colors.surfaceMuted),
                errorWidget: (context, url, error) => Container(
                  color: context.colors.surfaceMuted,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: context.colors.inkMuted,
                  ),
                ),
              ),
      ),
    );
  }
}
