import 'package:flutter/material.dart';

/// A [TextEditingController] that renders markdown syntax visually in the
/// input field. Markers (**  _  ~~  <u></u>  `) are made fully transparent
/// so only the styled content is visible — no asterisks or symbols shown.
class MarkdownTextEditingController extends TextEditingController {
  MarkdownTextEditingController({super.text});

  static final _pattern = RegExp(
    r'\*\*\*(.+?)\*\*\*'      // bold+italic  group 1
    r'|\*\*(.+?)\*\*'         // bold         group 2
    r'|__(.+?)__'             // bold alt     group 3
    r'|~~(.+?)~~'             // strike       group 4
    r'|<u>(.+?)<\/u>'        // underline    group 5
    r'|<i>(.+?)<\/i>'        // italic (button only) group 6
    r'|`([^`]+)`',            // code         group 7
    dotAll: true,
  );

  String? _lastText;
  TextStyle? _lastStyle;
  TextSpan? _cachedSpan;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    if (text.isEmpty) return TextSpan(style: style, text: '');

    if (_lastText == text && _lastStyle == style && _cachedSpan != null) {
      return _cachedSpan!;
    }

    // Transparent style — characters take up space (so cursor math is correct)
    // but are invisible.
    final invisible = (style ?? const TextStyle()).copyWith(
      color: Colors.transparent,
      fontSize: style?.fontSize ?? 14,
    );

    final spans = <InlineSpan>[];
    int pos = 0;

    for (final match in _pattern.allMatches(text)) {
      if (match.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, match.start), style: style));
      }

      TextStyle contentStyle;
      String content;
      String openMarker;
      String closeMarker;

      if (match.group(1) != null) {
        content = match.group(1)!;
        openMarker = '***'; closeMarker = '***';
        contentStyle = (style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        );
      } else if (match.group(2) != null) {
        content = match.group(2)!;
        openMarker = '**'; closeMarker = '**';
        contentStyle = (style ?? const TextStyle()).copyWith(fontWeight: FontWeight.bold);
      } else if (match.group(3) != null) {
        content = match.group(3)!;
        openMarker = '__'; closeMarker = '__';
        contentStyle = (style ?? const TextStyle()).copyWith(fontWeight: FontWeight.bold);
      } else if (match.group(4) != null) {
        content = match.group(4)!;
        openMarker = '~~'; closeMarker = '~~';
        contentStyle = (style ?? const TextStyle()).copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: style?.color,
        );
      } else if (match.group(5) != null) {
        content = match.group(5)!;
        openMarker = '<u>'; closeMarker = '</u>';
        contentStyle = (style ?? const TextStyle()).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: style?.color,
        );
      } else if (match.group(6) != null) {
        content = match.group(6)!;
        openMarker = '<i>'; closeMarker = '</i>';
        contentStyle = (style ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic);
      } else {
        content = match.group(7)!;
        openMarker = '`'; closeMarker = '`';
        contentStyle = (style ?? const TextStyle()).copyWith(
          fontFamily: 'monospace',
          fontSize: (style?.fontSize ?? 14) * 0.92,
          backgroundColor: const Color(0xFFF1F5F9),
          color: const Color(0xFF0F172A),
        );
      }

      // Markers are transparent (invisible) — content is styled
      spans.add(TextSpan(text: openMarker, style: invisible));
      spans.add(TextSpan(text: content, style: contentStyle));
      spans.add(TextSpan(text: closeMarker, style: invisible));

      pos = match.end;
    }

    if (pos < text.length) {
      // Hide any orphan/incomplete markers in the remaining plain text
      final remaining = text.substring(pos);
      final orphanSpans = _hideOrphanMarkers(remaining, style, invisible);
      spans.addAll(orphanSpans);
    }

    _lastText = text;
    _lastStyle = style;
    _cachedSpan = TextSpan(style: style, children: spans);
    return _cachedSpan!;
  }

  static final _orphanPattern = RegExp(
    r'\*\*\*|\*\*|__|\~\~|\<u\>|\<\/u\>|\<i\>|\<\/i\>|`'
  );

  /// Renders any standalone marker tokens (unmatched opening markers) as
  /// transparent so they don't show as raw symbols while the user is typing.
  List<InlineSpan> _hideOrphanMarkers(
      String text, TextStyle? style, TextStyle invisible) {
    final spans = <InlineSpan>[];
    int pos = 0;
    
    for (final match in _orphanPattern.allMatches(text)) {
      if (match.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, match.start), style: style));
      }
      spans.add(TextSpan(text: match.group(0), style: invisible));
      pos = match.end;
    }
    
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos), style: style));
    }

    return spans;
  }
}
