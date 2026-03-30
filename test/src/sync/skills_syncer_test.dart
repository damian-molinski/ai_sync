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
        File(p.join(destDir.path, p.basename(file.path)))
            .writeAsStringSync(file.readAsStringSync());
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
        expect(FileSystemEntity.isLinkSync(linkPath), isTrue,
            reason: '$relPath should be a symlink');
      }
    });

    test('symlink targets resolve to source skill directory', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final linkPath = p.join(tempRoot.path, '.claude', 'skills', 'create-adr');
      // Use resolveSymbolicLinksSync on both sides to handle platform symlinks
      // (e.g. macOS /var/folders → /private/var/folders).
      final resolvedLink = Link(linkPath).resolveSymbolicLinksSync();
      final expectedSkillDir = Directory(p.join(tempSource.path, 'skills', 'create-adr'))
          .resolveSymbolicLinksSync();
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
}
