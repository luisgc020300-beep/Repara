// lib/especialidad_profesional.dart
//
// Clasificación cerrada de oficios/especialidades (organizar las
// especialidades profesionales, noviembre 2026) -- ofrecida como opciones
// al editar el perfil (ver ajustes_pro_screen.dart), en vez de depender
// solo de texto libre.
//
// Profesional.especialidad sigue siendo un String? de siempre, nunca un
// enum cerrado en el modelo: convertirlo en un tipo cerrado rompería a
// cualquier profesional que ya tenga guardado un texto que no esté en esta
// lista. Lo que cambia es solo la FORMA de elegirlo -- un selector con
// estas opciones (más "Otro", que sigue abriendo el texto libre de
// siempre) en vez de un campo de texto directo. Cualquier valor ya
// guardado, esté o no en esta lista, se sigue mostrando tal cual en todos
// los sitios donde ya aparece (perfil_profesional_screen.dart,
// cercanos_screen.dart, ajustes_pro_screen.dart).
//
// Preparada para un futuro filtro por oficio (sección 18/Cercanos): quien
// elija de esta lista queda con un valor consistente, fácil de comparar
// más adelante -- sin implementar aquí ningún filtro ni búsqueda todavía.
const especialidadesProfesionales = <String>[
  'Fontanería',
  'Electricidad',
  'Climatización',
  'Albañilería',
  'Pintura',
  'Carpintería',
  'Cerrajería',
  'Electrodomésticos',
  'Persianas y toldos',
  'Tejados e impermeabilización',
  'Jardinería',
  'Limpieza',
  'Mudanzas',
  'Reformas integrales',
  especialidadProfesionalOtra,
];

/// Última opción del selector -- mantiene abierto el texto libre de
/// siempre para quien no encaje en ninguna de las anteriores.
const especialidadProfesionalOtra = 'Otro';
