// lib/screens/mis_valoraciones_screen.dart
//
// Reputación del profesional (unificación del sistema de valoraciones,
// noviembre 2026) -- nota media, nº total y distribución por estrellas
// vienen de profesionalesPublico/{uid} (el mismo agregado que ya usan el
// perfil público en Hogar, las tarjetas de Contactos y Cercanos -- nunca
// se recalcula nada aquí, una sola fuente de verdad). Los comentarios
// individuales vienen de valoraciones, filtradas a las del propio
// profesional (firestore.rules ya lo permite tal cual, sin cambios --
// ver PerfilProfesionalService.streamMisValoracionesRecibidas).
//
// Solo lectura: el profesional consulta sus valoraciones, nunca puede
// editarlas, borrarlas ni manipular su puntuación -- no hay ningún botón
// ni acción de escritura en esta pantalla.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/perfil_profesional_publico.dart';
import 'package:repara_core/perfil_profesional_service.dart';

class MisValoracionesScreen extends StatelessWidget {
  const MisValoracionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi reputación')),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<PerfilProfesionalPublico?>(
              stream: PerfilProfesionalService.streamPerfilPublico(uid),
              builder: (context, perfilSnapshot) {
                final perfil = perfilSnapshot.data;
                return StreamBuilder<List<ValoracionRecibida>>(
                  stream: PerfilProfesionalService.streamMisValoracionesRecibidas(),
                  builder: (context, valSnapshot) {
                    final valoraciones = valSnapshot.data ?? const [];
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, ReparaSpace.s4, 16, 32),
                      children: [
                        _CabeceraReputacion(perfil: perfil),
                        const SizedBox(height: ReparaSpace.s5),
                        Text(
                          'Distribución',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        _DistribucionEstrellas(valoraciones: valoraciones),
                        const SizedBox(height: ReparaSpace.s5),
                        Text(
                          'Comentarios',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        if (valoraciones.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Todavía no has recibido ninguna valoración.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.colors.inkMuted),
                            ),
                          )
                        else
                          ...valoraciones.map((v) => _TarjetaValoracion(valoracion: v)),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _CabeceraReputacion extends StatelessWidget {
  const _CabeceraReputacion({required this.perfil});

  final PerfilProfesionalPublico? perfil;

  @override
  Widget build(BuildContext context) {
    final media = perfil?.valoracionMedia;
    final total = perfil?.numValoraciones ?? 0;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s5),
        child: Column(
          children: [
            Text(
              media == null ? 'Sin valoraciones' : media.toStringAsFixed(1),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 40,
                color: context.colors.brand,
              ),
            ),
            const SizedBox(height: 4),
            if (media != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final lleno = i < media.round();
                  return Icon(
                    lleno ? Icons.star_rounded : Icons.star_border_rounded,
                    color: context.colors.warning,
                    size: 22,
                  );
                }),
              ),
            const SizedBox(height: 6),
            Text(
              total == 0
                  ? 'Todavía no has recibido ninguna valoración'
                  : '$total valoración${total == 1 ? '' : 'es'}',
              style: TextStyle(color: context.colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistribucionEstrellas extends StatelessWidget {
  const _DistribucionEstrellas({required this.valoraciones});

  final List<ValoracionRecibida> valoraciones;

  @override
  Widget build(BuildContext context) {
    final total = valoraciones.length;
    final conteo = <int, int>{for (var i = 1; i <= 5; i++) i: 0};
    for (final v in valoraciones) {
      if (conteo.containsKey(v.puntuacion)) conteo[v.puntuacion] = conteo[v.puntuacion]! + 1;
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s4),
        child: Column(
          children: [
            for (var estrellas = 5; estrellas >= 1; estrellas--)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text('$estrellas', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 4),
                    Icon(Icons.star_rounded, size: 14, color: context.colors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : (conteo[estrellas] ?? 0) / total,
                          minHeight: 8,
                          backgroundColor: context.colors.surfaceSunken,
                          color: context.colors.brand,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${conteo[estrellas] ?? 0}',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaValoracion extends StatelessWidget {
  const _TarjetaValoracion({required this.valoracion});

  final ValoracionRecibida valoracion;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: ReparaSpace.s2),
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < valoracion.puntuacion ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 16,
                      color: context.colors.warning,
                    ),
                  ),
                ),
                const Spacer(),
                if (valoracion.createdAt != null)
                  Text(
                    DateFormat('d MMM yyyy', 'es_ES').format(valoracion.createdAt!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            if ((valoracion.registroTitulo ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                valoracion.registroTitulo!,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
            if ((valoracion.comentario ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(valoracion.comentario!),
            ],
          ],
        ),
      ),
    );
  }
}
