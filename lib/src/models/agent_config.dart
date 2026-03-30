import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/frontmatter.dart';

/// Parsed representation of a canonical agent file.
///
/// An agent file is a markdown file with YAML frontmatter. The frontmatter
/// uses a canonical schema that is then mapped to provider-specific output
/// formats by the agent syncer.
///
/// Known fields per provider:
/// ```
/// // Sources:
/// //   Copilot: https://docs.github.com/en/copilot/reference/customization-cheat-sheet
/// //   Gemini:  https://geminicli.com/docs/core/subagents/
/// //   Claude:  https://code.claude.com/docs/en/sub-agents
///
/// // Shared fields (all providers):
/// //   name        — display name; Gemini requires slug format (use filename stem)
/// //   description — what the agent does
/// //   tools       — canonical tool list (mapped per provider)
///
/// // Copilot-only fields:
/// //   agents       — sub-agent names (preserved as-is in Copilot output)
/// //   user-invocable — whether shown in Copilot UI
///
/// // Claude-only fields:
/// //   model, skills, permissionMode, maxTurns, memory, hooks,
/// //   disallowedTools, background, effort, isolation, initialPrompt, mcpServers
///
/// // Gemini-only fields (canonical → Gemini mapping):
/// //   temperature   — model temperature (0.0–2.0), default 1
/// //   timeout_mins  — max execution time in minutes, default 10
/// //   kind          — "local" (default) or "remote"
/// //   maxTurns      → max_turns in Gemini output
/// ```
class AgentConfig {
  const AgentConfig({
    required this.name,
    required this.description,
    required this.tools,
    required this.agents,
    required this.body,
    required this.rawFrontmatterText,
    this.userInvocable,
    this.model,
    this.skills,
    this.permissionMode,
    this.maxTurns,
    this.memory,
    this.hooks,
    this.disallowedTools,
    this.background,
    this.effort,
    this.isolation,
    this.initialPrompt,
    this.mcpServers,
    this.temperature,
    this.timeoutMins,
    this.kind,
  });

  // Shared ────────────────────────────────────────────────────────────────────
  final String name;
  final String? description;
  final List<String> tools;

  // Copilot-specific ───────────────────────────────────────────────────────────
  /// Sub-agent names; each becomes `Agent(name)` in Claude output.
  final List<String> agents;
  final bool? userInvocable;

  // Claude-specific ────────────────────────────────────────────────────────────
  // Source: https://code.claude.com/docs/en/sub-agents
  final String? model;
  final List<String>? skills;
  final String? permissionMode;
  final int? maxTurns;
  final Object? memory;
  final Object? hooks;
  final List<String>? disallowedTools;
  final bool? background;
  final String? effort;
  final String? isolation;
  final String? initialPrompt;
  final Object? mcpServers;

  // Gemini-specific ────────────────────────────────────────────────────────────
  // Source: https://geminicli.com/docs/core/subagents/
  final double? temperature;
  final int? timeoutMins;
  final String? kind;

  // Raw text for Copilot output preservation ───────────────────────────────────
  /// The raw unparsed YAML frontmatter text, used by the Copilot syncer to
  /// preserve original array formatting byte-for-byte.
  final String rawFrontmatterText;

  /// The markdown body (system prompt).
  final String body;

  /// Filename stem of the source file (e.g. `brainstorm-implementation`).
  String get filenameStem => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  /// Parses a canonical agent file at [filePath].
  factory AgentConfig.fromFile(String filePath) {
    final content = File(filePath).readAsStringSync();
    final fm = Frontmatter.parse(content);

    int? parseIntField(String key) {
      final v = fm.rawFields[key];
      if (v == null) return null;
      return int.tryParse(v.toString());
    }

    double? parseDoubleField(String key) {
      final v = fm.rawFields[key];
      if (v == null) return null;
      return double.tryParse(v.toString());
    }

    bool? parseBoolField(String key) {
      final v = fm.rawFields[key];
      if (v == null) return null;
      if (v is bool) return v;
      return v.toString().toLowerCase() == 'true';
    }

    final nameStem = p.basenameWithoutExtension(filePath);
    final name = fm.getString('name') ?? nameStem;

    return AgentConfig(
      name: name,
      description: fm.getString('description'),
      tools: fm.getStringList('tools'),
      agents: fm.getStringList('agents'),
      userInvocable: parseBoolField('user-invocable'),
      model: fm.getString('model'),
      skills: fm.rawFields.containsKey('skills') ? fm.getStringList('skills') : null,
      permissionMode: fm.getString('permissionMode'),
      maxTurns: parseIntField('maxTurns'),
      memory: fm.rawFields['memory'],
      hooks: fm.rawFields['hooks'],
      disallowedTools: fm.rawFields.containsKey('disallowedTools')
          ? fm.getStringList('disallowedTools')
          : null,
      background: parseBoolField('background'),
      effort: fm.getString('effort'),
      isolation: fm.getString('isolation'),
      initialPrompt: fm.getString('initialPrompt'),
      mcpServers: fm.rawFields['mcpServers'],
      temperature: parseDoubleField('temperature'),
      timeoutMins: parseIntField('timeout_mins'),
      kind: fm.getString('kind'),
      rawFrontmatterText: fm.rawFrontmatterText,
      body: fm.body,
    );
  }
}
