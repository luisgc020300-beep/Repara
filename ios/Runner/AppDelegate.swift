import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Fase I de la misión de seguridad local (octubre 2026): iOS no tiene un
  // equivalente a FLAG_SECURE de Android -- no existe API pública para
  // impedir una captura de pantalla real. Lo que SÍ se puede (y se espera de
  // cualquier app seria con datos de facturas/garantías) es tapar el
  // contenido con un blur justo cuando el sistema toma la miniatura de la
  // app para el selector de apps recientes, que es el mismo instante en que
  // se dispara willResignActive.
  private var privacyOverlay: UIVisualEffectView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    guard privacyOverlay == nil, let window = self.window else { return }
    let overlay = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    overlay.frame = window.bounds
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.tag = 987654
    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
    super.applicationDidBecomeActive(application)
  }
}
