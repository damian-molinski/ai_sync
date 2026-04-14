import 'agent_config.dart';

// Canonical tool → provider-specific tool mapping.
//
// Sources:
//   Copilot: https://docs.github.com/en/copilot/reference/custom-agents-configuration#tool-aliases
//   Claude:  https://code.claude.com/docs/en/tools-reference
//   Gemini:  https://geminicli.com/docs/core/subagents/
//            https://github.com/google-gemini/gemini-cli/blob/main/packages/core/src/tools/definitions/base-declarations.ts
//
// | Canonical | Copilot (alias) | Claude Code                | Gemini CLI                    | Notes                              |
// |-----------|------------------|----------------------------|-------------------------------|------------------------------------|
// | read      | read             | Read                       | read_file                     |                                    |
// | search    | search           | Grep, Glob                 | grep_search, glob             | expands to two tools               |
// | execute   | execute          | Bash                       | run_shell_command             |                                    |
// | edit      | edit             | Edit, Write, NotebookEdit  | replace, write_file           | expands to two tools               |
// | web       | web              | WebFetch, WebSearch        | web_fetch, google_web_search  | expands to two tools               |
// | todo      | todo             | TodoWrite                  | write_todos                   |                                    |
// | agent     | agent            | Agent                      | (dropped)                     | Gemini subagents cannot recurse    |
// | vscode/*  | (dropped)        | (dropped)                  | (dropped)                     | no cross-provider equivalent       |
// | *         | all tools        | omit `tools` field         | *                             | provider-specific all-tools syntax |

/// Maps a single canonical tool name to zero or more Claude Code tool names.
List<String> mapToolToClaude(String canonical) => switch (canonical) {
  'read' => ['Read'],
  'search' => ['Grep', 'Glob'],
  'execute' => ['Bash'],
  'edit' => ['Edit', 'Write', 'NotebookEdit'],
  'web' => ['WebFetch', 'WebSearch'],
  'todo' => ['TodoWrite'],
  'agent' => ['Agent'],
  // Claude uses omitted `tools` for "all tools", not wildcard `*`.
  '*' => [],
  _ when canonical.startsWith('vscode/') => [],
  _ => [canonical],
};

/// Maps a single canonical tool name to zero or more Gemini CLI tool names.
///
/// Source of Gemini tool names:
/// https://github.com/google-gemini/gemini-cli/blob/main/packages/core/src/tools/definitions/base-declarations.ts
List<String> mapToolToGemini(String canonical) => switch (canonical) {
  'read' => ['read_file'],
  'search' => ['grep_search', 'glob'],
  'execute' => ['run_shell_command'],
  'edit' => ['replace', 'write_file'],
  'web' => ['web_fetch', 'google_web_search'],
  'todo' => ['write_todos'],
  // Gemini subagents cannot call other subagents.
  'agent' => [],
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

/// Builds the final Gemini `tools` list for [config].
List<String> buildGeminiToolsList(AgentConfig config) {
  final mapped = <String>[];
  for (final tool in config.tools) {
    mapped.addAll(mapToolToGemini(tool));
  }
  return mapped;
}
