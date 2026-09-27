import 'package:flutter_test/flutter_test.dart';
import 'package:word_wars/data/word_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('words.json loads with types and definitions', () async {
    final entries = await loadWordEntries();
    expect(entries.length, greaterThan(140000));
    expect(entries['CAT']!.type, 'noun');
    expect(entries['WALKED']!.definition, startsWith('Past tense of walk'));
    expect(entries['SELFIE'], isNull);
  });
}
