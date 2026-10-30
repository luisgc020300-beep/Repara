// lib/screens/registro_simple/registro_cabecera.dart
//
// Cabecera de un registro -- ahora COMPARTIDA entre simple y con
// profesional (CEO, octubre 2026): antes había dos ("RegistroSimpleCabecera"
// con una foto grande de portada arriba, y "_CabeceraRegistro" en
// registro_detail_screen.dart con una miniatura pequeña a la derecha y el
// texto a la izquierda, de una sola foto). El CEO pidió que el simple se
// viera como el de con profesional (texto a la izquierda, foto pequeña a
// la derecha) Y que el de con profesional también admitiera varias fotos
// -- así que se fusionan en una sola: el layout de _CabeceraRegistro, con
// la gestión de galería (ver/añadir/ampliar/borrar) que ya tenía esta.
// RegistroService.agregarFotos/eliminarFoto ya eran genéricos (casaId/
// elementoId/registroId, sin distinguir esConProfesional), así que no hace
// falta tocar nada de servidor.
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

class RegistroCabecera extends StatelessWidget {
  const RegistroCabecera({
    required this.casa,
    required this.elementoId,
    required this.registro,
    this.elemento,
    super.key,
  });

  final Casa casa;
  final String elementoId;
  final Registro registro;
  // Si este registro todavía no tiene ninguna foto propia, se enseña la
  // del elemento como portada provisional -- nunca forma parte de la
  // galería que se puede ampliar/borrar, solo un respaldo visual hasta que
  // se añada la primera.
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
    final fotoPortada = fotos.isNotEmpty ? fotos.first : elemento?.fotoUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                // Solo en un registro simple: no tiene su propia pestaña
                // "Profesional" (ver _SeccionInvitarProfesional, exclusiva
                // del cuerpo con profesional) -- aquí es el único sitio
                // donde se ve este dato.
                if (!registro.esConProfesional &&
                    registro.profesionalNombre != null) ...[
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(ReparaRadius.md),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: fotos.isEmpty
                      ? () => _anadirFotos(context)
                      : () => _abrirGaleria(context, 0),
                  child: fotoPortada != null
                      ? Image.network(
                          fotoPortada,
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          // URL de foto rota -- cae a un icono claro en vez
                          // de dejar un hueco en blanco.
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 92,
                                height: 92,
                                color: context.colors.surfaceMuted,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 24,
                                  color: context.colors.inkFaint,
                                ),
                              ),
                        )
                      : Container(
                          width: 92,
                          height: 92,
                          color: context.colors.surfaceMuted,
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 24,
                            color: context.colors.inkFaint,
                          ),
                        ),
                ),
                if (fotos.length > 1)
                  Positioned(
                    left: 3,
                    top: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
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
                            size: 9,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${fotos.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (fotos.isNotEmpty)
                  Positioned(
                    right: 3,
                    bottom: 3,
                    child: GestureDetector(
                      onTap: () => _anadirFotos(context),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_a_photo_outlined,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
