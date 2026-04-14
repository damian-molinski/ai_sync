import 'package:ai_sync/ai_sync.dart';
import 'package:test/test.dart';

void main() {
  group('mapToolToClaude', () {
    test('read → Read', () => expect(mapToolToClaude('read'), equals(['Read'])));
    test('search → Grep, Glob', () => expect(mapToolToClaude('search'), equals(['Grep', 'Glob'])));
    test('execute → Bash', () => expect(mapToolToClaude('execute'), equals(['Bash'])));
    test(
      'edit → Edit, Write, NotebookEdit',
      () => expect(mapToolToClaude('edit'), equals(['Edit', 'Write', 'NotebookEdit'])),
    );
    test(
      'web → WebFetch, WebSearch',
      () => expect(mapToolToClaude('web'), equals(['WebFetch', 'WebSearch'])),
    );
    test('todo → TodoWrite', () => expect(mapToolToClaude('todo'), equals(['TodoWrite'])));
    test('agent → Agent', () => expect(mapToolToClaude('agent'), equals(['Agent'])));
    test('* → omitted tools for Claude', () => expect(mapToolToClaude('*'), isEmpty));
    test('vscode/* → dropped', () {
      expect(mapToolToClaude('vscode/askQuestions'), isEmpty);
      expect(mapToolToClaude('vscode/terminal'), isEmpty);
    });
    test('MCP tool → pass through', () {
      expect(
        mapToolToClaude('dart-sdk-mcp-server/pub_dev_search'),
        equals(['dart-sdk-mcp-server/pub_dev_search']),
      );
    });
    test('unknown tool → pass through', () {
      expect(mapToolToClaude('custom-tool'), equals(['custom-tool']));
    });
  });

  group('buildClaudeToolsList', () {
    AgentConfig makeAgent({List<String> tools = const [], List<String> agents = const []}) =>
        AgentConfig(
          name: 'test',
          description: null,
          tools: tools,
          agents: agents,
          body: '',
          rawFrontmatterText: '',
        );

    test('maps canonical tools', () {
      final config = makeAgent(tools: ['read', 'search', 'web']);
      expect(
        buildClaudeToolsList(config),
        equals(['Read', 'Grep', 'Glob', 'WebFetch', 'WebSearch']),
      );
    });

    test('maps execute, edit, and todo aliases', () {
      final config = makeAgent(tools: ['execute', 'edit', 'todo']);
      expect(
        buildClaudeToolsList(config),
        equals(['Bash', 'Edit', 'Write', 'NotebookEdit', 'TodoWrite']),
      );
    });

    test('merges agents as Agent(name)', () {
      final config = makeAgent(tools: ['agent'], agents: ['Critic', 'Planner']);
      // generic `agent` suppressed when agents list is present
      expect(buildClaudeToolsList(config), equals(['Agent(Critic)', 'Agent(Planner)']));
    });

    test('keeps generic Agent when no agents list', () {
      final config = makeAgent(tools: ['agent']);
      expect(buildClaudeToolsList(config), equals(['Agent']));
    });

    test('drops vscode/* tools', () {
      final config = makeAgent(tools: ['read', 'vscode/askQuestions']);
      expect(buildClaudeToolsList(config), equals(['Read']));
    });

    test('passes through MCP tools', () {
      final config = makeAgent(tools: ['dart-sdk-mcp-server/pub_dev_search']);
      expect(buildClaudeToolsList(config), equals(['dart-sdk-mcp-server/pub_dev_search']));
    });

    test('canonical * omits tools for Claude', () {
      final config = makeAgent(tools: ['*']);
      expect(buildClaudeToolsList(config), isEmpty);
    });
  });

  group('mapToolToGemini', () {
    test('read → read_file', () => expect(mapToolToGemini('read'), equals(['read_file'])));
    test('search → grep_search, glob', () {
      expect(mapToolToGemini('search'), equals(['grep_search', 'glob']));
    });
    test('execute → run_shell_command', () {
      expect(mapToolToGemini('execute'), equals(['run_shell_command']));
    });
    test('edit → replace, write_file', () {
      expect(mapToolToGemini('edit'), equals(['replace', 'write_file']));
    });
    test('web → web_fetch, google_web_search', () {
      expect(mapToolToGemini('web'), equals(['web_fetch', 'google_web_search']));
    });
    test('todo → write_todos', () => expect(mapToolToGemini('todo'), equals(['write_todos'])));
    test('agent → dropped', () => expect(mapToolToGemini('agent'), isEmpty));
    test('vscode/* → dropped', () {
      expect(mapToolToGemini('vscode/askQuestions'), isEmpty);
    });
    test('MCP tool → pass through', () {
      expect(
        mapToolToGemini('dart-sdk-mcp-server/pub_dev_search'),
        equals(['dart-sdk-mcp-server/pub_dev_search']),
      );
    });
  });

  group('buildGeminiToolsList', () {
    AgentConfig makeAgent({List<String> tools = const []}) => AgentConfig(
      name: 'test',
      description: null,
      tools: tools,
      agents: const [],
      body: '',
      rawFrontmatterText: '',
    );

    test('maps canonical aliases', () {
      final config = makeAgent(tools: ['read', 'search', 'execute', 'edit', 'web', 'todo']);
      expect(
        buildGeminiToolsList(config),
        equals([
          'read_file',
          'grep_search',
          'glob',
          'run_shell_command',
          'replace',
          'write_file',
          'web_fetch',
          'google_web_search',
          'write_todos',
        ]),
      );
    });

    test('drops agent and vscode/*', () {
      final config = makeAgent(tools: ['agent', 'vscode/askQuestions']);
      expect(buildGeminiToolsList(config), isEmpty);
    });

    test('passes through MCP tools', () {
      final config = makeAgent(tools: ['dart-sdk-mcp-server/pub_dev_search']);
      expect(buildGeminiToolsList(config), equals(['dart-sdk-mcp-server/pub_dev_search']));
    });
  });
}
