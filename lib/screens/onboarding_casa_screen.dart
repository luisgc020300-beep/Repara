// lib/screens/onboarding_casa_screen.dart
//
// Onboarding deliberadamente mínimo (sección 7 del spec de producto): un
// único paso, nombrar la casa. No se pide inventariar nada todavía -- el
// valor se enseña dejando que el propietario añada su primer elemento o
// documento ya dentro de la app, no en un formulario largo antes de entrar.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/casa_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';

class OnboardingCasaScreen extends StatefulWidget {
  const OnboardingCasaScreen({super.key});

  @override
  State<OnboardingCasaScreen> createState() => _OnboardingCasaScreenState();
}

class _OnboardingCasaScreenState extends State<OnboardingCasaScreen> {
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  bool _cargando = false;
  bool _unirse = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _cargando = true);
    try {
      await CasaService.createCasa(nombre);
      unawaited(AnalyticsService.homeCreated());
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo crear la casa. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _unirseACasa() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) return;
    setState(() => _cargando = true);
    try {
      await CasaService.joinCasa(codigo);
    } catch (e) {
      if (mounted) AppError.show(context, 'Código no válido o la casa ya no existe.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repara'),
        actions: [
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _unirse ? '¿Cuál es el código de la casa?' : '¿Cómo quieres llamar a tu vivienda?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _unirse
                      ? 'Pídeselo a quien ya la tenga registrada en Repara.'
                      : 'Por ejemplo: "Casa Málaga" o "Piso de mis padres".',
                  style: TextStyle(color: context.colors.inkMuted),
                ),
                const SizedBox(height: 24),
                if (_unirse)
                  TextField(
                    controller: _codigoCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Código de casa'),
                  )
                else
                  TextField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre de la casa'),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _cargando ? null : (_unirse ? _unirseACasa : _crear),
                  child: _cargando
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_unirse ? 'Unirme' : 'Crear mi casa'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _cargando ? null : () => setState(() => _unirse = !_unirse),
                  child: Text(_unirse ? 'Prefiero crear una casa nueva' : 'Ya tengo un código para unirme'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
