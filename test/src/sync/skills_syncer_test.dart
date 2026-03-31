import 'dart:io';

import 'package:ai_sync/ai_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory tempSource;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('ai_sync_skills_test_root_');
    tempSource = Directory.systemTemp.createTempSync('ai_sync_skills_test_source_');

    // Copy skills fixture
    final skillsSource = Directory(p.join('test', 'fixtures', 'skills'));
    final skillsDest = Directory(p.join(tempSource.path, 'skills'));
    skillsDest.createSync(recursive: true);
    for (final entry in skillsSource.listSync().whereType<Directory>()) {
      final destDir = Directory(p.join(skillsDest.path, p.basename(entry.path)));
      destDir.createSync();
      for (final file in entry.listSync().whereType<File>()) {
        File(
          p.join(destDir.path, p.basename(file.path)),
        ).writeAsStringSync(file.readAsStringSync());
      }
    }
    File(p.join(tempSource.path, 'CONTEXT.md')).writeAsStringSync('# Context');
  });

  tearDown(() {
    tempRoot.deleteSync(recursive: true);
    tempSource.deleteSync(recursive: true);
  });

  group('SkillsSyncer workspace', () {
    late SkillsSyncer syncer;

    setUp(() {
      final source = SourcePaths(tempSource.path);
      syncer = SkillsSyncer(source, rootDir: tempRoot);
    });

    test('creates directory symlink for each provider', () {
      syncer.run(global: false, providers: Provider.values.toSet());

      final providers = {
        '.github/skills/create-adr',
        '.claude/skills/create-adr',
        '.gemini/skills/create-adr',
        '.agents/skills/create-adr',
      };

      for (final relPath in providers) {
        final linkPath = p.join(tempRoot.path, relPath);
        expect(
          FileSystemEntity.isLinkSync(linkPath),
          isTrue,
          reason: '$relPath should be a symlink',
        );
      }
    });

    test('symlink targets resolve to source skill directory', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final linkPath = p.join(tempRoot.path, '.claude', 'skills', 'create-adr');
      // Use resolveSymbolicLinksSync on both sides to handle platform symlinks
      // (e.g. macOS /var/folders → /private/var/folders).
      final resolvedLink = Link(linkPath).resolveSymbolicLinksSync();
      final expectedSkillDir = Directory(
        p.join(tempSource.path, 'skills', 'create-adr'),
      ).resolveSymbolicLinksSync();
      expect(resolvedLink, equals(expectedSkillDir));
    });

    test('SKILL.md is accessible through symlink', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final skillMd = File(p.join(tempRoot.path, '.claude', 'skills', 'create-adr', 'SKILL.md'));
      expect(skillMd.existsSync(), isTrue);
    });

    test('re-running replaces existing symlinks', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      syncer.run(global: false, providers: Provider.values.toSet()); // should not throw

      final linkPath = p.join(tempRoot.path, '.claude', 'skills', 'create-adr');
      expect(FileSystemEntity.isLinkSync(linkPath), isTrue);
    });
  });

  group('SkillsSyncer hard mode', () {
    late SkillsSyncer syncer;

    setUp(() {
      final source = SourcePaths(tempSource.path);
      syncer = SkillsSyncer(source, rootDir: tempRoot);
    });

    test('removes stale skill symlink when one skill deleted in hard mode', () {
      // Add a second skill fixture.
      final extraSkillDir = Directory(p.join(tempSource.path, 'skills', 'extra-skill'));
      extraSkillDir.createSync(recursive: true);
      File(p.join(extraSkillDir.path, 'SKILL.md')).writeAsStringSync('# Extra');

      syncer.run(global: false, providers: {Provider.claude});

      final createAdrLink = p.join(tempRoot.path, '.claude', 'skills', 'create-adr');
      final extraLink = p.join(tempRoot.path, '.claude', 'skills', 'extra-skill');
      expect(FileSystemEntity.isLinkSync(createAdrLink), isTrue);
      expect(FileSystemEntity.isLinkSync(extraLink), isTrue);

      // Delete the extra skill from source.
      extraSkillDir.deleteSync(recursive: true);

      syncer.run(global: false, providers: {Provider.claude}, mode: SyncMode.hard);

      expect(
        FileSystemEntity.isLinkSync(extraLink),
        isFalse,
        reason: 'stale symlink should be removed',
      );
      expect(
        FileSystemEntity.isLinkSync(createAdrLink),
        isTrue,
        reason: 'remaining skill symlink must be preserved',
      );
    });

    test('cleans all skill symlinks and removes dir when all skills deleted in hard mode', () {
      syncer.run(global: false, providers: {Provider.claude});

      final claudeSkillsDir = Directory(p.join(tempRoot.path, '.claude', 'skills'));
      expect(claudeSkillsDir.existsSync(), isTrue);

      // Delete all source skills.
      Directory(
        p.join(tempSource.path, 'skills'),
      ).listSync().whereType<Directory>().forEach((d) => d.deleteSync(recursive: true));

      syncer.run(global: false, providers: {Provider.claude}, mode: SyncMode.hard);

      expect(
        claudeSkillsDir.existsSync(),
        isFalse,
        reason: 'empty skills dir should be removed in hard mode',
      );
    });

    test('soft mode leaves stale skill symlinks intact', () {
      // Add and sync a second skill.
      final extraSkillDir = Directory(p.join(tempSource.path, 'skills', 'extra-skill'));
      extraSkillDir.createSync(recursive: true);
      File(p.join(extraSkillDir.path, 'SKILL.md')).writeAsStringSync('# Extra');

      syncer.run(global: false, providers: {Provider.claude});

      // Delete the extra skill from source, then re-run in soft mode.
      extraSkillDir.deleteSync(recursive: true);
      syncer.run(global: false, providers: {Provider.claude});

      final extraLink = p.join(tempRoot.path, '.claude', 'skills', 'extra-skill');
      expect(
        FileSystemEntity.isLinkSync(extraLink),
        isTrue,
        reason: 'soft mode must not remove stale symlinks',
      );
    });
  });
}
