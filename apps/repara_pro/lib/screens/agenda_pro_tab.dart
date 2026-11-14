// apps/repara_pro/lib/screens/agenda_pro_tab.dart
//
// Agenda (ampliación funcional REPARA Pro, Fase 4 -- CEO, noviembre 2026):
// planificación puramente personal del profesional -- trabajos
// programados, visitas, tareas pendientes, cualquier fecha importante.
// Todo construido a mano con widgets normales -- no se añade ningún
// paquete de calendario nuevo.
//
// Rediseño visual (CEO, noviembre 2026): "mismo diseño que oficio-ai, pero
// las funcionalidades de REPARA" -- interruptor Semana/Día con check,
// semana como lista de los 7 días (con las citas de cada uno debajo, no
// solo del día seleccionado), tarjeta de cita con rango horario, estado
// vacío de Día con CTA propia. La vista Mes (que oficio-ai no tiene) se
// conserva -- es una funcionalidad real de REPARA que no hay motivo para
// quitar -- pero se mueve a un icono de calendario en la cabecera en vez
// de competir por sitio en el interruptor principal. El naranja de
// oficio-ai se sustituye por el azul marino de marca de REPARA
// (context.colors.brandStrong) -- introducir un acento nuevo solo en esta
// pantalla rompería la consistencia visual del resto de la app (Fase 5).
//
// IMPORTANTE -- limitación documentada a propósito: no hay recordatorios
// push. No existe ninguna infraestructura de notificaciones programadas en
// el proyecto (solo reactivas a un evento, ver functions/index.js) --
// construirla exigiría Cloud Scheduler, con su propia implicación de coste,
// y el encargo pide explícitamente no fingir notificaciones que no
// funcionan de verdad. Queda documentado como trabajo futuro, no simulado.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:repara_core/cita.dart';
import 'package:repara_core/cita_service.dart';
import 'package:repara_core/profesional.dart';
import 'package:repara_core/profesional_service.dart';

import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_dialog.dart';
import 'package:repara_ui/app_error.dart';
import '../widgets/boton_ajustes_pro.dart';
import 'package:repara_ui/ios_list.dart';

DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<Cita> _citasDelDia(List<Cita> citas, DateTime dia) {
  final lista = citas.where((c) => _mismoDia(c.fecha, dia)).toList()
    ..sort((a, b) {
      if (a.todoElDia != b.todoElDia) return a.todoElDia ? -1 : 1;
      return a.fecha.compareTo(b.fecha);
    });
  return lista;
}

const _nombresDiaCorto = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _nombresDiaLargo = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

enum _VistaAgenda { semana, dia }

class AgendaProTab extends StatefulWidget {
  const AgendaProTab({super.key});

  @override
  State<AgendaProTab> createState() => _AgendaProTabState();
}

class _AgendaProTabState extends State<AgendaProTab> {
  _VistaAgenda _vista = _VistaAgenda.semana;
  DateTime _diaSeleccionado = _soloFecha(DateTime.now());

  void _irAHoy() =>
      setState(() => _diaSeleccionado = _soloFecha(DateTime.now()));

  void _verDia(DateTime dia) => setState(() {
    _diaSeleccionado = dia;
    _vista = _VistaAgenda.dia;
  });

  Future<void> _nuevaCita() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ReparaRadius.lg),
        ),
      ),
      builder: (_) => _EditorCitaSheet(fechaInicial: _diaSeleccionado),
    );
  }

  Future<void> _abrirCita(Cita cita) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ReparaRadius.lg),
        ),
      ),
      builder: (_) => _EditorCitaSheet(cita: cita),
    );
  }

  Future<void> _abrirMes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VistaMesScreen(
          diaInicial: _diaSeleccionado,
          onAbrirCita: _abrirCita,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'MODO PROFESIONAL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
            Text(
              'Agenda',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 26,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _irAHoy,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Hoy'),
          ),
          IconButton(
            tooltip: 'Ver mes',
            icon: const Icon(Icons.calendar_view_month_outlined),
            onPressed: _abrirMes,
          ),
          const BotonAjustesPro(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevaCita,
        tooltip: 'Nueva cita',
        backgroundColor: context.colors.brandStrong,
        foregroundColor: context.colors.brandOn,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Cita>>(
        stream: CitaService.streamCitas(),
        builder: (context, snapshot) {
          final citas = snapshot.data ?? const [];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ReparaSpace.s4,
                  ReparaSpace.s3,
                  ReparaSpace.s4,
                  ReparaSpace.s2,
                ),
                child: _PillToggle(
                  opciones: const ['Día', 'Semana'],
                  seleccionado: _vista == _VistaAgenda.dia ? 0 : 1,
                  onSeleccionado: (i) => setState(
                    () => _vista = i == 0
                        ? _VistaAgenda.dia
                        : _VistaAgenda.semana,
                  ),
                ),
              ),
              Expanded(
                child: switch (_vista) {
                  _VistaAgenda.semana => _VistaSemana(
                    citas: citas,
                    diaSeleccionado: _diaSeleccionado,
                    onSeleccionarDia: (d) =>
                        setState(() => _diaSeleccionado = d),
                    onVerDia: _verDia,
                    onAbrirCita: _abrirCita,
                  ),
                  _VistaAgenda.dia => _VistaDia(
                    citas: citas,
                    dia: _diaSeleccionado,
                    onCambiarDia: (d) => setState(() => _diaSeleccionado = d),
                    onAbrirCita: _abrirCita,
                    onNuevaCita: _nuevaCita,
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Interruptor de dos posiciones con fondo tenue y un check en la opción
/// activa -- mismo patrón visual que el selector Hogar/Pro de Ajustes
/// (_ModoAppToggle en settings_screen.dart), reaplicado aquí.
class _PillToggle extends StatelessWidget {
  const _PillToggle({
    required this.opciones,
    required this.seleccionado,
    required this.onSeleccionado,
  });

  final List<String> opciones;
  final int seleccionado;
  final ValueChanged<int> onSeleccionado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(ReparaRadius.sm),
      ),
      child: Row(
        children: [
          for (var i = 0; i < opciones.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _Segmento(
                label: opciones[i],
                seleccionado: seleccionado == i,
                onTap: () => onSeleccionado(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segmento extends StatelessWidget {
  const _Segmento({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = seleccionado
        ? context.colors.brandStrong
        : context.colors.inkMuted;
    return Material(
      color: seleccionado ? context.colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(ReparaRadius.xs),
      elevation: seleccionado ? 1 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(ReparaRadius.xs),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (seleccionado) ...[
                Icon(Icons.check, size: 15, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CeldaDia extends StatelessWidget {
  const _CeldaDia({
    required this.etiqueta,
    required this.numero,
    required this.seleccionado,
    required this.esHoy,
    required this.tieneCitas,
    required this.onTap,
  });

  final String etiqueta;
  final String numero;
  final bool seleccionado;
  final bool esHoy;
  final bool tieneCitas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ReparaRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ReparaSpace.s1),
        child: Column(
          children: [
            if (etiqueta.isNotEmpty) ...[
              Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
            ],
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: seleccionado
                    ? context.colors.brandStrong
                    : (esHoy ? context.colors.brandTint : Colors.transparent),
                borderRadius: BorderRadius.circular(ReparaRadius.sm),
              ),
              child: Text(
                numero,
                style: TextStyle(
                  color: seleccionado
                      ? context.colors.brandOn
                      : context.colors.ink,
                  fontWeight: esHoy || seleccionado
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: tieneCitas ? context.colors.brand : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _tiraDeDias(
  BuildContext context,
  List<DateTime> dias,
  DateTime diaSeleccionado,
  List<Cita> citas,
  ValueChanged<DateTime> onSeleccionarDia,
) {
  final hoy = _soloFecha(DateTime.now());
  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: ReparaSpace.s3,
      vertical: ReparaSpace.s2,
    ),
    child: Row(
      children: [
        for (var i = 0; i < dias.length; i++)
          Expanded(
            child: _CeldaDia(
              etiqueta: _nombresDiaCorto[i],
              numero: '${dias[i].day}',
              seleccionado: _mismoDia(dias[i], diaSeleccionado),
              esHoy: _mismoDia(dias[i], hoy),
              tieneCitas: _citasDelDia(citas, dias[i]).isNotEmpty,
              onTap: () => onSeleccionarDia(dias[i]),
            ),
          ),
      ],
    ),
  );
}

/// Semana completa como lista de días (CEO: "mismo diseño que oficio-ai")
/// -- cada uno de los 7 días se ve entero, con sus citas debajo si las
/// tiene, en vez de solo mostrar el día seleccionado de la tira.
class _VistaSemana extends StatelessWidget {
  const _VistaSemana({
    required this.citas,
    required this.diaSeleccionado,
    required this.onSeleccionarDia,
    required this.onVerDia,
    required this.onAbrirCita,
  });

  final List<Cita> citas;
  final DateTime diaSeleccionado;
  final ValueChanged<DateTime> onSeleccionarDia;
  final ValueChanged<DateTime> onVerDia;
  final void Function(Cita) onAbrirCita;

  @override
  Widget build(BuildContext context) {
    final lunes = diaSeleccionado.subtract(
      Duration(days: diaSeleccionado.weekday - 1),
    );
    final dias = List.generate(7, (i) => lunes.add(Duration(days: i)));
    final hoy = _soloFecha(DateTime.now());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ReparaSpace.s4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onSeleccionarDia(
                  diaSeleccionado.subtract(const Duration(days: 7)),
                ),
              ),
              Expanded(
                child: Text(
                  '${DateFormat('d MMM', 'es_ES').format(lunes)} - ${DateFormat('d MMM', 'es_ES').format(dias.last)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onSeleccionarDia(
                  diaSeleccionado.add(const Duration(days: 7)),
                ),
              ),
            ],
          ),
        ),
        _tiraDeDias(context, dias, diaSeleccionado, citas, onSeleccionarDia),
        const SizedBox(height: ReparaSpace.s2),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ReparaSpace.s4,
              0,
              ReparaSpace.s4,
              ReparaSpace.s4,
            ),
            children: [
              for (final d in dias) ...[
                _SeccionDia(
                  dia: d,
                  esHoy: _mismoDia(d, hoy),
                  citas: _citasDelDia(citas, d),
                  onVerDia: () => onVerDia(d),
                  onAbrirCita: onAbrirCita,
                ),
                const SizedBox(height: ReparaSpace.s2),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SeccionDia extends StatelessWidget {
  const _SeccionDia({
    required this.dia,
    required this.esHoy,
    required this.citas,
    required this.onVerDia,
    required this.onAbrirCita,
  });

  final DateTime dia;
  final bool esHoy;
  final List<Cita> citas;
  final VoidCallback onVerDia;
  final void Function(Cita) onAbrirCita;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onVerDia,
          borderRadius: BorderRadius.circular(ReparaRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ReparaSpace.s1),
            child: Row(
              children: [
                Text(
                  '${_nombresDiaLargo[dia.weekday - 1]} ${dia.day}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (esHoy) ...[
                  const SizedBox(width: ReparaSpace.s2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.brandTint,
                      borderRadius: BorderRadius.circular(ReparaRadius.pill),
                    ),
                    child: Text(
                      'HOY',
                      style: TextStyle(
                        color: context.colors.brandStrong,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (citas.isEmpty)
                  Text(
                    'Sin citas',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Icon(
                  Icons.chevron_right,
                  color: context.colors.inkMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (citas.isNotEmpty) ...[
          const SizedBox(height: ReparaSpace.s1),
          for (final c in citas) ...[
            _TarjetaCita(cita: c, onTap: () => onAbrirCita(c)),
            const SizedBox(height: ReparaSpace.s1),
          ],
        ],
      ],
    );
  }
}

class _VistaDia extends StatelessWidget {
  const _VistaDia({
    required this.citas,
    required this.dia,
    required this.onCambiarDia,
    required this.onAbrirCita,
    required this.onNuevaCita,
  });

  final List<Cita> citas;
  final DateTime dia;
  final ValueChanged<DateTime> onCambiarDia;
  final void Function(Cita) onAbrirCita;
  final VoidCallback onNuevaCita;

  @override
  Widget build(BuildContext context) {
    final lunes = dia.subtract(Duration(days: dia.weekday - 1));
    final dias = List.generate(7, (i) => lunes.add(Duration(days: i)));
    final citasDelDia = _citasDelDia(citas, dia);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ReparaSpace.s4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    onCambiarDia(dia.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: Text(
                  DateFormat('EEEE d MMM yyyy', 'es_ES').format(dia),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onCambiarDia(dia.add(const Duration(days: 1))),
              ),
            ],
          ),
        ),
        _tiraDeDias(context, dias, dia, citas, onCambiarDia),
        const SizedBox(height: ReparaSpace.s2),
        Expanded(
          child: citasDelDia.isEmpty
              ? _EstadoVacioDia(dia: dia, onNuevaCita: onNuevaCita)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    ReparaSpace.s4,
                    0,
                    ReparaSpace.s4,
                    ReparaSpace.s4,
                  ),
                  children: [
                    for (final c in citasDelDia) ...[
                      _TarjetaCita(cita: c, onTap: () => onAbrirCita(c)),
                      const SizedBox(height: ReparaSpace.s2),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _EstadoVacioDia extends StatelessWidget {
  const _EstadoVacioDia({required this.dia, required this.onNuevaCita});

  final DateTime dia;
  final VoidCallback onNuevaCita;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s6),
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
              child: Icon(
                Icons.event_available_outlined,
                size: 32,
                color: context.colors.brand,
              ),
            ),
            const SizedBox(height: ReparaSpace.s4),
            Text(
              'Sin citas este día',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ReparaSpace.s1),
            Text(
              'Programa una cita para ${DateFormat('d MMM yyyy', 'es_ES').format(dia)}.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: ReparaSpace.s4),
            FilledButton.icon(
              onPressed: onNuevaCita,
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.brandStrong,
                foregroundColor: context.colors.brandOn,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva cita'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de una cita -- rango horario, título, cliente (casaNombre --
/// nunca el nombre del propietario, ver decisión de privacidad de Fase 2)
/// y trabajo/descripción enlazados, con un check para completarla sin
/// entrar al editor.
class _TarjetaCita extends StatelessWidget {
  const _TarjetaCita({required this.cita, required this.onTap});

  final Cita cita;
  final VoidCallback onTap;

  Future<void> _alternarCompletada(BuildContext context) async {
    try {
      await CitaService.marcarCompletada(cita.id, !cita.completada);
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo actualizar la cita.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitulo = cita.descripcion?.isNotEmpty == true
        ? cita.descripcion!
        : cita.registroTitulo;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(ReparaSpace.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: cita.todoElDia
                    ? Text(
                        'Todo el día',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(cita.fecha),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (cita.horaFin != null)
                            Text(
                              DateFormat('HH:mm').format(cita.horaFin!),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
              ),
              const SizedBox(width: ReparaSpace.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cita.titulo,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cita.completada
                            ? context.colors.inkMuted
                            : context.colors.ink,
                        decoration: cita.completada
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (cita.casaNombre != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        cita.casaNombre!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (subtitulo != null && subtitulo.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            cita.enlazaTrabajo
                                ? Icons.build_outlined
                                : Icons.notes_outlined,
                            size: 13,
                            color: context.colors.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              subtitulo,
                              style: Theme.of(context).textTheme.bodySmall,
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
              IconButton(
                tooltip: cita.completada
                    ? 'Marcar como pendiente'
                    : 'Marcar como completada',
                icon: Icon(
                  cita.completada
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: cita.completada
                      ? context.colors.success
                      : context.colors.inkMuted,
                ),
                onPressed: () => _alternarCompletada(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vista Mes -- funcionalidad real de REPARA que oficio-ai no tiene, se
/// conserva como pantalla propia alcanzable desde el icono de calendario
/// de la cabecera en vez de competir por sitio en el interruptor principal
/// Semana/Día.
class VistaMesScreen extends StatefulWidget {
  const VistaMesScreen({
    required this.diaInicial,
    required this.onAbrirCita,
    super.key,
  });

  final DateTime diaInicial;
  final void Function(Cita) onAbrirCita;

  @override
  State<VistaMesScreen> createState() => _VistaMesScreenState();
}

class _VistaMesScreenState extends State<VistaMesScreen> {
  late DateTime _diaSeleccionado = widget.diaInicial;

  @override
  Widget build(BuildContext context) {
    final primerDiaMes = DateTime(
      _diaSeleccionado.year,
      _diaSeleccionado.month,
    );
    final inicioGrid = primerDiaMes.subtract(
      Duration(days: primerDiaMes.weekday - 1),
    );
    final hoy = _soloFecha(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda · Mes')),
      body: StreamBuilder<List<Cita>>(
        stream: CitaService.streamCitas(),
        builder: (context, snapshot) {
          final citas = snapshot.data ?? const [];
          final citasDelDia = _citasDelDia(citas, _diaSeleccionado);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ReparaSpace.s4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(
                        () => _diaSeleccionado = DateTime(
                          _diaSeleccionado.year,
                          _diaSeleccionado.month - 1,
                          _diaSeleccionado.day,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat(
                          'MMMM yyyy',
                          'es_ES',
                        ).format(_diaSeleccionado),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(
                        () => _diaSeleccionado = DateTime(
                          _diaSeleccionado.year,
                          _diaSeleccionado.month + 1,
                          _diaSeleccionado.day,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ReparaSpace.s3),
                child: Row(
                  children: [
                    for (final n in _nombresDiaCorto)
                      Expanded(
                        child: Center(
                          child: Text(
                            n,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (var fila = 0; fila < 6; fila++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ReparaSpace.s3,
                  ),
                  child: Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final d = inicioGrid.add(
                                Duration(days: fila * 7 + col),
                              );
                              final delMes = d.month == _diaSeleccionado.month;
                              return Opacity(
                                opacity: delMes ? 1 : 0.35,
                                child: _CeldaDia(
                                  etiqueta: '',
                                  numero: '${d.day}',
                                  seleccionado: _mismoDia(d, _diaSeleccionado),
                                  esHoy: _mismoDia(d, hoy),
                                  tieneCitas: _citasDelDia(citas, d).isNotEmpty,
                                  onTap: () =>
                                      setState(() => _diaSeleccionado = d),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: ReparaSpace.s3),
              Expanded(
                child: citasDelDia.isEmpty
                    ? const EmptyHint(
                        message: 'Nada programado para este día.',
                        icon: Icons.event_available_outlined,
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          ReparaSpace.s4,
                          0,
                          ReparaSpace.s4,
                          ReparaSpace.s4,
                        ),
                        children: [
                          for (final c in citasDelDia) ...[
                            _TarjetaCita(
                              cita: c,
                              onTap: () => widget.onAbrirCita(c),
                            ),
                            const SizedBox(height: ReparaSpace.s2),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditorCitaSheet extends StatefulWidget {
  const _EditorCitaSheet({this.cita, this.fechaInicial});

  final Cita? cita;
  final DateTime? fechaInicial;

  @override
  State<_EditorCitaSheet> createState() => _EditorCitaSheetState();
}

class _EditorCitaSheetState extends State<_EditorCitaSheet> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descripcionCtrl;
  late DateTime _fecha;
  late bool _todoElDia;
  late TimeOfDay _hora;
  TimeOfDay? _horaFin;
  RegistroProRef? _trabajoVinculado;
  late bool _compartida;
  bool _guardando = false;

  bool get _esEdicion => widget.cita != null;

  @override
  void initState() {
    super.initState();
    final cita = widget.cita;
    _tituloCtrl = TextEditingController(text: cita?.titulo ?? '');
    _descripcionCtrl = TextEditingController(text: cita?.descripcion ?? '');
    _fecha = _soloFecha(cita?.fecha ?? widget.fechaInicial ?? DateTime.now());
    _todoElDia = cita?.todoElDia ?? false;
    _hora = cita != null ? TimeOfDay.fromDateTime(cita.fecha) : TimeOfDay.now();
    _horaFin = cita?.horaFin != null
        ? TimeOfDay.fromDateTime(cita!.horaFin!)
        : null;
    _compartida = cita?.compartida ?? false;
    if (cita?.enlazaTrabajo == true) {
      _trabajoVinculado = RegistroProRef(
        casaId: cita!.casaId!,
        elementoId: cita.elementoId!,
        elementoNombre: '',
        registroId: cita.registroId!,
        registroTitulo: cita.registroTitulo ?? '',
        casaNombre: cita.casaNombre ?? '',
      );
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (elegida != null) setState(() => _fecha = _soloFecha(elegida));
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(context: context, initialTime: _hora);
    if (elegida != null) setState(() => _hora = elegida);
  }

  Future<void> _elegirHoraFin() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: _horaFin ?? _hora,
    );
    if (elegida != null) setState(() => _horaFin = elegida);
  }

  Future<void> _elegirTrabajo() async {
    final trabajos = await ProfesionalService.streamRegistrosProRefs().first;
    if (!mounted) return;
    final elegido = await showModalBottomSheet<RegistroProRef?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: trabajos.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(ReparaSpace.s5),
                child: Text('Todavía no tienes ningún trabajo aceptado.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final t in trabajos)
                    IosRow(
                      icon: Icons.build_outlined,
                      iconColor: ctx.colors.brand,
                      title: t.registroTitulo,
                      subtitle: t.casaNombre,
                      onTap: () => Navigator.pop(ctx, t),
                    ),
                ],
              ),
      ),
    );
    if (elegido != null) setState(() => _trabajoVinculado = elegido);
  }

  Future<void> _guardar() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      AppError.show(context, 'Ponle un título a la cita.');
      return;
    }
    setState(() => _guardando = true);
    final fechaCompleta = _todoElDia
        ? _fecha
        : DateTime(
            _fecha.year,
            _fecha.month,
            _fecha.day,
            _hora.hour,
            _hora.minute,
          );
    final horaFinCompleta = (!_todoElDia && _horaFin != null)
        ? DateTime(
            _fecha.year,
            _fecha.month,
            _fecha.day,
            _horaFin!.hour,
            _horaFin!.minute,
          )
        : null;
    final vinculo = _trabajoVinculado;
    // compartida solo tiene sentido si enlaza un trabajo -- si se quita el
    // vínculo, se desactiva sola en vez de dejar un permiso de lectura
    // "huérfano" que apuntaría a nada.
    final compartidaFinal = vinculo != null && _compartida;
    final cita = Cita(
      id: widget.cita?.id ?? '',
      titulo: titulo,
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      fecha: fechaCompleta,
      todoElDia: _todoElDia,
      horaFin: horaFinCompleta,
      casaId: vinculo?.casaId,
      elementoId: vinculo?.elementoId,
      registroId: vinculo?.registroId,
      registroTitulo: vinculo?.registroTitulo,
      casaNombre: vinculo?.casaNombre,
      completada: widget.cita?.completada ?? false,
      compartida: compartidaFinal,
      // CEO, noviembre 2026: toda cita compartida y vinculada a un trabajo
      // arranca pendiente de que el propietario la confirme, rechace o
      // proponga otra fecha -- tanto al crearla como en cualquier edición
      // posterior (el propietario vuelve a tener que responder a la fecha
      // nueva, no se da por aceptada en silencio).
      estado: compartidaFinal ? EstadoCita.pendienteConfirmacion : EstadoCita.confirmada,
    );
    try {
      if (_esEdicion) {
        await CitaService.actualizar(widget.cita!.id, cita);
      } else {
        await CitaService.crear(cita);
      }
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo guardar la cita.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Eliminar esta cita?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmar) return;
    try {
      await CitaService.eliminar(widget.cita!.id);
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo eliminar la cita.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _alternarCompletada() async {
    final nuevoValor = !(widget.cita!.completada);
    try {
      await CitaService.marcarCompletada(widget.cita!.id, nuevoValor);
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo actualizar la cita.',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.only(
          left: ReparaSpace.s5,
          right: ReparaSpace.s5,
          top: ReparaSpace.s5,
          bottom: ReparaSpace.s5 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _esEdicion ? 'Editar cita' : 'Nueva cita',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: ReparaSpace.s3),
              TextField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: ReparaSpace.s2),
              TextField(
                controller: _descripcionCtrl,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
              const SizedBox(height: ReparaSpace.s3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _elegirFecha,
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        DateFormat('d MMM yyyy', 'es_ES').format(_fecha),
                      ),
                    ),
                  ),
                  if (!_todoElDia) ...[
                    const SizedBox(width: ReparaSpace.s2),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _elegirHora,
                        icon: const Icon(Icons.schedule_outlined, size: 16),
                        label: Text(_hora.format(context)),
                      ),
                    ),
                  ],
                ],
              ),
              if (!_todoElDia) ...[
                const SizedBox(height: ReparaSpace.s2),
                OutlinedButton.icon(
                  onPressed: _elegirHoraFin,
                  icon: const Icon(Icons.schedule_outlined, size: 16),
                  label: Text(
                    _horaFin == null
                        ? 'Hora de fin (opcional)'
                        : 'Hasta las ${_horaFin!.format(context)}',
                  ),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Todo el día'),
                value: _todoElDia,
                onChanged: (v) => setState(() => _todoElDia = v),
              ),
              const SizedBox(height: ReparaSpace.s1),
              OutlinedButton.icon(
                onPressed: _elegirTrabajo,
                icon: const Icon(Icons.build_outlined, size: 16),
                label: Text(
                  _trabajoVinculado == null
                      ? 'Vincular a un trabajo (opcional)'
                      : _trabajoVinculado!.registroTitulo,
                ),
              ),
              if (_trabajoVinculado != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Compartir con el cliente'),
                  subtitle: const Text(
                    'Verá la fecha y hora en REPARA Hogar y recibirá un recordatorio.',
                  ),
                  value: _compartida,
                  onChanged: (v) => setState(() => _compartida = v),
                ),
              const SizedBox(height: ReparaSpace.s4),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.brandOn,
                        ),
                      )
                    : Text(_esEdicion ? 'Guardar cambios' : 'Crear cita'),
              ),
              if (_esEdicion) ...[
                const SizedBox(height: ReparaSpace.s2),
                OutlinedButton(
                  onPressed: _alternarCompletada,
                  child: Text(
                    widget.cita!.completada
                        ? 'Marcar como pendiente'
                        : 'Marcar como completada',
                  ),
                ),
                const SizedBox(height: ReparaSpace.s2),
                TextButton(
                  onPressed: _eliminar,
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.errorText,
                  ),
                  child: const Text('Eliminar cita'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
