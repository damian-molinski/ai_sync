import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';

import '../core/provider.dart';
import '../core/source_paths.dart';
import '../core/sync_mode.dart';
import '../core/sync_type.dart';
import '../sync/agents_syncer.dart';
import '../sync/context_syncer.dart';
import '../sync/rules_syncer.dart';
import '../sync/skills_syncer.dart';
import 'cli_utils.dart';

final _log = Logger('cli');

/// Entry point for the `ai_sync` CLI.
///
/// Usage:
///   ai_sync <source> [--providers <list>] [--type <list>] [--global] [--mode <mode>] [--log <level>]
///
/// Arguments:
///   <source>      Path to canonical source directory (required, positional).
///
/// Options:
///   -p, --providers   Comma-separated providers (default: all).
///                     Available: copilot, claude, gemini, antigravity
///   -t, --type        Comma-separated sync types (default: all).
///                     Available: context, rules, skills, agents
///   -g, --global      Write to provider global config dirs (~/) instead of workspace.
///   -m, --mode        Sync mode (default: soft).
///                     soft: never deletes existing output.
///                     hard: removes stale output when source resource is deleted.
///   -l, --log         Minimum log level (default: info).
///                     Available: all, finest, finer, fine, config, info, warning, severe, off
///   -h, --help        Show usage.
class CliRunner {
  Future<void> run(List<String> args) async {
    // Parse first to extract --log before configuring the root logger.
    final parser = ArgParser()
      ..addOption(
        'providers',
        abbr: 'p',
        valueHelp: 'list',
        help:
            'Comma-separated providers to sync (default: all).\n'
            'Available: ${Provider.allNames}',
      )
      ..addOption(
        'type',
        abbr: 't',
        valueHelp: 'list',
        help:
            'Comma-separated sync types (default: all).\n'
            'Available: ${SyncType.allNames}',
      )
      ..addFlag(
        'global',
        abbr: 'g',
        negatable: false,
        help: 'Write to provider global config dirs (~/) instead of workspace.',
      )
      ..addOption(
        'mode',
        abbr: 'm',
        valueHelp: 'mode',
        defaultsTo: 'soft',
        help:
            'Sync mode (default: soft).\n'
            'soft: never deletes existing output.\n'
            'hard: removes stale output when source resource is deleted.\n'
            'Available: ${SyncMode.allNames}',
      )
      ..addOption(
        'log',
        abbr: 'l',
        valueHelp: 'level',
        defaultsTo: 'info',
        help:
            'Minimum log level (default: info).\n'
            'Available: ${logLevelNames.keys.join(', ')}',
      )
      ..addFlag('help', abbr: 'h', negatable: false, hide: true);

    ArgResults results;
    try {
      results = parser.parse(args);
    } on FormatException catch (e) {
      stderr.writeln(e.message);
      stderr.writeln(_usage(parser));
      exit(64);
    }

    // Configure logging as early as possible so all subsequent output
    // respects the requested level.
    final Level logLevel;
    try {
      logLevel = parseLogLevelValue(results['log'] as String?);
    } on ArgumentError catch (e) {
      stderr.writeln(e.message);
      stderr.writeln(_usage(parser));
      exit(64);
    }
    _configureLogging(logLevel);

    if ((results['help'] as bool) || results.rest.isEmpty) {
      stdout.writeln(_usage(parser));
      return;
    }

    final sourcePath = results.rest.first;

    final Set<Provider> providers;
    final Set<SyncType> types;
    final SyncMode mode;
    try {
      providers = parseProvidersValue(results['providers'] as String?);
      types = parseTypesValue(results['type'] as String?);
      mode = parseModeValue(results['mode'] as String?);
    } on ArgumentError catch (e) {
      stderr.writeln(e.message);
      stderr.writeln(_usage(parser));
      exit(64);
    }

    final global = results['global'] as bool;
    final source = SourcePaths(sourcePath);

    if (types.contains(SyncType.context)) {
      ContextSyncer(source).run(global: global, providers: providers, mode: mode);
    }
    if (types.contains(SyncType.rules)) {
      RulesSyncer(source).run(global: global, providers: providers, mode: mode);
    }
    if (types.contains(SyncType.skills)) {
      SkillsSyncer(source).run(global: global, providers: providers, mode: mode);
    }
    if (types.contains(SyncType.agents)) {
      AgentsSyncer(source).run(global: global, providers: providers, mode: mode);
    }

    _log.info('✓ ai_sync complete.');
  }

  String _usage(ArgParser parser) => '''
Usage: ai_sync <source> [options]

  <source>    Path to canonical source directory (required)

${parser.usage}''';

  void _configureLogging(Level level) {
    Logger.root.level = level;
    Logger.root.onRecord.listen((record) {
      final prefix = switch (record.level) {
        Level.SEVERE => '[error]',
        Level.WARNING => '[warn]',
        Level.INFO => '[info]',
        Level.CONFIG => '[config]',
        _ => '[${record.level.name.toLowerCase()}]',
      };
      stdout.writeln('$prefix ${record.message}');
    });
  }
}
