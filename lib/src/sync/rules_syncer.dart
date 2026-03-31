import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../core/file_utils.dart';
import '../core/provider.dart';
import '../core/source_paths.dart';
import '../core/sync_mode.dart';
import '../models/rule_config.dart';

final _log = Logger('rules_syncer');

/// Reads canonical rule files and generates provider-specific output.
///
/// Output per provider:
///   Copilot     → .github/instructions/{name}.instructions.md
///   Antigravity → .agents/rules/{name}.md
///   Claude      → .claude/rules/{name}.md  (or ~/.claude/rules/ when --global)
///   Gemini      → (not supported)
///
/// Frontmatter formats:
///   Copilot:     applyTo: "**"                   (always-on)
///                applyTo: "{comma-joined-paths}"  (path-scoped)
///   Antigravity: trigger: always_on              (always-on)
///                trigger: glob + globs: ...       (path-scoped)
///   Claude:      (no frontmatter)                (always-on)
///                paths: [...]                    (path-scoped)
///
/// Sources:
///   Copilot:     https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions#creating-path-specific-custom-instructions
///   Claude:      https://code.claude.com/docs/en/settings
///   Antigravity: no public docs; format inferred from .agents/rules/ conventions
class RulesSyncer {
  RulesSyncer(this._source, {Directory? rootDir})
    : _rootDir = rootDir?.path ?? Directory.current.path;

  final SourcePaths _source;
  final String _rootDir;

  void run({
    required bool global,
    required Set<Provider> providers,
    SyncMode mode = SyncMode.soft,
  }) {
    if (!_source.hasRules) {
      if (mode == SyncMode.hard) {
        _cleanOutputDirs(global: global, providers: providers);
        _removeEmptyOutputDirs(global: global, providers: providers);
        _log.info('rules [hard]: removed stale output directories.');
      } else {
        _log.warning('No rule files found in ${_source.rulesDir} — skipping rules sync.');
      }
      return;
    }

    _cleanOutputDirs(global: global, providers: providers);

    final ruleFiles =
        Directory(
            _source.rulesDir,
          ).listSync().where((e) => e.path.endsWith('.md')).cast<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    int generated = 0;
    for (final file in ruleFiles) {
      final rule = RuleConfig.fromFile(file.path);
      _writeRule(rule, global: global, providers: providers);
      generated++;
    }

    _log.info(
      'rules: generated $generated rule(s) for ${_activeProviders(global, providers).map((p) => p.name).join(', ')}.',
    );
  }

  List<Provider> _activeProviders(bool global, Set<Provider> providers) {
    return Provider.values.where((provider) {
      if (!providers.contains(provider)) return false;
      final dir = global ? provider.globalRulesDir() : provider.workspaceRulesDir(_rootDir);
      return dir != null;
    }).toList();
  }

  void _cleanOutputDirs({required bool global, required Set<Provider> providers}) {
    for (final provider in Provider.values) {
      if (!providers.contains(provider)) continue;
      final dir = global ? provider.globalRulesDir() : provider.workspaceRulesDir(_rootDir);
      if (dir == null) continue;

      // Preserve symlinks in .agents/rules/ (e.g. GEMINI.md placed by instructions syncer).
      final preserveSymlinks = provider == Provider.antigravity;
      cleanDirectory(dir, preserveSymlinks: preserveSymlinks);
    }
  }

  void _removeEmptyOutputDirs({required bool global, required Set<Provider> providers}) {
    for (final provider in Provider.values) {
      if (!providers.contains(provider)) continue;
      final dir = global ? provider.globalRulesDir() : provider.workspaceRulesDir(_rootDir);
      if (dir == null) continue;
      removeIfEmptyDirectory(dir);
    }
  }

  void _writeRule(RuleConfig rule, {required bool global, required Set<Provider> providers}) {
    for (final provider in Provider.values) {
      if (!providers.contains(provider)) continue;
      final dir = global ? provider.globalRulesDir() : provider.workspaceRulesDir(_rootDir);
      if (dir == null) continue;

      ensureDirectory(dir);
      final filePath = _outputPath(provider, dir, rule.name);
      final content = _buildContent(provider, rule);
      writeFileString(filePath, content);
      _log.info('  ${provider.name}: $filePath');
    }
  }

  String _outputPath(Provider provider, String dir, String name) => switch (provider) {
    Provider.copilot => p.join(dir, '$name.instructions.md'),
    _ => p.join(dir, '$name.md'),
  };

  String _buildContent(Provider provider, RuleConfig rule) => switch (provider) {
    Provider.copilot => _copilotContent(rule),
    Provider.antigravity => _antigravityContent(rule),
    Provider.claude => _claudeContent(rule),
    Provider.gemini => '', // Not supported; filtered out before calling
  };

  // ---------------------------------------------------------------------------
  // Copilot
  // Source: https://docs.github.com/en/copilot/reference/customization-cheat-sheet
  // applyTo: glob string — always-on uses "**" (all files)
  // ---------------------------------------------------------------------------
  String _copilotContent(RuleConfig rule) {
    final applyTo = rule.isAlwaysOn ? '**' : rule.paths.join(', ');
    return '---\napplyTo: "$applyTo"\n---\n\n${rule.body}\n';
  }

  // ---------------------------------------------------------------------------
  // Antigravity
  // No public docs; format inferred from .agents/rules/ conventions.
  // trigger: always_on | glob
  // globs: comma-separated paths (only when trigger: glob)
  // ---------------------------------------------------------------------------
  String _antigravityContent(RuleConfig rule) {
    if (rule.isAlwaysOn) {
      return '---\ntrigger: always_on\n---\n\n${rule.body}\n';
    }
    final globs = rule.paths.join(', ');
    return '---\ntrigger: glob\nglobs: $globs\n---\n\n${rule.body}\n';
  }

  // ---------------------------------------------------------------------------
  // Claude
  // Source: https://code.claude.com/docs/en/settings
  // paths: array of glob strings — always-on has NO frontmatter
  // ---------------------------------------------------------------------------
  String _claudeContent(RuleConfig rule) {
    if (rule.isAlwaysOn) {
      return '${rule.body}\n';
    }
    final pathLines = rule.paths.map((path) => '  - "$path"').join('\n');
    return '---\npaths:\n$pathLines\n---\n\n${rule.body}\n';
  }
}
