// lib/screens/elemento_detail_screen.dart
//
// Ficha de un elemento (sección 11 del spec) -- una de las seis pantallas
// que el spec marca como "estrella" porque representan la propuesta de
// valor: convertir un aparato suelto en una identidad digital con su propio
// historial y documentación.
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../models/elemento.dart';
import '../models/habitacion.dart';
import '../models/registro.dart';
import '../services/documento_service.dart';
import '../services/elemento_service.dart';
import '../services/habitacion_service.dart';
import '../services/registro_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';
import 'nuevo_documento_flow.dart';
import 'nuevo_elemento_screen.dart';
import 'nuevo_registro_sheet.dart';
import 'registro_detail_screen.dart';

class ElementoDetailScreen extends StatelessWidget {
  const ElementoDetailScreen({required this.casa, required this.elementoId, super.key});

  final Casa casa;
  final String elementoId;

  Future<void> _editarMantenimiento(BuildContext context, Elemento elemento) async {
    final intervaloCtrl = TextEditingController(text: elemento.intervaloMantenimientoMeses?.toString() ?? '');
    DateTime? proxima = elemento.proximoMantenimiento;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Revisión periódica'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: intervaloCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Revisar cada cuántos meses'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final elegida = await showDatePicker(
                    context: ctx,
                    initialDate: proxima ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (elegida != null) setStateDialog(() => proxima = elegida);
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(proxima == null ? 'Próxima revisión' : '${proxima!.day}/${proxima!.month}/${proxima!.year}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (guardar != true) return;
    try {
      await ElementoService.actualizarMantenimiento(
        casa.id,
        elemento.id,
        intervaloMeses: int.tryParse(intervaloCtrl.text.trim()),
        proximoMantenimiento: proxima,
      );
    } catch (e, st) {
      if (context.mounted) AppError.show(context, 'No se pudo guardar la revisión periódica.', error: e, stackTrace: st);
    }
  }

  Future<void> _cambiarFoto(BuildContext context, Elemento elemento) async {
    final picker = ImagePicker();
    final foto = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(ReparaSpace.s4, ReparaSpace.s2, ReparaSpace.s4, ReparaSpace.s4),
          child: IosSection(
            rows: [
              IosRow(
                icon: Icons.photo_camera_outlined,
                iconColor: ctx.colors.brand,
                title: 'Hacer una foto',
                onTap: () async {
                  final navigator = Navigator.of(ctx);
                  final imagen = await picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600, maxHeight: 1600);
                  if (!ctx.mounted) return;
                  navigator.pop(imagen);
                },
              ),
              IosRow(
                icon: Icons.photo_library_outlined,
                iconColor: ctx.colors.brand,
                title: 'Elegir de la galería',
                onTap: () async {
                  final navigator = Navigator.of(ctx);
                  final imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600, maxHeight: 1600);
                  if (!ctx.mounted) return;
                  navigator.pop(imagen);
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (foto == null || !context.mounted) return;
    try {
      final url = await ElementoService.subirFoto(casa.id, elemento.id, File(foto.path));
      await ElementoService.actualizarFoto(casa.id, elemento.id, url);
    } catch (e, st) {
      if (context.mounted) AppError.show(context, 'No se pudo guardar la foto.', error: e, stackTrace: st);
    }
  }

  Future<void> _marcarRevisionHecha(BuildContext context, Elemento elemento) async {
    final intervalo = elemento.intervaloMantenimientoMeses;
    if (intervalo == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await RegistroService.crear(
        casa.id,
        elemento.id,
        Registro(
          id: '',
          elementoNombre: elemento.nombre,
          tipo: TipoRegistro.mantenimiento,
          esConProfesional: false,
          titulo: 'Revisión periódica · ${elemento.nombre}',
          estado: EstadoRegistro.terminado,
          fecha: DateTime.now(),
        ),
        createdBy: uid,
      );
      await ElementoService.marcarRevisionHecha(casa.id, elemento.id, intervalo);
      if (context.mounted) AppError.showSuccess(context, 'Revisión registrada. Próxima en $intervalo meses.');
    } catch (e, st) {
      if (context.mounted) AppError.show(context, 'No se pudo registrar la revisión.', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Elemento?>(
      stream: ElementoService.streamElemento(casa.id, elementoId),
      builder: (context, snapshot) {
        final elemento = snapshot.data;
        if (elemento == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar ficha',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NuevoElementoScreen(casa: casa, habitacionIdInicial: elemento.habitacionId, existente: elemento)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar elemento',
                onPressed: () async {
                  final confirmar = await AppDialog.confirmText(
                    context,
                    title: '¿Eliminar elemento?',
                    message: 'Se eliminará la ficha, no su historial ya registrado.',
                    confirmLabel: 'Eliminar',
                  );
                  if (confirmar) {
                    await ElementoService.eliminar(casa.id, elemento.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => mostrarNuevoRegistroSheet(context, casaId: casa.id, elementoId: elemento.id, elementoNombre: elemento.nombre),
            icon: const Icon(Icons.add),
            label: const Text('Añadir registro'),
          ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Sin foto todavía -- un marcador tocable es mejor que fingir
              // una (auditoría de craft, octubre 2026): avisa de que es un
              // hueco, no un dato, y toca para añadirla. Con foto, tocarla
              // la amplía a pantalla completa -- cambiarla es el lápiz
              // pequeño de la esquina, no toda el área (CEO, octubre 2026:
              // "se ve muy poco, que se pueda ampliar"). Relleno plano, no
              // degradado (briefing "REPARA Professional": sin degradados
              // decorativos).
              GestureDetector(
                onTap: () => elemento.fotoUrl == null
                    ? _cambiarFoto(context, elemento)
                    : Navigator.push(context, MaterialPageRoute(builder: (_) => _FotoAmpliadaScreen(url: elemento.fotoUrl!))),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: elemento.fotoUrl == null ? context.colors.surfaceMuted : null,
                    image: elemento.fotoUrl != null
                        ? DecorationImage(image: NetworkImage(elemento.fotoUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: elemento.fotoUrl == null
                      ? Center(child: Icon(Icons.add_a_photo_outlined, size: 34, color: context.colors.inkFaint))
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(ReparaSpace.s2),
                            child: GestureDetector(
                              onTap: () => _cambiarFoto(context, elemento),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                                child: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: StreamBuilder<List<Habitacion>>(
                  stream: HabitacionService.streamHabitaciones(casa.id),
                  builder: (context, habSnapshot) {
                    final coincidencias = (habSnapshot.data ?? const <Habitacion>[]).where((h) => h.id == elemento.habitacionId);
                    final nombreHabitacion = coincidencias.isEmpty ? null : coincidencias.first.nombre;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (nombreHabitacion ?? 'Elemento').toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.colors.inkMuted),
                        ),
                        Text(elemento.nombre, style: Theme.of(context).textTheme.displaySmall),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FichaCard(elemento: elemento, onEditarMantenimiento: () => _editarMantenimiento(context, elemento)),
                    if (elemento.intervaloMantenimientoMeses != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _marcarRevisionHecha(context, elemento),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Marcar revisión como hecha'),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text('Historial', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    StreamBuilder<List<Registro>>(
                      stream: RegistroService.streamRegistros(casa.id, elemento.id),
                      builder: (context, snapshot) {
                        final registros = snapshot.data ?? [];
                        if (registros.isEmpty) {
                          return Text('Sin registros todavía.', style: TextStyle(color: context.colors.inkMuted));
                        }
                        return Column(
                          children: registros
                              .map((r) => Card(
                                    margin: const EdgeInsets.only(bottom: 9),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(ReparaRadius.md),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => RegistroDetailScreen(casa: casa, elementoId: elemento.id, registroId: r.id)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(color: context.colors.brandTint, borderRadius: BorderRadius.circular(ReparaRadius.sm)),
                                              child: Icon(Icons.fact_check_outlined, size: 18, color: context.colors.brand),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(r.titulo, style: Theme.of(context).textTheme.titleMedium),
                                                  Text(DateFormat('d MMM yyyy', 'es_ES').format(r.fecha), style: Theme.of(context).textTheme.bodySmall),
                                                ],
                                              ),
                                            ),
                                            if (r.coste != null) Text('${r.coste!.toStringAsFixed(0)} €', style: ReparaText.amount(context)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Documentos', style: Theme.of(context).textTheme.headlineSmall),
                        TextButton.icon(
                          onPressed: () => iniciarNuevoDocumento(
                            context,
                            casaId: casa.id,
                            elementoId: elemento.id,
                            habitacionId: elemento.habitacionId,
                          ),
                          icon: const Icon(Icons.document_scanner_outlined, size: 18),
                          label: const Text('Escanear documento'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Documento>>(
                      stream: DocumentoService.streamDocumentos(casa.id, elementoId: elemento.id),
                      builder: (context, snapshot) {
                        final documentos = snapshot.data ?? [];
                        if (documentos.isEmpty) {
                          return Text('Sin documentos todavía.', style: TextStyle(color: context.colors.inkMuted));
                        }
                        return IosSection(rows: documentos.map((d) => _DocumentoTile(documento: d)).toList());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FichaCard extends StatelessWidget {
  const _FichaCard({required this.elemento, required this.onEditarMantenimiento});

  final Elemento elemento;
  final VoidCallback onEditarMantenimiento;

  @override
  Widget build(BuildContext context) {
    return IosSection(
      rows: [
        if (elemento.marca != null)
          IosValueRow(label: 'Marca / modelo', value: '${elemento.marca} ${elemento.modelo ?? ''}'.trim()),
        if (elemento.fechaInstalacion != null)
          IosValueRow(label: 'Instalado', value: DateFormat('d MMMM yyyy', 'es_ES').format(elemento.fechaInstalacion!)),
        if (elemento.coste != null) IosValueRow(label: 'Coste', value: '${elemento.coste!.toStringAsFixed(0)} €'),
        if (elemento.profesionalNombre != null) IosValueRow(label: 'Profesional', value: elemento.profesionalNombre!),
        if (elemento.garantiaHasta != null)
          IosValueRow(
            label: 'Garantía hasta',
            value: DateFormat('d MMMM yyyy', 'es_ES').format(elemento.garantiaHasta!),
            destacado: elemento.garantiaProximaAVencer,
          ),
        IosValueRow(
          label: 'Próxima revisión',
          value: elemento.proximoMantenimiento != null
              ? DateFormat('d MMMM yyyy', 'es_ES').format(elemento.proximoMantenimiento!)
              : 'Sin configurar',
          destacado: elemento.revisionPendiente,
          onTap: onEditarMantenimiento,
        ),
      ],
    );
  }
}

class _DocumentoTile extends StatelessWidget {
  const _DocumentoTile({required this.documento});

  final Documento documento;

  IconData get _icono => switch (documento.tipo) {
        TipoDocumento.factura => Icons.receipt_long_outlined,
        TipoDocumento.presupuesto => Icons.request_quote_outlined,
        TipoDocumento.garantia => Icons.shield_outlined,
        TipoDocumento.manual => Icons.menu_book_outlined,
        TipoDocumento.contrato => Icons.description_outlined,
        TipoDocumento.otro => Icons.insert_drive_file_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return IosRow(
      icon: _icono,
      iconColor: context.colors.brand,
      title: documento.proveedor ?? documento.nombreArchivo,
      subtitle: documento.fecha != null ? DateFormat('d MMM yyyy', 'es_ES').format(documento.fecha!) : null,
      trailing: documento.importe != null ? Text('${documento.importe!.toStringAsFixed(0)} €', style: ReparaText.amount(context)) : null,
      showChevron: false,
    );
  }
}

/// Foto del elemento a pantalla completa, con zoom -- InteractiveViewer
/// basta (pellizcar para ampliar), sin necesidad de ningún paquete nuevo.
class _FotoAmpliadaScreen extends StatelessWidget {
  const _FotoAmpliadaScreen({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
