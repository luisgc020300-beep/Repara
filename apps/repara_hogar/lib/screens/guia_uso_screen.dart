// apps/repara_hogar/lib/screens/guia_uso_screen.dart
//
// Guía de uso de REPARA Hogar (CEO, noviembre 2026: "quiero que sea un
// documento o texto dentro de la app, no un enlace externo"). Introducción,
// tour de las 3 pestañas, elementos/eventos, profesionales de Repara Pro
// frente a Contactos, documentos/garantías/mantenimiento, compartir la
// vivienda y preguntas frecuentes -- texto nativo, sin salir de la app.
import 'package:flutter/material.dart';

import 'package:repara_core/design_tokens.dart';

class GuiaUsoScreen extends StatelessWidget {
  const GuiaUsoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guía de uso')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Todo lo que hace REPARA Hogar',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: ReparaSpace.s2),
          Text(
            'La memoria digital de tu vivienda: qué tiene tu casa, qué le ha '
            'pasado y con quién lo arreglaste. Esta guía explica cada parte '
            'de la app y responde a las dudas más habituales.',
            style: TextStyle(color: context.colors.inkMuted),
          ),
          const SizedBox(height: ReparaSpace.s6),

          const _Seccion(
            icon: Icons.info_outline,
            titulo: 'Qué es REPARA',
            parrafos: [
              'REPARA Hogar guarda, en un solo sitio, todo lo que tiene tu '
                  'casa -- calderas, electrodomésticos, muebles, instalaciones -- '
                  'y el historial completo de cada uno: averías, reparaciones, '
                  'mantenimientos, compras, garantías y documentos.',
              'Tiene una app hermana, REPARA Pro, pensada para fontaneros, '
                  'electricistas y demás profesionales. Cuando invitas a un '
                  'profesional con cuenta en Repara Pro a un trabajo, puede '
                  'mandarte un presupuesto formal, llevas el seguimiento de los '
                  'pagos, y él confirma cuándo termina. Nada de esto es '
                  'obligatorio: REPARA Hogar funciona entera sin que ningún '
                  'profesional use la app.',
            ],
          ),

          const _Seccion(
            icon: Icons.dashboard_outlined,
            titulo: 'Las tres pestañas',
            parrafos: [],
            children: [
              _Subseccion(
                titulo: 'Inicio',
                texto:
                    'Resumen de lo que necesita atención (garantías a punto de '
                    'vencer, revisiones atrasadas, trabajos en curso) y el '
                    'listado completo de elementos de la casa. Desde aquí '
                    'añades un elemento nuevo, a mano o escaneando una factura '
                    'para que la IA rellene los datos.',
              ),
              _Subseccion(
                titulo: 'Casa',
                texto:
                    'La misma lista de elementos, organizada por habitaciones '
                    '-- salón, cocina, baño... Útil para encontrar algo por '
                    'dónde está, en vez de buscarlo en una lista plana.',
              ),
              _Subseccion(
                titulo: 'Contactos',
                texto:
                    'Tu libreta de profesionales de confianza: llama o invita '
                    'a un trabajo en un toque. "Cercanos" busca profesionales '
                    'que todavía no conoces, por proximidad, para cuando '
                    'ninguno de tus contactos habituales está disponible.',
              ),
            ],
          ),

          const _Seccion(
            icon: Icons.inventory_2_outlined,
            titulo: 'Elementos y eventos',
            parrafos: [
              'Un elemento es cualquier cosa de tu casa que quieras llevar '
                  'controlada: una caldera, una lavadora, un mueble, una '
                  'instalación eléctrica. Tiene su propia ficha con marca, '
                  'modelo, fecha de instalación, coste, garantía, fotos y '
                  'documentos.',
              'Un evento es cualquier cosa que le pase a un elemento '
                  'concreto: una avería, una reparación, una revisión de '
                  'mantenimiento, una compra. Queda anotado para siempre en el '
                  'historial de ese elemento, con su fecha, tipo y lo que '
                  'costó.',
            ],
            nota:
                '¿Qué fecha pongo en un evento? La fecha en la que ocurrió o '
                'se hizo el trabajo -- no el día en que lo registras en la '
                'app ni la fecha de garantía (eso es un dato aparte, dentro '
                'de la ficha del elemento).',
          ),

          _Seccion(
            icon: Icons.handyman_outlined,
            titulo: 'Trabajar con profesionales',
            parrafos: const [
              'Si activas el modo "con profesional de Repara Pro" al crear '
                  'un evento, la invitación se hace DESPUÉS de guardarlo, '
                  'desde su propia ficha -- no hace falta elegir profesional '
                  'en el mismo formulario de creación.',
              'Si ninguno de tus contactos habituales está disponible, '
                  '"Cercanos" busca profesionales con cuenta en Repara Pro que '
                  'se han hecho visibles por proximidad. Nunca ves su '
                  'ubicación exacta, solo una distancia aproximada.',
              'Cuando un trabajo con un profesional de Repara Pro termina, '
                  'puedes valorarlo (de 1 a 5 estrellas, con un comentario '
                  'opcional). Su perfil público muestra la valoración media y '
                  'cuántos trabajos ha terminado, desglosados por tipo.',
            ],
            children: [
              Container(
                margin: const EdgeInsets.only(top: ReparaSpace.s2),
                padding: const EdgeInsets.all(ReparaSpace.s4),
                decoration: BoxDecoration(
                  color: context.colors.brandTint,
                  borderRadius: BorderRadius.circular(ReparaRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anotar un profesional (Contactos)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Guardas su nombre y teléfono para tenerlo a mano y '
                      'dejar constancia de quién lo hizo. No activa '
                      'presupuesto ni pagos, y no hace falta que use REPARA.',
                      style: TextStyle(color: context.colors.inkMuted),
                    ),
                    const SizedBox(height: ReparaSpace.s3),
                    Text(
                      'Invitar a un profesional de Repara Pro',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'El profesional necesita (o crea) una cuenta en Repara '
                      'Pro, puede enviarte un presupuesto formal, llevas el '
                      'pago, y confirmas cuando él dice que ha terminado.',
                      style: TextStyle(color: context.colors.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const _Seccion(
            icon: Icons.description_outlined,
            titulo: 'Documentos, garantías y mantenimiento',
            parrafos: [
              'Puedes escanear facturas, garantías y manuales: la IA extrae '
                  'los datos automáticamente (importe, fecha, proveedor...) y '
                  'los asocia al elemento o evento correcto, sin tener que '
                  'teclearlos a mano.',
              'REPARA avisa cuando una garantía está a punto de vencer o '
                  'toca una revisión de mantenimiento periódica, directamente '
                  'desde Inicio.',
            ],
          ),

          const _Seccion(
            icon: Icons.house_outlined,
            titulo: 'Tu vivienda y compartirla',
            parrafos: [
              'Desde Ajustes → Tu vivienda puedes compartir la gestión de tu '
                  'casa con otra persona (tu pareja, un familiar): el '
                  '"código para invitar a alguien" se lo pasas tú, y '
                  'cualquier miembro puede ver y editar lo mismo.',
              'Si tienes más de una propiedad, puedes darte de alta en '
                  'varias y cambiar entre ellas desde esa misma pantalla.',
            ],
            nota:
                '¿Y "¿Tienes un código de invitación?"? Es distinto: es para '
                'cuando un CLIENTE te ha invitado a ti, como profesional, a '
                'un trabajo suyo -- te ha pasado un código porque todavía no '
                'tenías cuenta en Repara Pro. Lo introduces ahí y luego lo '
                'aceptas desde Inicio en REPARA Pro. No sirve para unirte a '
                'la vivienda de otra persona.',
          ),

          const _Seccion(
            icon: Icons.shield_outlined,
            titulo: 'Seguridad y privacidad',
            parrafos: [],
            children: [
              _Punto(texto: 'Puedes proteger el acceso a tus documentos sensibles (facturas, garantías) con Face ID o huella, desde Ajustes.'),
              _Punto(texto: 'Cercanos nunca muestra tu ubicación exacta ni la de ningún profesional -- solo una distancia aproximada.'),
              _Punto(texto: 'Las invitaciones y valoraciones son privadas entre las dos partes implicadas: nadie más puede verlas.'),
              _Punto(texto: 'Puedes eliminar tu cuenta en cualquier momento desde Ajustes → Tu cuenta; se te explica qué se borra antes de confirmar.'),
            ],
          ),

          const SizedBox(height: ReparaSpace.s4),
          Text(
            'Preguntas frecuentes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: ReparaSpace.s2),
          const _Faq(
            pregunta: '¿Necesito que mi fontanero o electricista use REPARA?',
            respuesta:
                'No. Puedes anotar cualquier trabajo y a quién se lo '
                'encargaste sin que esa persona tenga ninguna cuenta. '
                'Invitarle formalmente por Repara Pro es opcional.',
          ),
          const _Faq(
            pregunta: '¿Qué diferencia hay entre un elemento y un evento?',
            respuesta:
                'El elemento es la cosa (la caldera). El evento es algo que '
                'le pasa a esa cosa en un momento dado (la revisión anual de '
                'la caldera).',
          ),
          const _Faq(
            pregunta: '¿Puedo cambiar el tema de la app (claro/oscuro)?',
            respuesta:
                'Sí, desde Ajustes → Apariencia: claro, oscuro, o igual que '
                'el sistema de tu móvil.',
          ),
          const _Faq(
            pregunta: '¿Puedo tener más de una vivienda?',
            respuesta:
                'Sí, desde Ajustes → Tu vivienda puedes darte de alta en '
                'varias y cambiar cuál tienes activa.',
          ),
          const _Faq(
            pregunta: 'Si elimino mi cuenta, ¿qué pasa con mi vivienda?',
            respuesta:
                'Si eres el único miembro, se borra también la vivienda '
                'entera con su historial, documentos y fotos. Si la '
                'compartes con alguien más, solo se elimina tu vinculación a '
                'ella.',
          ),
          const _Faq(
            pregunta:
                '¿Por qué no puedo elegir al profesional en el mismo '
                'formulario al crear el evento?',
            respuesta:
                'Porque invitar a alguien exige que el evento ya exista. Al '
                'guardarlo con "profesional de Repara Pro" activado se abre '
                'directamente su ficha, donde está el botón de invitar.',
          ),
          const _Faq(
            pregunta:
                '¿Qué significa que una garantía o revisión aparezca marcada '
                'en Inicio?',
            respuesta:
                'Que está a punto de vencer (garantía) o atrasada (revisión '
                'de mantenimiento) -- un aviso para que no se te pase, nunca '
                'un bloqueo.',
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
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
          title: Text(
            pregunta,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              respuesta,
              style: TextStyle(color: context.colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
