import 'package:equatable/equatable.dart';

/// Tipo de coincidencia detectada por el motor de búsqueda.
enum MatchType {
  /// Coincidencia exacta de token o prefijo ('Starts With').
  perfectOrPrefix,

  /// Subcadena contenida ('Contains').
  contains,

  /// Coincidencia difusa con distancia Levenshtein ('Fuzzy').
  fuzzy,

  /// Coincidencia de caracteres esparcidos secuenciales ('Scattered').
  scattered,
}

/// Rango que define un segmento de texto coincidente para resaltado en la UI.
class HighlightSpan extends Equatable {
  /// Posición inicial inclusiva del segmento dentro del texto original.
  final int start;

  /// Posición final exclusiva del segmento dentro del texto original.
  final int end;

  /// Tipo de coincidencia asociada a este segmento.
  final MatchType matchType;

  /// Crea un segmento de resaltado de texto.
  const HighlightSpan({
    required this.start,
    required this.end,
    this.matchType = MatchType.contains,
  }) : assert(start <= end, 'start debe ser menor o igual a end');

  @override
  List<Object?> get props => [start, end, matchType];
}

/// Resultado y metadatos de búsqueda asociados a una entidad evaluada.
class SearchResult extends Equatable {
  /// Puntuación total ponderada calculada por el motor de búsqueda.
  final int score;

  /// Lista de rangos de caracteres dentro del nombre oficial de la entidad
  /// que deben ser resaltados visualmente en la interfaz.
  final List<HighlightSpan> highlightSpans;

  /// Palabras clave o sinónimos que originaron la coincidencia (si aplica).
  final List<String> matchedTokens;

  /// Crea un resultado de búsqueda con puntuación y rangos de resaltado.
  const SearchResult({
    required this.score,
    this.highlightSpans = const [],
    this.matchedTokens = const [],
  });

  /// Resultado vacío / sin coincidencia (score 0).
  static const empty = SearchResult(score: 0);

  @override
  List<Object?> get props => [score, highlightSpans, matchedTokens];
}
