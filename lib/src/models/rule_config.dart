import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/frontmatter.dart';

/// Parsed representation of a canonical rule file.
///
/// A rule file is a markdown file with optional YAML frontmatter:
/// ```yaml
/// ---
/// description: "Brief description"
/// paths:
///   - "**/src/**/*.dart"
/// ---
/// # Rule Title
/// Body content...
/// ```
///
/// Rules with no `paths` (or an empty `paths` list) are **always-on** and
/// apply unconditionally to all files.
class RuleConfig {
  const RuleConfig({
    required this.name,
    required this.paths,
    required this.body,
  });

  /// Filename stem of the source file (e.g. `drift-columns` from `drift-columns.md`).
  final String name;

  /// Glob patterns that scope this rule to specific files.
  /// Empty list means always-on (applies to all files).
  final List<String> paths;

  /// The markdown body content (without frontmatter).
  final String body;

  /// Whether this rule applies to all files unconditionally.
  bool get isAlwaysOn => paths.isEmpty;

  /// Parses a canonical rule file at [filePath].
  factory RuleConfig.fromFile(String filePath) {
    final content = File(filePath).readAsStringSync();
    final fm = Frontmatter.parse(content);
    final name = p.basenameWithoutExtension(filePath);
    final paths = fm.getStringList('paths');
    return RuleConfig(name: name, paths: paths, body: fm.body);
  }
}
