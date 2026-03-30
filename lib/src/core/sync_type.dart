/// Sync operation types available in `ai_sync`.
///
/// Used by the `--type` flag to select which asset categories to sync.
/// Omitting `--type` defaults to all types.
enum SyncType {
  context,
  rules,
  skills,
  agents;

  /// Parses a type name string (case-insensitive) to a [SyncType] value.
  /// Throws [ArgumentError] for unknown names.
  static SyncType fromName(String name) => switch (name.toLowerCase().trim()) {
        'context' => SyncType.context,
        'rules' => SyncType.rules,
        'skills' => SyncType.skills,
        'agents' => SyncType.agents,
        _ => throw ArgumentError(
            'Unknown type "$name". Valid types: $allNames',
          ),
      };

  /// Comma-separated list of all type names, used in help and error text.
  static String get allNames =>
      SyncType.values.map((t) => t.name).join(', ');
}
