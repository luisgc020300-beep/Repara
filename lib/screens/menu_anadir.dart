// lib/screens/menu_anadir.dart
//
// Menú compartido del botón "+" (sección 9 del spec): registrar un evento a
// mano o escanear un documento con IA. Usado desde Inicio e Historial.
import 'package:flutter/material.dart';

import 'nuevo_documento_flow.dart';
import 'nuevo_evento_sheet.dart';

Future<void> mostrarMenuAnadir(BuildContext context, {required String casaId}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.document_scanner_outlined),
          title: const Text('Escanear factura o documento'),
          subtitle: const Text('La IA rellena los datos por ti'),
          onTap: () {
            Navigator.pop(ctx);
            iniciarNuevoDocumento(context, casaId: casaId);
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit_note_outlined),
          title: const Text('Registrar evento a mano'),
          onTap: () {
            Navigator.pop(ctx);
            mostrarNuevoEventoSheet(context, casaId: casaId);
          },
        ),
      ]),
    ),
  );
}
