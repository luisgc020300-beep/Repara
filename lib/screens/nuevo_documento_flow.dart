// lib/screens/nuevo_documento_flow.dart
//
// Flujo de "Escanear factura o documento" con extracción por IA (secciones
// 3-8 del spec de producto). La IA solo SUGIERE -- el propietario siempre ve
// y puede corregir cada campo en una pantalla de revisión completa antes de
// guardar nada (sección 61: nunca se asume información no confirmada).
import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/documento.dart';
import '../models/elemento.dart';
import '../models/registro.dart';
import '../services/analytics_service.dart';
import '../services/documento_service.dart';
import '../services/elemento_service.dart';
import '../services/registro_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';
import '../widgets/seccion_formulario.dart';
import 'pago_detail_screen.dart';

Future<void> iniciarNuevoDocumento(
  BuildContext context, {
  required String casaId,
  String? elementoId,
  String? registroId,
  String? habitacionId,
}) async {
  final paginas = await _elegirPaginas(context);
  if (paginas == null || paginas.isEmpty || !context.mounted) return;

  final confirmadas = await Navigator.push<List<PaginaDocumento>>(
    context,
    MaterialPageRoute(
      builder: (_) => _VistaPreviaScreen(paginasIniciales: paginas),
    ),
  );
  if (confirmadas == null || confirmadas.isEmpty || !context.mounted) return;

  // Un profesional invitado a un registro concreto no tiene permiso para
  // listar TODOS los elementos de la casa (solo lee su propio registro) --
  // en ese caso se sigue sin lista de sugerencias en vez de reventar el flujo.
  List<Elemento> elementos = const [];
  try {
    elementos = await ElementoService.streamElementos(casaId).first;
  } catch (e) {
    // sin acceso al listado completo -- se continúa sin sugerencias.
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
    builder: (ctx) => AlertDialog(
      shape: AppDialog.shape(),
      content: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 16),
          Expanded(child: Text('Analizando documento…')),
        ],
      ),
    ),
  );
  try {
    // 55s, no 30s: la Cloud Function (classifyDocument) tiene
    // timeoutSeconds: 60 -- con un timeout de cliente más corto que el del
    // servidor, el cliente podía rendirse y mostrar "no se pudo contactar"
    // mientras la IA todavía estaba trabajando dentro de su propio margen
    // (confirmado en logs de producción, noviembre 2026: una llamada sin
    // ningún error de servidor, solo más lenta de lo habitual).
    sugerencia = await DocumentoService.clasificarConIA(
      confirmadas,
      elementosDisponibles: elementos.map((e) => e.nombre).toList(),
    ).timeout(const Duration(seconds: 55));
  } on FirebaseFunctionsException catch (e) {
    // 'resource-exhausted' (límite diario) y 'unavailable' (sin conexión
    // con la IA, incluido el timeout de 45s contra Anthropic) ya traen un
    // mensaje claro del propio servidor -- el resto de códigos cae al
    // genérico de siempre.
    errorIA =
        (e.code == 'resource-exhausted' || e.code == 'unavailable') &&
            e.message != null
        ? e.message!
        : 'No se pudo contactar con el servicio de IA. Puedes rellenar los datos a mano.';
  } catch (e) {
    errorIA =
        'No se pudo contactar con el servicio de IA. Puedes rellenar los datos a mano.';
  } finally {
    if (context.mounted) Navigator.pop(context);
  }
  unawaited(
    AnalyticsService.documentAiExtractionCompleted(
      exito: errorIA == null,
      confianza: sugerencia?.confianza,
    ),
  );

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
        elementoIdInicial: elementoId,
        registroIdInicial: registroId,
        habitacionIdInicial: habitacionId,
      ),
    ),
  );
}

/// Rellenar un presupuesto/factura a mano, sin escanear nada (CEO, noviembre
/// 2026: "un usuario también puede poner o escanear un presupuesto que le
/// haya dado un profesional que no use la app -- los mismos campos que un
/// documento, pero a mano, sin archivo obligatorio"). Mismo formulario de
/// revisión que el flujo con IA (_RevisionDocumentoScreen), sin páginas ni
/// sugerencia -- paginas: const [] es la señal de "sin archivo adjunto".
Future<void> iniciarNuevoDocumentoManual(
  BuildContext context, {
  required String casaId,
  String? elementoId,
  String? registroId,
  String? habitacionId,
  TipoDocumento? tipoInicial,
}) async {
  List<Elemento> elementos = const [];
  try {
    elementos = await ElementoService.streamElementos(casaId).first;
  } catch (e) {
    // Mismo motivo que en iniciarNuevoDocumento: un profesional invitado no
    // puede listar todos los elementos de la casa -- se sigue sin sugerencias.
  }
  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => _RevisionDocumentoScreen(
        casaId: casaId,
        paginas: const [],
        sugerencia: null,
        elementos: elementos,
        elementoIdInicial: elementoId,
        registroIdInicial: registroId,
        habitacionIdInicial: habitacionId,
        tipoInicial: tipoInicial,
      ),
    ),
  );
}

/// Elegir cómo añadir un presupuesto/factura-nota a un evento (CEO,
/// noviembre 2026): escanear (con IA) o rellenar a mano -- mismo patrón que
/// "+ Añadir evento" en elemento_detail_screen.dart. [tipoInicial] preselecciona
/// la categoría al rellenar a mano (Presupuestos -> presupuesto, Facturas/
/// Notas -> factura, editable igualmente desde el desplegable "Tipo").
Future<void> elegirFormaDeAnadirDocumento(
  BuildContext context, {
  required String casaId,
  String? elementoId,
  String? registroId,
  String? habitacionId,
  TipoDocumento? tipoInicial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ReparaSpace.s4,
          ReparaSpace.s2,
          ReparaSpace.s4,
          ReparaSpace.s4,
        ),
        child: IosSection(
          rows: [
            IosRow(
              icon: Icons.document_scanner_outlined,
              iconColor: ctx.colors.brand,
              title: 'Escanear',
              subtitle: 'La IA rellena los datos por ti',
              onTap: () {
                Navigator.pop(ctx);
                iniciarNuevoDocumento(
                  context,
                  casaId: casaId,
                  elementoId: elementoId,
                  registroId: registroId,
                  habitacionId: habitacionId,
                );
              },
            ),
            IosRow(
              icon: Icons.edit_outlined,
              iconColor: ctx.colors.brand,
              title: 'Rellenar a mano',
              subtitle:
                  'Sin escanear nada -- p.ej. lo que te han dicho de palabra',
              onTap: () {
                Navigator.pop(ctx);
                iniciarNuevoDocumentoManual(
                  context,
                  casaId: casaId,
                  elementoId: elementoId,
                  registroId: registroId,
                  habitacionId: habitacionId,
                  tipoInicial: tipoInicial,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Elegir cómo añadir un pago: escanear (con IA) o rellenar a mano -- mismo
/// patrón que elegirFormaDeAnadirDocumento, para Pagos (CEO, noviembre 2026:
/// "Presupuestos y Facturas/Notas ya dejan escanear, Pagos solo dejaba
/// rellenar a mano").
Future<void> elegirFormaDeAnadirPago(
  BuildContext context, {
  required String casaId,
  required String elementoId,
  required String registroId,
  required String registroTitulo,
  required double? presupuesto,
  required String conceptoSugerido,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ReparaSpace.s4,
          ReparaSpace.s2,
          ReparaSpace.s4,
          ReparaSpace.s4,
        ),
        child: IosSection(
          rows: [
            IosRow(
              icon: Icons.document_scanner_outlined,
              iconColor: ctx.colors.brand,
              title: 'Escanear',
              subtitle: 'La IA rellena el importe y la fecha por ti',
              onTap: () {
                Navigator.pop(ctx);
                iniciarEscaneoPago(
                  context,
                  casaId: casaId,
                  elementoId: elementoId,
                  registroId: registroId,
                  registroTitulo: registroTitulo,
                  presupuesto: presupuesto,
                  conceptoSugeridoPorDefecto: conceptoSugerido,
                );
              },
            ),
            IosRow(
              icon: Icons.edit_outlined,
              iconColor: ctx.colors.brand,
              title: 'Rellenar a mano',
              subtitle: 'Sin escanear nada',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PagoDetailScreen(
                      casaId: casaId,
                      elementoId: elementoId,
                      registroId: registroId,
                      registroTitulo: registroTitulo,
                      presupuesto: presupuesto,
                      editable: true,
                      conceptoSugerido: conceptoSugerido,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Escanear un recibo/justificante para registrar un pago -- mismo flujo de
/// IA que los Documentos (elegir origen, previsualizar, "Analizando
/// documento…"), pero el resultado nunca se guarda como Documento: solo
/// prerellena el recibo de PagoDetailScreen (importe/fecha/concepto), que
/// el propietario siempre revisa y confirma como con cualquier otro pago
/// (sección 61 del spec: nunca se asume información no confirmada). Si la
/// IA falla, cae a PagoDetailScreen sin prerellenar -- igual que
/// iniciarNuevoDocumento cae al formulario manual.
Future<void> iniciarEscaneoPago(
  BuildContext context, {
  required String casaId,
  required String elementoId,
  required String registroId,
  required String registroTitulo,
  required double? presupuesto,
  required String conceptoSugeridoPorDefecto,
}) async {
  final paginas = await _elegirPaginas(context);
  if (paginas == null || paginas.isEmpty || !context.mounted) return;

  final confirmadas = await Navigator.push<List<PaginaDocumento>>(
    context,
    MaterialPageRoute(
      builder: (_) => _VistaPreviaScreen(paginasIniciales: paginas),
    ),
  );
  if (confirmadas == null || confirmadas.isEmpty || !context.mounted) return;

  SugerenciaIA? sugerencia;
  String? comprobanteUrl;
  String? errorIA;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: AppDialog.shape(),
      content: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 16),
          Expanded(child: Text('Analizando documento…')),
        ],
      ),
    ),
  );
  // Clasificar y subir arrancan juntos (ambos son awaits sobre Futures ya
  // en marcha) -- no se combinan con Future.wait porque un fallo de
  // clasificar no debe tirar también la subida: aunque la IA no acierte a
  // leer el recibo, el comprobante en sí puede quedar guardado igual.
  final clasificarFuture = DocumentoService.clasificarConIA(
    confirmadas,
  ).timeout(const Duration(seconds: 55));
  final subirFuture = DocumentoService.subirArchivo(
    casaId,
    confirmadas.first.archivo,
    confirmadas.first.nombre,
    elementoId: elementoId,
    registroId: registroId,
  );
  try {
    sugerencia = await clasificarFuture;
  } on FirebaseFunctionsException catch (e) {
    errorIA =
        (e.code == 'resource-exhausted' || e.code == 'unavailable') &&
            e.message != null
        ? e.message!
        : 'No se pudo contactar con el servicio de IA. Puedes rellenar los datos a mano.';
  } catch (e) {
    errorIA =
        'No se pudo contactar con el servicio de IA. Puedes rellenar los datos a mano.';
  }
  try {
    comprobanteUrl = await subirFuture;
  } catch (e) {
    // No bloquea el flujo -- el pago se puede registrar igual, solo sin
    // comprobante adjunto.
    debugPrint('iniciarEscaneoPago: no se pudo subir el comprobante: $e');
  }
  if (context.mounted) Navigator.pop(context);

  if (!context.mounted) return;
  if (errorIA != null) AppError.show(context, errorIA);

  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => PagoDetailScreen(
        casaId: casaId,
        elementoId: elementoId,
        registroId: registroId,
        registroTitulo: registroTitulo,
        presupuesto: presupuesto,
        editable: true,
        fechaSugerida: sugerencia?.fecha,
        importeSugerido: sugerencia?.importe,
        comprobanteSugerido: comprobanteUrl,
        conceptoSugerido:
            sugerencia?.proveedor ??
            sugerencia?.descripcionTrabajo ??
            conceptoSugeridoPorDefecto,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: ctx.colors.inkMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.photo_camera_outlined,
                  iconColor: ctx.colors.brand,
                  title: 'Hacer una foto',
                  onTap: () async {
                    final navigator = Navigator.of(ctx);
                    final foto = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                      maxWidth: 1600,
                      maxHeight: 1600,
                    );
                    if (!ctx.mounted) return;
                    if (foto == null) return navigator.pop(null);
                    navigator.pop([_paginaDesdeXFile(foto)]);
                  },
                ),
                IosRow(
                  icon: Icons.photo_library_outlined,
                  iconColor: ctx.colors.brand,
                  title: 'Elegir de la galería',
                  subtitle:
                      'Puedes seleccionar varias fotos si el documento tiene varias páginas',
                  onTap: () async {
                    final navigator = Navigator.of(ctx);
                    final fotos = await picker.pickMultiImage(
                      imageQuality: 85,
                      maxWidth: 1600,
                      maxHeight: 1600,
                    );
                    if (!ctx.mounted) return;
                    if (fotos.isEmpty) return navigator.pop(null);
                    navigator.pop(fotos.map(_paginaDesdeXFile).toList());
                  },
                ),
                IosRow(
                  icon: Icons.upload_file_outlined,
                  iconColor: ctx.colors.brand,
                  title: 'Subir archivo (PDF o imagen)',
                  onTap: () async {
                    final navigator = Navigator.of(ctx);
                    final resultado = await FilePicker.platform.pickFiles(
                      allowMultiple: true,
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                    );
                    if (!ctx.mounted) return;
                    final paths =
                        resultado?.files
                            .where((f) => f.path != null)
                            .map((f) => f.path!)
                            .toList() ??
                        [];
                    if (paths.isEmpty) return navigator.pop(null);
                    navigator.pop(paths.map(_paginaDesdeRuta).toList());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

PaginaDocumento _paginaDesdeXFile(XFile foto) => PaginaDocumento(
  archivo: File(foto.path),
  mediaType: foto.path.toLowerCase().endsWith('.png')
      ? 'image/png'
      : 'image/jpeg',
  nombre: foto.name,
);

PaginaDocumento _paginaDesdeRuta(String ruta) {
  final extension = ruta.toLowerCase().split('.').last;
  final mediaType = switch (extension) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    _ => 'image/jpeg',
  };
  return PaginaDocumento(
    archivo: File(ruta),
    mediaType: mediaType,
    nombre: ruta.split(Platform.pathSeparator).last,
  );
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
      appBar: AppBar(
        title: Text(
          _paginas.length > 1 ? '${_paginas.length} páginas' : 'Vista previa',
        ),
      ),
      body: _paginas.isEmpty
          ? Center(
              child: Text(
                'No queda ninguna página.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(ReparaSpace.s4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: ReparaSpace.s3,
                crossAxisSpacing: ReparaSpace.s3,
              ),
              itemCount: _paginas.length,
              itemBuilder: (context, i) {
                final p = _paginas[i];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ReparaRadius.md),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: _esPdf(p)
                            ? Container(
                                color: context.colors.surfaceMuted,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf_outlined,
                                      size: 40,
                                      color: context.colors.inkMuted,
                                    ),
                                    const SizedBox(height: ReparaSpace.s1),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: ReparaSpace.s2,
                                      ),
                                      child: Text(
                                        p.nombre,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Image.file(
                                p.archivo,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
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
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
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
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ReparaSpace.s4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _anadirMas,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir más'),
                ),
              ),
              const SizedBox(width: ReparaSpace.s3),
              Expanded(
                child: FilledButton(
                  onPressed: _paginas.isEmpty
                      ? null
                      : () => Navigator.pop(context, _paginas),
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
    this.elementoIdInicial,
    this.registroIdInicial,
    this.habitacionIdInicial,
    this.tipoInicial,
  });

  final String casaId;
  final List<PaginaDocumento> paginas;
  final SugerenciaIA? sugerencia;
  final List<Elemento> elementos;
  final String? elementoIdInicial;
  final String? registroIdInicial;
  final String? habitacionIdInicial;
  // Categoría ya elegida antes de llegar aquí (CEO, noviembre 2026: "Añadir"
  // desde Presupuestos/Facturas-Notas) -- gana sobre la sugerencia de la IA,
  // que aquí ni siquiera existe (solo se usa desde iniciarNuevoDocumentoManual).
  final TipoDocumento? tipoInicial;

  @override
  State<_RevisionDocumentoScreen> createState() =>
      _RevisionDocumentoScreenState();
}

class _RevisionDocumentoScreenState extends State<_RevisionDocumentoScreen> {
  late TipoDocumento _tipo =
      widget.tipoInicial ?? widget.sugerencia?.tipo ?? TipoDocumento.otro;
  late TipoRegistro _tipoRegistro = _tipoRegistroPorDefecto(
    widget.sugerencia?.tipo,
  );
  late final _proveedorCtrl = TextEditingController(
    text: widget.sugerencia?.proveedor ?? '',
  );
  late final _nifCtrl = TextEditingController(
    text: widget.sugerencia?.nifCif ?? '',
  );
  late final _numeroCtrl = TextEditingController(
    text: widget.sugerencia?.numeroReferencia ?? '',
  );
  late final _importeCtrl = TextEditingController(
    text: _formatoImporte(widget.sugerencia?.importe),
  );
  late final _baseCtrl = TextEditingController(
    text: _formatoImporte(widget.sugerencia?.baseImponible),
  );
  late final _impuestosCtrl = TextEditingController(
    text: _formatoImporte(widget.sugerencia?.impuestos),
  );
  late final _descripcionCtrl = TextEditingController(
    text: widget.sugerencia?.descripcionTrabajo ?? '',
  );
  late final _garantiaCtrl = TextEditingController(
    text: widget.sugerencia?.garantiaTexto ?? '',
  );
  late final _observacionesCtrl = TextEditingController(
    text: widget.sugerencia?.observaciones ?? '',
  );
  late DateTime? _fecha = widget.sugerencia?.fecha;
  late DateTime? _fechaVencimiento = widget.sugerencia?.fechaVencimiento;
  late String? _elementoId =
      widget.elementoIdInicial ??
      _buscarIdPorNombre(widget.elementos, widget.sugerencia?.elementoSugerido);
  late final String? _registroId = widget.registroIdInicial;
  bool _guardando = false;

  // Auto-crear elemento (auditoría de producto, octubre 2026): si la IA
  // detecta un elemento que no existe todavía en la casa, en vez de perder
  // esa sugerencia se ofrece crearlo ya con los datos que ya se han
  // extraído del documento -- un documento nunca debe quedar aislado.
  late bool _crearElementoNuevo =
      widget.elementoIdInicial == null &&
      widget.sugerencia?.elementoSugerido != null &&
      _elementoId == null;
  late final _nuevoElementoNombreCtrl = TextEditingController(
    text: widget.sugerencia?.elementoSugerido ?? '',
  );

  static String _formatoImporte(double? v) =>
      v == null ? '' : v.toStringAsFixed(2);

  static String? _buscarIdPorNombre(List<Elemento> lista, String? nombre) {
    if (nombre == null) return null;
    for (final item in lista) {
      if (item.nombre.toLowerCase() == nombre.toLowerCase()) return item.id;
    }
    return null;
  }

  static TipoRegistro _tipoRegistroPorDefecto(TipoDocumento? t) => switch (t) {
    TipoDocumento.factura ||
    TipoDocumento.presupuesto => TipoRegistro.reparacion,
    _ => TipoRegistro.nota,
  };

  String _nombreElementoParaRegistro() {
    if (_crearElementoNuevo) return _nuevoElementoNombreCtrl.text.trim();
    for (final e in widget.elementos) {
      if (e.id == _elementoId) return e.nombre;
    }
    return '';
  }

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

  double? get _importe =>
      double.tryParse(_importeCtrl.text.replaceAll(',', '.'));
  String? get _proveedor =>
      _proveedorCtrl.text.trim().isEmpty ? null : _proveedorCtrl.text.trim();

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
          final continuar = await AppDialog.confirm(
            context,
            title: 'Posible documento duplicado',
            message:
                'Ya existe un documento del mismo proveedor, importe y fecha en esta casa. ¿Guardar de todas formas?',
            confirmLabel: 'Guardar igualmente',
          );
          if (!continuar) {
            setState(() => _guardando = false);
            return;
          }
        }
      }

      if (_crearElementoNuevo &&
          _nuevoElementoNombreCtrl.text.trim().isNotEmpty) {
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
        urls.add(
          await DocumentoService.subirArchivo(
            widget.casaId,
            p.archivo,
            p.nombre,
            elementoId: _elementoId,
            registroId: _registroId,
          ),
        );
      }
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Un registro nunca vive sin elemento -- si este documento no venía ya
      // vinculado a un registro concreto pero sí hay un elemento de por
      // medio, se crea aquí su registro fundacional para que el documento
      // quede reflejado en el historial del elemento (octubre 2026, fusión
      // Elemento/Trabajo/Evento). Un documento sin elemento sigue sin tener
      // registro -- se archiva igualmente en Documentos, sin historial.
      String? registroId = _registroId;
      final crearRegistroNuevo =
          !comoBorrador && registroId == null && _elementoId != null;
      if (crearRegistroNuevo) {
        registroId = await RegistroService.crear(
          widget.casaId,
          _elementoId!,
          Registro(
            id: '',
            elementoNombre: _nombreElementoParaRegistro(),
            tipo: _tipoRegistro,
            esConProfesional: false,
            titulo: _numeroCtrl.text.trim().isNotEmpty
                ? '${nombreTipoDocumento(_tipo)} · ${_numeroCtrl.text.trim()}'
                : nombreTipoDocumento(_tipo),
            estado: estadoInicialRegistroSimple(_importe),
            fecha: _fecha ?? DateTime.now(),
            descripcion: _descripcionCtrl.text.trim().isEmpty
                ? null
                : _descripcionCtrl.text.trim(),
            garantiaHasta: _fechaVencimiento,
            coste: _importe,
            profesionalNombre: _proveedor,
          ),
          createdBy: uid,
        );
      }

      final documento = Documento(
        id: '',
        // Sin páginas = relleno a mano, sin archivo (CEO, noviembre 2026) --
        // url vacía es la señal de "sin archivo adjunto" en toda la app (ver
        // documento_abrir.dart).
        url: urls.isEmpty ? '' : urls.first,
        nombreArchivo: widget.paginas.isEmpty
            ? nombreTipoDocumento(_tipo)
            : widget.paginas.first.nombre,
        tipo: _tipo,
        fecha: _fecha,
        proveedor: _proveedor,
        importe: _importe,
        numeroReferencia: _numeroCtrl.text.trim().isEmpty
            ? null
            : _numeroCtrl.text.trim(),
        fechaVencimiento: _fechaVencimiento,
        nifCif: _nifCtrl.text.trim().isEmpty ? null : _nifCtrl.text.trim(),
        baseImponible: double.tryParse(_baseCtrl.text.replaceAll(',', '.')),
        impuestos: double.tryParse(_impuestosCtrl.text.replaceAll(',', '.')),
        descripcionTrabajo: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        garantiaTexto: _garantiaCtrl.text.trim().isEmpty
            ? null
            : _garantiaCtrl.text.trim(),
        observaciones: _observacionesCtrl.text.trim().isEmpty
            ? null
            : _observacionesCtrl.text.trim(),
        archivosAdicionales: urls.skip(1).toList(),
        elementoId: _elementoId,
        registroId: registroId,
        habitacionId: widget.habitacionIdInicial,
        estadoIA: comoBorrador ? EstadoIA.pendiente : EstadoIA.confirmado,
        creadoPorIA: widget.sugerencia != null,
      );

      final documentoId = await DocumentoService.crear(
        widget.casaId,
        documento,
        createdBy: uid,
      );
      unawaited(AnalyticsService.firstDocumentUploaded());
      unawaited(AnalyticsService.documentConfirmed(comoBorrador: comoBorrador));

      if (crearRegistroNuevo) {
        await RegistroService.actualizar(
          widget.casaId,
          _elementoId!,
          registroId!,
          {
            'documentoIds': [documentoId],
          },
        );
      }

      if (mounted) {
        AppError.showSuccess(
          context,
          comoBorrador
              ? 'Guardado como borrador.'
              : 'Documento archivado en el historial.',
        );
        Navigator.pop(context);
      }
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo guardar el documento. Inténtalo de nuevo.',
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
    final confianza = widget.sugerencia?.confianza;
    final sinArchivo = widget.paginas.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(sinArchivo ? 'Añadir a mano' : 'Revisar documento'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(ReparaSpace.s4),
          children: [
            Text(
              sinArchivo
                  ? 'Añade los datos a mano'
                  : widget.sugerencia != null
                  ? 'Hemos preparado el evento de tu documento'
                  : 'No hemos podido leer el documento automáticamente',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: ReparaSpace.s1),
            Text(
              sinArchivo
                  ? 'Sin archivo, solo los datos que tengas a mano -- p.ej. un presupuesto que te hayan dado de palabra o en papel.'
                  : widget.sugerencia != null
                  ? 'Revisa los datos y corrige lo que haga falta antes de guardar.'
                  : 'Rellena los datos a mano.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (confianza == 'baja') ...[
              const SizedBox(height: ReparaSpace.s3),
              Container(
                padding: const EdgeInsets.all(ReparaSpace.s3),
                decoration: BoxDecoration(
                  color: context.colors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ReparaRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: context.colors.warning,
                    ),
                    const SizedBox(width: ReparaSpace.s2),
                    Expanded(
                      child: Text(
                        'La IA no está muy segura de estos datos -- revísalos con más cuidado.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.colors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!sinArchivo) ...[
              const SizedBox(height: ReparaSpace.s4),
              SeccionFormulario(
                titulo: 'Documento original',
                children: [
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.paginas.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: ReparaSpace.s2),
                      itemBuilder: (context, i) {
                        final p = widget.paginas[i];
                        return Container(
                          width: 70,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              ReparaRadius.sm,
                            ),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: _esPdf(p)
                              ? Container(
                                  color: context.colors.surfaceMuted,
                                  child: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                  ),
                                )
                              : Image.file(
                                  p.archivo,
                                  width: 70,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: ReparaSpace.s4),
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
                      child: OutlinedButton.icon(
                        onPressed: () => _elegirFecha(vencimiento: false),
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(
                          _fecha == null
                              ? 'Fecha'
                              : '${_fecha!.day}/${_fecha!.month}/${_fecha!.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: ReparaSpace.s3),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _elegirFecha(vencimiento: true),
                        icon: const Icon(Icons.event_outlined, size: 16),
                        label: Text(
                          _fechaVencimiento == null
                              ? 'Vencimiento'
                              : '${_fechaVencimiento!.day}/${_fechaVencimiento!.month}/${_fechaVencimiento!.year}',
                        ),
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
            const SizedBox(height: ReparaSpace.s4),
            SeccionFormulario(
              titulo: 'Relación con tu casa',
              children: [
                // Si ya se abrió el escáner desde la ficha de un elemento/registro
                // concreto (widget.*Inicial), ese vínculo queda fijo -- no se
                // ofrece un desplegable que además, para un profesional sin
                // permiso para listar TODOS los elementos de la casa, ni
                // siquiera podría rellenarse con opciones.
                if (widget.elementoIdInicial != null)
                  _VinculoFijo(
                    icono: Icons.category_outlined,
                    texto: _tituloElemento(
                      widget.elementos,
                      widget.elementoIdInicial!,
                    ),
                  )
                else if (_crearElementoNuevo)
                  Container(
                    padding: const EdgeInsets.all(ReparaSpace.s3),
                    decoration: BoxDecoration(
                      color: context.colors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(ReparaRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_outlined,
                              size: 18,
                              color: context.colors.brand,
                            ),
                            const SizedBox(width: ReparaSpace.s2),
                            Expanded(
                              child: Text(
                                'La IA no encontró ningún elemento con este nombre. Se creará uno nuevo con los datos de este documento.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: ReparaSpace.s2),
                        TextField(
                          controller: _nuevoElementoNombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del elemento nuevo',
                            isDense: true,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _crearElementoNuevo = false),
                            child: const Text(
                              'No crear, elegir uno que ya existe',
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String?>(
                    initialValue: _elementoId,
                    decoration: const InputDecoration(
                      labelText: 'Elemento relacionado (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Sin elemento específico'),
                      ),
                      ...widget.elementos.map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.nombre),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _elementoId = v),
                  ),
                if (widget.registroIdInicial != null) ...[
                  const SizedBox(height: ReparaSpace.s3),
                  const _VinculoFijo(
                    icono: Icons.build_outlined,
                    texto: 'Este evento',
                  ),
                ] else if (_elementoId != null) ...[
                  const SizedBox(height: ReparaSpace.s3),
                  DropdownButtonFormField<TipoRegistro>(
                    initialValue: _tipoRegistro,
                    decoration: const InputDecoration(
                      labelText: 'Aparecerá en el historial del elemento como',
                    ),
                    items: TipoRegistro.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(nombreTipoRegistro(t)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _tipoRegistro = v ?? _tipoRegistro),
                  ),
                ],
              ],
            ),
            const SizedBox(height: ReparaSpace.s6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _guardando
                    ? null
                    : () => _guardar(comoBorrador: false),
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar en el historial'),
              ),
            ),
            const SizedBox(height: ReparaSpace.s2),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _guardando
                    ? null
                    : () => _guardar(comoBorrador: true),
                child: const Text('Guardar como borrador'),
              ),
            ),
            const SizedBox(height: ReparaSpace.s2),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _guardando ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: ReparaSpace.s3,
        vertical: ReparaSpace.s3,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(ReparaRadius.md),
      ),
      child: Row(
        children: [
          Icon(icono, size: 18, color: context.colors.inkMuted),
          const SizedBox(width: ReparaSpace.s2),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

String _tituloElemento(List<Elemento> elementos, String id) {
  for (final e in elementos) {
    if (e.id == id) return e.nombre;
  }
  return 'Elemento de esta ficha';
}
