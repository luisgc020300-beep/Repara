// lib/screens/nuevo_registro_screen.dart
//
// Pantalla para añadir un registro a un elemento que ya existe -- p.ej.
// "cambio de depuradora" sobre la Piscina, o anotar una revisión hecha a
// mano. Un registro nunca vive sin elemento (octubre 2026, fusión Elemento/
// Trabajo/Evento) -- elementoId es siempre obligatorio.
//
// Pantalla completa, no hoja modal (CEO, noviembre 2026: "las pantallas de
// registrar evento a mano o por escaneo deberían ser prácticamente iguales")
// -- mismas tarjetas de sección (SeccionFormulario) que la revisión de un
// documento escaneado (nuevo_documento_flow.dart). La única diferencia real
// entre "a mano" y "por escaneo" es que el escaneo autorellena estos mismos
// campos a partir de la IA y además captura los datos propios de la factura
// (NIF, importe, número de referencia...), que aquí no aplican porque no hay
// ningún archivo detrás.
//
// "¿Lo hace un profesional?" (CEO, octubre 2026): antes esta hoja solo
// creaba registros simples -- la única vía para arrancar el flujo con
// profesional (presupuesto/invitación real) era crear un elemento nuevo
// desde cero (ver nuevo_elemento_screen.dart). Un elemento que ya existe
// nunca podía recibir un evento nuevo con profesional, aunque ya tuviera
// otros con profesional de antes (p.ej. una reforma más sobre el mismo
// elemento). Mismo interruptor y mismo criterio que allí: oculta Coste/
// Profesional/Plazos (ese dato se fija después, desde el propio evento, al
// invitar al profesional) y nace en estado "nuevo" en vez de "terminado"/
// "pendientePago".
//
// Profesionales (CEO, noviembre 2026): un evento simple puede tener más de
// un profesional, elegidos de la libreta de contactos o escritos a mano (ver
// selector_profesionales.dart).
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repara_core/registro.dart';

import '../services/analytics_service.dart';
import '../services/registro_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import '../widgets/seccion_formulario.dart';
import '../widgets/selector_profesional_field.dart';

Future<void> abrirNuevoRegistroScreen(
  BuildContext context, {
  required String casaId,
  required String elementoId,
  required String elementoNombre,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _NuevoRegistroScreen(
        casaId: casaId,
        elementoId: elementoId,
        elementoNombre: elementoNombre,
      ),
    ),
  );
}

class _NuevoRegistroScreen extends StatefulWidget {
  const _NuevoRegistroScreen({
    required this.casaId,
    required this.elementoId,
    required this.elementoNombre,
  });

  final String casaId;
  final String elementoId;
  final String elementoNombre;

  @override
  State<_NuevoRegistroScreen> createState() => _NuevoRegistroScreenState();
}

class _NuevoRegistroScreenState extends State<_NuevoRegistroScreen> {
  TipoRegistro _tipo = TipoRegistro.reparacion;
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _costeCtrl = TextEditingController();
  List<ProfesionalRegistro> _profesionales = [];
  final _plazoFrecuenciaCtrl = TextEditingController();
  final _plazoImporteCtrl = TextEditingController();
  DateTime _fecha = DateTime.now();
  bool _esConProfesional = false;
  bool _pagaAPlazos = false;
  // CEO, noviembre 2026: "a veces el trabajo no está hecho al registrarlo,
  // deberías poder poner en qué estado se encuentra de inicio" -- por
  // defecto true (comportamiento de siempre: se anota algo que ya pasó),
  // solo para un registro simple -- uno con profesional ya nace "nuevo"
  // (pendiente de presupuesto/invitación) por su propio flujo.
  bool _yaRealizado = true;
  bool _guardando = false;

  /// Eco visual en el propio campo del mismo error que ya muestra el
  /// snackbar de [AppError.show] -- mismo criterio que nuevo_contacto_
  /// sheet.dart: no sustituye ese aviso, hace más fácil ver qué campo
  /// exacto falta sin tener que recordar el mensaje que acaba de desaparecer.
  bool _mostrarErrorTitulo = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _costeCtrl.dispose();
    _plazoFrecuenciaCtrl.dispose();
    _plazoImporteCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      setState(() => _mostrarErrorTitulo = true);
      AppError.show(context, 'Escribe un título para el evento.');
      return;
    }
    setState(() => _guardando = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final coste = double.tryParse(_costeCtrl.text.replaceAll(',', '.'));
    final frecuencia = _pagaAPlazos
        ? int.tryParse(_plazoFrecuenciaCtrl.text)
        : null;
    final importePlazo = _pagaAPlazos
        ? double.tryParse(_plazoImporteCtrl.text.replaceAll(',', '.'))
        : null;
    // Un registro con profesional (esConProfesional) fija su profesional más
    // tarde, al invitarlo -- aquí la lista solo se guarda en un registro
    // simple, que es el único que muestra este campo.
    final profesionales = _esConProfesional
        ? const <ProfesionalRegistro>[]
        : _profesionales;
    try {
      await RegistroService.crear(
        widget.casaId,
        widget.elementoId,
        Registro(
          id: '',
          elementoNombre: widget.elementoNombre,
          tipo: _tipo,
          esConProfesional: _esConProfesional,
          titulo: titulo,
          estado: _esConProfesional
              ? EstadoRegistro.nuevo
              : estadoInicialRegistroSimple(coste, yaRealizado: _yaRealizado),
          descripcion: _descripcionCtrl.text.trim().isEmpty
              ? null
              : _descripcionCtrl.text.trim(),
          coste: coste,
          profesionales: profesionales,
          // Campos heredados: nombres unidos y teléfono del primero, para que
          // listados y notificaciones sigan mostrando algo coherente.
          profesionalNombre: nombresProfesionales(profesionales),
          profesionalContacto: telefonoPrincipalProfesionales(profesionales),
          // Los dos van juntos -- si falta cualquiera, no se guarda ninguno
          // (ver comentario de plazoFrecuenciaMeses en models/registro.dart).
          plazoFrecuenciaMeses: frecuencia != null && importePlazo != null
              ? frecuencia
              : null,
          plazoImporte: frecuencia != null && importePlazo != null
              ? importePlazo
              : null,
          fecha: _fecha,
        ),
        createdBy: uid,
      );
      // Solo tras confirmar que la creación salió bien -- nunca si falla o
      // si el usuario cancela antes de llegar aquí. _guardando ya impide que
      // un doble toque dispare esta rama dos veces (ver onPressed más abajo).
      unawaited(AnalyticsService.workCreated(tipo: _tipo.name));
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo guardar el evento.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Añadir evento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(ReparaSpace.s4),
          children: [
            Text(
              'Añade un evento a mano',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: ReparaSpace.s1),
            Text(
              'Rellena los datos del trabajo o incidencia.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: ReparaSpace.s4),
            SeccionFormulario(
              titulo: 'Tipo de evento',
              children: [
                Wrap(
                  spacing: ReparaSpace.s2,
                  runSpacing: ReparaSpace.s2,
                  children: TipoRegistro.values.map((t) {
                    return ChoiceChip(
                      label: Text(nombreTipoRegistro(t)),
                      selected: _tipo == t,
                      onSelected: (_) => setState(() => _tipo = t),
                    );
                  }).toList(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('¿Lo hace un profesional?'),
                  subtitle: const Text(
                    'Activa presupuesto, pagos e invitación de profesional',
                  ),
                  value: _esConProfesional,
                  onChanged: (v) => setState(() => _esConProfesional = v),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            SeccionFormulario(
              titulo: 'Información del evento',
              children: [
                TextField(
                  controller: _tituloCtrl,
                  decoration: InputDecoration(
                    labelText: 'Título (p.ej. Reparación de fuga)',
                    errorText: _mostrarErrorTitulo ? 'Obligatorio' : null,
                  ),
                  onChanged: (_) {
                    if (_mostrarErrorTitulo) {
                      setState(() => _mostrarErrorTitulo = false);
                    }
                  },
                ),
                const SizedBox(height: ReparaSpace.s3),
                TextField(
                  controller: _descripcionCtrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                ),
                const SizedBox(height: ReparaSpace.s3),
                OutlinedButton.icon(
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text('${_fecha.day}/${_fecha.month}/${_fecha.year}'),
                ),
                if (!_esConProfesional) ...[
                  const SizedBox(height: ReparaSpace.s2),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('¿Ya se ha realizado el trabajo?'),
                    subtitle: const Text(
                      'Desactívalo si todavía está pendiente de hacer',
                    ),
                    value: _yaRealizado,
                    onChanged: (v) => setState(() => _yaRealizado = v),
                  ),
                ],
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            if (!_esConProfesional)
              SeccionFormulario(
                titulo: 'Información económica',
                children: [
                  TextField(
                    controller: _costeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Coste (€)'),
                  ),
                  const SizedBox(height: ReparaSpace.s3),
                  SelectorProfesionalesField(
                    casaId: widget.casaId,
                    seleccionados: _profesionales,
                    onChanged: (v) => setState(() => _profesionales = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('¿Se paga a plazos?'),
                    subtitle: const Text(
                      'Para calcular cuándo toca el próximo pago',
                    ),
                    value: _pagaAPlazos,
                    onChanged: (v) => setState(() => _pagaAPlazos = v),
                  ),
                  if (_pagaAPlazos)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _plazoFrecuenciaCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cada cuántos meses',
                            ),
                          ),
                        ),
                        const SizedBox(width: ReparaSpace.s3),
                        Expanded(
                          child: TextField(
                            controller: _plazoImporteCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Importe por plazo (€)',
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              )
            else
              SeccionFormulario(
                titulo: 'Información económica',
                children: [
                  Text(
                    'El coste y el profesional de este trabajo se fijan '
                    'después, desde el propio evento: invita al profesional '
                    'y, cuando acepte, podrá enviarte un presupuesto.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            const SizedBox(height: ReparaSpace.s6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
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
                    : const Text('Guardar'),
              ),
            ),
            const SizedBox(height: ReparaSpace.s2),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _guardando ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
