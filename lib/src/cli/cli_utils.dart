import 'package:logging/logging.dart';

import '../core/provider.dart';
import '../core/sync_mode.dart';
import '../core/sync_type.dart';

/// Allowed log-level names exposed to the CLI user.
///
/// Maps lowercase name → [Level] constant.  Used both for parsing `--log`
/// and for generating the `allowed:` list in the arg parser.
const logLevelNames = {
  'all': Level.ALL,
  'finest': Level.FINEST,
  'finer': Level.FINER,
  'fine': Level.FINE,
  'config': Level.CONFIG,
  'info': Level.INFO,
  'warning': Level.WARNING,
  'severe': Level.SEVERE,
  'off': Level.OFF,
};

/// Parses the raw `--providers` option value into a validated [Set<Provider>].
///
/// Accepts a comma-separated string (e.g. `"copilot,claude"`).
/// Returns all providers when [raw] is null or empty.
/// Throws [ArgumentError] if any name is unknown.
Set<Provider> parseProvidersValue(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return Provider.values.toSet();
  final providers = <Provider>{};
  for (final name in value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
    providers.add(Provider.fromName(name)); // throws ArgumentError on bad name
  }
  return providers;
}

/// Parses the raw `--type` option value into a validated [Set<SyncType>].
///
/// Accepts a comma-separated string (e.g. `"context,rules"`).
/// Returns all types when [raw] is null or empty.
/// Throws [ArgumentError] if any name is unknown.
Set<SyncType> parseTypesValue(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return SyncType.values.toSet();
  final types = <SyncType>{};
  for (final name in value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
    types.add(SyncType.fromName(name)); // throws ArgumentError on bad name
  }
  return types;
}

/// Parses the raw `--mode` option value into a [SyncMode].
///
/// Returns [SyncMode.soft] when [raw] is null or empty.
/// Throws [ArgumentError] if the name is unknown.
SyncMode parseModeValue(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return SyncMode.soft;
  return SyncMode.fromName(value); // throws ArgumentError on bad name
}

/// Parses the raw `--log` option value into a [Level].
///
/// Returns [Level.INFO] when [raw] is null or empty.
/// Throws [ArgumentError] if the name is unknown.
Level parseLogLevelValue(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  if (value.isEmpty) return Level.INFO;
  final level = logLevelNames[value];
  if (level == null) {
    throw ArgumentError('Unknown log level "$raw". Valid levels: ${logLevelNames.keys.join(', ')}');
  }
  return level;
}
