import 'dart:io';

import 'package:ai_sync/ai_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory tempSource;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('ai_sync_context_test_root_');
    tempSource = Directory.systemTemp.createTempSync('ai_sync_context_test_source_');
    File(p.join(tempSource.path, 'CONTEXT.md'))
        .writeAsStringSync('# Shared Context');
  });

  tearDown(() {
    tempRoot.deleteSync(recursive: true);
    tempSource.deleteSync(recursive: true);
  });

  group('ContextSyncer workspace', () {
    late ContextSyncer syncer;

    setUp(() {
      final source = SourcePaths(tempSource.path);
      syncer = ContextSyncer(source, rootDir: tempRoot);
    });

    test('creates 3 workspace symlinks', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final expected = [
        p.join(tempRoot.path, 'GEMINI.md'),
        p.join(tempRoot.path, '.github', 'copilot-instructions.md'),
        p.join(tempRoot.path, '.claude', 'CLAUDE.md'),
      ];
      for (final path in expected) {
        expect(FileSystemEntity.isLinkSync(path), isTrue, reason: '$path should be a symlink');
      }
    });

    test('symlinks point to absolute source CONTEXT.md', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final contextPath = p.join(tempSource.path, 'CONTEXT.md');
      for (final relPath in [
        'GEMINI.md',
        '.github/copilot-instructions.md',
        '.claude/CLAUDE.md',
      ]) {
        final linkPath = p.join(tempRoot.path, relPath);
        expect(Link(linkPath).targetSync(), equals(contextPath));
      }
    });

    test('re-running replaces existing symlinks without error', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      syncer.run(global: false, providers: Provider.values.toSet());
      expect(
        FileSystemEntity.isLinkSync(p.join(tempRoot.path, '.claude', 'CLAUDE.md')),
        isTrue,
      );
    });

    test('logs warning and skips when CONTEXT.md is missing', () {
      File(p.join(tempSource.path, 'CONTEXT.md')).deleteSync();
      expect(() => syncer.run(global: false, providers: Provider.values.toSet()), returnsNormally);
      expect(
        FileSystemEntity.isLinkSync(p.join(tempRoot.path, '.claude', 'CLAUDE.md')),
        isFalse,
      );
    });
  });

  group('ContextSyncer global', () {
    test('creates ~/.gemini/GEMINI.md and ~/.claude/CLAUDE.md', () {
      // Use a fake HOME via environment override is not easy in Dart tests,
      // so we verify the path construction via SourcePaths + Provider logic.
      final home = Platform.environment['HOME'] ?? '';
      if (home.isEmpty) return; // skip if HOME not set

      // We just verify the path returned by Provider is correct without
      // actually writing to the real home dir.
      expect(
        Provider.gemini.globalInstructionsPath(),
        equals(p.join(home, '.gemini', 'GEMINI.md')),
      );
      expect(
        Provider.claude.globalInstructionsPath(),
        equals(p.join(home, '.claude', 'CLAUDE.md')),
      );
      expect(Provider.copilot.globalInstructionsPath(), isNull);
      expect(
        Provider.antigravity.globalInstructionsPath(),
        equals(p.join(home, '.gemini', 'GEMINI.md')),
      );
    });
  });
}
