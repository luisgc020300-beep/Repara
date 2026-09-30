// lib/screens/pro/perfil_pro_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/profesional.dart';
import '../../services/profesional_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';
import '../../widgets/boton_ajustes.dart';

class PerfilProTab extends StatefulWidget {
  const PerfilProTab({super.key});

  @override
  State<PerfilProTab> createState() => _PerfilProTabState();
}

class _PerfilProTabState extends State<PerfilProTab> {
  Future<void> _editarCampo(
    String titulo,
    String? actual,
    Future<void> Function(String) guardar,
  ) async {
    final ctrl = TextEditingController(text: actual ?? '');
    final valor = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (valor == null) return;
    try {
      await guardar(valor);
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo guardar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil profesional'), actions: const [BotonAjustes()]),
      body: StreamBuilder<Profesional?>(
        stream: ProfesionalService.streamPerfilPropio(),
        builder: (context, snapshot) {
          final perfil = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: Icon(Icons.badge_outlined, color: context.colors.brand),
                  title: Text(perfil?.nombreComercial?.isNotEmpty == true ? perfil!.nombreComercial! : 'Nombre comercial'),
                  subtitle: const Text('Toca para editar'),
                  onTap: () => _editarCampo(
                    'Nombre comercial',
                    perfil?.nombreComercial,
                    (v) => ProfesionalService.actualizarPerfil(nombreComercial: v),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(perfil?.especialidad?.isNotEmpty == true ? perfil!.especialidad! : 'Especialidad'),
                  subtitle: const Text('Toca para editar'),
                  onTap: () => _editarCampo(
                    'Especialidad',
                    perfil?.especialidad,
                    (v) => ProfesionalService.actualizarPerfil(especialidad: v),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(perfil?.telefono?.isNotEmpty == true ? perfil!.telefono! : 'Teléfono de contacto'),
                  subtitle: const Text('Toca para editar'),
                  onTap: () => _editarCampo(
                    'Teléfono',
                    perfil?.telefono,
                    (v) => ProfesionalService.actualizarPerfil(telefono: v),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Volver a modo propietario'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          );
        },
      ),
    );
  }
}
