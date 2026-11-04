// lib/screens/pro/agenda_pro_tab.dart
//
// Agenda (ampliación funcional REPARA Pro, Fase 4 -- CEO, noviembre 2026):
// planificación puramente personal del profesional -- trabajos
// programados, visitas, tareas pendientes, cualquier fecha importante.
// Vistas Semana (con protagonismo, CEO), Día y Mes, todas construidas a
// mano con widgets normales -- no se añade ningún paquete de calendario
// nuevo, la app no lo necesitaba hasta ahora y esto no justifica por sí
// solo una dependencia más.
//
// IMPORTANTE -- limitación documentada a propósito: no hay recordatorios
// push. No existe ninguna infraestructura de notificaciones programadas en
// el proyecto (solo reactivas a un evento, ver functions/index.js) --
// construirla exigiría Cloud Scheduler, con su propia implicación de coste,
// y el encargo pide explícitamente no fingir notificaciones que no
// funcionan de verdad. Queda documentado como trabajo futuro, no simulado.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/cita.dart';
import '../../models/profesional.dart';
import '../../services/cita_service.dart';
import '../../services/profesional_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_error.dart';
import '../../widgets/boton_ajustes.dart';
import '../../widgets/ios_list.dart';

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

enum _VistaAgenda { semana, dia, mes }

class AgendaProTab extends StatefulWidget {
  const AgendaProTab({super.key});

  @override
  State<AgendaProTab> createState() => _AgendaProTabState();
}

class _AgendaProTabState extends State<AgendaProTab> {
  _VistaAgenda _vista = _VistaAgenda.semana;
  DateTime _diaSeleccionado = _soloFecha(DateTime.now());

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
        actions: const [BotonAjustes(modoPro: true)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevaCita,
        tooltip: 'Nueva cita',
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
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Semana'),
                        selected: _vista == _VistaAgenda.semana,
                        onSelected: (_) =>
                            setState(() => _vista = _VistaAgenda.semana),
                      ),
                    ),
                    const SizedBox(width: ReparaSpace.s2),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Día'),
                        selected: _vista == _VistaAgenda.dia,
                        onSelected: (_) =>
                            setState(() => _vista = _VistaAgenda.dia),
                      ),
                    ),
                    const SizedBox(width: ReparaSpace.s2),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Mes'),
                        selected: _vista == _VistaAgenda.mes,
                        onSelected: (_) =>
                            setState(() => _vista = _VistaAgenda.mes),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (_vista) {
                  _VistaAgenda.semana => _VistaSemana(
                    citas: citas,
                    diaSeleccionado: _diaSeleccionado,
                    onSeleccionarDia: (d) =>
                        setState(() => _diaSeleccionado = d),
                    onAbrirCita: _abrirCita,
                  ),
                  _VistaAgenda.dia => _VistaDia(
                    citas: citas,
                    dia: _diaSeleccionado,
                    onCambiarDia: (d) => setState(() => _diaSeleccionado = d),
                    onAbrirCita: _abrirCita,
                  ),
                  _VistaAgenda.mes => _VistaMes(
                    citas: citas,
                    diaSeleccionado: _diaSeleccionado,
                    onSeleccionarDia: (d) =>
                        setState(() => _diaSeleccionado = d),
                    onAbrirCita: _abrirCita,
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

Widget _listaDeCitas(
  BuildContext context,
  List<Cita> citasDelDia,
  void Function(Cita) onAbrirCita,
) {
  if (citasDelDia.isEmpty) {
    return const EmptyHint(
      message: 'Nada programado para este día.',
      icon: Icons.event_available_outlined,
    );
  }
  return ListView(
    padding: const EdgeInsets.fromLTRB(
      ReparaSpace.s4,
      0,
      ReparaSpace.s4,
      ReparaSpace.s4,
    ),
    children: [
      IosSection(
        rows: citasDelDia
            .map(
              (c) => IosRow(
                icon: c.completada
                    ? Icons.check_circle_outline
                    : (c.enlazaTrabajo
                          ? Icons.build_outlined
                          : Icons.event_outlined),
                iconColor: c.completada
                    ? context.colors.success
                    : context.colors.brand,
                title: c.titulo,
                titleColor: c.completada ? context.colors.inkMuted : null,
                subtitle: [
                  c.todoElDia
                      ? 'Todo el día'
                      : DateFormat('HH:mm').format(c.fecha),
                  if (c.registroTitulo != null) c.registroTitulo!,
                ].join(' · '),
                onTap: () => onAbrirCita(c),
              ),
            )
            .toList(),
      ),
    ],
  );
}

class _VistaSemana extends StatelessWidget {
  const _VistaSemana({
    required this.citas,
    required this.diaSeleccionado,
    required this.onSeleccionarDia,
    required this.onAbrirCita,
  });

  final List<Cita> citas;
  final DateTime diaSeleccionado;
  final ValueChanged<DateTime> onSeleccionarDia;
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
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ReparaSpace.s3,
            vertical: ReparaSpace.s2,
          ),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
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
        ),
        const SizedBox(height: ReparaSpace.s2),
        Expanded(
          child: _listaDeCitas(
            context,
            _citasDelDia(citas, diaSeleccionado),
            onAbrirCita,
          ),
        ),
      ],
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
            Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: seleccionado
                    ? context.colors.brandStrong
                    : (esHoy ? context.colors.brandTint : Colors.transparent),
                shape: BoxShape.circle,
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

class _VistaDia extends StatelessWidget {
  const _VistaDia({
    required this.citas,
    required this.dia,
    required this.onCambiarDia,
    required this.onAbrirCita,
  });

  final List<Cita> citas;
  final DateTime dia;
  final ValueChanged<DateTime> onCambiarDia;
  final void Function(Cita) onAbrirCita;

  @override
  Widget build(BuildContext context) {
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
                  DateFormat('EEEE d MMMM', 'es_ES').format(dia),
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
        if (!_mismoDia(dia, _soloFecha(DateTime.now())))
          TextButton(
            onPressed: () => onCambiarDia(_soloFecha(DateTime.now())),
            child: const Text('Ir a hoy'),
          ),
        const SizedBox(height: ReparaSpace.s2),
        Expanded(
          child: _listaDeCitas(context, _citasDelDia(citas, dia), onAbrirCita),
        ),
      ],
    );
  }
}

class _VistaMes extends StatelessWidget {
  const _VistaMes({
    required this.citas,
    required this.diaSeleccionado,
    required this.onSeleccionarDia,
    required this.onAbrirCita,
  });

  final List<Cita> citas;
  final DateTime diaSeleccionado;
  final ValueChanged<DateTime> onSeleccionarDia;
  final void Function(Cita) onAbrirCita;

  @override
  Widget build(BuildContext context) {
    final primerDiaMes = DateTime(diaSeleccionado.year, diaSeleccionado.month);
    final inicioGrid = primerDiaMes.subtract(
      Duration(days: primerDiaMes.weekday - 1),
    );
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
                  DateTime(
                    diaSeleccionado.year,
                    diaSeleccionado.month - 1,
                    diaSeleccionado.day,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy', 'es_ES').format(diaSeleccionado),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onSeleccionarDia(
                  DateTime(
                    diaSeleccionado.year,
                    diaSeleccionado.month + 1,
                    diaSeleccionado.day,
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
            padding: const EdgeInsets.symmetric(horizontal: ReparaSpace.s3),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final d = inicioGrid.add(
                          Duration(days: fila * 7 + col),
                        );
                        final delMes = d.month == diaSeleccionado.month;
                        return Opacity(
                          opacity: delMes ? 1 : 0.35,
                          child: _CeldaDia(
                            etiqueta: '',
                            numero: '${d.day}',
                            seleccionado: _mismoDia(d, diaSeleccionado),
                            esHoy: _mismoDia(d, hoy),
                            tieneCitas: _citasDelDia(citas, d).isNotEmpty,
                            onTap: () => onSeleccionarDia(d),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: ReparaSpace.s2),
        Expanded(
          child: _listaDeCitas(
            context,
            _citasDelDia(citas, diaSeleccionado),
            onAbrirCita,
          ),
        ),
      ],
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
  RegistroProRef? _trabajoVinculado;
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
    final vinculo = _trabajoVinculado;
    final cita = Cita(
      id: widget.cita?.id ?? '',
      titulo: titulo,
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      fecha: fechaCompleta,
      todoElDia: _todoElDia,
      casaId: vinculo?.casaId,
      elementoId: vinculo?.elementoId,
      registroId: vinculo?.registroId,
      registroTitulo: vinculo?.registroTitulo,
      casaNombre: vinculo?.casaNombre,
      completada: widget.cita?.completada ?? false,
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
