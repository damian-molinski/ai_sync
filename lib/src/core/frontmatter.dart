import 'package:yaml/yaml.dart';

/// Parsed representation of a markdown file that may contain YAML frontmatter.
///
/// Frontmatter is the block delimited by `---` at the start of the file:
/// ```
/// ---
/// key: value
/// ---
/// Body text here.
/// ```
///
/// Exposes both the parsed YAML values and the raw unparsed frontmatter text,
/// which is needed when output must preserve the original YAML formatting
/// (e.g. Copilot agent output requires byte-for-byte array preservation).
class Frontmatter {
  const Frontmatter({
    required this.rawFrontmatterText,
    required this.rawFields,
    required this.body,
  });

  /// The raw unparsed text between the `---` delimiters, preserving original
  /// formatting. Empty string when no frontmatter is present.
  final String rawFrontmatterText;

  /// YAML-parsed key/value map. Empty map when no frontmatter is present.
  final Map<Object, Object?> rawFields;

  /// The markdown body after the frontmatter block (trimmed).
  final String body;

  /// Parses [content] into frontmatter and body.
  ///
  /// Handles:
  /// - No frontmatter (whole content becomes body)
  /// - Empty frontmatter (`---\n---`)
  /// - Multi-line string values
  static Frontmatter parse(String content) {
    final lines = content.split('\n');

    // Must start with a `---` delimiter to have frontmatter.
    if (lines.isEmpty || lines[0].trim() != '---') {
      return Frontmatter(
        rawFrontmatterText: '',
        rawFields: {},
        body: content.trim(),
      );
    }

    // Find closing `---`.
    int closeIndex = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        closeIndex = i;
        break;
      }
    }

    if (closeIndex == -1) {
      // No closing delimiter — treat whole content as body.
      return Frontmatter(
        rawFrontmatterText: '',
        rawFields: {},
        body: content.trim(),
      );
    }

    final rawFrontmatterText = lines.sublist(1, closeIndex).join('\n');
    final body = lines.sublist(closeIndex + 1).join('\n').trim();

    Map<Object, Object?> rawFields = {};
    if (rawFrontmatterText.trim().isNotEmpty) {
      final parsed = loadYaml(rawFrontmatterText);
      if (parsed is YamlMap) {
        rawFields = Map<Object, Object?>.from(parsed);
      }
    }

    return Frontmatter(
      rawFrontmatterText: rawFrontmatterText,
      rawFields: rawFields,
      body: body,
    );
  }

  /// Returns the string value for [key], or null if absent or not a string.
  String? getString(String key) {
    final value = rawFields[key];
    if (value == null) return null;
    return value.toString();
  }

  /// Returns the list of strings for [key].
  ///
  /// Handles both YAML sequences and comma-separated strings.
  /// Returns an empty list if the key is absent or the value is an empty list.
  List<String> getStringList(String key) {
    final value = rawFields[key];
    if (value == null) return [];
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    final str = value.toString().trim();
    if (str.isEmpty) return [];
    return str.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Whether this file has any frontmatter.
  bool get hasFrontmatter => rawFrontmatterText.isNotEmpty || rawFields.isNotEmpty;
}
