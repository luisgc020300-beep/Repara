// lib/screens/perfil_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../services/casa_service.dart';
import '../services/profesional_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import 'documentos_casa_screen.dart';
import 'pro/repara_pro_shell_screen.dart';

class PerfilTab extends StatelessWidget {
  const PerfilTab({required this.casa, super.key});

  final Casa casa;

  Future<void> _renombrar(BuildContext context) async {
    final ctrl = TextEditingController(text: casa.nombre);
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la casa'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty || nombre == casa.nombre) return;
    try {
      await CasaService.renombrarCasa(casa.id, nombre);
    } catch (e) {
      if (context.mounted) AppError.show(context, 'No se pudo renombrar la casa.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.house_outlined, color: context.colors.brand),
              title: Text(casa.nombre),
              subtitle: const Text('Toca para cambiar el nombre'),
              onTap: () => _renombrar(context),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.folder_open_outlined, color: context.colors.brand),
              title: const Text('Documentos'),
              subtitle: const Text('Facturas, presupuestos y garantías guardados'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentosCasaScreen(casa: casa))),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Miembros de esta casa'),
              subtitle: Text(casa.memberProfiles.values.map((m) => m.displayName).join(', ')),
            ),
          ),
          if (casa.joinCode != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Código para invitar a alguien'),
                subtitle: Text(casa.joinCode!, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _SeccionProfesional(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

/// Autoservicio de rol (sección 5 del spec: una persona puede tener varios
/// roles). Activar el modo profesional no cambia nada de Repara Hogar --
/// solo añade un acceso nuevo a Repara Pro desde este mismo Perfil.
class _SeccionProfesional extends StatefulWidget {
  @override
  State<_SeccionProfesional> createState() => _SeccionProfesionalState();
}

class _SeccionProfesionalState extends State<_SeccionProfesional> {
  bool _activando = false;

  Future<void> _activar() async {
    setState(() => _activando = true);
    try {
      await ProfesionalService.activarModoProfesional();
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo activar el modo profesional.');
    } finally {
      if (mounted) setState(() => _activando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ProfesionalService.streamEsProfesional(),
      builder: (context, snapshot) {
        final esProfesional = snapshot.data ?? false;
        if (!esProfesional) {
          return Card(
            child: ListTile(
              leading: Icon(Icons.engineering_outlined, color: context.colors.brand),
              title: const Text('¿Trabajas como profesional?'),
              subtitle: const Text('Activa el modo profesional para gestionar trabajos que te inviten'),
              trailing: _activando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(onPressed: _activar, child: const Text('Activar')),
            ),
          );
        }
        return Card(
          child: ListTile(
            leading: Icon(Icons.engineering_outlined, color: context.colors.brand),
            title: const Text('Modo profesional'),
            subtitle: const Text('Ver tus trabajos, clientes y presupuestos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReparaProShellScreen())),
          ),
        );
      },
    );
  }
}
