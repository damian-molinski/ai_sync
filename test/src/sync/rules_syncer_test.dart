import 'dart:io';

import 'package:ai_sync/ai_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory tempSource;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('ai_sync_rules_test_root_');
    tempSource = Directory.systemTemp.createTempSync('ai_sync_rules_test_source_');

    // Copy fixtures into temp source rules/ subdir
    final fixturesDir = Directory(p.join('test', 'fixtures', 'rules'));
    final rulesDestDir = Directory(p.join(tempSource.path, 'rules'))..createSync();
    for (final file in fixturesDir.listSync().whereType<File>()) {
      File(
        p.join(rulesDestDir.path, p.basename(file.path)),
      ).writeAsStringSync(file.readAsStringSync());
    }
    File(p.join(tempSource.path, 'CONTEXT.md')).writeAsStringSync('# Context');
  });

  tearDown(() {
    tempRoot.deleteSync(recursive: true);
    tempSource.deleteSync(recursive: true);
  });

  group('RulesSyncer workspace', () {
    late RulesSyncer syncer;

    setUp(() {
      final source = SourcePaths(tempSource.path);
      syncer = RulesSyncer(source, rootDir: tempRoot);
    });

    test('generates Copilot always-on rule with applyTo: "**"', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(
        p.join(tempRoot.path, '.github', 'instructions', 'security-and-env.instructions.md'),
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('applyTo: "**"'));
      expect(content, contains('Never hardcode'));
    });

    test('generates Copilot path-scoped rule with applyTo glob', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(
        p.join(tempRoot.path, '.github', 'instructions', 'drift-columns.instructions.md'),
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('applyTo: "**/database/tables/*.dart, **/database/daos/*.dart"'));
    });

    test('generates Antigravity always-on rule with trigger: always_on', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(p.join(tempRoot.path, '.agents', 'rules', 'security-and-env.md'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('trigger: always_on'));
      expect(content, isNot(contains('globs:')));
    });

    test('generates Antigravity path-scoped rule with trigger: glob', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(p.join(tempRoot.path, '.agents', 'rules', 'drift-columns.md'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('trigger: glob'));
      expect(content, contains('globs: **/database/tables/*.dart'));
    });

    test('generates Claude always-on rule with no frontmatter', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(p.join(tempRoot.path, '.claude', 'rules', 'security-and-env.md'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, isNot(contains('---')));
      expect(content, contains('Never hardcode'));
    });

    test('generates Claude path-scoped rule with paths array', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(p.join(tempRoot.path, '.claude', 'rules', 'drift-columns.md'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('paths:'));
      expect(content, contains('"**/database/tables/*.dart"'));
    });

    test('does not generate Gemini rule files', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final geminiDir = Directory(p.join(tempRoot.path, '.gemini', 'rules'));
      expect(geminiDir.existsSync(), isFalse);
    });

    test('cleans output dirs before regenerating', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      syncer.run(global: false, providers: Provider.values.toSet());
      final copilotDir = Directory(p.join(tempRoot.path, '.github', 'instructions'));
      final files = copilotDir.listSync().whereType<File>().toList();
      expect(files.length, equals(2)); // only 2 source rules
    });

    test('preserves symlinks in .agents/rules/ during clean', () {
      // Place a symlink before running
      final symlinkPath = p.join(tempRoot.path, '.agents', 'rules', 'GEMINI.md');
      ensureDirectory(p.dirname(symlinkPath));
      Link(symlinkPath).createSync('/tmp/fake-target');

      syncer.run(global: false, providers: Provider.values.toSet());

      expect(FileSystemEntity.isLinkSync(symlinkPath), isTrue);
    });
  });

  group('RulesSyncer hard mode', () {
    late RulesSyncer syncer;

    setUp(() {
      final source = SourcePaths(tempSource.path);
      syncer = RulesSyncer(source, rootDir: tempRoot);
    });

    test('cleans output dirs and removes them when all rules deleted in hard mode', () {
      syncer.run(global: false, providers: {Provider.copilot, Provider.claude});

      final copilotDir = Directory(p.join(tempRoot.path, '.github', 'instructions'));
      final claudeDir = Directory(p.join(tempRoot.path, '.claude', 'rules'));
      expect(copilotDir.existsSync(), isTrue);
      expect(claudeDir.existsSync(), isTrue);

      // Delete all source rules.
      Directory(
        p.join(tempSource.path, 'rules'),
      ).listSync().whereType<File>().forEach((f) => f.deleteSync());

      syncer.run(
        global: false,
        providers: {Provider.copilot, Provider.claude},
        mode: SyncMode.hard,
      );

      expect(copilotDir.existsSync(), isFalse, reason: 'empty dir should be removed');
      expect(claudeDir.existsSync(), isFalse, reason: 'empty dir should be removed');
    });

    test('soft mode leaves output dirs intact when all rules deleted', () {
      syncer.run(global: false, providers: {Provider.claude});

      final claudeDir = Directory(p.join(tempRoot.path, '.claude', 'rules'));
      expect(claudeDir.existsSync(), isTrue);

      Directory(
        p.join(tempSource.path, 'rules'),
      ).listSync().whereType<File>().forEach((f) => f.deleteSync());

      // Default soft mode — output should remain.
      syncer.run(global: false, providers: {Provider.claude});

      expect(claudeDir.existsSync(), isTrue, reason: 'soft mode must not remove existing output');
    });
  });
}
