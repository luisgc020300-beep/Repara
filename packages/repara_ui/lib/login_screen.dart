// packages/repara_ui/lib/login_screen.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:repara_core/analytics_service.dart';

import 'package:repara_core/design_tokens.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({this.backgroundImageAsset, super.key});

  /// Fondo fotográfico a pantalla completa (pedido solo para REPARA Hogar,
  /// noviembre 2026) -- opcional y `null` por defecto para no tocar el
  /// aspecto de REPARA Pro ni del monolito, que siguen llamando a
  /// `LoginScreen()` sin este parámetro y ven exactamente el mismo diseño
  /// plano de siempre.
  final String? backgroundImageAsset;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _esRegistro = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (_esRegistro) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        unawaited(AnalyticsService.authSignupCompleted());
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        unawaited(AnalyticsService.authLogin());
      }
      // Cierra el contexto de autofill al confirmarse el login/registro --
      // sin esto, en Android el aviso de "guardar contraseña" del gestor
      // del sistema no siempre llega a mostrarse tras cambiar de pantalla.
      TextInput.finishAutofillContext();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Error de autenticación');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.backgroundImageAsset == null
        ? _buildSinFondo(context)
        : _buildConFondo(context, widget.backgroundImageAsset!);
  }

  // Lista de campos del formulario, compartida tal cual por los dos diseños
  // -- misma lógica de autenticación, mismos controllers/validators, solo
  // cambia cómo se pintan alrededor.
  List<Widget> _camposFormulario() => [
        AutofillGroup(
          child: Column(
            children: [
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) => (v == null || !v.contains('@')) ? 'Correo no válido' : null,
              ),
              const SizedBox(height: ReparaSpace.s3),
              TextFormField(
                controller: _passCtrl,
                obscureText: true,
                autofillHints: [_esRegistro ? AutofillHints.newPassword : AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: ReparaSpace.s3),
          Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: context.colors.error),
              const SizedBox(width: ReparaSpace.s2),
              Expanded(child: Text(_error!, style: TextStyle(color: context.colors.errorText))),
            ],
          ),
        ],
        const SizedBox(height: ReparaSpace.s5),
        FilledButton(
          onPressed: _cargando ? null : _enviar,
          child: _cargando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_esRegistro ? 'Crear cuenta' : 'Entrar'),
        ),
      ];

  // Diseño original, sin fondo fotográfico -- intacto, es lo que siguen
  // viendo REPARA Pro y el monolito (llaman a LoginScreen() sin parámetro).
  Widget _buildSinFondo(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ReparaSpace.s6),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(ReparaRadius.md),
                      child: Image.asset('assets/icon/app_icon.png', width: 88, height: 88),
                    ),
                  ),
                  const SizedBox(height: ReparaSpace.s5),
                  Text(
                    'Repara',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: ReparaSpace.s2),
                  Text(
                    'Tu casa tiene una historia. Repara la recuerda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.inkMuted),
                  ),
                  const SizedBox(height: ReparaSpace.s8),
                  ..._camposFormulario(),
                  const SizedBox(height: ReparaSpace.s2),
                  TextButton(
                    onPressed: _cargando ? null : () => setState(() => _esRegistro = !_esRegistro),
                    child: Text(_esRegistro ? '¿Ya tienes cuenta? Entra' : '¿No tienes cuenta? Regístrate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Diseño con fotografía de fondo a pantalla completa (REPARA Hogar,
  // noviembre 2026) -- misma lógica/controladores/validaciones de arriba,
  // solo cambia la composición visual: foto + degradado oscuro (sobre
  // context.colors.ink, nunca un negro inventado aparte de la paleta) +
  // los mismos componentes Flutter funcionales superpuestos, nunca una
  // captura estática.
  Widget _buildConFondo(BuildContext context, String fondo) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            fondo,
            fit: BoxFit.cover,
            // Si el recurso no está disponible (p.ej. todavía no se ha
            // añadido en un fork/checkout concreto), la pantalla sigue
            // siendo utilizable con un degradado de marca en vez de
            // reventar -- nunca una pantalla en blanco o un error visible.
            errorBuilder: (context, error, stackTrace) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.colors.brand, context.colors.ink],
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.colors.ink.withValues(alpha: esOscuro ? 0.55 : 0.35),
                  context.colors.ink.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(ReparaSpace.s6),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(ReparaRadius.md),
                          child: Image.asset('assets/icon/app_icon.png', width: 88, height: 88),
                        ),
                      ),
                      const SizedBox(height: ReparaSpace.s5),
                      Text(
                        'Repara Hogar',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: ReparaSpace.s2),
                      Text(
                        'Tu hogar, siempre bajo control.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                      const SizedBox(height: ReparaSpace.s8),
                      ..._camposFormulario(),
                      const SizedBox(height: ReparaSpace.s2),
                      TextButton(
                        onPressed: _cargando ? null : () => setState(() => _esRegistro = !_esRegistro),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        child: Text(_esRegistro ? '¿Ya tienes cuenta? Entra' : '¿No tienes cuenta? Regístrate'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
