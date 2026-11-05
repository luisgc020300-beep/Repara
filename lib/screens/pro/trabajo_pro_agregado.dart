// lib/screens/pro/trabajo_pro_agregado.dart
//
// Ampliación funcional de REPARA Pro, Fase 1-2 (CEO, noviembre 2026):
// agregador reutilizable de "todos los trabajos del profesional, con su
// estado y sus números" -- antes cada pantalla (Dashboard, Trabajos,
// Presupuestos) montaba su propio abanico de suscripciones una por una
// (ver el patrón original en presupuestos_pro_tab.dart, _onTrabajos). Aquí
// se generaliza ese mismo patrón para no duplicarlo: el profesional nunca
// es miembro de ninguna casa (ver firestore.rules), así que no existe una
// consulta agregada del lado servidor -- la única vía es partir de
// users/{uid}.registrosProRefs (ProfesionalService.streamRegistrosProRefs)
// y abrir, por cada trabajo, hasta cuatro suscripciones más: el Registro
// completo (estado/fecha/importe), sus pagos (total cobrado), sus
// presupuestos (saber si hay uno "enviado" esperando respuesta, y cuál es
// el aceptado) y sus cambios de alcance (cuánto se ha aprobado de más) --
// Fase 2 añade estos dos últimos usos para Control económico y la ficha de
// cliente, reutilizando los mismos presupuestos que Fase 1 ya traía.
//
// Nota de escala: esto es correcto y barato para un profesional solo o un
// equipo pequeño (decenas de trabajos activos). Si algún día un
// profesional acumula cientos de trabajos activos a la vez, este patrón de
// N×4 listeners dejaría de ser razonable y habría que revisarlo (paginar,
// mover el cálculo a una Cloud Function...) -- no bloquea esta fase.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:repara_core/cambio_alcance.dart';
import 'package:repara_core/pago.dart';
import 'package:repara_core/presupuesto.dart';
import 'package:repara_core/profesional.dart';
import 'package:repara_core/registro.dart';

import '../../services/cambio_alcance_service.dart';
import '../../services/pago_service.dart';
import '../../services/presupuesto_service.dart';
import '../../services/profesional_service.dart';
import '../../services/registro_service.dart';

/// Agrupación visual del tablero de Trabajos sobre EstadoRegistro +
/// EstadoPresupuesto -- nunca un estado nuevo en el modelo de datos (ver
/// el mapeo documentado en el plan: no se inventan transiciones).
enum ColumnaTableroPro {
  sinPresupuestar,
  presupuestoEnviado,
  aprobadoPorEmpezar,
  enCurso,
  pendienteConfirmacion,
  pendienteCobro,
  terminado,
  archivado,
}

String nombreColumnaTableroPro(ColumnaTableroPro c) => switch (c) {
  ColumnaTableroPro.sinPresupuestar => 'Sin presupuestar',
  ColumnaTableroPro.presupuestoEnviado => 'Presupuesto enviado',
  ColumnaTableroPro.aprobadoPorEmpezar => 'Aprobado · por empezar',
  ColumnaTableroPro.enCurso => 'En curso',
  ColumnaTableroPro.pendienteConfirmacion => 'Pendiente de confirmación',
  ColumnaTableroPro.pendienteCobro => 'Pendiente de cobro',
  ColumnaTableroPro.terminado => 'Terminado',
  ColumnaTableroPro.archivado => 'Archivado',
};

/// Un trabajo del profesional con todo lo que hace falta para el Dashboard
/// y el tablero, ya combinado. [registro] es null mientras ese trabajo
/// concreto todavía está cargando su propio stream (los demás campos
/// quedan en sus valores por defecto hasta entonces).
class TrabajoProAgregado {
  const TrabajoProAgregado({
    required this.ref,
    this.registro,
    this.pagos = const [],
    this.presupuestos = const [],
    this.cambiosAlcance = const [],
  });

  final RegistroProRef ref;
  final Registro? registro;

  /// Lista completa (no solo la suma) -- hace falta para "cobros
  /// registrados durante el mes" en el Dashboard, que filtra por fecha de
  /// cada pago, no solo por el total acumulado.
  final List<Pago> pagos;

  /// Todos los presupuestos del trabajo, en cualquier estado -- Fase 1 solo
  /// necesitaba saber si había uno "enviado"; Fase 2 (Control económico,
  /// ficha de cliente) necesita también cuál está aceptado y su importe.
  final List<Presupuesto> presupuestos;

  /// Cambios de alcance del trabajo, en cualquier estado.
  final List<CambioAlcance> cambiosAlcance;

  double get totalPagado => pagos.fold<double>(0, (acc, p) => acc + p.importe);

  bool get presupuestoEsperandoRespuesta =>
      presupuestos.any((p) => p.estado == EstadoPresupuesto.enviado);

  /// El presupuesto aceptado de este trabajo, si lo hay -- el propio
  /// `crearPresupuesto` en servidor impide que exista más de uno aceptado a
  /// la vez (functions/index.js:1079-1081), así que tomar el primero que
  /// aparezca es seguro.
  Presupuesto? get presupuestoAceptado {
    for (final p in presupuestos) {
      if (p.estado == EstadoPresupuesto.aceptado) return p;
    }
    return null;
  }

  /// Suma de los cambios de alcance ya aprobados -- el mismo importe que el
  /// servidor ya sumó a `registro.presupuesto` vía FieldValue.increment
  /// (responderCambioAlcance, functions/index.js:1661). Se recalcula aquí
  /// solo para poder MOSTRAR el desglose, nunca para decidir cuánto se debe
  /// -- esa cifra autorizada sigue siendo [montoDebido].
  double get cambiosAprobados => cambiosAlcance
      .where((c) => c.estado == EstadoCambioAlcance.aprobado)
      .fold<double>(0, (acc, c) => acc + (c.importeAdicional ?? 0));

  /// "Lo que está sobre la mesa": el presupuesto aceptado si lo hay, o si
  /// no, el último enviado (esperando respuesta) -- 0 si todavía no se ha
  /// mandado ninguno. Para Control económico ("importe presupuestado"), que
  /// es distinto de [montoDebido]/[cambiosAprobados] (ver separación
  /// económica del encargo: no mezclar presupuesto con importe acordado).
  double get importePresupuestado {
    final aceptado = presupuestoAceptado;
    if (aceptado != null) return aceptado.total;
    for (final p in presupuestos) {
      if (p.estado == EstadoPresupuesto.enviado) return p.total;
    }
    return 0;
  }

  /// Fórmula real de servidor (functions/index.js, montoDebido): el
  /// presupuesto ya incluye los cambios de alcance aprobados (se le suman
  /// con FieldValue.increment en responderCambioAlcance) -- nunca se sigue
  /// sumando aparte aquí.
  double? get montoDebido {
    final r = registro;
    if (r == null) return null;
    return r.presupuesto ?? r.coste;
  }

  double? get saldoPendiente {
    final debido = montoDebido;
    if (debido == null) return null;
    final saldo = debido - totalPagado;
    return saldo < 0.01 ? 0 : saldo;
  }

  ColumnaTableroPro get columna {
    final r = registro;
    if (r == null) return ColumnaTableroPro.sinPresupuestar;
    return switch (r.estado) {
      EstadoRegistro.archivado => ColumnaTableroPro.archivado,
      EstadoRegistro.terminado => ColumnaTableroPro.terminado,
      EstadoRegistro.pendientePago => ColumnaTableroPro.pendienteCobro,
      EstadoRegistro.pendienteConfirmacion =>
        ColumnaTableroPro.pendienteConfirmacion,
      EstadoRegistro.enCurso => ColumnaTableroPro.enCurso,
      EstadoRegistro.presupuestado => ColumnaTableroPro.aprobadoPorEmpezar,
      EstadoRegistro.nuevo =>
        presupuestoEsperandoRespuesta
            ? ColumnaTableroPro.presupuestoEnviado
            : ColumnaTableroPro.sinPresupuestar,
    };
  }
}

/// Gestiona el abanico de suscripciones descrito arriba y expone la lista
/// combinada. `iniciar()`/`dispose()` siguen el mismo ciclo de vida manual
/// que el resto de controladores de este repo (ver _PresupuestosProTabState).
class TrabajosProAgregadosController extends ChangeNotifier {
  StreamSubscription<List<RegistroProRef>>? _refsSub;
  final Map<String, StreamSubscription<Registro?>> _registroSubs = {};
  final Map<String, StreamSubscription<List<Presupuesto>>> _presupuestoSubs =
      {};
  final Map<String, StreamSubscription<List<Pago>>> _pagoSubs = {};
  final Map<String, StreamSubscription<List<CambioAlcance>>> _cambioSubs = {};

  final Map<String, RegistroProRef> _refsPorId = {};
  final Map<String, Registro?> _registrosPorId = {};
  final Map<String, List<Presupuesto>> _presupuestosPorId = {};
  final Map<String, List<Pago>> _pagosPorId = {};
  final Map<String, List<CambioAlcance>> _cambiosPorId = {};

  bool cargando = true;

  void iniciar() {
    _refsSub = ProfesionalService.streamRegistrosProRefs().listen(_onRefs);
  }

  void _onRefs(List<RegistroProRef> refs) {
    final idsActuales = refs.map((r) => r.registroId).toSet();
    for (final id in _refsPorId.keys.toList()) {
      if (!idsActuales.contains(id)) {
        _registroSubs.remove(id)?.cancel();
        _presupuestoSubs.remove(id)?.cancel();
        _pagoSubs.remove(id)?.cancel();
        _cambioSubs.remove(id)?.cancel();
        _refsPorId.remove(id);
        _registrosPorId.remove(id);
        _presupuestosPorId.remove(id);
        _pagosPorId.remove(id);
        _cambiosPorId.remove(id);
      }
    }
    for (final r in refs) {
      _refsPorId[r.registroId] = r;
      _registroSubs.putIfAbsent(r.registroId, () {
        return RegistroService.streamRegistro(
          r.casaId,
          r.elementoId,
          r.registroId,
        ).listen((registro) {
          _registrosPorId[r.registroId] = registro;
          notifyListeners();
        });
      });
      _presupuestoSubs.putIfAbsent(r.registroId, () {
        return PresupuestoService.streamPresupuestos(
          r.casaId,
          r.elementoId,
          r.registroId,
        ).listen((lista) {
          _presupuestosPorId[r.registroId] = lista;
          notifyListeners();
        });
      });
      _pagoSubs.putIfAbsent(r.registroId, () {
        return PagoService.streamPagos(
          r.casaId,
          r.elementoId,
          r.registroId,
        ).listen((lista) {
          _pagosPorId[r.registroId] = lista;
          notifyListeners();
        });
      });
      _cambioSubs.putIfAbsent(r.registroId, () {
        return CambioAlcanceService.streamCambios(
          r.casaId,
          r.elementoId,
          r.registroId,
        ).listen((lista) {
          _cambiosPorId[r.registroId] = lista;
          notifyListeners();
        });
      });
    }
    cargando = false;
    notifyListeners();
  }

  List<TrabajoProAgregado> get trabajos => _refsPorId.values
      .map(
        (r) => TrabajoProAgregado(
          ref: r,
          registro: _registrosPorId[r.registroId],
          pagos: _pagosPorId[r.registroId] ?? const [],
          presupuestos: _presupuestosPorId[r.registroId] ?? const [],
          cambiosAlcance: _cambiosPorId[r.registroId] ?? const [],
        ),
      )
      .toList();

  @override
  void dispose() {
    _refsSub?.cancel();
    for (final s in _registroSubs.values) {
      s.cancel();
    }
    for (final s in _presupuestoSubs.values) {
      s.cancel();
    }
    for (final s in _pagoSubs.values) {
      s.cancel();
    }
    for (final s in _cambioSubs.values) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Envoltorio StatefulWidget del controlador de arriba -- mismo rol que
/// StreamBuilder, pero gestionando internamente el abanico de
/// suscripciones en vez de una sola.
class TrabajosProAgregadosBuilder extends StatefulWidget {
  const TrabajosProAgregadosBuilder({required this.builder, super.key});

  final Widget Function(
    BuildContext context,
    List<TrabajoProAgregado> trabajos,
    bool cargando,
  )
  builder;

  @override
  State<TrabajosProAgregadosBuilder> createState() =>
      _TrabajosProAgregadosBuilderState();
}

class _TrabajosProAgregadosBuilderState
    extends State<TrabajosProAgregadosBuilder> {
  final _controller = TrabajosProAgregadosController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.iniciar();
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _controller.trabajos, _controller.cargando);
}
