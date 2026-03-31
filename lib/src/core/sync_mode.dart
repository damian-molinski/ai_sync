/// Sync mode controlling whether stale output files are removed.
///
/// Passed via the `--mode` CLI flag.
///   soft (default) — never deletes existing output; preserves files whose
///                    source has been removed.
///   hard           — deletes previously-synced output when the corresponding
///                    source resource no longer exists. Also removes now-empty
///                    output directories.
enum SyncMode {
  soft,
  hard;

  /// Parses a mode name string (case-insensitive) to a [SyncMode] value.
  /// Throws [ArgumentError] for unknown names.
  static SyncMode fromName(String name) => switch (name.toLowerCase().trim()) {
    'soft' => SyncMode.soft,
    'hard' => SyncMode.hard,
    _ => throw ArgumentError('Unknown mode "$name". Valid modes: $allNames'),
  };

  /// Comma-separated list of all mode names, used in help and error text.
  static String get allNames => SyncMode.values.map((m) => m.name).join(', ');
}
