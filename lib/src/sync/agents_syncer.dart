import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../core/file_utils.dart';
import '../core/provider.dart';
import '../core/source_paths.dart';
import '../models/agent_config.dart';
import '../models/tool_mapping.dart';

final _log = Logger('agents_syncer');

// Claude-specific frontmatter keys to strip from Copilot output.
// Source: https://code.claude.com/docs/en/sub-agents
const _claudeOnlyKeys = {
  'model',
  'skills',
  'permissionMode',
  'maxTurns',
  'memory',
  'hooks',
  'disallowedTools',
  'background',
  'effort',
  'isolation',
  'initialPrompt',
  'mcpServers',
};

// Gemini-specific frontmatter keys to strip from Copilot/Claude output.
// Source: https://geminicli.com/docs/core/subagents/
const _geminiOnlyKeys = {
  'temperature',
  'timeout_mins',
  'kind',
};

/// Reads canonical agent files and generates provider-specific output.
///
/// Supported providers:
///   Copilot     → .github/agents/{name}.md
///   Claude      → .claude/agents/{name}.md  (or ~/.claude/agents/ when --global)
///   Gemini      → .gemini/agents/{name}.md  (or ~/.gemini/agents/ when --global)
///   Antigravity → (not supported)
///
/// Copilot output preserves original YAML array formatting via raw text
/// extraction — it strips Claude-only and Gemini-only keys using regex
/// line removal rather than re-serialising parsed YAML.
///
/// Claude output maps canonical tools to Claude Code tool names and merges
/// the `agents` list into `Agent(name)` tool entries.
///
/// Gemini output uses slug `name` (filename stem), maps maxTurns → max_turns,
/// and strips all Copilot/Claude-specific fields.
///
/// Sources:
///   Copilot: https://docs.github.com/en/copilot/reference/customization-cheat-sheet
///   Gemini:  https://geminicli.com/docs/core/subagents/
///   Claude:  https://code.claude.com/docs/en/sub-agents
class AgentsSyncer {
  AgentsSyncer(
    this._source, {
    Directory? rootDir,
  }) : _rootDir = rootDir?.path ?? Directory.current.path;

  final SourcePaths _source;
  final String _rootDir;

  void run({required bool global, required Set<Provider> providers}) {
    if (!_source.hasAgents) {
      _log.warning('No agent files found in ${_source.agentsDir} — skipping agents sync.');
      return;
    }

    _cleanOutputDirs(global: global, providers: providers);

    final agentFiles = Directory(_source.agentsDir)
        .listSync()
        .where((e) => e.path.endsWith('.md'))
        .cast<File>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    int generated = 0;
    for (final file in agentFiles) {
      final agent = AgentConfig.fromFile(file.path);
      _writeAgent(agent, global: global, providers: providers);
      generated++;
    }

    _log.info('agents: generated $generated agent(s).');
  }

  void _cleanOutputDirs({required bool global, required Set<Provider> providers}) {
    for (final provider in Provider.values) {
      if (!providers.contains(provider)) continue;
      final dir = global ? provider.globalAgentsDir() : provider.workspaceAgentsDir(_rootDir);
      if (dir == null) continue;
      cleanDirectory(dir);
    }
  }

  void _writeAgent(AgentConfig agent, {required bool global, required Set<Provider> providers}) {
    for (final provider in Provider.values) {
      if (!providers.contains(provider)) continue;
      final dir = global ? provider.globalAgentsDir() : provider.workspaceAgentsDir(_rootDir);
      if (dir == null) continue;

      ensureDirectory(dir);
      final stem = p.basenameWithoutExtension(agent.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'));
      final filePath = p.join(dir, '$stem.md');
      final content = _buildContent(provider, agent);
      writeFileString(filePath, content);
      _log.info('  ${provider.name}: $filePath');
    }
  }

  // ---------------------------------------------------------------------------
  // Copilot — strip Claude/Gemini keys from raw frontmatter; preserve formatting
  // Source: https://docs.github.com/en/copilot/reference/customization-cheat-sheet
  // ---------------------------------------------------------------------------
  String _copilotContent(AgentConfig agent) {
    final strippedFrontmatter = _stripKeysFromRaw(
      agent.rawFrontmatterText,
      {..._claudeOnlyKeys, ..._geminiOnlyKeys},
    );
    return '---\n$strippedFrontmatter\n---\n\n${agent.body}\n';
  }

  // ---------------------------------------------------------------------------
  // Claude — map tools, merge agents as Agent(name), strip non-Claude fields
  // Source: https://code.claude.com/docs/en/sub-agents
  // ---------------------------------------------------------------------------
  String _claudeContent(AgentConfig agent) {
    final fields = <String, Object?>{};

    if (agent.description != null) fields['description'] = agent.description;
    fields['name'] = agent.name;

    final claudeTools = buildClaudeToolsList(agent);
    if (claudeTools.isNotEmpty) {
      fields['tools'] = claudeTools.join(', ');
    }

    // Claude-only fields (keep if present)
    if (agent.model != null) fields['model'] = agent.model;
    if (agent.skills != null && agent.skills!.isNotEmpty) fields['skills'] = agent.skills;
    if (agent.permissionMode != null) fields['permissionMode'] = agent.permissionMode;
    if (agent.maxTurns != null) fields['maxTurns'] = agent.maxTurns;
    if (agent.memory != null) fields['memory'] = agent.memory;
    if (agent.hooks != null) fields['hooks'] = agent.hooks;
    if (agent.disallowedTools != null && agent.disallowedTools!.isNotEmpty) {
      fields['disallowedTools'] = agent.disallowedTools;
    }
    if (agent.background != null) fields['background'] = agent.background;
    if (agent.effort != null) fields['effort'] = agent.effort;
    if (agent.isolation != null) fields['isolation'] = agent.isolation;
    if (agent.initialPrompt != null) fields['initialPrompt'] = agent.initialPrompt;
    if (agent.mcpServers != null) fields['mcpServers'] = agent.mcpServers;

    final frontmatter = _serializeFields(fields);
    return '---\n$frontmatter\n---\n\n${agent.body}\n';
  }

  // ---------------------------------------------------------------------------
  // Gemini — slug name, map maxTurns → max_turns, strip Copilot/Claude fields
  // Source: https://geminicli.com/docs/core/subagents/
  // Gemini name must be slug format (lowercase letters, numbers, hyphens, underscores)
  // ---------------------------------------------------------------------------
  String _geminiContent(AgentConfig agent) {
    final stem = p.basenameWithoutExtension(
      agent.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
    );

    final fields = <String, Object?>{};
    fields['name'] = stem;
    if (agent.description != null) fields['description'] = agent.description;
    if (agent.model != null) fields['model'] = agent.model;
    if (agent.temperature != null) fields['temperature'] = agent.temperature;
    if (agent.maxTurns != null) fields['max_turns'] = agent.maxTurns; // renamed
    if (agent.timeoutMins != null) fields['timeout_mins'] = agent.timeoutMins;
    if (agent.kind != null) fields['kind'] = agent.kind;

    final frontmatter = _serializeFields(fields);
    return '---\n$frontmatter\n---\n\n${agent.body}\n';
  }

  String _buildContent(Provider provider, AgentConfig agent) =>
      switch (provider) {
        Provider.copilot => _copilotContent(agent),
        Provider.claude => _claudeContent(agent),
        Provider.gemini => _geminiContent(agent),
        Provider.antigravity => '', // Not supported; filtered out
      };

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Removes lines starting with any of [keys] from [raw] YAML frontmatter
  /// text, preserving all other lines including multi-line values and arrays.
  String _stripKeysFromRaw(String raw, Set<String> keys) {
    final lines = raw.split('\n');
    final result = <String>[];
    var skipUntilNextKey = false;

    for (final line in lines) {
      // A top-level key line starts with a non-space character followed by `:`.
      final keyMatch = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_-]*)(\s*:.*)').firstMatch(line);
      if (keyMatch != null) {
        final key = keyMatch.group(1)!;
        skipUntilNextKey = keys.contains(key);
      } else if (!line.startsWith(' ') && !line.startsWith('\t') && line.isNotEmpty) {
        // Non-indented, non-key line — reset skip state.
        skipUntilNextKey = false;
      }

      if (!skipUntilNextKey) result.add(line);
    }

    return result.join('\n').trim();
  }

  /// Serialises a flat map of fields to YAML lines.
  ///
  /// Handles strings (quoted), booleans, numbers, lists, and YamlNode pass-through.
  String _serializeFields(Map<String, Object?> fields) {
    final lines = <String>[];
    for (final entry in fields.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) continue;

      if (value is String) {
        // Inline string — quote if it contains special characters.
        lines.add('$key: ${_quoteIfNeeded(value)}');
      } else if (value is bool || value is num) {
        lines.add('$key: $value');
      } else if (value is List) {
        lines.add('$key:');
        for (final item in value) {
          lines.add('  - ${_quoteIfNeeded(item.toString())}');
        }
      } else if (value is YamlNode) {
        // Pass through complex YAML values (hooks, mcpServers, memory) as-is.
        lines.add('$key: ${_yamlNodeToString(value)}');
      } else {
        lines.add('$key: $value');
      }
    }
    return lines.join('\n');
  }

  String _quoteIfNeeded(String value) {
    // Quote if value contains YAML-special characters or is already quoted.
    if (value.contains(':') ||
        value.contains('#') ||
        value.contains('"') ||
        value.contains("'") ||
        value.startsWith('{') ||
        value.startsWith('[')) {
      return '"${value.replaceAll('"', '\\"')}"';
    }
    return value;
  }

  String _yamlNodeToString(YamlNode node) {
    if (node is YamlScalar) return node.value.toString();
    if (node is YamlList) {
      return '[${node.map((e) => e.toString()).join(', ')}]';
    }
    if (node is YamlMap) {
      return '{${node.entries.map((e) => '${e.key}: ${e.value}').join(', ')}}';
    }
    return node.toString();
  }
}
