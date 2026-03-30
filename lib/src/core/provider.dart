import 'dart:io';

import 'package:path/path.dart' as p;

// Sources:
//   Copilot:     https://docs.github.com/en/copilot/reference/customization-cheat-sheet
//   Claude:      https://code.claude.com/docs/en/settings
//   Gemini:      https://geminicli.com/docs/cli/gemini-md/
//   Antigravity: https://antigravity.google/docs (no public docs; inferred from conventions)

/// Supported AI provider targets.
enum Provider {
  copilot,
  claude,
  gemini,
  antigravity;

  /// Parses a provider name string (case-insensitive) to a [Provider] value.
  /// Throws [ArgumentError] for unknown names.
  static Provider fromName(String name) => switch (name.toLowerCase().trim()) {
        'copilot' => Provider.copilot,
        'claude' => Provider.claude,
        'gemini' => Provider.gemini,
        'antigravity' => Provider.antigravity,
        _ => throw ArgumentError(
            'Unknown provider "$name". Valid providers: $allNames',
          ),
      };

  /// Comma-separated list of all provider names, used in help and error text.
  static String get allNames =>
      Provider.values.map((p) => p.name).join(', ');

  // ---------------------------------------------------------------------------
  // Instructions (CONTEXT.md symlink destinations)
  // ---------------------------------------------------------------------------

  /// The symlink path for the instructions file in workspace mode, or null if
  /// this provider has no workspace instructions path.
  String? workspaceInstructionsPath(String rootDir) => switch (this) {
        Provider.copilot =>
          p.join(rootDir, '.github', 'copilot-instructions.md'),
        Provider.claude => p.join(rootDir, '.claude', 'CLAUDE.md'),
        Provider.gemini => p.join(rootDir, 'GEMINI.md'),
        Provider.antigravity => null, // No workspace instructions path
      };

  /// The symlink path for the instructions file in global mode, or null if
  /// this provider has no global instructions path.
  String? globalInstructionsPath() {
    final home = Platform.environment['HOME'] ?? '';
    return switch (this) {
      Provider.copilot => null, // No global instructions path
      Provider.claude => p.join(home, '.claude', 'CLAUDE.md'),
      // ~/.gemini/GEMINI.md serves both Gemini and Antigravity in global mode.
      Provider.gemini => p.join(home, '.gemini', 'GEMINI.md'),
      Provider.antigravity => p.join(home, '.gemini', 'GEMINI.md'),
    };
  }

  // ---------------------------------------------------------------------------
  // Rules
  // ---------------------------------------------------------------------------

  /// Output directory for generated rule files in workspace mode, or null if
  /// this provider does not support rules.
  String? workspaceRulesDir(String rootDir) => switch (this) {
        Provider.copilot => p.join(rootDir, '.github', 'instructions'),
        Provider.claude => p.join(rootDir, '.claude', 'rules'),
        Provider.antigravity => p.join(rootDir, '.agents', 'rules'),
        Provider.gemini => null, // Gemini CLI has no rules format
      };

  /// Output directory for generated rule files in global mode, or null if
  /// this provider does not support global rules.
  String? globalRulesDir() {
    final home = Platform.environment['HOME'] ?? '';
    return switch (this) {
      Provider.claude => p.join(home, '.claude', 'rules'),
      Provider.copilot => null,
      Provider.gemini => null,
      Provider.antigravity => null,
    };
  }

  // ---------------------------------------------------------------------------
  // Skills
  // ---------------------------------------------------------------------------

  /// Output directory for skill directory symlinks in workspace mode.
  String workspaceSkillsDir(String rootDir) => switch (this) {
        Provider.copilot => p.join(rootDir, '.github', 'skills'),
        Provider.claude => p.join(rootDir, '.claude', 'skills'),
        Provider.gemini => p.join(rootDir, '.gemini', 'skills'),
        Provider.antigravity => p.join(rootDir, '.agents', 'skills'),
      };

  /// Output directory for skill directory symlinks in global mode.
  String globalSkillsDir() {
    final home = Platform.environment['HOME'] ?? '';
    return switch (this) {
      Provider.copilot => p.join(home, '.copilot', 'skills'),
      Provider.claude => p.join(home, '.claude', 'skills'),
      Provider.gemini => p.join(home, '.gemini', 'skills'),
      // Source: https://antigravity.google/docs/skills (global path)
      Provider.antigravity => p.join(home, '.gemini', 'antigravity', 'skills'),
    };
  }

  // ---------------------------------------------------------------------------
  // Agents
  // ---------------------------------------------------------------------------

  /// Output directory for generated agent files in workspace mode, or null if
  /// this provider does not support agents.
  String? workspaceAgentsDir(String rootDir) => switch (this) {
        Provider.copilot => p.join(rootDir, '.github', 'agents'),
        Provider.claude => p.join(rootDir, '.claude', 'agents'),
        Provider.gemini => p.join(rootDir, '.gemini', 'agents'),
        Provider.antigravity => null, // No agent format for Antigravity
      };

  /// Output directory for generated agent files in global mode, or null if
  /// this provider does not support global agents.
  String? globalAgentsDir() {
    final home = Platform.environment['HOME'] ?? '';
    return switch (this) {
      Provider.copilot => null,
      Provider.claude => p.join(home, '.claude', 'agents'),
      Provider.gemini => p.join(home, '.gemini', 'agents'),
      Provider.antigravity => null,
    };
  }
}
