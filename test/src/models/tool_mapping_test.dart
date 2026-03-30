import 'package:ai_sync/ai_sync.dart';
import 'package:test/test.dart';

void main() {
  group('mapToolToClaude', () {
    test('read → Read', () => expect(mapToolToClaude('read'), equals(['Read'])));
    test('search → Grep, Glob', () => expect(mapToolToClaude('search'), equals(['Grep', 'Glob'])));
    test('web → WebFetch', () => expect(mapToolToClaude('web'), equals(['WebFetch'])));
    test('agent → Agent', () => expect(mapToolToClaude('agent'), equals(['Agent'])));
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
    AgentConfig makeAgent({
      List<String> tools = const [],
      List<String> agents = const [],
    }) =>
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
      expect(buildClaudeToolsList(config), equals(['Read', 'Grep', 'Glob', 'WebFetch']));
    });

    test('merges agents as Agent(name)', () {
      final config = makeAgent(
        tools: ['agent'],
        agents: ['Critic', 'Planner'],
      );
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
      expect(
        buildClaudeToolsList(config),
        equals(['dart-sdk-mcp-server/pub_dev_search']),
      );
    });
  });
}
