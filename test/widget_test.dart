import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_wars/game.dart';
import 'package:word_wars/online.dart';

void main() {
  test("mock board: LAMB near Blue's home takes hexes", () {
    final g = Game({'LAB', 'LAMB'})..newGame(true);
    final l = g.idxAt(1, 2), a = g.idxAt(1, 4), m = g.idxAt(1, 6), b = g.idxAt(2, 3);
    for (final i in [l, a, m, b]) {
      g.tap(i);
    }
    final an = g.analyze();
    expect(an.word, 'LAMB');
    expect(an.ok, isTrue);
    expect(g.play(), isTrue);
    expect(g.turn, 2);
    expect(g.countOf(1), greaterThan(0));
  });

  test('two passes end the game in a draw on an empty board', () {
    final g = Game({});
    g.pass();
    g.pass();
    expect(g.over?.winner, 0);
  });

  test('state survives a JSON round trip', () {
    final g = Game({'LAMB'});
    g.newGame(true);
    for (final i in [g.idxAt(1, 2), g.idxAt(1, 4), g.idxAt(1, 6), g.idxAt(2, 3)]) {
      g.tap(i);
    }
    g.play();
    final copy = Game({})..loadJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect(copy.turn, g.turn);
    expect(copy.log.single.word, 'LAMB');
    expect([for (final x in copy.cells) x.owner], [for (final x in g.cells) x.owner]);
    expect([for (final x in copy.cells) x.letter], [for (final x in g.cells) x.letter]);
    expect(copy.fresh, g.fresh);
  });

  test('invite links parse from web and app URLs', () {
    expect(codeFromLink(Uri.parse('https://example.com/join/abc234')), 'ABC234');
    expect(codeFromLink(Uri.parse('wordwars://join/ABC234')), 'ABC234');
    expect(codeFromLink(Uri.parse('https://example.com/')), isNull);
  });
}
