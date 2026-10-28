// lib/screens/elementos_archivados_screen.dart
//
// Pantalla dedicada a ver los elementos archivados (auditoría R5, octubre
// 2026) -- nunca mezclados con los activos (ver ElementoService.
// streamElementosArchivados). Permite abrir la ficha completa (igual que
// cualquier elemento activo: su historial, documentos y datos económicos
// siguen disponibles) y restaurarlo directamente desde la fila, sin tener
// que entrar primero.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../services/elemento_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import 'elemento_detail_screen.dart';

class ElementosArchivadosScreen extends StatelessWidget {
  const ElementosArchivadosScreen({required this.casa, super.key});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elementos archivados')),
      body: StreamBuilder<List<Elemento>>(
        stream: ElementoService.streamElementosArchivados(casa.id),
        builder: (context, snapshot) {
          final elementos = snapshot.data ?? const <Elemento>[];
          if (elementos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(ReparaSpace.s5),
                child: Text(
                  'No tienes ningún elemento archivado.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(ReparaSpace.s4),
            itemCount: elementos.length,
            separatorBuilder: (_, _) => const SizedBox(height: ReparaSpace.s2),
            itemBuilder: (context, i) =>
                _ElementoArchivadoCard(casa: casa, elemento: elementos[i]),
          );
        },
      ),
    );
  }
}

class _ElementoArchivadoCard extends StatefulWidget {
  const _ElementoArchivadoCard({required this.casa, required this.elemento});

  final Casa casa;
  final Elemento elemento;

  @override
  State<_ElementoArchivadoCard> createState() =>
      _ElementoArchivadoCardState();
}

class _ElementoArchivadoCardState extends State<_ElementoArchivadoCard> {
  bool _restaurando = false;

  Future<void> _restaurar() async {
    setState(() => _restaurando = true);
    try {
      await ElementoService.restaurar(widget.casa.id, widget.elemento.id);
      if (mounted) AppError.showSuccess(context, 'Elemento restaurado.');
    } on FirebaseFunctionsException catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          e.message ?? 'No se pudo restaurar el elemento.',
          error: e,
          stackTrace: st,
        );
      }
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo restaurar el elemento.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _restaurando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final elemento = widget.elemento;
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ElementoDetailScreen(casa: widget.casa, elementoId: elemento.id),
          ),
        ),
        title: Text(elemento.nombre),
        subtitle: elemento.archivadoAt != null
            ? Text(
                'Archivado el ${DateFormat('d MMM yyyy', 'es_ES').format(elemento.archivadoAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
        trailing: _restaurando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : OutlinedButton(
                onPressed: _restaurar,
                child: const Text('Restaurar'),
              ),
      ),
    );
  }
}
