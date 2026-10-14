// lib/screens/login_screen.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/analytics_service.dart';
import '../theme/design_tokens.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
}
