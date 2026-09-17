import 'dart:math' as math;

import '../../domain/entities/inventario_item.dart';
import '../../domain/entities/search_match.dart';
import '../../domain/entities/searchable_item.dart';
import '../../domain/repositories/search_repository.dart';
import '../../infrastructure/algorithms/levenshtein.dart';
import '../../infrastructure/algorithms/scattered_match.dart';
import '../../infrastructure/utils/text_normalizer.dart';

/// Caso de uso central: Motor de búsqueda reactivo con Scoring, Fuzzy Matching,
/// Scattered Matching, limpieza de Stop Words y cálculo de resaltado visual.
class SearchEngine<T extends SearchableItem> {
  /// Conjunto de palabras vacías (Stop Words) en español que se descartan en el query.
  static const Set<String> defaultStopWords = {
    'de',
    'la',
    'el',
    'los',
    'las',
    'en',
    'y',
    'del',
    'al',
    'por',
    'con',
    'un',
    'una',
    'para',
  };

  final Set<String> _stopWords;

  /// Crea una instancia del motor de búsqueda configurable con stop words personalizadas.
  SearchEngine({Set<String>? stopWords})
      : _stopWords = stopWords ?? defaultStopWords;

  /// Ejecuta la búsqueda sobre [items] con el [query] ingresado.
  ///
  /// Opcionalmente recibe [synonyms] (o consulta el [repository]) para concatenar
  /// sinónimos y códigos ocultos antes de evaluar.
  /// Retorna la lista ordenada de mayor a menor puntuación (excluyendo items con score 0).
  List<T> search({
    required List<T> items,
    required String query,
    Map<String, String>? synonyms,
  }) {
    final rawTokens = TextNormalizer.tokenize(query);
    if (rawTokens.isEmpty) {
      return const [];
    }

    // Filtrar Stop Words
    var cleanTokens = rawTokens
        .where((token) => !_stopWords.contains(token))
        .toList();

    // Si todas las palabras eran stop words (ej. 'de'), usar los tokens originales
    if (cleanTokens.isEmpty) {
      cleanTokens = rawTokens;
    }

    final scoredItems = <T>[];

    for (final item in items) {
      // 1. Obtener sinónimos ocultos asociados a la entidad
      final itemSynonym = _resolveSynonym(item, synonyms);

      // 2. Concatenar texto oficial + código + sinónimos para evaluación
      final officialNameNorm = TextNormalizer.normalize(item.name);
      final synonymNorm = TextNormalizer.normalize(itemSynonym);
      final fullSearchText = '$officialNameNorm $synonymNorm'.trim();

      // Palabras normalizadas del texto objetivo
      final targetWords = TextNormalizer.tokenize(fullSearchText);
      final officialWords = TextNormalizer.tokenize(officialNameNorm);

      var totalScore = 0;
      final matchedTokens = <String>[];
      final highlightSpans = <HighlightSpan>[];

      for (final qToken in cleanTokens) {
        final tokenEval = _evaluateToken(
          qToken: qToken,
          targetWords: targetWords,
          fullSearchText: fullSearchText,
        );

        if (tokenEval.score > 0) {
          totalScore += tokenEval.score;
          matchedTokens.add(qToken);

          // Extraer rangos de resaltado para el nombre oficial visible
          _extractHighlightSpans(
            qToken: qToken,
            officialName: item.name,
            officialNameNorm: officialNameNorm,
            officialWords: officialWords,
            spans: highlightSpans,
          );
        }
      }

      if (totalScore > 0) {
        final mergedSpans = _mergeHighlightSpans(highlightSpans);
        final searchResult = SearchResult(
          score: totalScore,
          highlightSpans: mergedSpans,
          matchedTokens: matchedTokens,
        );

        final updatedItem = item.copyWithSearchResult(searchResult) as T;
        scoredItems.add(updatedItem);
      }
    }

    // Ordenar de mayor a menor puntuación
    scoredItems.sort((a, b) => b.score.compareTo(a.score));

    return scoredItems;
  }

  /// Ejecuta la búsqueda consumiendo directamente un [SearchRepository].
  List<T> searchFromRepository({
    required SearchRepository<T> repository,
    required String query,
  }) {
    return search(
      items: repository.getItems(),
      query: query,
      synonyms: repository.getSynonyms(),
    );
  }

  /// Resuelve los sinónimos y atributos secundarios disponibles para un item.
  String _resolveSynonym(T item, Map<String, String>? synonyms) {
    final buffer = StringBuffer();

    if (item is InventarioItem) {
      buffer.write('${item.id} ${item.marca} ${item.modelo} ${item.talla} ');
    }

    if (synonyms != null) {
      final syn = synonyms[item.id];
      if (syn != null && syn.isNotEmpty) {
        buffer.write('$syn ');
      }
    }

    return buffer.toString().trim();
  }

  /// Evalúa un token del query contra las palabras y texto objetivo de la entidad.
  _TokenEvaluation _evaluateToken({
    required String qToken,
    required List<String> targetWords,
    required String fullSearchText,
  }) {
    var bestScore = 0;
    MatchType bestMatchType = MatchType.contains;

    // 1. Perfect Match / Starts With contra cualquiera de las palabras objetivo (100 pts)
    for (final tWord in targetWords) {
      if (tWord == qToken || tWord.startsWith(qToken)) {
        return const _TokenEvaluation(
          score: 100,
          matchType: MatchType.perfectOrPrefix,
        );
      }
    }

    // Si el texto completo empieza con el token
    if (fullSearchText.startsWith(qToken)) {
      return const _TokenEvaluation(
        score: 100,
        matchType: MatchType.perfectOrPrefix,
      );
    }

    // 2. Contains (50 pts)
    for (final tWord in targetWords) {
      if (tWord.contains(qToken)) {
        bestScore = math.max(bestScore, 50);
        bestMatchType = MatchType.contains;
        break;
      }
    }
    if (bestScore == 0 && fullSearchText.contains(qToken)) {
      bestScore = math.max(bestScore, 50);
      bestMatchType = MatchType.contains;
    }

    // 3. Fuzzy Match (Levenshtein distance <= 1 o 2 dependiendo del largo)
    // Puntaje basado en la distancia: 80 - (distancia * 15)
    final maxAllowedDistance = (qToken.length > 4) ? 2 : 1;
    if (qToken.length >= 3) {
      for (final tWord in targetWords) {
        // Solo comparar si las longitudes son razonablemente similares
        if ((tWord.length - qToken.length).abs() <= maxAllowedDistance) {
          final dist = Levenshtein.distance(qToken, tWord);
          if (dist > 0 && dist <= maxAllowedDistance) {
            final fuzzyScore = 80 - (dist * 15);
            if (fuzzyScore > bestScore) {
              bestScore = fuzzyScore;
              bestMatchType = MatchType.fuzzy;
            }
          }
        }
      }
    }

    // 4. Scattered Match (30 pts): solo si la palabra clave tiene >= 3 caracteres
    if (qToken.length >= 3) {
      for (final tWord in targetWords) {
        if (ScatteredMatch.isMatch(qToken, tWord)) {
          if (30 > bestScore) {
            bestScore = 30;
            bestMatchType = MatchType.scattered;
          }
          break;
        }
      }
      if (bestScore < 30 && ScatteredMatch.isMatch(qToken, fullSearchText)) {
        bestScore = 30;
        bestMatchType = MatchType.scattered;
      }
    }

    return _TokenEvaluation(score: bestScore, matchType: bestMatchType);
  }

  /// Extrae rangos de caracteres dentro del nombre oficial para resaltado.
  void _extractHighlightSpans({
    required String qToken,
    required String officialName,
    required String officialNameNorm,
    required List<String> officialWords,
    required List<HighlightSpan> spans,
  }) {
    if (qToken.isEmpty || officialName.isEmpty) return;

    // 1. Buscar coincidencias de subcadena exactas/normalizadas en officialNameNorm
    var startPos = 0;
    while (true) {
      final matchIndex = officialNameNorm.indexOf(qToken, startPos);
      if (matchIndex == -1) break;

      spans.add(
        HighlightSpan(
          start: matchIndex,
          end: matchIndex + qToken.length,
          matchType: MatchType.contains,
        ),
      );
      startPos = matchIndex + qToken.length;
    }

    // 2. Si no hubo coincidencia directa por substring, verificar coincidencias esparcidas
    if (spans.isEmpty && qToken.length >= 3) {
      final scatteredIndices =
          ScatteredMatch.findMatchIndices(qToken, officialNameNorm);
      if (scatteredIndices != null && scatteredIndices.isNotEmpty) {
        for (final idx in scatteredIndices) {
          spans.add(
            HighlightSpan(
              start: idx,
              end: idx + 1,
              matchType: MatchType.scattered,
            ),
          );
        }
      }
    }
  }

  /// Fusiona y ordena rangos de resaltado superpuestos o contiguos.
  List<HighlightSpan> _mergeHighlightSpans(List<HighlightSpan> spans) {
    if (spans.isEmpty) return const [];

    final sorted = List<HighlightSpan>.from(spans)
      ..sort((a, b) => a.start.compareTo(b.start));

    final merged = <HighlightSpan>[];
    var current = sorted.first;

    for (var i = 1; i < sorted.length; i++) {
      final next = sorted[i];
      if (next.start <= current.end) {
        // Se superponen o son contiguos
        final newEnd = math.max(current.end, next.end);
        current = HighlightSpan(
          start: current.start,
          end: newEnd,
          matchType: current.matchType,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    return merged;
  }
}

class _TokenEvaluation {
  final int score;
  final MatchType matchType;

  const _TokenEvaluation({required this.score, required this.matchType});
}
