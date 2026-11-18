// lib/screens/perfil_profesional_screen.dart
//
// Perfil público de un profesional (mejora de perfiles profesionales,
// noviembre 2026) -- solo se abre desde un evento al que ya está vinculado
// (nunca desde un listado/directorio: no es un marketplace). Muestra
// únicamente información pública y agregada -- nombre, especialidad, nº de
// trabajos terminados y valoración media -- nunca nada de una vivienda
// concreta, ni fotos privadas, ni comentarios de otros propietarios.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/perfil_profesional_publico.dart';
import 'package:repara_core/perfil_profesional_service.dart';
import 'package:repara_ui/app_error.dart';

/// Datos del trabajo terminado desde el que se abre el perfil, para ofrecer
/// "Valorar este trabajo" -- null si se abre desde un evento que todavía no
/// está terminado (entonces solo se ve el perfil, sin opción de valorar).
class ContextoValoracion {
  const ContextoValoracion({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
    required this.tituloTrabajo,
  });

  final String casaId;
  final String elementoId;
  final String registroId;
  final String tituloTrabajo;
}

class PerfilProfesionalScreen extends StatelessWidget {
  const PerfilProfesionalScreen({
    required this.profesionalUid,
    required this.nombreMostrado,
    this.contextoValoracion,
    super.key,
  });

  final String profesionalUid;

  /// Nombre a mostrar mientras carga el perfil público, o si el profesional
  /// todavía no ha rellenado nombreComercial -- el que ya conocía esta casa
  /// por el propio evento (Registro.profesionalNombre), nunca inventado.
  final String nombreMostrado;
  final ContextoValoracion? contextoValoracion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil del profesional')),
      body: StreamBuilder<PerfilProfesionalPublico?>(
        stream: PerfilProfesionalService.streamPerfilPublico(profesionalUid),
        builder: (context, snapshot) {
          final perfil = snapshot.data;
          final nombre = (perfil?.nombreComercial?.isNotEmpty ?? false)
              ? perfil!.nombreComercial!
              : nombreMostrado;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: context.colors.brandTint,
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: context.colors.brand,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ReparaSpace.s3),
              Text(
                nombre,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (perfil?.especialidad?.isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(
                  perfil!.especialidad!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.inkMuted),
                ),
              ],
              const SizedBox(height: ReparaSpace.s5),
              Row(
                children: [
                  Expanded(
                    child: _Estadistica(
                      icon: Icons.task_alt_outlined,
                      valor: '${perfil?.trabajosTerminados ?? 0}',
                      etiqueta: 'trabajos terminados',
                    ),
                  ),
                  const SizedBox(width: ReparaSpace.s3),
                  Expanded(
                    child: _Estadistica(
                      icon: Icons.star_rounded,
                      valor: perfil?.valoracionMedia == null
                          ? 'Sin datos'
                          : perfil!.valoracionMedia!.toStringAsFixed(1),
                      etiqueta: (perfil?.numValoraciones ?? 0) == 0
                          ? 'valoraciones'
                          : '${perfil!.numValoraciones} valoración${perfil.numValoraciones == 1 ? '' : 'es'}',
                    ),
                  ),
                ],
              ),
              if (contextoValoracion != null) ...[
                const SizedBox(height: ReparaSpace.s5),
                _SeccionValorar(
                  profesionalUid: profesionalUid,
                  contexto: contextoValoracion!,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Estadistica extends StatelessWidget {
  const _Estadistica({
    required this.icon,
    required this.valor,
    required this.etiqueta,
  });

  final IconData icon;
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s4),
        child: Column(
          children: [
            Icon(icon, color: context.colors.brand),
            const SizedBox(height: 6),
            Text(valor, style: Theme.of(context).textTheme.titleLarge),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeccionValorar extends StatefulWidget {
  const _SeccionValorar({required this.profesionalUid, required this.contexto});

  final String profesionalUid;
  final ContextoValoracion contexto;

  @override
  State<_SeccionValorar> createState() => _SeccionValorarState();
}

class _SeccionValorarState extends State<_SeccionValorar> {
  int _puntuacionElegida = 0;
  final _comentarioCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_puntuacionElegida == 0) {
      AppError.show(context, 'Elige de 1 a 5 estrellas antes de enviar.');
      return;
    }
    setState(() => _enviando = true);
    try {
      await PerfilProfesionalService.crearValoracion(
        casaId: widget.contexto.casaId,
        elementoId: widget.contexto.elementoId,
        registroId: widget.contexto.registroId,
        puntuacion: _puntuacionElegida,
        comentario: _comentarioCtrl.text.trim(),
      );
      if (mounted) AppError.showSuccess(context, '¡Gracias por tu valoración!');
    } on FirebaseFunctionsException catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          e.code == 'already-exists'
              ? 'Ya has valorado este trabajo.'
              : (e.message ?? 'No se pudo enviar la valoración.'),
          error: e,
          stackTrace: st,
        );
      }
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo enviar la valoración.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MiValoracion?>(
      stream: PerfilProfesionalService.streamMiValoracion(
        widget.contexto.registroId,
      ),
      builder: (context, snapshot) {
        final mia = snapshot.data;
        if (mia != null) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(ReparaSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu valoración de "${widget.contexto.tituloTrabajo}"',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < mia.puntuacion
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: context.colors.warning,
                      ),
                    ),
                  ),
                  if ((mia.comentario ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(mia.comentario!),
                  ],
                ],
              ),
            ),
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(ReparaSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valorar "${widget.contexto.tituloTrabajo}"',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final estrella = i + 1;
                    return IconButton(
                      onPressed: () =>
                          setState(() => _puntuacionElegida = estrella),
                      icon: Icon(
                        estrella <= _puntuacionElegida
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: context.colors.warning,
                        size: 32,
                      ),
                    );
                  }),
                ),
                TextField(
                  controller: _comentarioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Comentario (opcional)',
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _enviando ? null : _enviar,
                    child: _enviando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enviar valoración'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
