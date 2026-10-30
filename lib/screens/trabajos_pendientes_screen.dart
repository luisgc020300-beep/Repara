// lib/screens/trabajos_pendientes_screen.dart
//
// Lista de registros pendientes (CEO, octubre 2026: una fila por evento,
// no una por elemento -- un mismo elemento puede tener varios eventos
// pendientes a la vez, ver registrosConTrabajoPendiente en
// registro_service.dart) -- se abre al tocar "Trabajos pendientes" en
// Inicio, mismo patrón que garantias_proximas_screen.dart y
// revisiones_pendientes_screen.dart.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../theme/design_tokens.dart';
import '../widgets/ios_list.dart';
import 'registro_detail_screen.dart';

class TrabajosPendientesScreen extends StatelessWidget {
  const TrabajosPendientesScreen({
    required this.casa,
    required this.items,
    super.key,
  });

  final Casa casa;
  final List<
    ({
      Elemento elemento,
      String registroId,
      String registroTitulo,
      DateTime fecha,
      String? fotoUrl,
    })
  >
  items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trabajos pendientes',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: items.isEmpty
          ? Center(
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
                      child: Icon(
                        Icons.hourglass_top_outlined,
                        size: 32,
                        color: context.colors.brand,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes ningún trabajo en curso con un profesional.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.inkMuted),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                IosSection(
                  rows: items
                      .map(
                        (item) => IosRow(
                          icon: Icons.hourglass_top_outlined,
                          iconColor: context.colors.brand,
                          imageUrl: item.fotoUrl,
                          title: item.elemento.nombre,
                          subtitle:
                              '${item.registroTitulo} · ${DateFormat('d MMM yyyy', 'es_ES').format(item.fecha)}',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegistroDetailScreen(
                                casa: casa,
                                elementoId: item.elemento.id,
                                registroId: item.registroId,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
    );
  }
}
