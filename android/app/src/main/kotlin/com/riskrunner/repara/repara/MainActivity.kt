package com.riskrunner.repara.repara

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

// FLAG_SECURE (Fase I de la misión de seguridad local, octubre 2026): bloquea
// las capturas de pantalla/grabación de pantalla del sistema y sustituye la
// miniatura de Repara en "apps recientes" por una pantalla en blanco -- la
// app guarda facturas, garantías y datos de la vivienda, no algo que deba
// quedar visible en una captura o en el selector de apps. Siempre activo,
// no depende de ningún ajuste: no hay ningún caso de uso legítimo dentro de
// Repara donde el usuario necesite hacer una captura de pantalla de la app.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }
}
