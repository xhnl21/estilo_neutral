import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/colors.dart';
import '../../domain/entities/search_match.dart';

/// Widget que construye un [RichText] resaltando en negrita y con fondo tenue
/// los segmentos de texto coincidentes según los [HighlightSpan] proporcionados.
class SearchHighlightedText extends StatelessWidget {
  /// Cadena original visible que se va a mostrar y resaltar.
  final String text;

  /// Lista de rangos coincidentes para aplicar el resaltado.
  final List<HighlightSpan> highlightSpans;

  /// Estilo de texto base para los segmentos no coincidentes.
  final TextStyle? style;

  /// Estilo de texto personalizado para los segmentos coincidentes.
  final TextStyle? highlightStyle;

  /// Color de fondo tenue para los segmentos coincidentes.
  final Color? highlightBackgroundColor;

  /// Número máximo de líneas permitidas.
  final int? maxLines;

  /// Comportamiento ante desbordamiento de texto.
  final TextOverflow overflow;

  /// Crea un widget de texto con resaltado de coincidencias.
  const SearchHighlightedText({
    super.key,
    required this.text,
    this.highlightSpans = const [],
    this.style,
    this.highlightStyle,
    this.highlightBackgroundColor,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultBaseStyle = DefaultTextStyle.of(context).style.merge(
          style ??
              const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 15,
              ),
        );

    final effectiveHighlightBg = highlightBackgroundColor ??
        AppPalette.blue100.withValues(alpha: 0.7);

    final effectiveHighlightStyle = defaultBaseStyle
        .merge(
          highlightStyle ??
              const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppPalette.blue900,
              ),
        )
        .copyWith(
          backgroundColor: effectiveHighlightBg,
        );

    if (highlightSpans.isEmpty) {
      return Text(
        text,
        style: defaultBaseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    final textLength = text.length;

    // Asegurar que los spans estén ordenados y dentro del rango de texto
    final sortedSpans = highlightSpans
        .where((s) => s.start < textLength && s.end <= textLength && s.start < s.end)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final span in sortedSpans) {
      final safeStart = math.max(cursor, math.min(span.start, textLength));
      final safeEnd = math.max(safeStart, math.min(span.end, textLength));

      // Texto previo no resaltado
      if (safeStart > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, safeStart),
            style: defaultBaseStyle,
          ),
        );
      }

      // Segmento resaltado
      if (safeEnd > safeStart) {
        spans.add(
          TextSpan(
            text: text.substring(safeStart, safeEnd),
            style: effectiveHighlightStyle,
          ),
        );
      }

      cursor = safeEnd;
    }

    // Texto remanente tras el último span
    if (cursor < textLength) {
      spans.add(
        TextSpan(
          text: text.substring(cursor),
          style: defaultBaseStyle,
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
