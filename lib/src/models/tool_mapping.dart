import 'agent_config.dart';

// Canonical tool → Claude Code tool mapping.
//
// Source: https://code.claude.com/docs/en/sub-agents
//
// | Canonical | Claude Code       | Notes                              |
// |-----------|-------------------|------------------------------------|
// | read      | Read              |                                    |
// | search    | Grep, Glob        | expands to two tools               |
// | web       | WebFetch          |                                    |
// | agent     | Agent             | only when no `agents` list present |
// | vscode/*  | (dropped)         | no Claude equivalent               |
// | *         | pass through      | e.g. MCP tools                     |

/// Maps a single canonical tool name to zero or more Claude Code tool names.
List<String> mapToolToClaude(String canonical) => switch (canonical) {
      'read' => ['Read'],
      'search' => ['Grep', 'Glob'],
      'web' => ['WebFetch'],
      'agent' => ['Agent'],
      _ when canonical.startsWith('vscode/') => [],
      _ => [canonical],
    };

/// Builds the final Claude `tools` list for [config].
///
/// Merges the mapped canonical tools with `Agent(name)` entries derived from
/// the `agents` field. When specific `Agent(name)` entries are present the
/// generic `agent` → `Agent` mapping is suppressed to avoid redundancy.
List<String> buildClaudeToolsList(AgentConfig config) {
  final hasAgentsList = config.agents.isNotEmpty;

  final mapped = <String>[];
  for (final tool in config.tools) {
    // Suppress generic `agent` → `Agent` when specific Agent(name) will be added.
    if (tool == 'agent' && hasAgentsList) continue;
    mapped.addAll(mapToolToClaude(tool));
  }

  // Append Agent(name) for each sub-agent.
  for (final agentName in config.agents) {
    mapped.add('Agent($agentName)');
  }

  return mapped;
}
