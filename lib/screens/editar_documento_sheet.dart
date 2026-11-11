// lib/screens/editar_documento_sheet.dart
//
// Corregir los datos de un documento ya guardado (CEO, noviembre 2026: "si
// he subido uno donde no era o me he equivocado en algo, cada documento
// debería ser editable"). Mismos campos/etiquetas que la revisión de un
// documento recién escaneado (nuevo_documento_flow.dart), pero sin ninguno
// de los pasos de creación (nada de "Documento original", aviso de la IA,
// duplicados, ni crear elemento/registro de paso) -- esto solo corrige los
// datos de un documento que ya existe. El archivo en sí (url/nombreArchivo)
// y a qué elemento/registro pertenece no se tocan aquí: eso es una
// reubicación, no una corrección de datos.
import 'package:flutter/material.dart';
import 'package:repara_core/documento.dart';
import 'package:repara_core/documento_service.dart';

import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/documento_gate.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/miniatura_documento.dart';
import 'package:repara_ui/seccion_formulario.dart';

Future<void> mostrarEditarDocumentoSheet(
  BuildContext context, {
  required String casaId,
  required Documento documento,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Con el formulario largo, la hoja crece hasta arriba del todo -- sin
    // esto, el título "Editar documento" quedaba debajo de la hora y la
    // batería (CEO, noviembre 2026). useSafeArea hace que la hoja se pare
    // justo debajo de la barra de estado.
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ReparaRadius.lg),
      ),
    ),
    builder: (ctx) =>
        _EditarDocumentoForm(casaId: casaId, documento: documento),
  );
}

class _EditarDocumentoForm extends StatefulWidget {
  const _EditarDocumentoForm({required this.casaId, required this.documento});

  final String casaId;
  final Documento documento;

  @override
  State<_EditarDocumentoForm> createState() => _EditarDocumentoFormState();
}

class _EditarDocumentoFormState extends State<_EditarDocumentoForm> {
  late TipoDocumento _tipo = widget.documento.tipo;
  late final _numeroCtrl = TextEditingController(
    text: widget.documento.numeroReferencia ?? '',
  );
  late final _proveedorCtrl = TextEditingController(
    text: widget.documento.proveedor ?? '',
  );
  late final _nifCtrl = TextEditingController(
    text: widget.documento.nifCif ?? '',
  );
  late final _baseCtrl = TextEditingController(
    text: _formatoImporte(widget.documento.baseImponible),
  );
  late final _impuestosCtrl = TextEditingController(
    text: _formatoImporte(widget.documento.impuestos),
  );
  late final _importeCtrl = TextEditingController(
    text: _formatoImporte(widget.documento.importe),
  );
  late final _descripcionCtrl = TextEditingController(
    text: widget.documento.descripcionTrabajo ?? '',
  );
  late final _garantiaCtrl = TextEditingController(
    text: widget.documento.garantiaTexto ?? '',
  );
  late final _observacionesCtrl = TextEditingController(
    text: widget.documento.observaciones ?? '',
  );
  late DateTime? _fecha = widget.documento.fecha;
  late DateTime? _fechaVencimiento = widget.documento.fechaVencimiento;
  bool _guardando = false;

  static String _formatoImporte(double? v) =>
      v == null ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

  static String _formatoFecha(DateTime f) => '${f.day}/${f.month}/${f.year}';

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _proveedorCtrl.dispose();
    _nifCtrl.dispose();
    _baseCtrl.dispose();
    _impuestosCtrl.dispose();
    _importeCtrl.dispose();
    _descripcionCtrl.dispose();
    _garantiaCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha({required bool vencimiento}) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: (vencimiento ? _fechaVencimiento : _fecha) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (elegida == null) return;
    setState(() {
      if (vencimiento) {
        _fechaVencimiento = elegida;
      } else {
        _fecha = elegida;
      }
    });
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.'));
  String? _texto(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    // Igual que editar_registro_sheet.dart: se escribe explícitamente null
    // (no se omite la clave) cuando un campo queda vacío -- un mapa parcial
    // a Firestore.update() solo toca las claves presentes, así que borrar
    // el texto de un campo y guardar debe mandar null explícito.
    final cambios = <String, dynamic>{
      'tipo': _tipo.name,
      'numeroReferencia': _texto(_numeroCtrl),
      'fecha': _fecha,
      'fechaVencimiento': _fechaVencimiento,
      'proveedor': _texto(_proveedorCtrl),
      'nifCif': _texto(_nifCtrl),
      'baseImponible': _num(_baseCtrl),
      'impuestos': _num(_impuestosCtrl),
      'importe': _num(_importeCtrl),
      'descripcionTrabajo': _texto(_descripcionCtrl),
      'garantiaTexto': _texto(_garantiaCtrl),
      'observaciones': _texto(_observacionesCtrl),
    };
    try {
      await DocumentoService.actualizar(
        widget.casaId,
        widget.documento.id,
        cambios,
      );
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudieron guardar los cambios.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: ReparaSpace.s5,
        right: ReparaSpace.s5,
        top: ReparaSpace.s5,
        // Teclado abierto (viewInsets) o, si no, la barra de inicio del
        // iPhone (padding) -- para que "Guardar cambios" nunca quede debajo.
        bottom:
            ReparaSpace.s5 +
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Editar documento',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: ReparaSpace.s4),
            if (widget.documento.url.isNotEmpty) ...[
              MiniaturaDocumento(
                url: widget.documento.url,
                nombreArchivo: widget.documento.nombreArchivo,
                verificarAcceso: verificarAccesoDocumento,
              ),
              const SizedBox(height: ReparaSpace.s4),
            ],
            SeccionFormulario(
              titulo: 'Información del documento',
              children: [
                DropdownButtonFormField<TipoDocumento>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: TipoDocumento.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(nombreTipoDocumento(t)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _tipo = v ?? _tipo),
                ),
                const SizedBox(height: ReparaSpace.s3),
                TextField(
                  controller: _numeroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Número de factura/referencia',
                  ),
                ),
                const SizedBox(height: ReparaSpace.s3),
                Row(
                  children: [
                    Expanded(
                      child: _BotonFecha(
                        icono: Icons.calendar_today_outlined,
                        texto: _fecha == null
                            ? 'Fecha'
                            : _formatoFecha(_fecha!),
                        onPressed: () => _elegirFecha(vencimiento: false),
                      ),
                    ),
                    const SizedBox(width: ReparaSpace.s3),
                    Expanded(
                      child: _BotonFecha(
                        icono: Icons.event_outlined,
                        texto: _fechaVencimiento == null
                            ? 'Vencimiento'
                            : _formatoFecha(_fechaVencimiento!),
                        onPressed: () => _elegirFecha(vencimiento: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ReparaSpace.s3),
                TextField(
                  controller: _proveedorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Profesional / empresa emisora',
                  ),
                ),
                const SizedBox(height: ReparaSpace.s3),
                TextField(
                  controller: _nifCtrl,
                  decoration: const InputDecoration(
                    labelText: 'NIF/CIF (opcional)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            SeccionFormulario(
              titulo: 'Información económica',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _baseCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Base imponible (€)',
                        ),
                      ),
                    ),
                    const SizedBox(width: ReparaSpace.s3),
                    Expanded(
                      child: TextField(
                        controller: _impuestosCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Impuestos (€)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ReparaSpace.s3),
                TextField(
                  controller: _importeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    labelText: 'Importe total (€)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            SeccionFormulario(
              titulo: 'Información del trabajo',
              children: [
                TextField(
                  controller: _descripcionCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del servicio/reparación',
                  ),
                ),
                const SizedBox(height: ReparaSpace.s3),
                TextField(
                  controller: _garantiaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Garantía indicada (opcional)',
                  ),
                ),
                const SizedBox(height: ReparaSpace.s3),
                TextField(
                  controller: _observacionesCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Observaciones'),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s5),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.brandOn,
                      ),
                    )
                  : const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de fecha de media anchura (Fecha / Vencimiento). El texto va
/// siempre en una sola línea y, si no cabe entero, se reduce un poco en vez
/// de partirse -- antes "Vencimiento" se cortaba en "Vencimient-o" en
/// pantallas estrechas (CEO, noviembre 2026). Padding horizontal más
/// ajustado que el de un OutlinedButton normal para dejarle más sitio.
class _BotonFecha extends StatelessWidget {
  const _BotonFecha({
    required this.icono,
    required this.texto,
    required this.onPressed,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      icon: Icon(icono, size: 16),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(texto, maxLines: 1, softWrap: false),
      ),
    );
  }
}