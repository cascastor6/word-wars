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

/// One seat in an online game stored at games/{code} in the Realtime Database.
/// Each device signs in anonymously; its user id is its seat, so reopening the
/// link on the same device puts the player back in their seat.
///
/// The player whose turn it is applies the move locally and writes the new
/// state. Database rules (database.rules.json) only let that player write,
/// and only on top of the latest version.
class OnlineSession extends ChangeNotifier {
  OnlineSession(Set<String> words, {this.code}) : game = Game(words) {
    _start().catchError((Object e) => _fail(_describe(e)));
  }

  final Game game;
  String? code;
  int? seat;
  Link link = Link.connecting;
  String? error;
  bool pending = false;
  bool opponentJoined = false;
  bool opponentOnline = false;

  /// Called when a new move lands, so the board can animate it.
  VoidCallback? onMove;

  final _db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _databaseUrl);
  final _subs = <StreamSubscription>[];
  DatabaseReference? _presence;
  int _version = 0;
  bool _closed = false;

  bool get myTurn => link == Link.live && seat == game.turn && !pending && game.over == null;

  DatabaseReference get _game => _db.ref('games/$code');

  Future<void> _start() async {
    final auth = FirebaseAuth.instance;
    final uid = (auth.currentUser ?? (await auth.signInAnonymously()).user)!.uid;

    if (code == null) {
      // Rules refuse to overwrite an existing game, so a clash just rolls again.
      for (var tries = 0; seat == null; tries++) {
        final c = _newCode();
        try {
          await _db.ref('games/$c').set({
            'seats': {'p1': uid},
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
      if (seats['p1'] == uid) {
        seat = 1;
      } else if (seats['p2'] == uid) {
        seat = 2;
      } else if (seats['p2'] != null) {
        return _fail('That game already has two players.');
      } else {
        try {
          await _game.child('seats/p2').set(uid);
          seat = 2;
        } on FirebaseException {
          return _fail('That game already has two players.');
        }
      }
    }
    if (_closed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastKey, code!);

    _presence = _game.child('online/p$seat');
    _subs
      ..add(_db.ref('.info/connected').onValue.listen((e) {
        final up = e.snapshot.value == true;
        if (up) {
          _presence!.onDisconnect().remove();
          _presence!.set(true);
        }
        link = up ? Link.live : Link.reconnecting;
        notifyListeners();
      }))
      ..add(_game.child('state').onValue.listen(_onState, onError: (Object e) => _fail(_describe(e))))
      ..add(_game.child('online').onValue.listen((e) {
        final on = _plain(e.snapshot.value) as Map<String, dynamic>?;
        opponentOnline = on?['p${3 - seat!}'] == true;
        notifyListeners();
      }))
      ..add(_game.child('seats/p2').onValue.listen((e) {
        opponentJoined = e.snapshot.value != null;
        notifyListeners();
      }));
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
    notifyListeners();
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
    if (game.over == null || pending) return;
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
    _presence?.onDisconnect().cancel();
    _presence?.remove();
    super.dispose();
  }
}
