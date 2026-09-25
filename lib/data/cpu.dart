import 'dart:math';
import 'dart:typed_data';

import 'package:word_wars/data/game.dart';

/// How strongly the computer plays.
enum Difficulty {
  easy(
    'Easy',
    lengths: {3: 40, 4: 50, 5: 10},
    shortlist: 40,
    choices: 5,
    lookahead: 0,
  ),
  medium(
    'Medium',
    lengths: {3: 25, 4: 35, 5: 25, 6: 15},
    shortlist: 120,
    choices: 2,
    lookahead: 0,
  ),
  hard(
    'Hard',
    lengths: {3: 15, 4: 35, 5: 30, 6: 15, 7: 5},
    shortlist: 200,
    choices: 1,
    lookahead: 6,
  );

  const Difficulty(
    this.label, {
    required this.lengths,
    required this.shortlist,
    required this.choices,
    required this.lookahead,
  });
  final String label;

  /// How often it plays each word length, in percent.
  final Map<int, int> lengths;

  /// The longest word it knows.
  int get maxLen => lengths.keys.reduce(max);

  /// How many promising words it tries on the board each turn.
  final int shortlist;

  /// It picks at random among this many of its best plays.
  final int choices;

  /// How many of its best plays it checks against the rival's best reply.
  final int lookahead;
}

typedef _Play = ({List<int> sel, double score});

/// A computer opponent. Since a word's hexes don't need to touch, any word
/// whose letters are on the board can be spelled. The computer shortlists
/// words with many letters next to its territory, picks hexes that push
/// towards the rival's home, then plays each one out on a copy of the game
/// and keeps the best.
class Cpu {
  Cpu(Set<String> words, this.level)
    : _words = [
        for (final w in words)
          if (w.length >= 3 &&
              w.length <= level.maxLen &&
              w.codeUnits.every((u) => u >= 65 && u <= 90))
            Uint8List.fromList([for (final u in w.codeUnits) u - 65]),
      ];

  final Difficulty level;

  /// Known words as letter numbers, A = 0.
  final List<Uint8List> _words;
  final _rng = Random();

  /// Steps from each player's home to every cell, per board size.
  final _dist = <BoardSize, Map<int, List<int>>>{};

  /// The cells to select for the current player, in spelling order, or null to pass.
  List<int>? move(Game g) {
    if (g.over != null) return null;
    final p = g.turn, o = opponentOf(p);
    // The rival just passed, so passing now ends the game. Take the win when ahead.
    if (g.passes == 1 && g.countOf(p) > g.countOf(o)) return null;

    // Pick a word length by the level's odds, falling back to the other
    // lengths when no word of that length can be played.
    final odds = Map.of(level.lengths);
    while (odds.isNotEmpty) {
      final length = _pickLength(odds);
      odds.remove(length);
      var plays = _rank(g, level.shortlist, length);
      if (plays.isEmpty) continue;
      if (level.lookahead > 0) {
        plays = [
          for (final play in plays.take(level.lookahead))
            (sel: play.sel, score: _afterReply(g, play.sel, p)),
        ]..sort((a, b) => b.score.compareTo(a.score));
      }
      return plays[_rng.nextInt(min(level.choices, plays.length))].sel;
    }
    return null;
  }

  /// A word length drawn at random, weighted by [odds].
  int _pickLength(Map<int, int> odds) {
    var roll = _rng.nextInt(odds.values.reduce((a, b) => a + b));
    for (final MapEntry(key: length, value: weight) in odds.entries) {
      roll -= weight;
      if (roll < 0) return length;
    }
    return odds.keys.last;
  }

  /// Legal plays for the current player, best first, using only words of
  /// [length] letters if it's given.
  List<_Play> _rank(Game g, int shortlist, [int? length]) {
    final p = g.turn;
    final dist = _distances(g);
    final start = g.toJson();
    final sim = Game(g.words, size: g.size);
    final plays = <_Play>[];
    for (final w in _promising(g, p, shortlist, length)) {
      final sel = _place(g, w, p, dist);
      if (sel == null) continue;
      sim.loadJson(start);
      sim.sel = sel;
      if (sim.play()) plays.add((sel: sel, score: _eval(sim, p, dist)));
    }
    return plays..sort((a, b) => b.score.compareTo(a.score));
  }

  /// How good playing [sel] looks for [p] once the rival makes their best reply.
  double _afterReply(Game g, List<int> sel, int p) {
    final sim = Game(g.words, size: g.size)..loadJson(g.toJson());
    sim.sel = sel;
    sim.play();
    if (sim.over == null) {
      final replies = _rank(sim, 60);
      if (replies.isEmpty) {
        sim.pass();
      } else {
        sim.sel = replies.first.sel;
        sim.play();
      }
    }
    return _eval(sim, p, _distances(g));
  }

  /// Up to [n] words that fit the board's letters, most promising first:
  /// those with the most letters in unowned hexes next to [p]'s territory,
  /// then in hexes one step further out.
  Iterable<Uint8List> _promising(Game g, int p, int n, int? length) {
    final all = List.filled(26, 0),
        near = List.filled(26, 0),
        next = List.filled(26, 0);
    final ring = <int>{};
    for (var i = 0; i < g.cells.length; i++) {
      final x = g.cells[i];
      if (x.home != 0) continue;
      final l = _letter(x);
      all[l]++;
      if (x.owner != p && g.adj[i].any((n) => g.territory(n, p))) {
        near[l]++;
        ring.add(i);
      }
    }
    for (var i = 0; i < g.cells.length; i++) {
      final x = g.cells[i];
      if (x.home == 0 &&
          x.owner != p &&
          !ring.contains(i) &&
          g.adj[i].any(ring.contains)) {
        next[_letter(x)]++;
      }
    }

    final need = List.filled(26, 0);
    final scored = <(Uint8List, double)>[];
    for (final w in _words) {
      if (length != null && w.length != length) continue;
      for (final l in w) {
        need[l]++;
      }
      var fits = true;
      var a = 0, b = 0;
      for (final l in w) {
        final k = need[l];
        if (k == 0) continue; // repeated letter, already counted
        if (k > all[l]) fits = false;
        final m = min(k, near[l]);
        a += m;
        b += min(k - m, next[l]);
        need[l] = 0;
      }
      if (fits && a > 0) scored.add((w, a + b * .5 + w.length * .05));
    }
    scored.sort((x, y) => y.$2.compareTo(x.$2));
    return scored.take(n).map((e) => e.$1);
  }

  /// Picks a hex for each letter of [w], taking the most valuable hex that
  /// links to [p]'s territory each time, then borrowing the rest from
  /// neutral hexes. Returns them in spelling order, or null if it can't.
  List<int>? _place(Game g, Uint8List w, int p, Map<int, List<int>> dist) {
    final need = List.filled(26, 0);
    for (final l in w) {
      need[l]++;
    }
    var left = w.length;
    final used = <int>{}, linked = <int>{};
    final byLetter = <int, List<int>>{};
    void take(int i, int l) {
      used.add(i);
      byLetter.putIfAbsent(l, () => []).add(i);
      need[l]--;
      left--;
    }

    bool links(int i) =>
        g.cells[i].owner == p ||
        g.adj[i].any((n) => g.territory(n, p) || linked.contains(n));

    while (left > 0) {
      var best = -1;
      var bestValue = double.negativeInfinity;
      for (var i = 0; i < g.cells.length; i++) {
        final x = g.cells[i];
        if (x.home != 0 ||
            used.contains(i) ||
            need[_letter(x)] == 0 ||
            !links(i)) {
          continue;
        }
        final v = _value(g, i, p, dist);
        if (v > bestValue) {
          best = i;
          bestValue = v;
        }
      }
      if (best < 0) break;
      take(best, _letter(g.cells[best]));
      linked.add(best);
    }
    for (var i = 0; i < g.cells.length && left > 0; i++) {
      final x = g.cells[i];
      if (x.home == 0 &&
          x.owner == 0 &&
          !used.contains(i) &&
          need[_letter(x)] > 0) {
        take(i, _letter(x));
      }
    }
    if (left > 0) return null;
    return [for (final l in w) byLetter[l]!.removeLast()];
  }

  /// How much [p] wants to claim cell [i].
  double _value(Game g, int i, int p, Map<int, List<int>> dist) {
    final x = g.cells[i], o = opponentOf(p);
    if (x.owner == p) return 0;
    final toRival = dist[o]![i], toHome = dist[p]![i];
    var v = x.owner == o ? 3.0 : 1.0;
    v += 2 / toRival;
    if (toRival == 1) v += 4; // around the rival's home
    if (x.owner == o && toHome <= 2) {
      v += 3; // pushes the rival back from our home
    }
    return v + _rng.nextDouble() * .1;
  }

  /// How good the position is for [p].
  double _eval(Game g, int p, Map<int, List<int>> dist) {
    final o = opponentOf(p);
    if (g.over case final over?) {
      return over.winner == p
          ? 1e6
          : over.winner == o
          ? -1e6
          : 0;
    }
    const danger = [0.0, 4.0, 15.0, 200.0];
    return (g.countOf(p) - g.countOf(o)) +
        danger[min(g.pressureOn(o), 3)] -
        1.5 * danger[min(g.pressureOn(p), 3)] +
        1.5 * (_closest(g, o, dist[p]!) - _closest(g, p, dist[o]!));
  }

  /// Steps from the home [d] was measured from to [q]'s nearest hex.
  int _closest(Game g, int q, List<int> d) {
    var best = d[g.homeIdx[q]!];
    for (var i = 0; i < g.cells.length; i++) {
      if (g.cells[i].owner == q && d[i] < best) best = d[i];
    }
    return best;
  }

  Map<int, List<int>> _distances(Game g) => _dist[g.size] ??= {
    for (final MapEntry(key: p, value: h) in g.homeIdx.entries)
      p: _stepsFrom(g, h),
  };

  static List<int> _stepsFrom(Game g, int from) {
    final d = List.filled(g.cells.length, 1 << 20);
    d[from] = 0;
    final queue = [from];
    for (var k = 0; k < queue.length; k++) {
      final i = queue[k];
      for (final n in g.adj[i]) {
        if (d[n] > d[i] + 1) {
          d[n] = d[i] + 1;
          queue.add(n);
        }
      }
    }
    return d;
  }

  static int _letter(Cell x) => x.letter.codeUnitAt(0) - 65;
}
