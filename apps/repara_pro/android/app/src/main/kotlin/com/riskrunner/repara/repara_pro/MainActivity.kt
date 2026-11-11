package com.riskrunner.repara.repara_pro

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (no FlutterActivity): local_auth exige una
// FragmentActivity de verdad para mostrar el diálogo nativo de biometría
// (BiometricPrompt vive en un DialogFragment) -- con FlutterActivity a
// secas, local_auth.authenticate() revienta la app en cuanto se llama
// (requisito documentado en el propio README de local_auth, sección
// "Android Integration" -- mismo criterio que el monolito).
class MainActivity : FlutterFragmentActivity()
