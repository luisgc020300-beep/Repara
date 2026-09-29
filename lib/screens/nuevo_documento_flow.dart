// lib/screens/nuevo_documento_flow.dart
//
// Flujo de "Añadir documento" con clasificación por IA (secciones 22-23 del
// spec de producto). La IA solo SUGIERE -- el propietario siempre ve y
// puede corregir cada campo antes de guardar nada (sección 61: nunca se
// asume información no confirmada por el usuario).
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/documento.dart';
import '../services/documento_service.dart';
import '../widgets/app_error.dart';

Future<void> iniciarNuevoDocumento(
  BuildContext context, {
  required String casaId,
  String? elementoId,
  String? trabajoId,
  List<String> elementosDisponibles = const [],
}) async {
  final picker = ImagePicker();
  final foto = await showModalBottomSheet<XFile?>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Hacer una foto'),
          onTap: () async {
            final navigator = Navigator.of(ctx);
            final imagen = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
            navigator.pop(imagen);
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Elegir de la galería'),
          onTap: () async {
            final navigator = Navigator.of(ctx);
            final imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
            navigator.pop(imagen);
          },
        ),
      ]),
    ),
  );
  if (foto == null || !context.mounted) return;

  final archivo = File(foto.path);
  final mediaType = foto.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

  SugerenciaIA? sugerencia;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      content: Row(children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 16),
        Text('Analizando documento…'),
      ]),
    ),
  );
  try {
    sugerencia = await DocumentoService.clasificarConIA(
      archivo,
      mediaType: mediaType,
      elementosDisponibles: elementosDisponibles,
    );
  } catch (e) {
    sugerencia = null;
  } finally {
    if (context.mounted) Navigator.pop(context);
  }

  if (!context.mounted) return;
  final resultado = await showModalBottomSheet<_DatosDocumentoConfirmados>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _ConfirmarDocumentoSheet(sugerencia: sugerencia),
  );
  if (resultado == null || !context.mounted) return;

  try {
    final url = await DocumentoService.subirArchivo(casaId, archivo, foto.name);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await DocumentoService.crear(
      casaId,
      Documento(
        id: '',
        url: url,
        nombreArchivo: foto.name,
        tipo: resultado.tipo,
        fecha: resultado.fecha,
        proveedor: resultado.proveedor,
        importe: resultado.importe,
        elementoId: elementoId,
        trabajoId: trabajoId,
        estadoIA: sugerencia != null ? EstadoIA.confirmado : EstadoIA.manual,
      ),
      createdBy: uid,
    );
    if (context.mounted) AppError.showSuccess(context, 'Documento guardado.');
  } catch (e) {
    if (context.mounted) AppError.show(context, 'No se pudo guardar el documento.');
  }
}

class _DatosDocumentoConfirmados {
  const _DatosDocumentoConfirmados({required this.tipo, this.fecha, this.proveedor, this.importe});
  final TipoDocumento tipo;
  final DateTime? fecha;
  final String? proveedor;
  final double? importe;
}

class _ConfirmarDocumentoSheet extends StatefulWidget {
  const _ConfirmarDocumentoSheet({this.sugerencia});

  final SugerenciaIA? sugerencia;

  @override
  State<_ConfirmarDocumentoSheet> createState() => _ConfirmarDocumentoSheetState();
}

class _ConfirmarDocumentoSheetState extends State<_ConfirmarDocumentoSheet> {
  late TipoDocumento _tipo = widget.sugerencia?.tipo ?? TipoDocumento.otro;
  late final _proveedorCtrl = TextEditingController(text: widget.sugerencia?.proveedor ?? '');
  late final _importeCtrl = TextEditingController(
    text: widget.sugerencia?.importe != null ? widget.sugerencia!.importe!.toStringAsFixed(2) : '',
  );
  late DateTime? _fecha = widget.sugerencia?.fecha;

  @override
  void dispose() {
    _proveedorCtrl.dispose();
    _importeCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    Navigator.pop(
      context,
      _DatosDocumentoConfirmados(
        tipo: _tipo,
        fecha: _fecha,
        proveedor: _proveedorCtrl.text.trim().isEmpty ? null : _proveedorCtrl.text.trim(),
        importe: double.tryParse(_importeCtrl.text.replaceAll(',', '.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.sugerencia != null ? 'Repara cree que esto es:' : 'No hemos podido leer el documento automáticamente',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text('Revisa y corrige lo que haga falta antes de guardar.'),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoDocumento>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: TipoDocumento.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(_nombreTipoDoc(t))))
                  .toList(),
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: 12),
            TextField(controller: _proveedorCtrl, decoration: const InputDecoration(labelText: 'Proveedor / profesional')),
            const SizedBox(height: 12),
            TextField(
              controller: _importeCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Importe (€)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final elegida = await showDatePicker(
                  context: context,
                  initialDate: _fecha ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (elegida != null) setState(() => _fecha = elegida);
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(_fecha == null ? 'Fecha del documento' : '${_fecha!.day}/${_fecha!.month}/${_fecha!.year}'),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _confirmar, child: const Text('Guardar documento')),
          ],
        ),
      ),
    );
  }
}

String _nombreTipoDoc(TipoDocumento t) => switch (t) {
      TipoDocumento.factura => 'Factura',
      TipoDocumento.presupuesto => 'Presupuesto',
      TipoDocumento.garantia => 'Garantía',
      TipoDocumento.manual => 'Manual',
      TipoDocumento.contrato => 'Contrato',
      TipoDocumento.otro => 'Otro',
    };
