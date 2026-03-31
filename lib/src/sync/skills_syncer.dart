import 'dart:io';

import 'package:logging/logging.dart';

import '../core/file_utils.dart';
import '../core/provider.dart';
import '../core/source_paths.dart';
import '../core/sync_mode.dart';

final _log = Logger('skills_syncer');

/// Creates one directory symlink per skill per provider.
///
/// For each skill directory in source `skills/`:
///   1. Deletes the existing entry at `{provider-skills-dir}/{skill-name}`.
///   2. Creates a symlink: `{provider-skills-dir}/{skill-name}` → `<source>/skills/{skill-name}`.
///
/// All symlink targets are absolute paths (source is resolved to absolute on startup).
/// Adding new files to a skill source directory is automatically reflected
/// without re-running `ai_sync`.
///
/// Output directories:
///   Copilot     workspace: .github/skills/        global: ~/.copilot/skills/
///   Claude      workspace: .claude/skills/         global: ~/.claude/skills/
///   Gemini      workspace: .gemini/skills/          global: ~/.gemini/skills/
///   Antigravity workspace: .agents/skills/          global: ~/.gemini/antigravity/skills/
///
/// Sources:
///   Copilot:     https://docs.github.com/en/copilot/reference/customization-cheat-sheet
///   Gemini:      https://geminicli.com/docs/cli/skills/
///   Antigravity: https://antigravity.google/docs/skills
///   Claude:      https://code.claude.com/docs/en/settings
class SkillsSyncer {
  SkillsSyncer(this._source, {Directory? rootDir})
    : _rootDir = rootDir?.path ?? Directory.current.path;

  final SourcePaths _source;
  final String _rootDir;

  void run({
    required bool global,
    required Set<Provider> providers,
    SyncMode mode = SyncMode.soft,
  }) {
    if (!_source.hasSkills) {
      if (mode == SyncMode.hard) {
        _cleanAllSkillDirs(global: global, providers: providers);
        _log.info('skills [hard]: removed stale skill symlinks.');
      } else {
        _log.warning('No skill directories found in ${_source.skillsDir} — skipping skills sync.');
      }
      return;
    }

    final skillDirs = Directory(_source.skillsDir).listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final currentSkillNames = skillDirs
        .map((d) => d.uri.pathSegments.lastWhere((s) => s.isNotEmpty))
        .toSet();

    if (mode == SyncMode.hard) {
      _removeStaleSkills(
        global: global,
        providers: providers,
        currentSkillNames: currentSkillNames,
      );
    }

    int linked = 0;
    for (final skillDir in skillDirs) {
      _syncSkill(skillDir, global: global, providers: providers);
      linked++;
    }

    _log.info('skills: linked $linked skill(s) for ${providers.map((p) => p.name).join(', ')}.');
  }

  /// Removes skill entries from each provider's skills dir whose name is not
  /// in [currentSkillNames]. After removal, deletes the directory if empty.
  void _removeStaleSkills({
    required bool global,
    required Set<Provider> providers,
    required Set<String> currentSkillNames,
  }) {
    for (final provider in Provider.values) {
      if (!providers.contains(provider)) continue;
      final skillsDir = global ? provider.globalSkillsDir() : provider.workspaceSkillsDir(_rootDir);
      final dir = Directory(skillsDir);
      if (!dir.existsSync()) continue;

      for (final entry in dir.listSync()) {
        final name = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        if (!currentSkillNames.contains(name)) {
          deleteIfExists(entry.path);
          _log.fine('  ${provider.name}: removed stale skill $name');
        }
      }
      removeIfEmptyDirectory(skillsDir);
    }
  }

  /// Removes all skill entries from each provider's skills dir (used when all
  /// source skills have been deleted) then removes the now-empty directory.
  void _cleanAllSkillDirs({required bool global, required Set<Provider> providers}) {
    for (final provider in Provider.values) {
      if (!providers.contains(provider)) continue;
      final skillsDir = global ? provider.globalSkillsDir() : provider.workspaceSkillsDir(_rootDir);
      cleanDirectory(skillsDir);
      removeIfEmptyDirectory(skillsDir);
    }
  }

  void _syncSkill(Directory skillDir, {required bool global, required Set<Provider> providers}) {
    final skillName = skillDir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    final targetPath = skillDir.path; // absolute (source resolved on startup)

    for (final provider in Provider.values) {
      if (!providers.contains(provider)) continue;

      final skillsDir = global ? provider.globalSkillsDir() : provider.workspaceSkillsDir(_rootDir);

      ensureDirectory(skillsDir);
      final linkPath = '$skillsDir/$skillName';
      createSymlink(targetPath, linkPath);
      _log.fine('  ${provider.name}: $linkPath → $targetPath');
    }
  }
}
