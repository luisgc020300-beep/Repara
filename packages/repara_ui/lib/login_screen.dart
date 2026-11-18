// packages/repara_ui/lib/login_screen.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:repara_core/analytics_service.dart';

import 'package:repara_core/design_tokens.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    this.backgroundImageAsset,
    this.backgroundImageAssetDark,
    super.key,
  });

  /// Fondo fotográfico a pantalla completa (pedido solo para REPARA Hogar,
  /// noviembre 2026) -- opcional y `null` por defecto para no tocar el
  /// aspecto de REPARA Pro ni del monolito, que siguen llamando a
  /// `LoginScreen()` sin este parámetro y ven exactamente el mismo diseño
  /// plano de siempre.
  final String? backgroundImageAsset;

  /// Foto de fondo para modo oscuro (REPARA Hogar, noviembre 2026). Si es
  /// `null`, en modo oscuro se usa la misma que en claro.
  final String? backgroundImageAssetDark;

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

  // Mostrar/ocultar contraseña (pulido visual del registro/login de Hogar,
  // noviembre 2026) -- solo cuando hay foto de fondo (backgroundImageAsset
  // != null, la señal que ya usa todo este archivo para distinguir Hogar de
  // Pro/monolito): afinar un campo que ya existe, no toca ni añade ningún
  // dato ni lógica de autenticación, y deja a Pro/monolito con el mismo
  // campo exacto de siempre.
  bool _passwordVisible = false;

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
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final fondo = esOscuro
        ? (widget.backgroundImageAssetDark ?? widget.backgroundImageAsset)
        : widget.backgroundImageAsset;
    return fondo == null
        ? _buildSinFondo(context)
        : _buildConFondo(context, fondo);
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
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Correo no válido' : null,
          ),
          const SizedBox(height: ReparaSpace.s3),
          TextFormField(
            controller: _passCtrl,
            obscureText: widget.backgroundImageAsset == null
                ? true
                : !_passwordVisible,
            autofillHints: [
              _esRegistro ? AutofillHints.newPassword : AutofillHints.password,
            ],
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: widget.backgroundImageAsset == null
                  ? null
                  : IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(
                        () => _passwordVisible = !_passwordVisible,
                      ),
                    ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
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
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: context.colors.errorText),
            ),
          ),
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
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
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
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 88,
                        height: 88,
                      ),
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
                    onPressed: _cargando
                        ? null
                        : () => setState(() => _esRegistro = !_esRegistro),
                    child: Text(
                      _esRegistro
                          ? '¿Ya tienes cuenta? Entra'
                          : '¿No tienes cuenta? Regístrate',
                    ),
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
            // Sin parpadeo en blanco si se cambia de tema con la pantalla abierta.
            gaplessPlayback: true,
            // Si el recurso no está disponible (p.ej. todavía no se ha
            // añadido en un fork/checkout concreto), la pantalla sigue
            // siendo utilizable con un degradado de marca en vez de
            // reventar -- nunca una pantalla en blanco o un error visible.
            errorBuilder: (context, error, stackTrace) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.colors.brand, context.colors.brandStrong],
                ),
              ),
            ),
          ),
          // Velo azul (pulido visual, noviembre 2026) -- siempre
          // `brandStrong`, nunca `ink`: `ink` es el color de TEXTO (en modo
          // oscuro es casi blanco, pensado para leerse sobre fondos oscuros,
          // no para pintar un velo), mientras que `brandStrong` es azul de
          // marca en los dos temas (más oscuro en claro, algo más claro en
          // oscuro) -- el tono "coherente con la paleta de cada tema" que
          // pide el encargo. La foto de día (clara, cielo despejado) necesita
          // más velo para que el texto blanco siga siendo legible; la de
          // noche ya es oscura de por sí, así que lleva menos.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.colors.brandStrong.withValues(
                    alpha: esOscuro ? 0.12 : 0.22,
                  ),
                  context.colors.brandStrong.withValues(
                    alpha: esOscuro ? 0.62 : 0.82,
                  ),
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
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 88,
                            height: 88,
                          ),
                        ),
                      ),
                      const SizedBox(height: ReparaSpace.s5),
                      Text(
                        'Repara Hogar',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: ReparaSpace.s2),
                      Text(
                        // Distingue a simple vista entrar/registrarse (pulido
                        // visual, noviembre 2026) -- antes el mismo subtítulo
                        // se quedaba fijo en los dos modos y solo cambiaba el
                        // texto del botón, al final del formulario.
                        _esRegistro
                            ? 'Crea tu cuenta para empezar a llevar el historial de tu hogar.'
                            : 'Tu hogar, siempre bajo control.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: ReparaSpace.s8),
                      ..._camposFormulario(),
                      const SizedBox(height: ReparaSpace.s2),
                      TextButton(
                        onPressed: _cargando
                            ? null
                            : () => setState(() => _esRegistro = !_esRegistro),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _esRegistro
                              ? '¿Ya tienes cuenta? Entra'
                              : '¿No tienes cuenta? Regístrate',
                        ),
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
