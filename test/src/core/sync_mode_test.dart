import 'package:ai_sync/ai_sync.dart';
import 'package:test/test.dart';

void main() {
  group('SyncMode.fromName', () {
    test('parses soft', () => expect(SyncMode.fromName('soft'), SyncMode.soft));
    test('parses hard', () => expect(SyncMode.fromName('hard'), SyncMode.hard));
    test('is case-insensitive', () => expect(SyncMode.fromName('HARD'), SyncMode.hard));
    test('trims whitespace', () => expect(SyncMode.fromName('  soft  '), SyncMode.soft));

    test('throws ArgumentError for unknown name', () {
      expect(() => SyncMode.fromName('strict'), throwsArgumentError);
    });
  });

  group('SyncMode.allNames', () {
    test('contains both modes', () {
      expect(SyncMode.allNames, contains('soft'));
      expect(SyncMode.allNames, contains('hard'));
    });
  });
}
