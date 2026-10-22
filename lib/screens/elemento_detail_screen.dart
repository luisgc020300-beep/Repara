// lib/screens/elemento_detail_screen.dart
//
// Ficha de un elemento (sección 11 del spec) -- una de las seis pantallas
// que el spec marca como "estrella" porque representan la propuesta de
// valor: convertir un aparato suelto en una identidad digital con su propio
// historial y documentación. Rediseño de fidelidad visual (octubre 2026),
// misma identidad "REPARA Professional" que registro_detail_screen.dart,
// adaptada a que esta ficha trata de un objeto físico: la foto vive dentro
// de una tarjeta (no detrás de un AppBar transparente) y el mantenimiento
// tiene su propia tarjeta con acciones, igual que la de registro_detail_
// screen.dart (que lee estos mismos campos del Elemento).
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
  const ElementoDetailScreen({
    required this.casa,
    required this.elementoId,
    super.key,
  });

  final Casa casa;
  final String elementoId;

  Future<void> _editarMantenimiento(
    BuildContext context,
    Elemento elemento,
  ) async {
    final intervaloCtrl = TextEditingController(
      text: elemento.intervaloMantenimientoMeses?.toString() ?? '',
    );
    DateTime? proxima = elemento.proximoMantenimiento;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: AppDialog.shape(),
          title: const Text('Revisión periódica'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: intervaloCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Revisar cada cuántos meses',
                ),
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
                label: Text(
                  proxima == null
                      ? 'Próxima revisión'
                      : '${proxima!.day}/${proxima!.month}/${proxima!.year}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
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
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo guardar la revisión periódica.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _cambiarFoto(BuildContext context, Elemento elemento) async {
    final picker = ImagePicker();
    final foto = await showModalBottomSheet<XFile?>(
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
                icon: Icons.photo_camera_outlined,
                iconColor: ctx.colors.brand,
                title: 'Hacer una foto',
                onTap: () async {
                  final navigator = Navigator.of(ctx);
                  final imagen = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                    maxWidth: 1600,
                    maxHeight: 1600,
                  );
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
                  final imagen = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                    maxWidth: 1600,
                    maxHeight: 1600,
                  );
                  if (!ctx.mounted) return;
                  navigator.pop(imagen);
                },
              ),
              if (elemento.fotoUrl != null)
                IosRow(
                  icon: Icons.delete_outline,
                  iconColor: ctx.colors.errorText,
                  titleColor: ctx.colors.errorText,
                  title: 'Eliminar foto',
                  showChevron: false,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _eliminarFoto(context, elemento);
                  },
                ),
            ],
          ),
        ),
      ),
    );
    if (foto == null || !context.mounted) return;
    try {
      final url = await ElementoService.subirFoto(
        casa.id,
        elemento.id,
        File(foto.path),
      );
      await ElementoService.actualizarFoto(casa.id, elemento.id, url);
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo guardar la foto.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _eliminarFoto(BuildContext context, Elemento elemento) async {
    final confirmar = await AppDialog.confirmText(
      context,
      title: '¿Eliminar la foto?',
      confirmLabel: 'Eliminar',
    );
    if (!confirmar || !context.mounted) return;
    try {
      await ElementoService.actualizarFoto(casa.id, elemento.id, null);
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo eliminar la foto.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _marcarRevisionHecha(
    BuildContext context,
    Elemento elemento,
  ) async {
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
      await ElementoService.marcarRevisionHecha(
        casa.id,
        elemento.id,
        intervalo,
      );
      if (context.mounted) {
        AppError.showSuccess(
          context,
          'Revisión registrada. Próxima en $intervalo meses.',
        );
      }
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo registrar la revisión.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _eliminar(BuildContext context, Elemento elemento) async {
    final confirmar = await AppDialog.confirmText(
      context,
      title: '¿Eliminar elemento?',
      message: 'Se eliminará la ficha, no su historial ya registrado.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmar || !context.mounted) return;
    await ElementoService.eliminar(casa.id, elemento.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Elemento?>(
      stream: ElementoService.streamElemento(casa.id, elementoId),
      builder: (context, snapshot) {
        final elemento = snapshot.data;
        if (elemento == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 14,
                  color: context.colors.inkMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    casa.nombre,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar ficha',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NuevoElementoScreen(
                      casa: casa,
                      habitacionIdInicial: elemento.habitacionId,
                      existente: elemento,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: context.colors.errorText,
                ),
                tooltip: 'Eliminar elemento',
                onPressed: () => _eliminar(context, elemento),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => mostrarNuevoRegistroSheet(
              context,
              casaId: casa.id,
              elementoId: elemento.id,
              elementoNombre: elemento.nombre,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Añadir evento'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              _FotoElemento(
                onTap: () => _onTapFoto(context, elemento),
                onEditar: () => _cambiarFoto(context, elemento),
                fotoUrl: elemento.fotoUrl,
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<Habitacion>>(
                stream: HabitacionService.streamHabitaciones(casa.id),
                builder: (context, habSnapshot) {
                  final coincidencias =
                      (habSnapshot.data ?? const <Habitacion>[]).where(
                        (h) => h.id == elemento.habitacionId,
                      );
                  final nombreHabitacion = coincidencias.isEmpty
                      ? null
                      : coincidencias.first.nombre;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.room_outlined,
                            size: 12,
                            color: context.colors.inkMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            (nombreHabitacion ?? 'Sin habitación asignada')
                                .toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 11,
                                  color: context.colors.inkMuted,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        elemento.nombre,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              _TarjetaInformacion(elemento: elemento),
              const SizedBox(height: 16),
              _TarjetaMantenimiento(
                elemento: elemento,
                onEditar: () => _editarMantenimiento(context, elemento),
                onMarcarHecha: () => _marcarRevisionHecha(context, elemento),
              ),
              const SizedBox(height: 22),
              Text(
                'Historial',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<Registro>>(
                stream: RegistroService.streamRegistros(casa.id, elemento.id),
                builder: (context, snapshot) {
                  final registros = snapshot.data ?? [];
                  if (registros.isEmpty) {
                    return const EmptyHint(
                      message: 'Sin eventos todavía.',
                      icon: Icons.fact_check_outlined,
                    );
                  }
                  return IosSection(
                    rows: registros
                        .map(
                          (r) => IosRow(
                            icon: Icons.fact_check_outlined,
                            iconColor: context.colors.brand,
                            title: r.titulo,
                            subtitle: DateFormat(
                              'd MMM yyyy',
                              'es_ES',
                            ).format(r.fecha),
                            trailing: r.coste != null
                                ? Text(
                                    '${r.coste!.toStringAsFixed(0)} €',
                                    style: ReparaText.amount(context),
                                  )
                                : null,
                            showChevron: false,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegistroDetailScreen(
                                  casa: casa,
                                  elementoId: elemento.id,
                                  registroId: r.id,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Documentos',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
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
                stream: DocumentoService.streamDocumentos(
                  casa.id,
                  elementoId: elemento.id,
                ),
                builder: (context, snapshot) {
                  final documentos = snapshot.data ?? [];
                  if (documentos.isEmpty) {
                    return const EmptyHint(
                      message: 'Sin documentos todavía.',
                      icon: Icons.description_outlined,
                    );
                  }
                  return IosSection(
                    rows: documentos
                        .map((d) => _DocumentoTile(documento: d))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onTapFoto(BuildContext context, Elemento elemento) {
    if (elemento.fotoUrl == null) {
      _cambiarFoto(context, elemento);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FotoAmpliadaScreen(url: elemento.fotoUrl!),
        ),
      );
    }
  }
}

/// Foto del elemento dentro de una tarjeta -- a diferencia del banner a
/// pantalla completa de antes, vive en el flujo normal del contenido con el
/// mismo radio/borde que el resto de tarjetas de la app, para que el AppBar
/// y sus controles de navegación nunca queden detrás de la imagen ni se
/// pierdan al hacer scroll. Sin foto, un estado vacío que invita a tocar en
/// vez de fingir una imagen (auditoría de craft, octubre 2026). Con foto,
/// tocarla la amplía a pantalla completa -- cambiarla es el lápiz pequeño de
/// la esquina.
class _FotoElemento extends StatelessWidget {
  const _FotoElemento({
    required this.fotoUrl,
    required this.onTap,
    required this.onEditar,
  });

  final String? fotoUrl;
  final VoidCallback onTap;

  /// Toca del lápiz, separado de [onTap] -- antes compartían el mismo
  /// GestureDetector del Stack entero, así que con foto, tocar el lápiz
  /// hacía lo mismo que tocar cualquier otro punto de la imagen (ampliarla),
  /// nunca abría el selector de cámara/galería (CEO, octubre 2026: "el
  /// botón de abajo a la derecha... no funciona").
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 190,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.colors.surfaceMuted,
          borderRadius: BorderRadius.circular(ReparaRadius.lg),
          border: Border.all(color: context.colors.border),
        ),
        child: Stack(
          children: [
            if (fotoUrl != null)
              Positioned.fill(
                child: Image.network(
                  fotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 30,
                          color: context.colors.inkFaint,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No se pudo cargar la foto. Toca el lápiz para cambiarla.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 30,
                      color: context.colors.inkFaint,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toca para añadir una foto',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (fotoUrl != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: GestureDetector(
                  onTap: onEditar,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Información consolidada en una sola tarjeta -- marca/modelo, instalación,
/// coste, profesional y garantía. El mantenimiento tiene su propia tarjeta
/// (ver _TarjetaMantenimiento) porque, a diferencia de estos, lleva acciones
/// propias. Si no hay ningún dato, IosSection no pinta nada (nunca una
/// sección vacía sin utilidad real).
class _TarjetaInformacion extends StatelessWidget {
  const _TarjetaInformacion({required this.elemento});

  final Elemento elemento;

  @override
  Widget build(BuildContext context) {
    return IosSection(
      rows: [
        if (elemento.marca != null)
          IosValueRow(
            label: 'Marca / modelo',
            value: '${elemento.marca} ${elemento.modelo ?? ''}'.trim(),
          ),
        if (elemento.fechaInstalacion != null)
          IosValueRow(
            label: 'Instalado',
            value: DateFormat(
              'd MMMM yyyy',
              'es_ES',
            ).format(elemento.fechaInstalacion!),
          ),
        if (elemento.coste != null)
          IosValueRow(
            label: 'Coste',
            value: '${elemento.coste!.toStringAsFixed(0)} €',
          ),
        if (elemento.profesionalNombre != null)
          IosValueRow(label: 'Profesional', value: elemento.profesionalNombre!),
        if (elemento.garantiaHasta != null)
          IosValueRow(
            label: 'Garantía hasta',
            value: DateFormat(
              'd MMMM yyyy',
              'es_ES',
            ).format(elemento.garantiaHasta!),
            destacado: elemento.garantiaProximaAVencer,
          ),
      ],
    );
  }
}

/// Mismo lenguaje visual que la tarjeta de mantenimiento de
/// registro_detail_screen.dart (que lee estos mismos campos del Elemento
/// padre): icono+texto arriba a todo lo ancho, acciones debajo -- nunca
/// todo en una sola fila, para que el texto no se apriete contra el botón.
class _TarjetaMantenimiento extends StatelessWidget {
  const _TarjetaMantenimiento({
    required this.elemento,
    required this.onEditar,
    required this.onMarcarHecha,
  });

  final Elemento elemento;
  final VoidCallback onEditar;
  final VoidCallback onMarcarHecha;

  @override
  Widget build(BuildContext context) {
    final fecha = elemento.proximoMantenimiento;
    final destacado = elemento.revisionPendiente;
    final puedeMarcarHecha = elemento.intervaloMantenimientoMeses != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(ReparaRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_outlined, color: context.colors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Próxima revisión',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fecha != null
                          ? DateFormat('d MMMM yyyy', 'es_ES').format(fecha)
                          : 'Sin configurar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: destacado ? context.colors.warningText : null,
                        fontWeight: destacado ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditar,
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(fecha != null ? 'Editar' : 'Configurar'),
                ),
              ),
              if (puedeMarcarHecha) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onMarcarHecha,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Marcar hecha'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
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
      subtitle: documento.fecha != null
          ? DateFormat('d MMM yyyy', 'es_ES').format(documento.fecha!)
          : null,
      trailing: documento.importe != null
          ? Text(
              '${documento.importe!.toStringAsFixed(0)} €',
              style: ReparaText.amount(context),
            )
          : null,
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
