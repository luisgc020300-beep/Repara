// lib/screens/registro_simple/registro_simple_cabecera.dart
//
// Cabecera nueva, SOLO para un registro simple (sin profesional) --
// gestión de varias fotos (CEO, octubre 2026): ver galería, contador,
// añadir desde cámara o varias de golpe desde la galería del teléfono,
// ampliar, borrar una a una. _CabeceraRegistro (registro_detail_screen.
// dart) sigue tal cual para el elemento y para un registro CON
// profesional -- ninguno de los dos necesita más de una foto, y no se
// tocan para no alterar esa pantalla (petición explícita del CEO).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/casa.dart';
import '../../models/elemento.dart';
import '../../models/registro.dart';
import '../../services/registro_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';
import '../../widgets/estado_registro_chip.dart';
import '../../widgets/galeria_fotos_screen.dart';
import '../../widgets/ios_list.dart';

class RegistroSimpleCabecera extends StatelessWidget {
  const RegistroSimpleCabecera({
    required this.casa,
    required this.elementoId,
    required this.registro,
    this.elemento,
    super.key,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;
  // Mismo criterio de siempre (_CabeceraRegistro): si este registro
  // todavía no tiene ninguna foto propia, se enseña la del elemento como
  // portada provisional -- nunca forma parte de la galería que se puede
  // ampliar/borrar, solo un respaldo visual hasta que se añada la primera.
  final Elemento? elemento;

  Future<void> _abrirGaleria(BuildContext context, int indiceInicial) async {
    final fotos = registro.fotos;
    if (fotos.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GaleriaFotosScreen(
          urls: fotos,
          indiceInicial: indiceInicial,
          onEliminar: (url) => RegistroService.eliminarFoto(
            casa.id,
            elementoId,
            registro.id,
            fotos,
            url,
          ),
        ),
      ),
    );
  }

  Future<void> _anadirFotos(BuildContext context) async {
    final picker = ImagePicker();
    final elegidas = await showModalBottomSheet<List<XFile>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                  navigator.pop(imagen == null ? null : [imagen]);
                },
              ),
              IosRow(
                icon: Icons.photo_library_outlined,
                iconColor: ctx.colors.brand,
                title: 'Elegir de la galería',
                subtitle: 'Puedes seleccionar varias a la vez',
                onTap: () async {
                  final navigator = Navigator.of(ctx);
                  final imagenes = await picker.pickMultiImage(
                    imageQuality: 85,
                    maxWidth: 1600,
                    maxHeight: 1600,
                  );
                  if (!ctx.mounted) return;
                  navigator.pop(imagenes.isEmpty ? null : imagenes);
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (elegidas == null || elegidas.isEmpty || !context.mounted) return;
    try {
      await RegistroService.agregarFotos(
        casa.id,
        elementoId,
        registro.id,
        registro.fotos,
        elegidas.map((f) => File(f.path)).toList(),
      );
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudieron guardar las fotos.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotos = registro.fotos;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ReparaRadius.md),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: fotos.isEmpty
                      ? () => _anadirFotos(context)
                      : () => _abrirGaleria(context, 0),
                  child: fotos.isNotEmpty
                      ? Image.network(
                          fotos.first,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: double.infinity,
                                height: 160,
                                color: context.colors.surfaceMuted,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 32,
                                  color: context.colors.inkFaint,
                                ),
                              ),
                        )
                      : elemento?.fotoUrl != null
                      ? Image.network(
                          elemento!.fotoUrl!,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: double.infinity,
                                height: 160,
                                color: context.colors.surfaceMuted,
                                child: Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 32,
                                  color: context.colors.inkFaint,
                                ),
                              ),
                        )
                      : Container(
                          width: double.infinity,
                          height: 160,
                          color: context.colors.surfaceMuted,
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 32,
                            color: context.colors.inkFaint,
                          ),
                        ),
                ),
                if (fotos.length > 1)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(ReparaRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_library_outlined,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${fotos.length} fotos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: () => _anadirFotos(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                iconoTipoRegistro(registro.tipo),
                size: 12,
                color: context.colors.inkMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${registro.elementoNombre} · ${nombreTipoRegistro(registro.tipo)}'
                      .toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: context.colors.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            registro.titulo,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              EstadoRegistroChip(estado: registro.estado),
              const SizedBox(width: 8),
              Text(
                '· ${DateFormat('d MMM yyyy', 'es_ES').format(registro.fecha)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (registro.profesionalNombre != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: context.colors.inkMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${registro.profesionalNombre}${registro.profesionalContacto != null ? ' · ${registro.profesionalContacto}' : ''}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
