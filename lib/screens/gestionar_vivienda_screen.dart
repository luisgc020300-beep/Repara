// lib/screens/gestionar_vivienda_screen.dart
//
// "Gestiona tu vivienda" (rediseño Ajustes, noviembre 2026): consolida lo
// que antes era la sección "Tu casa" + el selector de "Tus casas" + el
// canje de código de trabajo, todo suelto directamente en Ajustes. Lógica
// movida tal cual desde settings_screen.dart -- solo cambia dónde vive.
import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:repara_core/analytics_service.dart';
import 'package:repara_core/invitacion_service.dart';

import '../models/casa.dart';
import '../services/casa_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';
import 'documentos_casa_screen.dart';
import 'expediente_vivienda_screen.dart';

class GestionarViviendaScreen extends StatefulWidget {
  const GestionarViviendaScreen({required this.casa, super.key});

  final Casa casa;

  @override
  State<GestionarViviendaScreen> createState() => _GestionarViviendaScreenState();
}

class _GestionarViviendaScreenState extends State<GestionarViviendaScreen> {
  Future<void> _renombrarCasa(Casa casa) async {
    final nombre = await AppDialog.promptText(context, title: 'Nombre de la casa', initialValue: casa.nombre);
    if (nombre == null || nombre.isEmpty || nombre == casa.nombre) return;
    try {
      await CasaService.renombrarCasa(casa.id, nombre);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo renombrar la casa.');
    }
  }

  Future<void> _canjearCodigoTrabajo() async {
    final codigo = await AppDialog.promptText(
      context,
      title: 'Código de invitación',
      hint: 'Ej. AB12CD',
      confirmLabel: 'Canjear',
      textCapitalization: TextCapitalization.characters,
    );
    if (codigo == null || codigo.isEmpty || !mounted) return;
    try {
      final resultado = await InvitacionService.canjearCodigo(codigo);
      if (mounted) {
        AppError.showSuccess(
          context,
          'Vinculado a "${resultado.registroTitulo}" en ${resultado.casaNombre}. Acéptalo desde Inicio Pro.',
        );
      }
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'Ese código no es válido o ya se ha usado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final casa = widget.casa;
    return Scaffold(
      appBar: AppBar(title: const Text('Tu vivienda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          IosSection(
            header: 'Tu casa',
            rows: [
              IosRow(
                icon: Icons.house_outlined,
                iconColor: context.colors.brand,
                title: casa.nombre,
                subtitle: 'Toca para cambiar el nombre',
                onTap: () => _renombrarCasa(casa),
              ),
              IosRow(
                icon: Icons.folder_open_outlined,
                iconColor: context.colors.brand,
                title: 'Documentos',
                subtitle: 'Facturas, presupuestos y garantías guardados',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentosCasaScreen(casa: casa))),
              ),
              IosRow(
                icon: Icons.summarize_outlined,
                iconColor: context.colors.brand,
                title: 'Expediente de la vivienda',
                subtitle: 'Para vender, asegurar o pedir financiación',
                onTap: () {
                  unawaited(AnalyticsService.householdRecordViewed());
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ExpedienteViviendaScreen(casa: casa)));
                },
              ),
              IosRow(
                icon: Icons.group_outlined,
                iconColor: context.colors.brand,
                title: 'Miembros de esta casa',
                subtitle: casa.memberProfiles.values.map((m) => m.displayName).join(', '),
              ),
              if (casa.joinCode != null)
                IosRow(
                  icon: Icons.key_outlined,
                  iconColor: context.colors.brand,
                  title: 'Código para invitar a alguien',
                  subtitle: casa.joinCode!,
                ),
            ],
          ),
          _SeccionTusCasas(casaActivaId: casa.id),
          IosSection(
            rows: [
              IosRow(
                icon: Icons.confirmation_number_outlined,
                iconColor: context.colors.brand,
                title: '¿Tienes un código de invitación?',
                subtitle: 'Un cliente te lo habrá pasado para un trabajo suyo',
                onTap: _canjearCodigoTrabajo,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Selector de varias casas por usuario (octubre 2026, feedback de
/// producto: gente con más de una propiedad). createCasa/joinCasa ya
/// guardaban casaIds como array -- esto era solo la UI que faltaba.
class _SeccionTusCasas extends StatefulWidget {
  const _SeccionTusCasas({required this.casaActivaId});

  final String casaActivaId;

  @override
  State<_SeccionTusCasas> createState() => _SeccionTusCasasState();
}

class _SeccionTusCasasState extends State<_SeccionTusCasas> {
  bool _procesando = false;

  Future<void> _cambiarA(String casaId) async {
    if (casaId == widget.casaActivaId || _procesando) return;
    setState(() => _procesando = true);
    try {
      await CasaService.cambiarCasaActiva(casaId);
      // Igual que al cerrar sesión: hay que volver a la raíz para que
      // CasaGateScreen vuelva a ser la pantalla activa y recoja el nuevo
      // activeCasaId -- si no, esta pantalla (apilada por encima de la casa
      // anterior) seguiría mostrando datos viejos.
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo cambiar de casa.');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _crearOtraCasa() async {
    final nombre = await AppDialog.promptText(context, title: 'Nueva casa', hint: 'p.ej. Casa de la playa', confirmLabel: 'Crear');
    if (nombre == null || nombre.isEmpty || !mounted) return;
    setState(() => _procesando = true);
    try {
      await CasaService.createCasa(nombre);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo crear la casa.');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _unirseAOtraCasa() async {
    final codigo = await AppDialog.promptText(
      context,
      title: 'Código de la casa',
      hint: 'Ej. AB12CD',
      confirmLabel: 'Unirme',
      textCapitalization: TextCapitalization.characters,
    );
    if (codigo == null || codigo.isEmpty || !mounted) return;
    setState(() => _procesando = true);
    try {
      await CasaService.joinCasa(codigo);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'Ese código no es válido o ya se ha usado.');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: CasaService.streamCasaIds(),
      builder: (context, snapshot) {
        final casaIds = snapshot.data ?? [widget.casaActivaId];
        return IosSection(
          header: 'Tus casas',
          rows: [
            for (final id in casaIds)
              FutureBuilder<Casa?>(
                future: CasaService.obtenerCasa(id),
                builder: (context, snap) {
                  final activa = id == widget.casaActivaId;
                  return IosRow(
                    icon: Icons.house_outlined,
                    iconColor: context.colors.brand,
                    title: snap.data?.nombre ?? '…',
                    showChevron: false,
                    selected: activa,
                    trailing: activa ? Icon(Icons.check, color: context.colors.brand) : null,
                    onTap: _procesando ? null : () => _cambiarA(id),
                  );
                },
              ),
            IosRow(
              icon: Icons.add_home_outlined,
              iconColor: context.colors.brand,
              title: 'Crear otra casa',
              showChevron: false,
              onTap: _procesando ? null : _crearOtraCasa,
            ),
            IosRow(
              icon: Icons.key_outlined,
              iconColor: context.colors.brand,
              title: 'Unirme a otra casa con código',
              showChevron: false,
              onTap: _procesando ? null : _unirseAOtraCasa,
            ),
          ],
        );
      },
    );
  }
}
