import '../core/provider.dart';
import '../core/sync_mode.dart';
import '../core/sync_type.dart';

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
