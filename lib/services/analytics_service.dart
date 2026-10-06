// lib/services/analytics_service.dart
//
// Eventos de producto orientados a decisiones (auditoría de producto,
// octubre 2026): el embudo registro → vivienda → primer valor → trabajo →
// profesional invitado → invitación aceptada → presupuesto → presupuesto
// aceptado → pago → trabajo finalizado → retorno.
//
// Principio: nunca se registra texto privado, documentos, direcciones ni
// nombres completos. Los importes de dinero se mandan como rango, nunca
// como cifra exacta -- basta para analizar comportamiento sin exponer el
// importe real de un usuario concreto. D1/D7/D30/D90 no necesitan ningún
// evento propio: Firebase Analytics los calcula solo en su panel de
// Retención en cuanto el SDK está inicializado (recolección automática de
// first_open/session_start) -- userReturned() es un evento complementario,
// no la fuente de esa métrica.
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics instance = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: instance);

  static Future<void> _log(String name, [Map<String, Object>? params]) {
    return instance.logEvent(name: name, parameters: params);
  }

  /// true si es profesional, false si no -- se repite en cada llamada
  /// porque el mismo usuario puede activar el modo profesional más tarde
  /// (sección 5 del spec: varios roles en la misma cuenta).
  static Future<void> setEsProfesional(bool esProfesional) =>
      instance.setUserProperty(name: 'es_profesional', value: esProfesional.toString());

  // ── AUTH ───────────────────────────────────────────────────────────────
  static Future<void> authSignupCompleted() => _log('auth_signup_completed');
  static Future<void> authLogin() => _log('auth_login');

  // ── ONBOARDING / VIVIENDA ────────────────────────────────────────────────
  static Future<void> homeCreated() => _log('home_created');
  static Future<void> firstElementCreated() => _log('first_element_created');
  static Future<void> firstDocumentUploaded() => _log('first_document_uploaded');
  static Future<void> documentAiExtractionCompleted({required bool exito, String? confianza}) =>
      _log('document_ai_extraction_completed', {'exito': exito, 'confianza': ?confianza});
  static Future<void> documentConfirmed({required bool comoBorrador}) =>
      _log('document_confirmed', {'como_borrador': comoBorrador});

  // ── TRABAJO / PROFESIONAL ────────────────────────────────────────────────
  static Future<void> workCreated({required String tipo}) => _log('work_created', {'tipo': tipo});
  static Future<void> professionalInvited({required String metodo}) =>
      _log('professional_invited', {'metodo': metodo}); // 'email' | 'codigo'
  static Future<void> professionalInvitationAccepted() => _log('professional_invitation_accepted');

  // ── PRESUPUESTOS ──────────────────────────────────────────────────────
  static Future<void> quoteCreated({required int numLineas}) => _log('quote_created', {'num_lineas': numLineas});
  static Future<void> quoteViewed() => _log('quote_viewed');
  static Future<void> quoteAccepted() => _log('quote_accepted');
  static Future<void> quoteRejected() => _log('quote_rejected');

  // ── SCOPEGUARD ────────────────────────────────────────────────────────
  static Future<void> scopeChangeCreated() => _log('scope_change_created');
  static Future<void> scopeChangeAccepted() => _log('scope_change_accepted');

  // ── PAGOS Y FINALIZACIÓN ──────────────────────────────────────────────
  static Future<void> paymentCreated({required double importe}) =>
      _log('payment_created', {'importe_rango': _rangoImporte(importe)});
  static Future<void> workCompleted({required bool pagadoDelTodo}) =>
      _log('work_completed', {'pagado_del_todo': pagadoDelTodo});

  // ── EXPEDIENTE / RETENCIÓN ────────────────────────────────────────────
  static Future<void> householdRecordViewed() => _log('household_record_viewed');
  static Future<void> householdRecordShared() => _log('household_record_shared');
  static Future<void> userReturned() => _log('user_returned');

  static String _rangoImporte(double v) {
    if (v <= 0) return '0';
    if (v < 50) return '1-49';
    if (v < 200) return '50-199';
    if (v < 1000) return '200-999';
    if (v < 5000) return '1000-4999';
    return '5000+';
  }
}
