import 'dart:io';

import 'package:ai_sync/ai_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory tempSource;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('ai_sync_agents_test_root_');
    tempSource = Directory.systemTemp.createTempSync('ai_sync_agents_test_source_');

    final fixturesDir = Directory(p.join('test', 'fixtures', 'agents'));
    final agentsDestDir = Directory(p.join(tempSource.path, 'agents'))..createSync();
    for (final file in fixturesDir.listSync().whereType<File>()) {
      File(p.join(agentsDestDir.path, p.basename(file.path)))
          .writeAsStringSync(file.readAsStringSync());
    }
    File(p.join(tempSource.path, 'CONTEXT.md')).writeAsStringSync('# Context');
  });

  tearDown(() {
    tempRoot.deleteSync(recursive: true);
    tempSource.deleteSync(recursive: true);
  });

  group('AgentsSyncer — brainstorm-implementation', () {
    late AgentsSyncer syncer;

    setUp(() {
      final source = SourcePaths(tempSource.path);
      syncer = AgentsSyncer(source, rootDir: tempRoot);
    });

    test('Copilot output preserves tools/agents array formatting', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(p.join(tempRoot.path, '.github', 'agents', 'brainstorm-implementation.md'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      // Array formatting must be preserved byte-for-byte
      expect(content, contains('tools: [agent, vscode/askQuestions]'));
      expect(content, contains('"Software Idea Critic",'));
      expect(content, contains('"Implementation Architect",'));
      expect(content, contains('user-invocable: true'));
    });

    test('Copilot output strips Claude-only fields', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(p.join(tempRoot.path, '.github', 'agents', 'flutter-feasibility-assessor.md'));
      final content = file.readAsStringSync();
      expect(content, isNot(contains('model:')));
      expect(content, isNot(contains('permissionMode:')));
      expect(content, isNot(contains('maxTurns:')));
    });

    test('Claude output maps tools and merges agents as Agent(name)', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(p.join(tempRoot.path, '.claude', 'agents', 'brainstorm-implementation.md'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('Agent(Software Idea Critic)'));
      expect(content, contains('Agent(Implementation Architect)'));
      expect(content, contains('Agent(Flutter Feasibility Assessor)'));
      expect(content, contains('Agent(Implementation Planner)'));
      // generic `agent` suppressed; vscode dropped
      expect(content, isNot(contains(': Agent,')));
      expect(content, isNot(contains('vscode')));
      expect(content, isNot(contains('agents:')));
      expect(content, isNot(contains('user-invocable')));
    });

    test('Claude output retains Claude-only fields from MCP agent', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(p.join(tempRoot.path, '.claude', 'agents', 'flutter-feasibility-assessor.md'));
      final content = file.readAsStringSync();
      expect(content, contains('model: claude-sonnet-4-6'));
      expect(content, contains('permissionMode: acceptEdits'));
      expect(content, contains('maxTurns: 10'));
    });

    test('Claude output maps read + search + MCP tools', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(p.join(tempRoot.path, '.claude', 'agents', 'flutter-feasibility-assessor.md'));
      final content = file.readAsStringSync();
      expect(content, contains('Read'));
      expect(content, contains('Grep'));
      expect(content, contains('Glob'));
      expect(content, contains('dart-sdk-mcp-server/pub_dev_search'));
    });

    test('Gemini output uses slug name', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(p.join(tempRoot.path, '.gemini', 'agents', 'brainstorm-implementation.md'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('name: brainstorm-implementation'));
    });

    test('Gemini output strips Copilot/Claude-only fields', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final file = File(p.join(tempRoot.path, '.gemini', 'agents', 'brainstorm-implementation.md'));
      final content = file.readAsStringSync();
      expect(content, isNot(contains('user-invocable')));
      expect(content, isNot(contains('agents:')));
    });

    test('Antigravity has no agents output', () {
      syncer.run(global: false, providers: Provider.values.toSet());
      final antigravityDir = Directory(p.join(tempRoot.path, '.agents', 'agents'));
      expect(antigravityDir.existsSync(), isFalse);
    });
  });
}
