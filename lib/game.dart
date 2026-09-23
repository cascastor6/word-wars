import 'dart:math';

/// Column positions of the hexes in each board row. Columns step by 2 so that
/// neighbouring rows interleave into a hex grid.
const rows = [
  [3, 5, 7],
  [2, 4, 6, 8],
  [1, 3, 5, 7, 9],
  [0, 2, 4, 6, 8, 10],
  [1, 3, 5, 7, 9],
  [2, 4, 6, 8],
  [3, 5, 7],
];

/// A fixed board for testing. `*` marks the home hexes, which have no letter.
const mock = ['L*I', 'LAMN', 'YBDOA', 'DOLANL', 'BREIF', 'YVRY', 'E*E'];

const names = {1: 'Blue', 2: 'Red'};

/// Where each player's home sits: Blue at the top, Red at the bottom.
const _homes = {1: (r: 0, c: 5), 2: (r: 6, c: 5)};

/// Row/column offsets from a hex to its six neighbours.
const _neighbourOffsets = [
  (dr: 0, dc: -2), // left
  (dr: 0, dc: 2), // right
  (dr: -1, dc: -1), // up-left
  (dr: -1, dc: 1), // up-right
  (dr: 1, dc: -1), // down-left
  (dr: 1, dc: 1), // down-right
];

/// English letter frequencies, in percent.
const freq = {
  'E': 12.7,
  'T': 9.1,
  'A': 8.2,
  'O': 7.5,
  'I': 7.0,
  'N': 6.7,
  'S': 6.3,
  'H': 6.1,
  'R': 6.0,
  'D': 4.3,
  'L': 4.0,
  'C': 2.8,
  'U': 2.8,
  'M': 2.4,
  'W': 2.4,
  'F': 2.2,
  'G': 2.0,
  'Y': 2.0,
  'P': 1.9,
  'B': 1.5,
  'V': 1.0,
  'K': 0.8,
  'J': 0.15,
  'X': 0.15,
  'Q': 0.1,
  'Z': 0.07,
};
final double _freqTotal = freq.values.reduce((a, b) => a + b);
final _rng = Random();

/// A random letter, weighted by how common it is in English.
String randLetter() {
  var remaining = _rng.nextDouble() * _freqTotal;
  for (final MapEntry(key: letter, value: weight) in freq.entries) {
    remaining -= weight;
    if (remaining <= 0) return letter;
  }
  return 'E';
}

/// The other player.
int opponentOf(int p) => 3 - p;

String _plural(int n, String word, [String suffix = 's']) => n == 1 ? word : '$word$suffix';

class Cell {
  Cell(this.r, this.c, this.home);
  final int r, c;
  final int home; // 0 = not a home, otherwise the player number
  String letter = '';
  int owner = 0;
}

class LogEntry {
  LogEntry.pass(this.p) : pass = true, word = '', took = 0, steals = 0, cut = 0;
  LogEntry.play(this.p, this.word, this.took, this.steals, this.cut)
    : pass = false;
  final int p;
  final bool pass;
  final String word;
  final int took, steals, cut;

  Map<String, Object> toJson() => pass
      ? {'p': p, 'pass': true}
      : {'p': p, 'word': word, 'took': took, 'steals': steals, 'cut': cut};

  static LogEntry fromJson(Map<String, dynamic> j) => j['pass'] == true
      ? LogEntry.pass(j['p'] as int)
      : LogEntry.play(j['p'] as int, j['word'] as String, j['took'] as int,
          j['steals'] as int, j['cut'] as int);
}

class GameOver {
  GameOver(this.winner, this.why);
  final int winner; // 0 = draw
  final String why;
}

/// What would happen if the current player played their selection.
class Analysis {
  Analysis(this.word, this.linked, this.ok, this.msg, this.gains, this.steals);
  final String word;

  /// Selected hexes that link to the player's territory.
  final Set<int> linked;

  /// Whether the selection is a legal play.
  final bool ok;

  /// Explains why the play is illegal, or what it will do.
  final String msg;

  /// Linked hexes the player doesn't own yet, which the play would take.
  final List<int> gains;

  /// How many of [gains] belong to the opponent.
  final int steals;
}

class Game {
  Game(this.words) {
    for (var r = 0; r < rows.length; r++) {
      for (final c in rows[r]) {
        cells.add(Cell(r, c, _homeOwnerAt(r, c)));
      }
    }
    for (final x in cells) {
      adj.add([
        for (final d in _neighbourOffsets)
          if (idxAt(x.r + d.dr, x.c + d.dc) case final n when n >= 0) n,
      ]);
    }
    homeIdx = {for (final MapEntry(key: p, value: h) in _homes.entries) p: idxAt(h.r, h.c)};
    newGame(false);
  }

  final Set<String> words;
  final cells = <Cell>[];

  /// Neighbour indices for each cell.
  final adj = <List<int>>[];

  /// Cell index of each player's home.
  late final Map<int, int> homeIdx;

  int turn = 1;

  /// Selected cell indices, in the order they spell the word.
  List<int> sel = [];

  /// Consecutive passes. Two in a row end the game.
  int passes = 0;
  GameOver? over;
  List<LogEntry> log = [];

  /// Cells that just got new letters, for highlighting.
  Set<int> fresh = {};

  /// The player whose home is at row [r], column [c], or 0 if it's not a home.
  static int _homeOwnerAt(int r, int c) {
    for (final MapEntry(key: p, value: home) in _homes.entries) {
      if (home == (r: r, c: c)) return p;
    }
    return 0;
  }

  /// Index of the cell at row [r], column [c], or -1 if there is none.
  int idxAt(int r, int c) => cells.indexWhere((x) => x.r == r && x.c == c);

  void newGame(bool useMock) {
    for (final x in cells) {
      x.owner = 0;
      if (x.home != 0) continue;
      x.letter = useMock ? mock[x.r][rows[x.r].indexOf(x.c)] : randLetter();
    }
    turn = 1;
    sel = [];
    passes = 0;
    over = null;
    log = [];
    fresh = {};
  }

  /// Shared state for online play. The current selection stays local to each player.
  Map<String, Object?> toJson() => {
    'letters': [for (final x in cells) x.letter],
    'owners': [for (final x in cells) x.owner],
    'turn': turn,
    'passes': passes,
    'over': over == null ? null : {'winner': over!.winner, 'why': over!.why},
    'log': [for (final e in log) e.toJson()],
    'fresh': fresh.toList(),
  };

  void loadJson(Map<String, dynamic> j) {
    final letters = j['letters'] as List, owners = j['owners'] as List;
    for (var i = 0; i < cells.length; i++) {
      cells[i].letter = letters[i] as String;
      cells[i].owner = owners[i] as int;
    }
    turn = j['turn'] as int;
    passes = j['passes'] as int? ?? 0;
    final o = j['over'] as Map<String, dynamic>?;
    over = o == null ? null : GameOver(o['winner'] as int, o['why'] as String);
    // Stores like Firebase drop empty lists, so these may be missing.
    log = [for (final e in j['log'] as List? ?? []) LogEntry.fromJson(e as Map<String, dynamic>)];
    fresh = {for (final i in j['fresh'] as List? ?? []) i as int};
    sel = [];
  }

  /// Whether cell [i] is player [p]'s home or one of their hexes.
  bool territory(int i, int p) => cells[i].home == p || cells[i].owner == p;

  /// Selected hexes that link to [p]'s territory, either directly or through
  /// other linked selected hexes.
  Set<int> _linkedSelection(int p) {
    final linked = <int>{};
    bool links(int i) =>
        cells[i].owner == p || adj[i].any((n) => territory(n, p) || linked.contains(n));

    // Keep sweeping until no more hexes join, since each new link can
    // connect hexes that were checked earlier.
    var grew = true;
    while (grew) {
      grew = false;
      for (final i in sel) {
        if (!linked.contains(i) && links(i)) {
          linked.add(i);
          grew = true;
        }
      }
    }
    return linked;
  }

  /// Why the selection can't be played, or null if it can.
  String? _problemWith(String word, Set<int> linked, List<int> blocked, int o) {
    if (sel.isEmpty) return 'Tap hexes to spell a word.';
    if (sel.length < 3) return 'Words need at least 3 letters.';
    if (linked.isEmpty) return 'Use at least one hex next to your home or your hexes.';
    if (blocked.isNotEmpty) {
      final letters = blocked.map((i) => cells[i].letter).join(', ');
      final pronoun = blocked.length > 1 ? 'them' : 'it';
      return "${names[o]}'s $letters must link to your territory before you can use $pronoun.";
    }
    if (!words.contains(word)) return "$word isn't in the word list.";
    return null;
  }

  Analysis analyze() {
    final p = turn, o = opponentOf(p);
    final word = sel.map((i) => cells[i].letter).join();
    final linked = _linkedSelection(p);
    final blocked = sel.where((i) => cells[i].owner == o && !linked.contains(i)).toList();
    final gains = linked.where((i) => cells[i].owner != p).toList();
    final steals = gains.where((i) => cells[i].owner == o).length;

    final problem = _problemWith(word, linked, blocked, o);
    if (problem != null) return Analysis(word, linked, false, problem, gains, steals);

    final String msg;
    if (gains.isEmpty) {
      msg = 'Play $word. It takes no new hexes but refreshes ${sel.length} letters.';
    } else {
      final stolen = steals > 0 ? ', $steals from ${names[o]}' : '';
      msg = 'Play $word to take ${gains.length} ${_plural(gains.length, 'hex', 'es')}$stolen.';
    }
    return Analysis(word, linked, true, msg, gains, steals);
  }

  /// Cells reachable from [q]'s home by stepping only through [q]'s hexes.
  Set<int> _connectedToHome(int q) {
    final home = homeIdx[q]!;
    final seen = {home};
    final stack = [home];
    while (stack.isNotEmpty) {
      for (final n in adj[stack.removeLast()]) {
        if (cells[n].owner == q && seen.add(n)) stack.add(n);
      }
    }
    return seen;
  }

  /// Neutralises every hex of player [q] no longer connected to their home.
  /// Returns how many hexes they lost.
  int prune(int q) {
    final connected = _connectedToHome(q);
    var lost = 0;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].owner == q && !connected.contains(i)) {
        cells[i].owner = 0;
        lost++;
      }
    }
    return lost;
  }

  /// How many hexes around [p]'s home the opponent owns.
  int pressureOn(int p) =>
      adj[homeIdx[p]!].where((n) => cells[n].owner == opponentOf(p)).length;

  int countOf(int p) => cells.where((x) => x.owner == p).length;

  /// Plays the current selection. Returns false if it isn't a legal play.
  bool play() {
    if (over != null) return false;
    final a = analyze();
    if (!a.ok) return false;
    final p = turn, o = opponentOf(p);

    for (final i in a.gains) {
      cells[i].owner = p;
    }
    for (final i in sel) {
      cells[i].letter = randLetter();
    }
    fresh = sel.toSet();
    final cut = prune(o);
    prune(p);

    log.add(LogEntry.play(p, a.word, a.gains.length, a.steals, cut));
    sel = [];
    passes = 0;

    if (pressureOn(o) >= 3) {
      over = GameOver(p, "${names[o]}'s home is surrounded.");
    } else {
      turn = o;
    }
    return true;
  }

  void pass() {
    if (over != null) return;
    sel = [];
    fresh = {};
    passes++;
    log.add(LogEntry.pass(turn));

    if (passes >= 2) {
      over = _resultByHexCount();
    } else {
      turn = opponentOf(turn);
    }
  }

  /// The result when both players pass: whoever owns more hexes wins.
  GameOver _resultByHexCount() {
    final blue = countOf(1), red = countOf(2);
    if (blue == red) return GameOver(0, 'Both players passed with $blue hexes each.');
    final winner = blue > red ? 1 : 2;
    return GameOver(
      winner,
      'Both players passed. ${names[winner]} owns more hexes, ${max(blue, red)} to ${min(blue, red)}.',
    );
  }

  /// Adds cell [i] to the selection, or if it's already selected, trims the
  /// selection back to just before it.
  void tap(int i) {
    if (over != null || cells[i].home != 0) return;
    final k = sel.indexOf(i);
    if (k == -1) {
      sel.add(i);
    } else {
      sel = sel.sublist(0, k);
    }
    fresh = {};
  }

  void backspace() {
    if (sel.isNotEmpty) sel.removeLast();
    fresh = {};
  }

  void clear() {
    sel = [];
    fresh = {};
  }
}
