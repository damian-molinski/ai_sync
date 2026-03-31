import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves and validates the canonical source directory.
///
/// All paths are resolved to **absolute** paths on construction so that
/// symlink targets are always absolute regardless of CWD at call time.
class SourcePaths {
  SourcePaths(String sourcePath) : baseDir = p.normalize(p.absolute(sourcePath)) {
    if (!Directory(baseDir).existsSync()) {
      throw ArgumentError('Source directory does not exist: $baseDir');
    }
  }

  /// The absolute, normalized path to the root of the canonical source dir.
  final String baseDir;

  /// Absolute path to the `CONTEXT.md` instructions file.
  String get instructionsFile => p.join(baseDir, 'CONTEXT.md');

  /// Absolute path to the `rules/` subdirectory.
  String get rulesDir => p.join(baseDir, 'rules');

  /// Absolute path to the `agents/` subdirectory.
  String get agentsDir => p.join(baseDir, 'agents');

  /// Absolute path to the `skills/` subdirectory.
  String get skillsDir => p.join(baseDir, 'skills');

  /// Whether the `rules/` subdirectory exists and is non-empty.
  bool get hasRules {
    final dir = Directory(rulesDir);
    return dir.existsSync() && dir.listSync().any((e) => e.path.endsWith('.md'));
  }

  /// Whether the `agents/` subdirectory exists and is non-empty.
  bool get hasAgents {
    final dir = Directory(agentsDir);
    return dir.existsSync() && dir.listSync().any((e) => e.path.endsWith('.md'));
  }

  /// Whether the `skills/` subdirectory exists and has any subdirectories.
  bool get hasSkills {
    final dir = Directory(skillsDir);
    return dir.existsSync() && dir.listSync().any((e) => e is Directory);
  }

  /// Whether the `CONTEXT.md` instructions file exists.
  bool get hasInstructions => File(instructionsFile).existsSync();
}
