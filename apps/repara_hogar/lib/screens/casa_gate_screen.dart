// lib/screens/casa_gate_screen.dart
//
// Decide qué pantalla mostrar tras el login: onboarding si el usuario no
// tiene ninguna casa activa todavía, o el shell principal si ya la tiene.
// Mismo rol que HouseholdGateScreen en Convive.
import 'package:flutter/material.dart';

import '../core/casa_context.dart';
import '../services/casa_service.dart';
import 'casa_shell_screen.dart';
import 'onboarding_casa_screen.dart';

class CasaGateScreen extends StatelessWidget {
  const CasaGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: CasaService.streamActiveCasaId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final casaId = snapshot.data;
        if (casaId == null) return const OnboardingCasaScreen();
        CasaContext.instance.setCasaActiva(casaId);
        return CasaShellScreen(casaId: casaId);
      },
    );
  }
}
