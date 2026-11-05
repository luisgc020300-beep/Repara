// lib/screens/pro/trabajo_profesional_sheet.dart
//
// Hoja para crear o editar un trabajo privado del profesional (Fase 1,
// noviembre 2026). Si se abre sin un cliente ya fijado (p.ej. desde la
// pestaña Trabajos en vez de desde la ficha de un cliente), incluye un
// selector que permite elegir uno existente o crear uno nuevo sin salir
// del formulario.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/cliente_profesional.dart';
import '../../models/registro.dart';
import '../../models/trabajo_profesional.dart';
import '../../services/cliente_profesional_service.dart';
import '../../services/trabajo_profesional_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';
import '../../widgets/ios_list.dart';
import 'cliente_profesional_sheet.dart';
import 'registro_pro_detail_screen.dart';

Future<void> mostrarEditorTrabajoProfesional(
  BuildContext context, {
  String? clienteId,
  String? clienteNombre,
  TrabajoProfesional? existente,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ReparaRadius.lg)),
    ),
    builder: (_) => _EditorTrabajoProfesionalSheet(
      clienteId: clienteId,
      clienteNombre: clienteNombre,
      existente: existente,
    ),
  );
}

class _EditorTrabajoProfesionalSheet extends StatefulWidget {
  const _EditorTrabajoProfesionalSheet({
    this.clienteId,
    this.clienteNombre,
    this.existente,
  });

  final String? clienteId;
  final String? clienteNombre;
  final TrabajoProfesional? existente;

  @override
  State<_EditorTrabajoProfesionalSheet> createState() =>
      _EditorTrabajoProfesionalSheetState();
}

class _EditorTrabajoProfesionalSheetState
    extends State<_EditorTrabajoProfesionalSheet> {
  late final _tituloCtrl = TextEditingController(
    text: widget.existente?.titulo ?? '',
  );
  late final _descripcionCtrl = TextEditingController(
    text: widget.existente?.descripcion ?? '',
  );
  late final _presupuestoCtrl = TextEditingController(
    text: widget.existente?.presupuestoEstimado?.toStringAsFixed(2) ?? '',
  );
  late final _direccionCtrl = TextEditingController(
    text: widget.existente?.direccionIntervencion ?? '',
  );
  late TipoRegistro _tipo = widget.existente?.tipo ?? TipoRegistro.reparacion;
  late DateTime? _fechaProgramada = widget.existente?.fechaProgramada;
  late String? _clienteId = widget.existente?.clienteId ?? widget.clienteId;
  late String? _clienteNombre =
      widget.existente?.clienteNombre ?? widget.clienteNombre;
  bool _guardando = false;
  bool _mostrarErrorTitulo = false;

  bool get _esEdicion => widget.existente != null;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _presupuestoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirCliente() async {
    final clientes = await ClienteProfesionalService.streamClientes().first;
    if (!mounted) return;
    final elegido = await showModalBottomSheet<ClienteProfesional?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: ReparaSpace.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.add, color: ctx.colors.brand),
                title: const Text('Crear nuevo cliente'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final id = await mostrarEditorClienteProfesional(context);
                  if (id != null && mounted) {
                    // No tenemos el nombre recién tecleado aquí sin volver a
                    // leer -- se vuelve a abrir el selector tras crear, para
                    // que el profesional lo elija de la lista ya actualizada
                    // en vez de arriesgarnos a desincronizar clienteNombre.
                    await _elegirCliente();
                  }
                },
              ),
              const Divider(height: 1),
              if (clientes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(ReparaSpace.s5),
                  child: Text('Todavía no tienes ningún cliente privado.'),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in clientes)
                        IosRow(
                          icon: Icons.person_outline,
                          iconColor: ctx.colors.brand,
                          title: c.nombre,
                          subtitle: c.telefono,
                          onTap: () => Navigator.pop(ctx, c),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (elegido != null) {
      setState(() {
        _clienteId = elegido.id;
        _clienteNombre = elegido.nombre;
      });
    }
  }

  Future<void> _mostrarVincularHogar(TrabajoProfesional trabajo) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ReparaRadius.lg)),
      ),
      builder: (_) => _VincularHogarSheet(trabajo: trabajo),
    );
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaProgramada ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (elegida != null) setState(() => _fechaProgramada = elegida);
  }

  Future<void> _guardar() async {
    final titulo = _tituloCtrl.text.trim();
    final clienteId = _clienteId;
    final clienteNombre = _clienteNombre;
    if (titulo.isEmpty) {
      setState(() => _mostrarErrorTitulo = true);
      AppError.show(context, 'Ponle un título al trabajo.');
      return;
    }
    if (clienteId == null || clienteNombre == null) {
      AppError.show(context, 'Elige un cliente para este trabajo.');
      return;
    }
    setState(() => _guardando = true);
    final presupuesto = double.tryParse(
      _presupuestoCtrl.text.trim().replaceAll(',', '.'),
    );
    final trabajo = TrabajoProfesional(
      id: widget.existente?.id ?? '',
      clienteId: clienteId,
      clienteNombre: clienteNombre,
      titulo: titulo,
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      tipo: _tipo,
      estado: widget.existente?.estado ?? EstadoTrabajoProfesional.abierto,
      presupuestoEstimado: presupuesto,
      direccionIntervencion: _direccionCtrl.text.trim().isEmpty
          ? null
          : _direccionCtrl.text.trim(),
      fechaProgramada: _fechaProgramada,
    );
    try {
      if (_esEdicion) {
        await TrabajoProfesionalService.actualizar(
          widget.existente!.id,
          trabajo,
        );
      } else {
        await TrabajoProfesionalService.crear(trabajo);
      }
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo guardar el trabajo.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Vinculado a REPARA Hogar (Fase 2): el Registro real es la fuente de
    // verdad a partir de aquí -- estado/presupuesto/pagos se gestionan
    // desde ahí, no desde este editor privado. Solo lectura + acceso
    // directo al trabajo real.
    final vinculo = widget.existente?.vinculo;
    if (vinculo != null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ReparaSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existente!.titulo, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: ReparaSpace.s2),
              IosSection(
                rows: [
                  IosRow(
                    icon: Icons.link,
                    iconColor: context.colors.success,
                    title: 'Vinculado a REPARA Hogar',
                    subtitle: 'en ${vinculo.casaNombre}',
                    showChevron: false,
                  ),
                ],
              ),
              const SizedBox(height: ReparaSpace.s3),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegistroProDetailScreen(
                        casaId: vinculo.casaId,
                        elementoId: vinculo.elementoId,
                        registroId: vinculo.registroId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Abrir el trabajo vinculado'),
              ),
            ],
          ),
        ),
      );
    }
    final clienteFijo = widget.clienteId != null || _esEdicion;
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
                _esEdicion ? 'Editar trabajo' : 'Nuevo trabajo',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: ReparaSpace.s3),
              if (!clienteFijo)
                Padding(
                  padding: const EdgeInsets.only(bottom: ReparaSpace.s3),
                  child: OutlinedButton.icon(
                    onPressed: _elegirCliente,
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: Text(_clienteNombre ?? 'Elige un cliente'),
                  ),
                )
              else if (_clienteNombre != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: ReparaSpace.s3),
                  child: Text(
                    'Cliente: ${_clienteNombre!}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              TextField(
                controller: _tituloCtrl,
                decoration: InputDecoration(
                  labelText: 'Título',
                  errorText: _mostrarErrorTitulo ? 'Escribe un título.' : null,
                ),
                onChanged: (_) {
                  if (_mostrarErrorTitulo) {
                    setState(() => _mostrarErrorTitulo = false);
                  }
                },
              ),
              const SizedBox(height: ReparaSpace.s2),
              DropdownButtonFormField<TipoRegistro>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: TipoRegistro.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(nombreTipoRegistro(t)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v ?? _tipo),
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
              const SizedBox(height: ReparaSpace.s2),
              TextField(
                controller: _presupuestoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Presupuesto estimado (opcional)',
                  suffixText: '€',
                ),
              ),
              const SizedBox(height: ReparaSpace.s2),
              TextField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección de la intervención (opcional)',
                ),
              ),
              const SizedBox(height: ReparaSpace.s2),
              OutlinedButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  _fechaProgramada == null
                      ? 'Fecha prevista (opcional)'
                      : '${_fechaProgramada!.day}/${_fechaProgramada!.month}/${_fechaProgramada!.year}',
                ),
              ),
              if (_esEdicion) ...[
                const SizedBox(height: ReparaSpace.s3),
                OutlinedButton.icon(
                  onPressed: () => _mostrarVincularHogar(widget.existente!),
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Vincular con REPARA Hogar'),
                ),
              ],
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
                    : Text(_esEdicion ? 'Guardar cambios' : 'Crear trabajo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vincular un trabajo privado con una cuenta real de REPARA Hogar (Fase 2,
/// noviembre 2026) -- mismo formulario/patrón que _SeccionInvitarProfesional
/// en registro_detail_screen.dart (email o teléfono, invitación directa o
/// código abierto), en la dirección inversa.
class _VincularHogarSheet extends StatefulWidget {
  const _VincularHogarSheet({required this.trabajo});

  final TrabajoProfesional trabajo;

  @override
  State<_VincularHogarSheet> createState() => _VincularHogarSheetState();
}

class _VincularHogarSheetState extends State<_VincularHogarSheet> {
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  bool _enviando = false;
  String? _ultimoCodigoGenerado;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _compartirCodigo(String codigo) async {
    final mensaje =
        'Voy a llevar "${widget.trabajo.titulo}" en Repara, así tienes todo el historial, '
        'presupuestos y fotos organizados en un solo sitio.\n'
        'Descárgate la app, crea tu cuenta y, cuando te pida un código de invitación, introduce: $codigo';
    if (!mounted) return;
    try {
      await Share.share(
        mensaje,
        sharePositionOrigin: Offset.zero & MediaQuery.of(context).size,
      );
    } catch (e) {
      // El código ya se generó y se muestra en pantalla -- que falle el
      // selector de compartir no debe parecer que la invitación falló.
    }
  }

  Future<void> _invitar() async {
    final email = _emailCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();
    if (email.isEmpty && telefono.isEmpty) return;
    setState(() => _enviando = true);
    try {
      final resultado = await TrabajoProfesionalService.invitarAHogar(
        trabajoProfesionalId: widget.trabajo.id,
        emailCliente: email.isEmpty ? null : email,
        telefonoCliente: telefono.isEmpty ? null : telefono,
      );
      _emailCtrl.clear();
      _telefonoCtrl.clear();
      if (resultado.esDirecta) {
        if (mounted) {
          AppError.showSuccess(context, 'Invitación enviada.');
          Navigator.pop(context);
        }
      } else if (mounted) {
        setState(() => _ultimoCodigoGenerado = resultado.codigo);
        await _compartirCodigo(resultado.codigo!);
      }
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo enviar la invitación.',
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
    return SafeArea(
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
                'Vincular con REPARA Hogar',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: ReparaSpace.s1),
              Text(
                'Tu cliente verá este trabajo, su estado, presupuesto y cualquier cambio directamente en su cuenta de Repara.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: ReparaSpace.s3),
              if (_ultimoCodigoGenerado != null) ...[
                Row(
                  children: [
                    Icon(Icons.qr_code_2_outlined, color: context.colors.brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Código para compartir: $_ultimoCodigoGenerado',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 1),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      tooltip: 'Compartir código',
                      onPressed: () => _compartirCodigo(_ultimoCodigoGenerado!),
                    ),
                  ],
                ),
                const SizedBox(height: ReparaSpace.s2),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Listo'),
                ),
              ] else ...[
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email de tu cliente'),
                ),
                const SizedBox(height: ReparaSpace.s2),
                TextField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'o teléfono (opcional)'),
                ),
                const SizedBox(height: ReparaSpace.s3),
                FilledButton(
                  onPressed: _enviando ? null : _invitar,
                  child: _enviando
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.brandOn,
                          ),
                        )
                      : const Text('Enviar invitación'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
