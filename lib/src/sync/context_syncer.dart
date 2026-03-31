import 'dart:io';

import 'package:logging/logging.dart';

import '../core/file_utils.dart';
import '../core/provider.dart';
import '../core/source_paths.dart';
import '../core/sync_mode.dart';

final _log = Logger('context_syncer');

/// Creates CONTEXT.md symlinks at provider-expected locations.
///
/// Workspace mode (no --global):
///   .GEMINI.md                       → <source>/CONTEXT.md  (Gemini)
///   .github/copilot-instructions.md  → <source>/CONTEXT.md  (Copilot)
///   .claude/CLAUDE.md                → <source>/CONTEXT.md  (Claude)
///
/// Global mode (--global):
///   ~/.gemini/GEMINI.md              → <source>/CONTEXT.md  (Gemini + Antigravity)
///   ~/.claude/CLAUDE.md              → <source>/CONTEXT.md  (Claude)
///
/// All symlink targets are absolute paths.
///
/// Sources:
///   Copilot: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions
///   Gemini:  https://geminicli.com/docs/cli/gemini-md/
///   Claude:  https://code.claude.com/docs/en/settings
class ContextSyncer {
  ContextSyncer(this._source, {Directory? rootDir})
    : _rootDir = rootDir?.path ?? Directory.current.path;

  final SourcePaths _source;
  final String _rootDir;

  void run({
    required bool global,
    required Set<Provider> providers,
    SyncMode mode = SyncMode.soft,
  }) {
    if (!_source.hasInstructions) {
      if (mode == SyncMode.hard) {
        _deleteSymlinks(global: global, providers: providers);
      } else {
        _log.warning(
          'CONTEXT.md not found at ${_source.instructionsFile} — skipping context sync.',
        );
      }
      return;
    }

    final target = _source.instructionsFile;
    int created = 0;

    for (final provider in Provider.values) {
      if (!providers.contains(provider)) continue;

      final linkPath = global
          ? provider.globalInstructionsPath()
          : provider.workspaceInstructionsPath(_rootDir);

      if (linkPath == null) continue;

      // Antigravity shares ~/.gemini/GEMINI.md with Gemini in global mode —
      // avoid creating the same symlink twice.
      if (global && provider == Provider.antigravity) continue;

      createSymlink(target, linkPath);
      _log.info('  ${provider.name}: $linkPath → $target');
      created++;
    }

    _log.info('context: created $created symlink(s).');
  }

  /// Deletes the instruction symlinks for each provider when in hard mode.
  void _deleteSymlinks({required bool global, required Set<Provider> providers}) {
    int deleted = 0;
    for (final provider in Provider.values) {
      if (!providers.contains(provider)) continue;
      if (global && provider == Provider.antigravity) continue;

      final linkPath = global
          ? provider.globalInstructionsPath()
          : provider.workspaceInstructionsPath(_rootDir);

      if (linkPath == null) continue;

      deleteIfExists(linkPath);
      _log.info('  ${provider.name}: removed $linkPath');
      deleted++;
    }
    if (deleted > 0) {
      _log.info('context [hard]: removed $deleted stale symlink(s).');
    }
  }
}
