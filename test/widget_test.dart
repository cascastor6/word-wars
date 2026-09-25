import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_wars/game.dart';
import 'package:word_wars/online.dart';

void main() {
  test("mock board: LAMB near Blue's home takes hexes", () {
    final g = Game({'LAB', 'LAMB'})..newGame(true);
    final l = g.idxAt(1, 3), a = g.idxAt(1, 5), m = g.idxAt(1, 7), b = g.idxAt(2, 4);
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

  test('board sizes have the right rows and centred homes', () {
    for (final (size, widths) in [
      (BoardSize.small, [3, 4, 5, 6, 5, 4, 3]),
      (BoardSize.normal, [3, 4, 5, 6, 7, 6, 5, 4, 3]),
      (BoardSize.large, [3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3]),
    ]) {
      final g = Game({}, size: size);
      expect([for (final r in g.rows) r.length], widths);
      expect(g.cells[g.homeIdx[1]!].r, 0);
      expect(g.cells[g.homeIdx[2]!].r, size.rows - 1);
      expect(g.adj[g.homeIdx[1]!].length, 4);
    }
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
    for (final i in [g.idxAt(1, 3), g.idxAt(1, 5), g.idxAt(1, 7), g.idxAt(2, 4)]) {
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
