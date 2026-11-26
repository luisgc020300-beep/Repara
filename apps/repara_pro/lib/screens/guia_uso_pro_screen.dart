// apps/repara_pro/lib/screens/guia_uso_pro_screen.dart
//
// Guía de uso de REPARA Pro (paridad con guia_uso_screen.dart de Hogar --
// CEO, auditoría de calidad, noviembre 2026: "en ajustes de repara pro,
// acerca de repara pro, no hay una guía de uso igual que la que sí hay en
// repara hogar"). Mismo criterio que allí: texto nativo dentro de la app,
// sin salir a ningún enlace externo. _Seccion/_Subseccion/_Punto/_Faq son
// una copia manual de los widgets privados de guia_uso_screen.dart --
// mismo motivo que el resto de duplicaciones de este repo (son privados a
// su archivo, y Hogar/Pro no comparten pantallas entre sí).
import 'package:flutter/material.dart';

import 'package:repara_core/design_tokens.dart';

class GuiaUsoProScreen extends StatelessWidget {
  const GuiaUsoProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guía de uso')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Todo lo que hace REPARA Pro',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: ReparaSpace.s2),
          Text(
            'Gestiona tus trabajos y clientes desde un solo sitio. Esta guía '
            'explica cada parte de la app y responde a las dudas más '
            'habituales.',
            style: TextStyle(color: context.colors.inkMuted),
          ),
          const SizedBox(height: ReparaSpace.s6),

          const _Seccion(
            icon: Icons.info_outline,
            titulo: 'Qué es REPARA Pro',
            parrafos: [
              'REPARA Pro es la app hermana de REPARA Hogar, pensada para '
                  'fontaneros, electricistas y demás profesionales. Cuando un '
                  'cliente con REPARA Hogar te invita a un trabajo, puedes '
                  'mandarle un presupuesto formal, llevar el seguimiento de '
                  'los pagos y confirmar cuándo termina -- todo queda '
                  'reflejado también en su cuenta.',
              'No depende de que tus clientes usen la app: con los clientes '
                  'privados llevas igual de organizado tu propio trabajo '
                  'aunque nadie más tenga REPARA.',
              'La primera vez que entras con una cuenta nueva (que nunca ha '
                  'pasado por REPARA Hogar) hay que activar el perfil '
                  'profesional antes de llegar a la app -- un paso único, no '
                  'hace falta repetirlo.',
            ],
          ),

          const _Seccion(
            icon: Icons.dashboard_outlined,
            titulo: 'Las cinco pestañas',
            parrafos: [],
            children: [
              _Subseccion(
                titulo: 'Inicio',
                texto:
                    'Centro de control: KPIs de tu actividad, "Necesita tu '
                    'atención" (presupuestos esperando respuesta, trabajos '
                    'sin empezar...), las invitaciones nuevas que te han '
                    'llegado y la actividad reciente.',
              ),
              _Subseccion(
                titulo: 'Trabajos',
                texto:
                    'Todos tus trabajos, en tres vistas: Lista (con una '
                    'sección aparte para los privados), Tablero (columnas '
                    'por fase, solo para los compartidos con un cliente de '
                    'REPARA Hogar) y Por cliente (agrupados por vivienda). '
                    'El filtro "Activos"/"Todos" oculta o muestra lo ya '
                    'terminado.',
              ),
              _Subseccion(
                titulo: 'Clientes',
                texto:
                    'Una fila por cliente, combinando los derivados de '
                    'trabajos ya aceptados en REPARA Hogar con los privados '
                    'que creas tú mismo con el botón "+".',
              ),
              _Subseccion(
                titulo: 'Agenda',
                texto:
                    'Tu planificación personal -- visitas, citas, cualquier '
                    'fecha importante. Puedes vincular una cita a un '
                    'trabajo y, si la compartes con el cliente, la verá '
                    'también en su REPARA Hogar.',
              ),
              _Subseccion(
                titulo: 'Económico',
                texto:
                    'Cuánto has acordado cobrar, cuánto has cobrado de '
                    'verdad y cuánto te queda pendiente, con desglose por '
                    'período y por estado de presupuesto. No sustituye a un '
                    'programa de facturación -- es solo tu visión de '
                    'conjunto.',
              ),
            ],
          ),

          const _Seccion(
            icon: Icons.people_outline,
            titulo: 'Clientes compartidos y clientes privados',
            parrafos: [
              'Un cliente "compartido" nace cuando aceptas una invitación '
                  'real de REPARA Hogar -- es la vivienda de esa persona, y '
                  'aparece con su nombre. Por privacidad, nunca ves su '
                  'teléfono ni su email desde la ficha: ese contacto sigue '
                  'siendo el que ya tenías por fuera (WhatsApp, llamada...).',
              'Un cliente "privado" lo creas tú con el botón "+" de la '
                  'pestaña Clientes, para alguien que todavía no tiene '
                  'REPARA Hogar. Aquí sí guardas sus datos de contacto, '
                  'porque los has escrito tú mismo. Se distingue con la '
                  'insignia "PRIVADO".',
            ],
            nota:
                '¿Se puede pasar un cliente privado a compartido? Sí -- '
                'desde un trabajo privado, "Vincular con REPARA Hogar" '
                'genera un código o una invitación directa (por email o '
                'teléfono) para que tu cliente se dé de alta y lo vea todo '
                'también desde su cuenta.',
          ),

          const _Seccion(
            icon: Icons.request_quote_outlined,
            titulo: 'Presupuestos, cambios de alcance y pagos',
            parrafos: [
              'En un trabajo compartido, el flujo normal es: envías un '
                  'presupuesto, el cliente lo acepta o lo rechaza desde su '
                  'REPARA Hogar, y si durante la obra hace falta algo más '
                  'que no estaba previsto, le propones un cambio de alcance '
                  'que también tiene que aprobar.',
              'Lo acordado para cobrar es el presupuesto aceptado más los '
                  'cambios de alcance aprobados -- nunca se mezcla con lo ya '
                  'cobrado. La pestaña Económico y el Tablero de Trabajos '
                  'muestran ese reparto con cuidado: "pendiente de cobro" no '
                  'es lo mismo que "pendiente de confirmación" por parte del '
                  'cliente.',
            ],
          ),

          const _Seccion(
            icon: Icons.event_outlined,
            titulo: 'Agenda y recordatorios',
            parrafos: [
              'Al crear una cita puedes marcarla "Compartir con el cliente": '
                  'la verá en su REPARA Hogar y, poco antes de la hora '
                  'programada, los dos recibís un aviso -- siempre queda '
                  'guardado en tu lista de notificaciones, y además te '
                  'llega como notificación push si tienes el dispositivo '
                  'configurado para ello.',
            ],
          ),

          const _Seccion(
            icon: Icons.shield_outlined,
            titulo: 'Seguridad y privacidad',
            parrafos: [],
            children: [
              _Punto(
                texto:
                    'Puedes proteger el acceso a datos sensibles con Face ID o huella, desde Ajustes.',
              ),
              _Punto(
                texto:
                    'Nunca ves el teléfono ni el email de un cliente derivado de REPARA Hogar -- solo su nombre y el historial del trabajo.',
              ),
              _Punto(
                texto:
                    '"Cercanos" nunca muestra tu ubicación exacta a los propietarios -- solo una distancia aproximada, y solo si lo activas tú.',
              ),
              _Punto(
                texto:
                    'Puedes eliminar tu cuenta en cualquier momento desde Ajustes → Tu cuenta; se te explica qué se borra antes de confirmar.',
              ),
            ],
          ),

          const SizedBox(height: ReparaSpace.s4),
          Text(
            'Preguntas frecuentes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: ReparaSpace.s2),
          const _Faq(
            pregunta:
                '¿Qué diferencia hay entre un cliente privado y uno compartido?',
            respuesta:
                'El privado lo creas tú a mano para alguien sin REPARA '
                'Hogar, y guardas sus datos de contacto. El compartido nace '
                'de una invitación real ya aceptada, y por privacidad no '
                'muestra teléfono ni email -- solo el nombre y el historial '
                'del trabajo.',
          ),
          const _Faq(
            pregunta: '¿Por qué no veo un trabajo privado en el Tablero?',
            respuesta:
                'El Tablero agrupa por fases pensadas para el flujo con '
                'presupuesto y pagos de REPARA Hogar (sin presupuestar, '
                'enviado, en curso, pendiente de cobro...), que no aplican '
                'a un trabajo privado. Lo encuentras en la vista Lista, en '
                'su propia sección "Privados".',
          ),
          const _Faq(
            pregunta:
                '¿Cómo empiezo a trabajar con un cliente que ya tiene REPARA Hogar?',
            respuesta:
                'Esperas a que te invite a uno de sus trabajos desde su '
                'app, o si ya llevas ese trabajo como privado, usas '
                '"Vincular con REPARA Hogar" desde su ficha para '
                'invitarlo tú.',
          ),
          const _Faq(
            pregunta:
                '¿Qué pasa si acabo de instalar solo REPARA Pro, sin haber usado REPARA Hogar antes?',
            respuesta:
                'Al entrar por primera vez se te pide activar tu perfil '
                'profesional -- un paso único. En cuanto lo activas, pasas '
                'directamente a la app.',
          ),
          const _Faq(
            pregunta: '¿Un cambio de alcance aprobado cuenta como un ingreso?',
            respuesta:
                'No. Se suma a lo acordado para cobrar, pero solo pasa a '
                '"cobrado" cuando se registra el pago correspondiente -- '
                'nunca se cuenta dos veces.',
          ),
          const _Faq(
            pregunta: '¿Puedo cambiar el tema de la app (claro/oscuro)?',
            respuesta:
                'Sí, desde Ajustes → Apariencia: claro, oscuro, o igual que '
                'el sistema de tu móvil.',
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.icon,
    required this.titulo,
    required this.parrafos,
    this.children = const [],
    this.nota,
  });

  final IconData icon;
  final String titulo;
  final List<String> parrafos;
  final List<Widget> children;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ReparaSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.colors.brand, size: 20),
              const SizedBox(width: ReparaSpace.s2),
              Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: ReparaSpace.s3),
          for (final p in parrafos) ...[
            Text(p, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: ReparaSpace.s3),
          ],
          ...children,
          if (nota != null) ...[
            const SizedBox(height: ReparaSpace.s2),
            Container(
              padding: const EdgeInsets.all(ReparaSpace.s4),
              decoration: BoxDecoration(
                color: context.colors.surfaceSunken,
                borderRadius: BorderRadius.circular(ReparaRadius.md),
              ),
              child: Text(
                nota!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.colors.inkMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Subseccion extends StatelessWidget {
  const _Subseccion({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ReparaSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            texto,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ReparaSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 5, color: context.colors.inkMuted),
          const SizedBox(width: ReparaSpace.s2),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.pregunta, required this.respuesta});

  final String pregunta;
  final String respuesta;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: ReparaSpace.s2),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(pregunta, style: Theme.of(context).textTheme.titleSmall),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(respuesta, style: TextStyle(color: context.colors.inkMuted)),
          ],
        ),
      ),
    );
  }
}
