import 'package:ai_sync/ai_sync.dart';
import 'package:test/test.dart';

void main() {
  group('Frontmatter.parse', () {
    test('parses simple key/value frontmatter', () {
      const content = '''
---
description: "A simple rule"
---

# Title

Body text.
''';
      final fm = Frontmatter.parse(content.trim());
      expect(fm.getString('description'), equals('A simple rule'));
      expect(fm.body, equals('# Title\n\nBody text.'));
      expect(fm.hasFrontmatter, isTrue);
    });

    test('parses paths as YAML sequence', () {
      const content = '''
---
paths:
  - "**/src/**/*.dart"
  - "**/lib/**/*.dart"
---
Body.
''';
      final fm = Frontmatter.parse(content.trim());
      expect(fm.getStringList('paths'), equals(['**/src/**/*.dart', '**/lib/**/*.dart']));
    });

    test('returns empty list for paths: []', () {
      const content = '---\npaths: []\n---\nBody.';
      final fm = Frontmatter.parse(content);
      expect(fm.getStringList('paths'), isEmpty);
    });

    test('returns empty list for missing paths key', () {
      const content = '---\ndescription: "x"\n---\nBody.';
      final fm = Frontmatter.parse(content);
      expect(fm.getStringList('paths'), isEmpty);
    });

    test('handles no frontmatter', () {
      const content = '# Just a title\n\nBody.';
      final fm = Frontmatter.parse(content);
      expect(fm.hasFrontmatter, isFalse);
      expect(fm.rawFields, isEmpty);
      expect(fm.body, equals('# Just a title\n\nBody.'));
    });

    test('handles empty frontmatter (--- ---)', () {
      const content = '---\n---\nBody.';
      final fm = Frontmatter.parse(content);
      expect(fm.rawFields, isEmpty);
      expect(fm.body, equals('Body.'));
    });

    test('preserves rawFrontmatterText exactly', () {
      const raw = '''tools: [agent, vscode/askQuestions]
agents:
  [
    "Sub Agent One",
    "Sub Agent Two",
  ]
user-invocable: true''';
      final content = '---\n$raw\n---\nBody.';
      final fm = Frontmatter.parse(content);
      expect(fm.rawFrontmatterText, equals(raw));
    });

    test('handles multi-line string values', () {
      const content = '---\ndescription: "A long description that keeps going"\n---\nBody.';
      final fm = Frontmatter.parse(content);
      expect(fm.getString('description'), equals('A long description that keeps going'));
    });

    test('returns null for missing key', () {
      const content = '---\nfoo: bar\n---\nBody.';
      final fm = Frontmatter.parse(content);
      expect(fm.getString('missing'), isNull);
    });
  });
}
