// packages/repara_ui/lib/login_screen.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:repara_core/analytics_service.dart';
import 'package:repara_core/cuenta_service.dart';

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
  final _nombreCtrl = TextEditingController();
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
    _nombreCtrl.dispose();
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
        // Nombre al registrarse (punto 9, personalización, noviembre 2026)
        // -- opcional y en el mejor esfuerzo: sin esto, cualquier cuenta
        // nueva aparecía como "Tu perfil" (saludo de Inicio, miembros de la
        // casa, notificaciones) hasta que alguien entraba a mano en Ajustes
        // a ponerlo. Si falla, la cuenta ya está creada e iniciada sesión
        // igualmente -- se puede poner el nombre después desde Ajustes.
        final nombre = _nombreCtrl.text.trim();
        if (nombre.isNotEmpty) {
          try {
            await CuentaService.actualizarNombrePerfil(nombre);
          } catch (_) {
            // Best-effort -- ver comentario de arriba.
          }
        }
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

  // "Continuar con Google" (noviembre 2026) -- sirve tanto para entrar como
  // para registrarse: signInWithCredential crea la cuenta de Firebase Auth
  // sola si no existía. Igual que en el registro con correo, el nombre se
  // rellena best-effort (ver comentario de _enviar) para que el saludo de
  // Inicio no se quede en "Tu perfil".
  Future<void> _iniciarSesionConGoogle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _cargando = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final esNuevo = userCred.additionalUserInfo?.isNewUser ?? false;
      if (esNuevo) {
        final nombre = userCred.user?.displayName?.trim();
        if (nombre != null && nombre.isNotEmpty) {
          try {
            await CuentaService.actualizarNombrePerfil(nombre);
          } catch (_) {
            // Best-effort -- ver comentario de _enviar.
          }
        }
        unawaited(AnalyticsService.authSignupCompleted());
      } else {
        unawaited(AnalyticsService.authLogin());
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Error al iniciar sesión con Google');
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión con Google.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // "¿Olvidaste tu contraseña?" (noviembre 2026) -- usa el mismo campo de
  // correo del formulario, no uno aparte: si el usuario ya lo escribió para
  // entrar y falló, no tiene que volver a teclearlo.
  Future<void> _recuperarContrasena() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
        () => _error = 'Escribe tu correo arriba para recuperar la contraseña.',
      );
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Te hemos enviado un correo a $email para restablecer tu contraseña.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error = e.message ?? 'No se pudo enviar el correo de recuperación.',
      );
    } catch (_) {
      setState(() => _error = 'No se pudo enviar el correo de recuperación.');
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
          // Nombre (punto 9, personalización, noviembre 2026) -- solo al
          // registrarse, y opcional: sin él, cualquier cuenta nueva aparece
          // como "Tu perfil" en el saludo de Inicio y en "Miembros de esta
          // casa" hasta que alguien lo pone a mano en Ajustes. No añade
          // fricción al login (que sigue solo con correo+contraseña).
          if (_esRegistro) ...[
            TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Nombre (opcional)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: ReparaSpace.s3),
          ],
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
          // "¿Olvidaste tu contraseña?" (noviembre 2026) -- solo al entrar,
          // no al registrarse (ahí la contraseña todavía no existe).
          if (!_esRegistro)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _cargando ? null : _recuperarContrasena,
                style: widget.backgroundImageAsset == null
                    ? null
                    : TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
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
    const SizedBox(height: ReparaSpace.s4),
    Row(
      children: [
        Expanded(
          child: Divider(
            color: widget.backgroundImageAsset == null
                ? null
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ReparaSpace.s3),
          child: Text(
            'o',
            style: TextStyle(
              color: widget.backgroundImageAsset == null
                  ? context.colors.inkMuted
                  : Colors.white70,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: widget.backgroundImageAsset == null
                ? null
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    ),
    const SizedBox(height: ReparaSpace.s4),
    OutlinedButton.icon(
      onPressed: _cargando ? null : _iniciarSesionConGoogle,
      style: widget.backgroundImageAsset == null
          ? null
          : OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
            ),
      icon: const _GoogleIcon(),
      label: const Text('Continuar con Google'),
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

// Logo "G" de Google pintado a mano (sin añadir ningún asset de imagen al
// paquete) -- mismas proporciones/colores oficiales que el resto de botones
// "Continuar con Google" del ecosistema.
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(18, 18), painter: _GoogleIconPainter());
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p1 = Paint()..color = const Color(0xFF4285F4);
    final p2 = Paint()..color = const Color(0xFF34A853);
    final p3 = Paint()..color = const Color(0xFFFBBC05);
    final p4 = Paint()..color = const Color(0xFFEA4335);

    canvas.drawPath(
      Path()
        ..moveTo(22.56 * s, 12.25 * s)
        ..lineTo(22.36 * s, 10 * s)
        ..lineTo(12 * s, 10 * s)
        ..lineTo(12 * s, 14.26 * s)
        ..lineTo(17.92 * s, 14.26 * s)
        ..cubicTo(17.66 * s, 15.63 * s, 16.88 * s, 16.79 * s, 15.71 * s, 17.57 * s)
        ..lineTo(15.71 * s, 20.34 * s)
        ..lineTo(19.28 * s, 20.34 * s)
        ..cubicTo(21.36 * s, 18.42 * s, 22.56 * s, 15.60 * s, 22.56 * s, 12.25 * s)
        ..close(),
      p1,
    );

    canvas.drawPath(
      Path()
        ..moveTo(12 * s, 23 * s)
        ..cubicTo(14.97 * s, 23 * s, 17.46 * s, 22.02 * s, 19.28 * s, 20.34 * s)
        ..lineTo(15.71 * s, 17.57 * s)
        ..cubicTo(14.73 * s, 18.23 * s, 13.48 * s, 18.63 * s, 12 * s, 18.63 * s)
        ..cubicTo(9.14 * s, 18.63 * s, 6.71 * s, 16.70 * s, 5.84 * s, 14.10 * s)
        ..lineTo(2.18 * s, 14.10 * s)
        ..lineTo(2.18 * s, 16.94 * s)
        ..cubicTo(3.99 * s, 20.53 * s, 7.70 * s, 23 * s, 12 * s, 23 * s)
        ..close(),
      p2,
    );

    canvas.drawPath(
      Path()
        ..moveTo(5.84 * s, 14.09 * s)
        ..cubicTo(5.62 * s, 13.43 * s, 5.49 * s, 12.73 * s, 5.49 * s, 12 * s)
        ..cubicTo(5.49 * s, 11.27 * s, 5.62 * s, 10.57 * s, 5.84 * s, 9.91 * s)
        ..lineTo(5.84 * s, 7.07 * s)
        ..lineTo(2.18 * s, 7.07 * s)
        ..cubicTo(1.43 * s, 8.55 * s, 1 * s, 10.22 * s, 1 * s, 12 * s)
        ..cubicTo(1 * s, 13.78 * s, 1.43 * s, 15.45 * s, 2.18 * s, 16.93 * s)
        ..lineTo(5.84 * s, 14.09 * s)
        ..close(),
      p3,
    );

    canvas.drawPath(
      Path()
        ..moveTo(12 * s, 5.38 * s)
        ..cubicTo(13.62 * s, 5.38 * s, 15.06 * s, 5.94 * s, 16.21 * s, 7.02 * s)
        ..lineTo(19.36 * s, 3.87 * s)
        ..cubicTo(17.45 * s, 2.09 * s, 14.97 * s, 1 * s, 12 * s, 1 * s)
        ..cubicTo(7.70 * s, 1 * s, 3.99 * s, 3.47 * s, 2.18 * s, 7.07 * s)
        ..lineTo(5.84 * s, 9.91 * s)
        ..cubicTo(6.71 * s, 7.31 * s, 9.14 * s, 5.38 * s, 12 * s, 5.38 * s)
        ..close(),
      p4,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
