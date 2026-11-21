// lib/screens/cercanos_screen.dart
//
// "Cercanos" (noviembre 2026) -- a diferencia del resto de Contactos, esto
// SÍ busca gente nueva a propósito (decisión explícita del CEO, que revierte
// la de las dos tareas anteriores): profesionales que han optado por
// hacerse visibles cerca de ti, para cuando no tienes disponible a ninguno
// de tus profesionales habituales.
//
// Nunca se pide el permiso de ubicación al abrir Contactos -- solo al
// entrar aquí, y solo una vez por visita a esta pantalla. El servidor
// (buscarProfesionalesCercanos) ya devuelve los resultados ordenados por
// cercanía y con la distancia redondeada -- este archivo nunca ve ni
// necesita coordenadas de nadie.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/invitacion_service.dart';
import 'package:repara_core/location_service.dart';
import 'package:repara_core/perfil_profesional_service.dart';
import 'package:repara_core/profesional_cercano.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/valoracion_resumen.dart';

import 'contacto_acciones.dart' show elegirEventoParaInvitar;
import 'perfil_profesional_screen.dart';

enum _EstadoCercanos {
  cargando,
  resultados,
  servicioDesactivado,
  permisoDenegado,
  permisoDenegadoParaSiempre,
  limiteAlcanzado,
  error,
}

class CercanosScreen extends StatefulWidget {
  const CercanosScreen({required this.casaId, super.key});

  final String casaId;

  @override
  State<CercanosScreen> createState() => _CercanosScreenState();
}

class _CercanosScreenState extends State<CercanosScreen> {
  _EstadoCercanos _estado = _EstadoCercanos.cargando;
  List<ProfesionalCercano> _resultados = const [];

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  Future<void> _buscar() async {
    setState(() => _estado = _EstadoCercanos.cargando);

    final permiso = await DeviceLocation.instance.solicitarPermiso();
    if (!mounted) return;
    switch (permiso) {
      case SolicitudUbicacionResultado.servicioDesactivado:
        setState(() => _estado = _EstadoCercanos.servicioDesactivado);
        return;
      case SolicitudUbicacionResultado.denegadoParaSiempre:
        setState(() => _estado = _EstadoCercanos.permisoDenegadoParaSiempre);
        return;
      case SolicitudUbicacionResultado.denegado:
        setState(() => _estado = _EstadoCercanos.permisoDenegado);
        return;
      case SolicitudUbicacionResultado.error:
        setState(() => _estado = _EstadoCercanos.error);
        return;
      case SolicitudUbicacionResultado.concedido:
        break;
    }

    final posicion = await DeviceLocation.instance.posicionActual();
    if (!mounted) return;
    if (posicion == null) {
      setState(() => _estado = _EstadoCercanos.error);
      return;
    }

    try {
      final resultados = await PerfilProfesionalService.buscarCercanos(
        lat: posicion.lat,
        lng: posicion.lng,
      );
      if (!mounted) return;
      setState(() {
        _resultados = resultados;
        _estado = _EstadoCercanos.resultados;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(
        () => _estado = e.code == 'resource-exhausted'
            ? _EstadoCercanos.limiteAlcanzado
            : _EstadoCercanos.error,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _estado = _EstadoCercanos.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cercanos')),
      body: switch (_estado) {
        _EstadoCercanos.cargando => const Center(
          child: CircularProgressIndicator(),
        ),
        _EstadoCercanos.servicioDesactivado => _MensajeEstado(
          icon: Icons.location_off_outlined,
          titulo: 'La ubicación está desactivada',
          mensaje:
              'Activa la ubicación de tu dispositivo para buscar profesionales cerca de ti.',
          accionLabel: 'Abrir ajustes',
          onAccion: () async {
            await DeviceLocation.instance.abrirAjustesUbicacion();
          },
          onReintentar: _buscar,
        ),
        _EstadoCercanos.permisoDenegado => _MensajeEstado(
          icon: Icons.my_location_outlined,
          titulo: 'Necesitamos tu ubicación',
          mensaje:
              'Para encontrar profesionales cerca de ti, Repara necesita permiso de ubicación.',
          accionLabel: 'Volver a intentar',
          onAccion: _buscar,
        ),
        _EstadoCercanos.permisoDenegadoParaSiempre => _MensajeEstado(
          icon: Icons.location_disabled_outlined,
          titulo: 'Permiso de ubicación bloqueado',
          mensaje:
              'Has denegado el permiso de ubicación de forma permanente. Actívalo desde los ajustes de la app para usar Cercanos.',
          accionLabel: 'Abrir ajustes de la app',
          onAccion: () async {
            await DeviceLocation.instance.abrirAjustesApp();
          },
          onReintentar: _buscar,
        ),
        _EstadoCercanos.limiteAlcanzado => _MensajeEstado(
          icon: Icons.hourglass_bottom_outlined,
          titulo: 'Demasiadas búsquedas',
          mensaje: 'Has repetido esta búsqueda muchas veces hoy. Inténtalo de nuevo mañana.',
        ),
        _EstadoCercanos.error => _MensajeEstado(
          icon: Icons.error_outline,
          titulo: 'No se pudo buscar',
          mensaje: 'Algo ha fallado al buscar profesionales cercanos.',
          accionLabel: 'Reintentar',
          onAccion: _buscar,
        ),
        _EstadoCercanos.resultados => _resultados.isEmpty
            ? const _MensajeEstado(
                icon: Icons.near_me_outlined,
                titulo: 'Nadie cerca por ahora',
                mensaje:
                    'Ningún profesional visible en Cercanos está a menos de 50 km de ti todavía.',
              )
            : _ListaResultados(
                casaId: widget.casaId,
                resultados: _resultados,
              ),
      },
    );
  }
}

class _MensajeEstado extends StatelessWidget {
  const _MensajeEstado({
    required this.icon,
    required this.titulo,
    required this.mensaje,
    this.accionLabel,
    this.onAccion,
    this.onReintentar,
  });

  final IconData icon;
  final String titulo;
  final String mensaje;
  final String? accionLabel;
  final VoidCallback? onAccion;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.colors.brandTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: context.colors.brand),
            ),
            const SizedBox(height: 16),
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.inkMuted),
            ),
            if (accionLabel != null && onAccion != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  onAccion!();
                  onReintentar?.call();
                },
                child: Text(accionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListaResultados extends StatelessWidget {
  const _ListaResultados({required this.casaId, required this.resultados});

  final String casaId;
  final List<ProfesionalCercano> resultados;

  // El servidor nunca manda menos de 2 km (suelo deliberado contra
  // triangulación, ver distanciaAproximadaKm en functions/index.js) -- aquí
  // solo se formatea, nunca se afina más.
  String _distanciaLabel(double km) {
    if (km <= 2) return 'A menos de 2 km';
    final esEntero = km == km.roundToDouble();
    final texto = esEntero ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
    return 'A $texto km';
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, ReparaSpace.s4, 16, 32),
      itemCount: resultados.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = resultados[i];
        final nombre = (p.nombreComercial?.isNotEmpty ?? false)
            ? p.nombreComercial!
            : 'Profesional';
        return Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PerfilProfesionalScreen(
                  profesionalUid: p.uid,
                  nombreMostrado: nombre,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: context.colors.brandTint,
                    backgroundImage: p.fotoUrl != null
                        ? NetworkImage(p.fotoUrl!)
                        : null,
                    child: p.fotoUrl == null
                        ? Text(
                            nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                            style: TextStyle(color: context.colors.brand),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (p.especialidad?.isNotEmpty ?? false)
                          Text(
                            p.especialidad!,
                            style: TextStyle(color: context.colors.inkMuted),
                          ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: context.colors.inkMuted,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _distanciaLabel(p.distanciaAproxKm),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Visibilidad suficiente para decidir con quién
                        // contactar (CEO) -- en su propia línea, no
                        // apretujada junto a la distancia. Misma fuente
                        // (profesionalesPublico) y mismo widget que
                        // Contactos y REPARA Pro -- nunca una cifra propia
                        // calculada aquí.
                        ValoracionResumen(
                          valoracionMedia: p.valoracionMedia,
                          numValoraciones: p.numValoraciones,
                          tamanoEstrella: 16,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Invitar a un evento',
                    icon: Icon(
                      Icons.person_add_alt_outlined,
                      color: context.colors.brand,
                    ),
                    onPressed: () => _invitar(context, p, nombre),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _invitar(
    BuildContext context,
    ProfesionalCercano p,
    String nombre,
  ) async {
    // Bug real (CEO, noviembre 2026: "le doy al + y no hace nada"): si
    // eventosDisponiblesParaInvitar() falla (p.ej. consulta a Firestore sin
    // índice), la excepción no tenía ningún try/catch alrededor y quedaba
    // sin capturar -- el botón parecía no hacer nada en absoluto, sin
    // mensaje de error ni nada visible.
    final elegido = await (() async {
      try {
        return await elegirEventoParaInvitar(
          context,
          casaId: casaId,
          nombrePersona: nombre,
        );
      } catch (e, st) {
        if (context.mounted) {
          AppError.show(
            context,
            'No se pudo comprobar tus eventos abiertos a un profesional.',
            error: e,
            stackTrace: st,
          );
        }
        return null;
      }
    })();
    if (elegido == null || !context.mounted) return;
    try {
      final resultado = await InvitacionService.invitarProfesional(
        casaId: casaId,
        elementoId: elegido.elementoId,
        registroId: elegido.registro.id,
        profesionalUidDirecto: p.uid,
      );
      if (!context.mounted) return;
      if (resultado.esDirecta) {
        AppError.showSuccess(context, 'Invitación enviada a $nombre.');
      }
    } on FirebaseFunctionsException catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          e.code == 'not-found'
              ? 'Ese profesional ya no está disponible.'
              : (e.message ?? 'No se pudo enviar la invitación.'),
          error: e,
          stackTrace: st,
        );
      }
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo enviar la invitación.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }
}
