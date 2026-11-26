// lib/sugerencias_recientes.dart
//
// Generaliza el autocompletado de texto libre que ya existía solo para el
// campo "Profesional" de nuevo_elemento_screen.dart (Hogar, RawAutocomplete
// sobre Contactos) a cualquier lista de valores de texto ya introducidos por
// el usuario -- marca, modelo, proveedor de un documento... (CEO, noviembre
// 2026: "reutilizar información que el usuario ya ha introducido
// anteriormente").
//
// Quien llama decide de dónde vienen los valores y en qué orden (normalmente
// recorriendo una lista que el propio servicio ya devuelve ordenada por
// fecha de creación descendente -- ver ElementoService.streamElementos /
// DocumentoService.streamTodos, ninguno de los dos necesita una consulta ni
// un campo nuevos para esto). Esta función solo limpia esa lista: quita
// vacíos, elimina duplicados ignorando mayúsculas/minúsculas y espacios de
// más (conservando la PRIMERA forma con la que apareció cada valor, que por
// venir ya en orden de más reciente a más antiguo es también la más
// reciente) y limita cuántas sugerencias se devuelven.
//
// LIMITACIÓN DOCUMENTADA: "más reciente" aquí significa "del elemento/
// documento creado más recientemente que use ese valor", no "la última vez
// que alguien lo escribió" -- no existe en el modelo de datos un timestamp
// por campo (p.ej. cuándo se tecleó "marca" por última vez), así que no hay
// forma más fiable de aproximar recencia sin añadir un campo nuevo. Para el
// uso real (sugerir qué escribir) la diferencia es irrelevante.
List<String> valoresRecientesSinDuplicados(
  Iterable<String?> valores, {
  int limite = 8,
}) {
  final vistos = <String>{};
  final resultado = <String>[];
  for (final valor in valores) {
    final limpio = valor?.trim();
    if (limpio == null || limpio.isEmpty) continue;
    if (vistos.add(limpio.toLowerCase())) {
      resultado.add(limpio);
      if (resultado.length >= limite) break;
    }
  }
  return resultado;
}

/// Filtra [sugerencias] por coincidencia de subcadena con [texto], ignorando
/// mayúsculas/minúsculas y espacios de más en ambos lados -- mismo criterio
/// de comparación que [valoresRecientesSinDuplicados] usa para deduplicar,
/// para que "ya lo tengo en la lista" y "esto coincide con lo que escribo"
/// signifiquen siempre lo mismo.
Iterable<String> filtrarSugerencias(List<String> sugerencias, String texto) {
  final buscado = texto.trim().toLowerCase();
  if (buscado.isEmpty) return sugerencias;
  return sugerencias.where((s) => s.toLowerCase().contains(buscado));
}
