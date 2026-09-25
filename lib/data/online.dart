import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';

/// Where the web app is hosted. Invite links point here; web builds use
/// whatever site they were loaded from. Both come from .env.
const _appUrl = String.fromEnvironment('APP_URL');
const _databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL');

Uri get appUrl => kIsWeb ? Uri.parse(Uri.base.origin) : Uri.parse(_appUrl);

Uri inviteLink(String code) => appUrl.replace(path: '/join/$code');

/// Pulls a game code out of https://host/join/CODE or wordwars://join/CODE.
String? codeFromLink(Uri uri) {
  final parts = [if (uri.scheme == 'wordwars') uri.host, ...uri.pathSegments]
      .where((s) => s.isNotEmpty)
      .toList();
  final k = parts.indexOf('join');
  if (k < 0 || k + 1 >= parts.length) return null;
  final code = parts[k + 1].toUpperCase();
  return RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(code) ? code : null;
}

const _lastKey = 'online.last';

Future<String?> lastOnlineGame() async =>
    (await SharedPreferences.getInstance()).getString(_lastKey);

final _rng = Random.secure();
// No 0/O or 1/I/L so codes can be read aloud or typed.
const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
String _newCode() => List.generate(6, (_) => _alphabet[_rng.nextInt(_alphabet.length)]).join();

/// Firebase hands back loosely typed maps; the game wants JSON-shaped ones.
dynamic _plain(Object? v) => switch (v) {
      Map() => {for (final e in v.entries) '${e.key}': _plain(e.value)},
      List() => [for (final x in v) _plain(x)],
      _ => v,
    };

enum Link { connecting, live, reconnecting, failed }

/// One device's view of an online game stored at games/{code} in the Realtime
/// Database. Each device signs in anonymously; its user id is its seat, so
/// reopening the link on the same device puts the player back in their seat.
/// A device that isn't seated in a full game can watch, or take over a seat
/// (say the link was first opened in an in-app browser); the device it
/// replaces drops to watching.
///
/// The player whose turn it is applies the move locally and writes the new
/// state. Database rules (database.rules.json) only let that player write,
/// and only on top of the latest version. While they pick letters, their
/// selection is mirrored to games/{code}/draft so the other player can watch.
class OnlineSession extends ChangeNotifier {
  /// Hosts a new game on a [size] board, or joins the game at [code], whose
  /// host already picked the size.
  OnlineSession(this._words, {this.code, BoardSize size = BoardSize.normal}) {
    if (code == null) game = Game(_words, size: size);
    _start().catchError((Object e) => _fail(_describe(e)));
  }

  final Set<String> _words;

  /// Set before [seat], so it's ready once the session has a seat.
  late final Game game;
  String? code;

  /// This device's seat, or null while it's watching or deciding.
  int? seat;

  /// The game is full and this device isn't in it: waiting for [spectate] or [takeSeat].
  bool choosing = false;
  bool spectating = false;

  /// Why this device is watching when it used to be seated.
  String? notice;
  Link link = Link.connecting;
  String? error;
  bool pending = false;

  /// Ready to show the board: seated or watching.
  bool get joined => seat != null || spectating;

  bool get opponentJoined => seat == null || _seats['p${3 - seat!}'] != null;
  bool get opponentOnline => seat != null && isOnline(3 - seat!);
  bool isOnline(int p) => _online['p$p'] == true;

  /// Called when a new move lands, so the board can animate it.
  VoidCallback? onMove;

  final _db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _databaseUrl);
  final _subs = <StreamSubscription>[];
  DatabaseReference? _presence;
  bool _connected = false;
  late final String _uid;
  Map<String, dynamic> _seats = {};
  Map<String, dynamic> _online = {};
  int _version = 0;
  bool _closed = false;

  /// The latest selection the opponent shared, tagged with the state version
  /// it was made on so a draft from before a move is never shown after it.
  Map<String, dynamic>? _draft;

  bool get myTurn => link == Link.live && seat == game.turn && !pending && game.over == null;

  DatabaseReference get _game => _db.ref('games/$code');

  Future<void> _start() async {
    final auth = FirebaseAuth.instance;
    final uid = _uid = (auth.currentUser ?? (await auth.signInAnonymously()).user)!.uid;

    if (code == null) {
      // Rules refuse to overwrite an existing game, so a clash just rolls again.
      for (var tries = 0; seat == null; tries++) {
        final c = _newCode();
        try {
          await _db.ref('games/$c').set({
            'seats': {'p1': uid},
            'size': game.size.name,
            'state': {...game.toJson(), 'v': 0},
          });
          code = c;
          seat = 1;
        } on FirebaseException {
          if (tries >= 4) rethrow;
        }
      }
    } else {
      final seats = _plain((await _game.child('seats').get()).value) as Map<String, dynamic>?;
      if (seats == null) return _fail('No game with code $code.');
      // Games from before sizes existed were all on the 7-row board.
      final size = (await _game.child('size').get()).value as String? ?? BoardSize.small.name;
      game = Game(_words, size: BoardSize.values.asNameMap()[size] ?? BoardSize.normal);
      if (seats['p1'] == uid) {
        seat = 1;
      } else if (seats['p2'] == uid) {
        seat = 2;
      } else {
        // The empty second seat goes to whoever reaches it first; if it's
        // taken, this device picks between watching and taking over.
        final r = await _game
            .child('seats/p2')
            .runTransaction((v) => v == null ? Transaction.success(uid) : Transaction.abort());
        if (r.committed) {
          seat = 2;
        } else {
          choosing = true;
        }
      }
    }
    if (_closed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastKey, code!);

    if (seat != null) _presence = _game.child('online/p$seat');
    _subs
      ..add(_db.ref('.info/connected').onValue.listen((e) {
        _connected = e.snapshot.value == true;
        if (_connected) _announce();
        link = _connected ? Link.live : Link.reconnecting;
        notifyListeners();
      }))
      ..add(_game.child('state').onValue.listen(_onState, onError: (Object e) => _fail(_describe(e))))
      ..add(_game.child('draft').onValue.listen((e) {
        _draft = _plain(e.snapshot.value) as Map<String, dynamic>?;
        if (_showDraft()) notifyListeners();
      }))
      ..add(_game.child('online').onValue.listen((e) {
        _online = _plain(e.snapshot.value) as Map<String, dynamic>? ?? {};
        notifyListeners();
      }))
      ..add(_game.child('seats').onValue.listen(_onSeats));
  }

  /// Marks this device's seat as online until it disconnects.
  void _announce() {
    final p = _presence;
    if (p == null || !_connected) return;
    p.onDisconnect().remove();
    p.set(true).catchError((_) {});
  }

  void _onSeats(DatabaseEvent e) {
    _seats = _plain(e.snapshot.value) as Map<String, dynamic>? ?? {};
    final s = seat;
    if (s != null && _seats['p$s'] != _uid) {
      // Another device took this seat. It now owns the presence flag too.
      _presence?.onDisconnect().cancel().catchError((_) {});
      _presence = null;
      seat = null;
      spectating = true;
      notice = 'Someone took over ${names[s]} on another device. You are now watching.';
      _showDraft();
    }
    notifyListeners();
  }

  /// Watch the game without playing.
  void spectate() {
    choosing = false;
    spectating = true;
    notice = null;
    _showDraft();
    notifyListeners();
  }

  /// Goes back to the choice between watching and taking a seat.
  void chooseSeat() {
    if (seat != null) return;
    spectating = false;
    choosing = true;
    notifyListeners();
  }

  /// Takes seat [p], replacing whoever is in it.
  Future<void> takeSeat(int p) async {
    error = null;
    try {
      await _game.child('seats/p$p').set(_uid);
    } on FirebaseException catch (e) {
      error = _describe(e);
      notifyListeners();
      return;
    }
    if (_closed) return;
    seat = p;
    choosing = spectating = false;
    notice = null;
    game.sel = [];
    _presence = _game.child('online/p$p');
    _announce();
    _showDraft();
    notifyListeners();
  }

  void _onState(DatabaseEvent e) {
    final j = _plain(e.snapshot.value) as Map<String, dynamic>?;
    if (j == null) return;
    _version = j['v'] as int;
    final moves = game.log.length, turn = game.turn;
    final keep = List.of(game.sel);
    game.loadJson(j);
    final moved = game.log.length != moves || game.turn != turn;
    if (!moved) {
      game.sel = keep; // same position (or our own write echoing back); keep the draft
    } else if (game.fresh.isNotEmpty) {
      onMove?.call();
    }
    _showDraft();
    notifyListeners();
  }

  /// Copies the opponent's shared selection onto the board while it's their
  /// turn. Returns whether it did.
  bool _showDraft() {
    final d = _draft;
    if (game.turn == seat || game.over != null) return false;
    final current = d != null && d['seat'] == game.turn && d['v'] == _version;
    game.sel = current ? [for (final i in d['sel'] as List? ?? []) i as int] : [];
    return true;
  }

  /// Shares this player's current selection with the opponent.
  void shareSelection() {
    if (!myTurn) return;
    _game.child('draft').set({'seat': seat, 'v': _version, 'sel': List.of(game.sel)}).catchError((_) {});
  }

  void _fail(String msg) {
    if (_closed) return;
    link = Link.failed;
    error = msg;
    notifyListeners();
  }

  String _describe(Object e) {
    if (e is FirebaseAuthException && e.code == 'operation-not-allowed') {
      return 'Online play is not set up: enable Anonymous sign-in in Firebase Authentication.';
    }
    if (e is FirebaseException) return e.message ?? "Couldn't reach the game server.";
    return "Couldn't reach the game server.";
  }

  /// Applies [change] locally, then publishes it. Rolls back if the write is refused.
  Future<void> _commit(bool Function() change) async {
    final before = game.toJson();
    if (!change()) return;
    final next = {...game.toJson(), 'v': _version + 1};
    pending = true;
    error = null;
    if (game.fresh.isNotEmpty) onMove?.call();
    notifyListeners();
    try {
      await _game.child('state').set(next);
    } on FirebaseException {
      game.loadJson(before);
      error = 'That move could not be saved. Try again.';
    }
    pending = false;
    shareSelection(); // a refused move clears the selection; tell the opponent
    if (!_closed) notifyListeners();
  }

  void play() {
    if (myTurn) _commit(game.play);
  }

  void pass() {
    if (myTurn) {
      _commit(() {
        game.pass();
        return true;
      });
    }
  }

  void newBoard(bool mock) {
    if (seat == null || game.over == null || pending) return;
    _commit(() {
      game.newGame(mock);
      return true;
    });
  }

  @override
  void dispose() {
    _closed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _presence?.onDisconnect().cancel().catchError((_) {});
    _presence?.remove().catchError((_) {});
    super.dispose();
  }
}
