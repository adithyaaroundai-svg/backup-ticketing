import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat Markdown and URL Parser', () {
    final tokenPattern = RegExp(
      r'https?:\/\/[^\s<]+'
      r'|\*\*\*'
      r'|\*\*'
      r'|__'
      r'|\*(?!\*)'
      r'|_(?!_)'
      r'|~~'
      r'|<u>'
      r'|<\/u>'
      r'|`[^`]+`',
      caseSensitive: false,
    );

    test('preserves Google Drive URLs with underscores intact', () {
      const url = 'https://drive.google.com/file/d/1FJUqvvG2rgoq-qdwhfhXrle5qi8u_tWe/view?usp=drive_link';
      final matches = tokenPattern.allMatches(url).toList();

      expect(matches.length, equals(1));
      expect(matches.first.group(0), equals(url));
    });

    test('matches URLs inside sentence without breaking on underscores or hyphens', () {
      const text = 'Here is the file: https://drive.google.com/file/d/1FJUqvvG2rgoq-qdwhfhXrle5qi8u_tWe/view?usp=drive_link please check';
      final matches = tokenPattern.allMatches(text).toList();

      expect(matches.length, equals(1));
      expect(matches.first.group(0), equals('https://drive.google.com/file/d/1FJUqvvG2rgoq-qdwhfhXrle5qi8u_tWe/view?usp=drive_link'));
    });

    test('still parses markdown outside of URLs', () {
      const text = 'Hello *bold* world and https://example.com/a_b_c done';
      final matches = tokenPattern.allMatches(text).toList();

      expect(matches.length, equals(3));
      expect(matches[0].group(0), equals('*'));
      expect(matches[1].group(0), equals('*'));
      expect(matches[2].group(0), equals('https://example.com/a_b_c'));
    });
  });
}

