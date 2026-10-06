// lib/screens/nuevo_documento_flow.dart
//
// Flujo de "Escanear factura o documento" con extracción por IA (secciones
// 3-8 del spec de producto). La IA solo SUGIERE -- el propietario siempre ve
// y puede corregir cada campo en una pantalla de revisión completa antes de
// guardar nada (sección 61: nunca se asume información no confirmada).
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/documento.dart';
import '../models/elemento.dart';
import '../models/evento.dart';
import '../models/trabajo.dart';
import '../services/documento_service.dart';
import '../services/elemento_service.dart';
import '../services/evento_service.dart';
import '../services/trabajo_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';

Future<void> iniciarNuevoDocumento(
  BuildContext context, {
  required String casaId,
  String? elementoId,
  String? trabajoId,
  String? habitacionId,
}) async {
  final paginas = await _elegirPaginas(context);
  if (paginas == null || paginas.isEmpty || !context.mounted) return;

  final confirmadas = await Navigator.push<List<PaginaDocumento>>(
    context,
    MaterialPageRoute(builder: (_) => _VistaPreviaScreen(paginasIniciales: paginas)),
  );
  if (confirmadas == null || confirmadas.isEmpty || !context.mounted) return;

  // Un profesional invitado a un trabajo concreto no tiene permiso para
  // listar TODOS los elementos/trabajos de la casa (solo el suyo) -- en ese
  // caso se sigue sin listas de sugerencia en vez de reventar el flujo.
  List<Elemento> elementos = const [];
  List<Trabajo> trabajos = const [];
  try {
    elementos = await ElementoService.streamElementos(casaId).first;
    trabajos = await TrabajoService.streamTrabajos(casaId).first;
  } catch (e) {
    // sin acceso a las listas completas -- se continúa sin sugerencias.
  }
  if (!context.mounted) return;

  SugerenciaIA? sugerencia;
  String? errorIA;
  // OJO: no se hace `await` aquí -- este diálogo es solo un indicador de
  // carga (sin botones, sin cierre al tocar fuera) y se cierra a mano en el
  // finally de abajo. Si se espera a que showDialog se resuelva antes de
  // seguir, el código nunca llega a llamar a la IA (nada lo puede cerrar
  // antes) y el "Analizando documento…" se queda para siempre.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      content: Row(children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 16),
        Expanded(child: Text('Analizando documento…')),
      ]),
    ),
  );
  try {
    sugerencia = await DocumentoService.clasificarConIA(
      confirmadas,
      elementosDisponibles: elementos.map((e) => e.nombre).toList(),
      trabajosDisponibles: trabajos.map((t) => t.titulo).toList(),
    ).timeout(const Duration(seconds: 30));
  } on FirebaseFunctionsException catch (e) {
    // 'resource-exhausted' es el límite diario de IA -- su mensaje ya es
    // claro para el usuario, a diferencia del resto de fallos de red.
    errorIA = e.code == 'resource-exhausted'
        ? (e.message ?? 'Has alcanzado el límite diario de análisis con IA.')
        : 'No se pudo contactar con el servicio de IA. Puedes rellenar los datos a mano.';
  } catch (e) {
    errorIA = 'No se pudo contactar con el servicio de IA. Puedes rellenar los datos a mano.';
  } finally {
    if (context.mounted) Navigator.pop(context);
  }

  if (!context.mounted) return;
  if (errorIA != null) AppError.show(context, errorIA);

  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => _RevisionDocumentoScreen(
        casaId: casaId,
        paginas: confirmadas,
        sugerencia: sugerencia,
        elementos: elementos,
        trabajos: trabajos,
        elementoIdInicial: elementoId,
        trabajoIdInicial: trabajoId,
        habitacionIdInicial: habitacionId,
      ),
    ),
  );
}

// =============================================================================
// SELECCIÓN DE ORIGEN: cámara, galería (varias páginas) o archivo (PDF)
// =============================================================================
Future<List<PaginaDocumento>?> _elegirPaginas(BuildContext context) async {
  final picker = ImagePicker();
  return showModalBottomSheet<List<PaginaDocumento>>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Hacer una foto'),
          onTap: () async {
            final navigator = Navigator.of(ctx);
            final foto = await picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 85,
              maxWidth: 1600,
              maxHeight: 1600,
            );
            if (foto == null) return navigator.pop(null);
            navigator.pop([_paginaDesdeXFile(foto)]);
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Elegir de la galería'),
          subtitle: const Text('Puedes seleccionar varias fotos si el documento tiene varias páginas'),
          onTap: () async {
            final navigator = Navigator.of(ctx);
            final fotos = await picker.pickMultiImage(imageQuality: 85, maxWidth: 1600, maxHeight: 1600);
            if (fotos.isEmpty) return navigator.pop(null);
            navigator.pop(fotos.map(_paginaDesdeXFile).toList());
          },
        ),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text('Subir archivo (PDF o imagen)'),
          onTap: () async {
            final navigator = Navigator.of(ctx);
            final resultado = await FilePicker.platform.pickFiles(
              allowMultiple: true,
              type: FileType.custom,
              allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
            );
            final paths = resultado?.files.where((f) => f.path != null).map((f) => f.path!).toList() ?? [];
            if (paths.isEmpty) return navigator.pop(null);
            navigator.pop(paths.map(_paginaDesdeRuta).toList());
          },
        ),
      ]),
    ),
  );
}

PaginaDocumento _paginaDesdeXFile(XFile foto) => PaginaDocumento(
      archivo: File(foto.path),
      mediaType: foto.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
      nombre: foto.name,
    );

PaginaDocumento _paginaDesdeRuta(String ruta) {
  final extension = ruta.toLowerCase().split('.').last;
  final mediaType = switch (extension) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    _ => 'image/jpeg',
  };
  return PaginaDocumento(archivo: File(ruta), mediaType: mediaType, nombre: ruta.split(Platform.pathSeparator).last);
}

bool _esPdf(PaginaDocumento p) => p.mediaType == 'application/pdf';

// =============================================================================
// VISTA PREVIA: revisar páginas seleccionadas antes de analizarlas
// =============================================================================
class _VistaPreviaScreen extends StatefulWidget {
  const _VistaPreviaScreen({required this.paginasIniciales});

  final List<PaginaDocumento> paginasIniciales;

  @override
  State<_VistaPreviaScreen> createState() => _VistaPreviaScreenState();
}

class _VistaPreviaScreenState extends State<_VistaPreviaScreen> {
  late final List<PaginaDocumento> _paginas = List.of(widget.paginasIniciales);

  Future<void> _anadirMas() async {
    final nuevas = await _elegirPaginas(context);
    if (nuevas == null) return;
    setState(() => _paginas.addAll(nuevas));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_paginas.length > 1 ? '${_paginas.length} páginas' : 'Vista previa')),
      body: _paginas.isEmpty
          ? Center(child: Text('No queda ninguna página.', style: TextStyle(color: context.colors.inkMuted)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12),
              itemCount: _paginas.length,
              itemBuilder: (context, i) {
                final p = _paginas[i];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _esPdf(p)
                            ? Container(
                                color: context.colors.surfaceMuted,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.picture_as_pdf_outlined, size: 40, color: context.colors.inkMuted),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(p.nombre, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              )
                            : Image.file(p.archivo, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => setState(() => _paginas.removeAt(i)),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.black54,
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    if (_paginas.length > 1)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: context.colors.brand,
                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                  ],
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _anadirMas,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir más'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _paginas.isEmpty ? null : () => Navigator.pop(context, _paginas),
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PANTALLA DE REVISIÓN: "Hemos preparado el registro de tu documento"
// =============================================================================
class _RevisionDocumentoScreen extends StatefulWidget {
  const _RevisionDocumentoScreen({
    required this.casaId,
    required this.paginas,
    required this.sugerencia,
    required this.elementos,
    required this.trabajos,
    this.elementoIdInicial,
    this.trabajoIdInicial,
    this.habitacionIdInicial,
  });

  final String casaId;
  final List<PaginaDocumento> paginas;
  final SugerenciaIA? sugerencia;
  final List<Elemento> elementos;
  final List<Trabajo> trabajos;
  final String? elementoIdInicial;
  final String? trabajoIdInicial;
  final String? habitacionIdInicial;

  @override
  State<_RevisionDocumentoScreen> createState() => _RevisionDocumentoScreenState();
}

class _RevisionDocumentoScreenState extends State<_RevisionDocumentoScreen> {
  late TipoDocumento _tipo = widget.sugerencia?.tipo ?? TipoDocumento.otro;
  late TipoEvento _tipoEvento = _tipoEventoPorDefecto(widget.sugerencia?.tipo);
  late final _proveedorCtrl = TextEditingController(text: widget.sugerencia?.proveedor ?? '');
  late final _nifCtrl = TextEditingController(text: widget.sugerencia?.nifCif ?? '');
  late final _numeroCtrl = TextEditingController(text: widget.sugerencia?.numeroReferencia ?? '');
  late final _importeCtrl = TextEditingController(text: _formatoImporte(widget.sugerencia?.importe));
  late final _baseCtrl = TextEditingController(text: _formatoImporte(widget.sugerencia?.baseImponible));
  late final _impuestosCtrl = TextEditingController(text: _formatoImporte(widget.sugerencia?.impuestos));
  late final _descripcionCtrl = TextEditingController(text: widget.sugerencia?.descripcionTrabajo ?? '');
  late final _garantiaCtrl = TextEditingController(text: widget.sugerencia?.garantiaTexto ?? '');
  late final _observacionesCtrl = TextEditingController(text: widget.sugerencia?.observaciones ?? '');
  late DateTime? _fecha = widget.sugerencia?.fecha;
  late DateTime? _fechaVencimiento = widget.sugerencia?.fechaVencimiento;
  late String? _elementoId = widget.elementoIdInicial ?? _buscarIdPorNombre(widget.elementos, widget.sugerencia?.elementoSugerido);
  late String? _trabajoId = widget.trabajoIdInicial ?? _buscarIdPorNombre(widget.trabajos, widget.sugerencia?.trabajoSugerido);
  bool _guardando = false;

  // Auto-crear elemento (auditoría de producto, octubre 2026): si la IA
  // detecta un elemento que no existe todavía en la casa, en vez de perder
  // esa sugerencia se ofrece crearlo ya con los datos que ya se han
  // extraído del documento -- un documento nunca debe quedar aislado.
  late bool _crearElementoNuevo = widget.elementoIdInicial == null &&
      widget.sugerencia?.elementoSugerido != null &&
      _elementoId == null;
  late final _nuevoElementoNombreCtrl = TextEditingController(text: widget.sugerencia?.elementoSugerido ?? '');

  static String _formatoImporte(double? v) => v == null ? '' : v.toStringAsFixed(2);

  static String? _buscarIdPorNombre(List<dynamic> lista, String? nombre) {
    if (nombre == null) return null;
    for (final item in lista) {
      final n = item is Elemento ? item.nombre : (item as Trabajo).titulo;
      final id = item is Elemento ? item.id : (item as Trabajo).id;
      if (n.toLowerCase() == nombre.toLowerCase()) return id;
    }
    return null;
  }

  static TipoEvento _tipoEventoPorDefecto(TipoDocumento? t) => switch (t) {
        TipoDocumento.factura || TipoDocumento.presupuesto => TipoEvento.reparacion,
        _ => TipoEvento.nota,
      };

  @override
  void dispose() {
    _proveedorCtrl.dispose();
    _nifCtrl.dispose();
    _numeroCtrl.dispose();
    _importeCtrl.dispose();
    _baseCtrl.dispose();
    _impuestosCtrl.dispose();
    _descripcionCtrl.dispose();
    _garantiaCtrl.dispose();
    _observacionesCtrl.dispose();
    _nuevoElementoNombreCtrl.dispose();
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

  double? get _importe => double.tryParse(_importeCtrl.text.replaceAll(',', '.'));
  String? get _proveedor => _proveedorCtrl.text.trim().isEmpty ? null : _proveedorCtrl.text.trim();

  Future<void> _guardar({required bool comoBorrador}) async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      if (!comoBorrador) {
        final duplicado = await DocumentoService.posibleDuplicado(
          widget.casaId,
          proveedor: _proveedor,
          importe: _importe,
          fecha: _fecha,
        );
        if (duplicado && mounted) {
          final continuar = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Posible documento duplicado'),
              content: const Text('Ya existe un documento del mismo proveedor, importe y fecha en esta casa. ¿Guardar de todas formas?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar igualmente')),
              ],
            ),
          );
          if (continuar != true) {
            setState(() => _guardando = false);
            return;
          }
        }
      }

      if (_crearElementoNuevo && _nuevoElementoNombreCtrl.text.trim().isNotEmpty) {
        _elementoId = await ElementoService.crear(
          widget.casaId,
          Elemento(
            id: '',
            nombre: _nuevoElementoNombreCtrl.text.trim(),
            habitacionId: widget.habitacionIdInicial,
            coste: _importe,
            fechaInstalacion: _fecha,
            garantiaHasta: _fechaVencimiento,
            profesionalNombre: _proveedor,
          ),
        );
      }

      final urls = <String>[];
      for (final p in widget.paginas) {
        urls.add(await DocumentoService.subirArchivo(widget.casaId, p.archivo, p.nombre, trabajoId: _trabajoId));
      }
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final documento = Documento(
        id: '',
        url: urls.first,
        nombreArchivo: widget.paginas.first.nombre,
        tipo: _tipo,
        fecha: _fecha,
        proveedor: _proveedor,
        importe: _importe,
        numeroReferencia: _numeroCtrl.text.trim().isEmpty ? null : _numeroCtrl.text.trim(),
        fechaVencimiento: _fechaVencimiento,
        nifCif: _nifCtrl.text.trim().isEmpty ? null : _nifCtrl.text.trim(),
        baseImponible: double.tryParse(_baseCtrl.text.replaceAll(',', '.')),
        impuestos: double.tryParse(_impuestosCtrl.text.replaceAll(',', '.')),
        descripcionTrabajo: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
        garantiaTexto: _garantiaCtrl.text.trim().isEmpty ? null : _garantiaCtrl.text.trim(),
        observaciones: _observacionesCtrl.text.trim().isEmpty ? null : _observacionesCtrl.text.trim(),
        archivosAdicionales: urls.skip(1).toList(),
        elementoId: _elementoId,
        trabajoId: _trabajoId,
        habitacionId: widget.habitacionIdInicial,
        estadoIA: comoBorrador ? EstadoIA.pendiente : EstadoIA.confirmado,
        creadoPorIA: widget.sugerencia != null,
      );

      final documentoId = await DocumentoService.crear(widget.casaId, documento, createdBy: uid);

      if (!comoBorrador) {
        await EventoService.crear(
          widget.casaId,
          Evento(
            id: '',
            tipo: _tipoEvento,
            titulo: _numeroCtrl.text.trim().isNotEmpty
                ? '${_nombreTipoDoc(_tipo)} · ${_numeroCtrl.text.trim()}'
                : _nombreTipoDoc(_tipo),
            descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
            elementoId: _elementoId,
            habitacionId: widget.habitacionIdInicial,
            trabajoId: _trabajoId,
            coste: _importe,
            profesionalNombre: _proveedor,
            documentoIds: [documentoId],
            fecha: _fecha ?? DateTime.now(),
          ),
          createdBy: uid,
        );
      }

      if (mounted) {
        AppError.showSuccess(context, comoBorrador ? 'Guardado como borrador.' : 'Documento archivado en el historial.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo guardar el documento. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final confianza = widget.sugerencia?.confianza;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar documento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.sugerencia != null ? 'Hemos preparado el registro de tu documento' : 'No hemos podido leer el documento automáticamente',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.sugerencia != null ? 'Revisa los datos y corrige lo que haga falta antes de guardar.' : 'Rellena los datos a mano.',
              style: TextStyle(color: context.colors.inkMuted),
            ),
            if (confianza == 'baja') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: context.colors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: context.colors.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text('La IA no está muy segura de estos datos -- revísalos con más cuidado.', style: TextStyle(color: context.colors.ink))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _seccion(context, 'Documento original'),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.paginas.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = widget.paginas[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _esPdf(p)
                        ? Container(width: 70, color: context.colors.surfaceMuted, child: const Icon(Icons.picture_as_pdf_outlined))
                        : Image.file(p.archivo, width: 70, height: 90, fit: BoxFit.cover),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _seccion(context, 'Información del documento'),
            DropdownButtonFormField<TipoDocumento>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: TipoDocumento.values.map((t) => DropdownMenuItem(value: t, child: Text(_nombreTipoDoc(t)))).toList(),
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: 12),
            TextField(controller: _numeroCtrl, decoration: const InputDecoration(labelText: 'Número de factura/referencia')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _elegirFecha(vencimiento: false),
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(_fecha == null ? 'Fecha' : '${_fecha!.day}/${_fecha!.month}/${_fecha!.year}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _elegirFecha(vencimiento: true),
                  icon: const Icon(Icons.event_outlined, size: 16),
                  label: Text(_fechaVencimiento == null ? 'Vencimiento' : '${_fechaVencimiento!.day}/${_fechaVencimiento!.month}/${_fechaVencimiento!.year}'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _proveedorCtrl, decoration: const InputDecoration(labelText: 'Profesional / empresa emisora')),
            const SizedBox(height: 12),
            TextField(controller: _nifCtrl, decoration: const InputDecoration(labelText: 'NIF/CIF (opcional)')),
            const SizedBox(height: 20),
            _seccion(context, 'Información económica'),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _baseCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Base imponible (€)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _impuestosCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Impuestos (€)'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _importeCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Importe total (€)'),
            ),
            const SizedBox(height: 20),
            _seccion(context, 'Información del trabajo'),
            TextField(
              controller: _descripcionCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción del servicio/reparación'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _garantiaCtrl, decoration: const InputDecoration(labelText: 'Garantía indicada (opcional)')),
            const SizedBox(height: 12),
            TextField(
              controller: _observacionesCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observaciones'),
            ),
            const SizedBox(height: 20),
            _seccion(context, 'Relación con tu casa'),
            // Si ya se abrió el escáner desde la ficha de un elemento/trabajo
            // concreto (widget.*Inicial), ese vínculo queda fijo -- no se
            // ofrece un desplegable que además, para un profesional sin
            // permiso para listar TODOS los elementos/trabajos de la casa,
            // ni siquiera podría rellenarse con opciones.
            if (widget.elementoIdInicial != null)
              _VinculoFijo(icono: Icons.category_outlined, texto: _tituloElemento(widget.elementos, widget.elementoIdInicial!))
            else if (_crearElementoNuevo)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.colors.brand.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_outlined, size: 18, color: context.colors.brand),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'La IA no encontró ningún elemento con este nombre. Se creará uno nuevo con los datos de este documento.',
                            style: TextStyle(fontSize: 12, color: context.colors.inkMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nuevoElementoNombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre del elemento nuevo', isDense: true),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _crearElementoNuevo = false),
                        child: const Text('No crear, elegir uno que ya existe'),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String?>(
                initialValue: _elementoId,
                decoration: const InputDecoration(labelText: 'Elemento relacionado (opcional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin elemento específico')),
                  ...widget.elementos.map((e) => DropdownMenuItem(value: e.id, child: Text(e.nombre))),
                ],
                onChanged: (v) => setState(() => _elementoId = v),
              ),
            const SizedBox(height: 12),
            if (widget.trabajoIdInicial != null)
              _VinculoFijo(icono: Icons.build_outlined, texto: _tituloTrabajo(widget.trabajos, widget.trabajoIdInicial!))
            else
              DropdownButtonFormField<String?>(
                initialValue: _trabajoId,
                decoration: const InputDecoration(labelText: 'Trabajo relacionado (opcional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin trabajo específico')),
                  ...widget.trabajos.map((t) => DropdownMenuItem(value: t.id, child: Text(t.titulo))),
                ],
                onChanged: (v) => setState(() => _trabajoId = v),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TipoEvento>(
              initialValue: _tipoEvento,
              decoration: const InputDecoration(labelText: 'Aparecerá en el historial como'),
              items: TipoEvento.values.map((t) => DropdownMenuItem(value: t, child: Text(_nombreTipoEvento(t)))).toList(),
              onChanged: (v) => setState(() => _tipoEvento = v ?? _tipoEvento),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _guardando ? null : () => _guardar(comoBorrador: false),
              child: _guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar en el historial'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _guardando ? null : () => _guardar(comoBorrador: true),
              child: const Text('Guardar como borrador'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _guardando ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VinculoFijo extends StatelessWidget {
  const _VinculoFijo({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: context.colors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [Icon(icono, size: 18, color: context.colors.inkMuted), const SizedBox(width: 8), Text(texto)]),
    );
  }
}

String _tituloElemento(List<Elemento> elementos, String id) {
  for (final e in elementos) {
    if (e.id == id) return e.nombre;
  }
  return 'Elemento de esta ficha';
}

String _tituloTrabajo(List<Trabajo> trabajos, String id) {
  for (final t in trabajos) {
    if (t.id == id) return t.titulo;
  }
  return 'Este trabajo';
}

Widget _seccion(BuildContext context, String titulo) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(titulo, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: context.colors.brand)),
    );

String _nombreTipoDoc(TipoDocumento t) => switch (t) {
      TipoDocumento.factura => 'Factura',
      TipoDocumento.presupuesto => 'Presupuesto',
      TipoDocumento.garantia => 'Garantía',
      TipoDocumento.manual => 'Manual',
      TipoDocumento.contrato => 'Contrato',
      TipoDocumento.otro => 'Otro',
    };

String _nombreTipoEvento(TipoEvento t) => switch (t) {
      TipoEvento.instalacion => 'Instalación',
      TipoEvento.revision => 'Revisión',
      TipoEvento.reparacion => 'Reparación',
      TipoEvento.sustitucion => 'Sustitución',
      TipoEvento.reforma => 'Reforma',
      TipoEvento.nota => 'Nota',
    };
