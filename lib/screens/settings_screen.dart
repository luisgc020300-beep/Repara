// lib/screens/settings_screen.dart
//
// Ajustes accesibles desde cualquier pestaña (icono de engranaje en la
// barra superior) -- apariencia (claro/oscuro/sistema) y cerrar sesión.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmar != true) return;
    await FirebaseAuth.instance.signOut();
    // El StreamBuilder de MaterialApp ya muestra LoginScreen por debajo en
    // cuanto cambia la sesión, pero esta pantalla sigue empujada encima en
    // la pila de navegación -- hay que volver a la raíz para que se vea.
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Apariencia', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: context.colors.inkMuted)),
            const SizedBox(height: 8),
            Card(
              child: RadioGroup<ThemeMode>(
                groupValue: ThemeController.instance.mode,
                onChanged: (m) => ThemeController.instance.setMode(m!),
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: Text('Claro'),
                      secondary: Icon(Icons.light_mode_outlined),
                    ),
                    Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: Text('Oscuro'),
                      secondary: Icon(Icons.dark_mode_outlined),
                    ),
                    Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: Text('Igual que el sistema'),
                      secondary: Icon(Icons.smartphone_outlined),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: Icon(Icons.logout_outlined, color: context.colors.error),
                title: Text('Cerrar sesión', style: TextStyle(color: context.colors.error, fontWeight: FontWeight.w600)),
                onTap: _confirmarCerrarSesion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
