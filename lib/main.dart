import 'dart:async';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import 'firebase_options.dart';
import 'game.dart';
import 'online.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final raw = await rootBundle.loadString('assets/words.txt');
  final words = raw.split('\n').map((w) => w.trim()).where((w) => w.isNotEmpty).toSet();
  runApp(HexWordDuelApp(words: words));
}

/// Colour tokens, mirroring the light and dark palettes of the original page.
class Palette {
  const Palette({
    required this.bg, required this.ink, required this.muted, required this.line,
    required this.hex, required this.soft,
    required this.p1, required this.p1Line, required this.p1Tint,
    required this.p2, required this.p2Line, required this.p2Tint,
  });
  final Color bg, ink, muted, line, hex, soft;
  final Color p1, p1Line, p1Tint, p2, p2Line, p2Tint;

  static const light = Palette(
    bg: Color(0xFFFFFFFF), ink: Color(0xFF1D1D1F), muted: Color(0xFF6C6C72),
    line: Color(0xFF1D1D1F), hex: Color(0xFFFFFFFF), soft: Color(0xFFF1F1F3),
    p1: Color(0xFF1B0AA6), p1Line: Color(0xFF1B0AA6), p1Tint: Color(0xFFE5E2FB),
    p2: Color(0xFFEE3535), p2Line: Color(0xFFE02424), p2Tint: Color(0xFFFDE2E2),
  );
  static const dark = Palette(
    bg: Color(0xFF131315), ink: Color(0xFFF1F1F3), muted: Color(0xFF9B9BA3),
    line: Color(0xFFD4D4DA), hex: Color(0xFF1E1E22), soft: Color(0xFF26262B),
    p1: Color(0xFF3B2DE0), p1Line: Color(0xFF8F86FF), p1Tint: Color(0xFF29245E),
    p2: Color(0xFFE23A3A), p2Line: Color(0xFFFF7B7B), p2Tint: Color(0xFF4B2126),
  );

  Color fill(int p) => p == 1 ? p1 : p2;
  Color lineOf(int p) => p == 1 ? p1Line : p2Line;
  Color tint(int p) => p == 1 ? p1Tint : p2Tint;
}

Palette paletteOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Palette.dark : Palette.light;

class HexWordDuelApp extends StatefulWidget {
  const HexWordDuelApp({super.key, required this.words});
  final Set<String> words;

  @override
  State<HexWordDuelApp> createState() => _HexWordDuelAppState();
}

class _HexWordDuelAppState extends State<HexWordDuelApp> {
  final nav = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? links;
  String? lastOpened;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // On the web an invite link is simply the page address.
      final code = codeFromLink(Uri.base);
      if (code != null) WidgetsBinding.instance.addPostFrameCallback((_) => openInvite(code));
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      // The stream also delivers the link that launched the app.
      links = AppLinks().uriLinkStream.listen((uri) {
        final code = codeFromLink(uri);
        if (code != null) openInvite(code);
      });
    }
  }

  @override
  void dispose() {
    links?.cancel();
    super.dispose();
  }

  void openInvite(String code) {
    final n = nav.currentState;
    if (n == null) return;
    if (code == lastOpened && n.canPop()) return; // already in that game
    lastOpened = code;
    n.popUntil((r) => r.isFirst);
    n.push(MaterialPageRoute(
        builder: (_) => GameScreen(words: widget.words, online: OnlineSession(widget.words, code: code))));
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) {
      final pal = b == Brightness.dark ? Palette.dark : Palette.light;
      return ThemeData(
        brightness: b,
        scaffoldBackgroundColor: pal.bg,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData(brightness: b).textTheme)
            .apply(bodyColor: pal.ink, displayColor: pal.ink),
      );
    }

    return MaterialApp(
      title: 'Word Wars',
      navigatorKey: nav,
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: HomeScreen(words: widget.words, onJoin: openInvite),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.words, required this.onJoin});
  final Set<String> words;
  final void Function(String code) onJoin;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? resume;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final r = await lastOnlineGame();
    if (mounted) setState(() => resume = r);
  }

  Future<void> open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    refresh();
  }

  Future<void> askForCode() async {
    final ctl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a game'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Game code or link'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctl.text), child: const Text('Join')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    final t = code.trim();
    final parsed = t.contains('/') ? codeFromLink(Uri.parse(t)) : t.toUpperCase();
    if (parsed != null) widget.onJoin(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final pal = paletteOf(context);
    final resume = this.resume;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CustomPaint(size: const Size(34, 38), painter: _MiniHex(pal.p1)),
                    const SizedBox(width: 6),
                    CustomPaint(size: const Size(34, 38), painter: _MiniHex(pal.p2)),
                  ]),
                  const SizedBox(height: 12),
                  const Text('Word Wars',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Spell words to claim hexes and surround your rival’s home.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: pal.muted)),
                  const SizedBox(height: 28),
                  GameButton('Play on this device', pal: pal, turn: 1, primary: true,
                      onPressed: () => open(GameScreen(words: widget.words))),
                  const SizedBox(height: 10),
                  GameButton('Invite a friend with a link', pal: pal, turn: 2, primary: true,
                      onPressed: () => open(GameScreen(words: widget.words, online: OnlineSession(widget.words)))),
                  const SizedBox(height: 10),
                  GameButton('Join with a code', pal: pal, turn: 1, onPressed: askForCode),
                  if (resume != null) ...[
                    const SizedBox(height: 10),
                    GameButton('Resume online game $resume', pal: pal, turn: 1,
                        onPressed: () => widget.onJoin(resume)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.words, this.online});
  final Set<String> words;

  /// Set for a game played over a link; null for two players on one device.
  final OnlineSession? online;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final OnlineSession? online = widget.online;
  late final Game game = online?.game ?? Game(widget.words);
  late final AnimationController pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450), value: 1);
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    online?.addListener(_onlineChanged);
    online?.onMove = () {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) pop.forward(from: 0);
    };
  }

  void _onlineChanged() => setState(() {});

  @override
  void dispose() {
    online?.removeListener(_onlineChanged);
    online?.dispose();
    pop.dispose();
    focus.dispose();
    super.dispose();
  }

  /// Whether this device may change the selection or move right now.
  bool get canAct => online == null ? game.over == null : online!.myTurn;

  void act(void Function() f) {
    setState(f);
    focus.requestFocus();
  }

  void doPlay() => act(() {
        if (online != null) return online!.play();
        if (game.play() && !MediaQuery.disableAnimationsOf(context)) pop.forward(from: 0);
      });

  void doPass() => act(() => online != null ? online!.pass() : game.pass());

  void newBoard() => act(() => online != null ? online!.newBoard(false) : game.newGame(false));

  KeyEventResult onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent || !canAct) return KeyEventResult.ignored;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.backspace:
        act(game.backspace);
      case LogicalKeyboardKey.escape:
        act(game.clear);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        doPlay();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final pal = paletteOf(context);
    final online = this.online;
    if (online != null && online.seat == null) return _connecting(pal, online);
    final a = game.analyze();
    final turn = game.turn;
    final over = game.over;

    return Scaffold(
      body: Focus(
        focusNode: focus,
        autofocus: true,
        onKeyEvent: onKey,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _topBar(pal),
                      if (online != null) _onlineBanner(pal, online),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: PlayerChip(game: game, p: 1, pal: pal, you: online?.seat == 1)),
                        const SizedBox(width: 10),
                        Expanded(child: PlayerChip(game: game, p: 2, pal: pal, you: online?.seat == 2)),
                      ]),
                      const SizedBox(height: 14),
                      Board(game: game, analysis: a, pal: pal, pop: pop,
                          onTap: (i) {
                            if (canAct) act(() => game.tap(i));
                          }),
                      const SizedBox(height: 6),
                      if (over == null) ..._playSection(pal, a, turn) else ..._overSection(pal, over),
                      const SizedBox(height: 18),
                      Disclosure(title: 'Rules', pal: pal, initiallyOpen: false, child: _rules(pal)),
                      const SizedBox(height: 18),
                      Disclosure(title: 'Moves', pal: pal, initiallyOpen: true, child: _log(pal)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(Palette pal) => Row(children: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back, size: 20, color: pal.ink),
          label: Text('Menu', style: TextStyle(color: pal.ink, fontSize: 15)),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
        ),
      ]);

  Future<void> share(String code) async {
    final link = inviteLink(code).toString();
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
    try {
      await SharePlus.instance.share(ShareParams(text: 'Play Word Wars with me: $link'));
    } catch (_) {
      // Copying is enough when there's no share sheet.
    }
  }

  Widget _onlineBanner(Palette pal, OnlineSession s) {
    final code = s.code!;
    final opp = names[3 - s.seat!]!;
    final String status;
    if (s.link == Link.reconnecting) {
      status = 'Connection lost. Reconnecting…';
    } else if (s.link == Link.failed) {
      status = s.error ?? 'Disconnected.';
    } else if (!s.opponentJoined) {
      status = 'Send this link to your friend. They play as $opp.';
    } else if (!s.opponentOnline) {
      status = '$opp is offline. The game will continue when they come back.';
    } else {
      status = 'Online game $code. You are ${names[s.seat]}.';
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(color: pal.soft, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!s.opponentJoined)
              SelectableText(inviteLink(code).toString(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(status, style: TextStyle(fontSize: 14, color: pal.muted)),
          ]),
        ),
        IconButton(
          tooltip: 'Share invite link',
          onPressed: () => share(code),
          icon: Icon(Icons.ios_share, color: pal.ink),
        ),
      ]),
    );
  }

  Widget _connecting(Palette pal, OnlineSession s) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (s.link == Link.failed) ...[
                  Text(s.error ?? "Couldn't connect.",
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
                  const SizedBox(height: 16),
                  GameButton('Back to menu', pal: pal, turn: 1, primary: true,
                      onPressed: () => Navigator.of(context).maybePop()),
                ] else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(s.code == null ? 'Creating a game…' : 'Joining game ${s.code}…',
                      style: TextStyle(fontSize: 16, color: pal.muted)),
                ],
              ]),
            ),
          ),
        ),
      );

  List<Widget> _playSection(Palette pal, Analysis a, int turn) {
    final online = this.online;
    if (online != null && online.seat != turn) {
      return [
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Waiting for '),
            TextSpan(text: names[turn], style: TextStyle(color: pal.lineOf(turn), fontWeight: FontWeight.w700)),
            const TextSpan(text: ' to play…'),
          ]),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: pal.muted),
        ),
        const SizedBox(height: 90),
      ];
    }
    final err = online?.error;
    return [
        Text.rich(
          TextSpan(children: [
            if (online != null)
              TextSpan(text: 'Your turn', style: TextStyle(color: pal.lineOf(turn), fontWeight: FontWeight.w700))
            else ...[
              TextSpan(text: names[turn], style: TextStyle(color: pal.lineOf(turn), fontWeight: FontWeight.w700)),
              const TextSpan(text: "'s turn"),
            ],
          ]),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: pal.muted),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 48,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(a.word,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: 34 * .12)),
          ),
        ),
        const SizedBox(height: 2),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Text(err ?? a.msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: err != null ? pal.p2Line : a.ok ? pal.ink : pal.muted)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(flex: 10, child: GameButton('Clear', pal: pal, turn: turn,
              onPressed: game.sel.isEmpty || !canAct ? null : () => act(game.clear))),
          const SizedBox(width: 8),
          Expanded(flex: 10, child: GameButton('Pass', pal: pal, turn: turn, onPressed: canAct ? doPass : null)),
          const SizedBox(width: 8),
          Expanded(flex: 16, child: GameButton('Play word', pal: pal, turn: turn, primary: true,
              onPressed: a.ok && canAct ? doPlay : null)),
        ]),
      ];
  }

  List<Widget> _overSection(Palette pal, GameOver over) => [
        const SizedBox(height: 6),
        Text(over.winner != 0 ? '${names[over.winner]} wins' : "It's a draw",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15)),
        const SizedBox(height: 4),
        Text(over.why, textAlign: TextAlign.center, style: TextStyle(color: pal.muted, fontSize: 16)),
        const SizedBox(height: 14),
        GameButton('New board', pal: pal, turn: game.turn, primary: true, onPressed: newBoard),
      ];

  Widget _rules(Palette pal) {
    const rules = [
      "Tap hexes in order to spell a word of 3 or more letters. Each hex can be used once per word, and the hexes don't need to touch each other.",
      'At least one hex in the word must link to your home or your hexes. Hexes can link through each other, so a chain reaching out from your territory counts.',
      'Linked hexes become yours. Unlinked hexes are just borrowed letters and stay as they were.',
      "You can only use an opponent's hex if it links to your territory, and using it takes it.",
      "Hexes that lose their connection to their owner's home turn neutral.",
      "Own 3 of the 4 hexes around your opponent's home to win. If both players pass in a row, whoever owns more hexes wins.",
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final r in rules) ListItem(marker: '•', child: Text(r, style: const TextStyle(fontSize: 15))),
      const SizedBox(height: 4),
      Text('Keyboard: Backspace removes the last letter, Escape clears, Enter plays.',
          style: TextStyle(fontSize: 15, color: pal.muted)),
    ]);
  }

  Widget _log(Palette pal) {
    if (game.log.isEmpty) {
      return Text('No moves yet.', style: TextStyle(fontSize: 15, color: pal.muted));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var n = 0; n < game.log.length; n++) ListItem(marker: '${n + 1}.', child: _logLine(pal, game.log[n])),
    ]);
  }

  Widget _logLine(Palette pal, LogEntry e) {
    final who = TextSpan(text: names[e.p], style: TextStyle(color: pal.lineOf(e.p), fontWeight: FontWeight.w600));
    String rest;
    if (e.pass) {
      rest = ' passed.';
    } else {
      final o = names[3 - e.p];
      rest = ' played ${e.word} and took ${e.took} hex${e.took == 1 ? '' : 'es'}';
      if (e.steals > 0) rest += ', ${e.steals} from $o';
      rest += '.';
      if (e.cut > 0) rest += " ${e.cut} of $o's hex${e.cut == 1 ? ' was' : 'es were'} cut off.";
    }
    return Text.rich(TextSpan(children: [who, TextSpan(text: rest)]), style: const TextStyle(fontSize: 15));
  }
}

class ListItem extends StatelessWidget {
  const ListItem({super.key, required this.marker, required this.child});
  final String marker;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 22, child: Text(marker, style: const TextStyle(fontSize: 15))),
          Expanded(child: child),
        ]),
      );
}

class GameButton extends StatelessWidget {
  const GameButton(this.label, {super.key, required this.pal, required this.turn, this.onPressed, this.primary = false});
  final String label;
  final Palette pal;
  final int turn;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final border = primary ? pal.fill(turn) : pal.line;
    return Opacity(
      opacity: onPressed == null ? .35 : 1,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: primary ? pal.fill(turn) : Colors.transparent,
          foregroundColor: primary ? Colors.white : pal.ink,
          disabledForegroundColor: primary ? Colors.white : pal.ink,
          disabledBackgroundColor: primary ? pal.fill(turn) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: border, width: 2),
          ),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class Disclosure extends StatefulWidget {
  const Disclosure({super.key, required this.title, required this.pal, required this.child, required this.initiallyOpen});
  final String title;
  final Palette pal;
  final Widget child;
  final bool initiallyOpen;

  @override
  State<Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<Disclosure> {
  late bool open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: widget.pal.soft))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => setState(() => open = !open),
            child: Row(children: [
              AnimatedRotation(
                turns: open ? .25 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.arrow_right, size: 22, color: widget.pal.ink),
              ),
              Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (open) Padding(padding: const EdgeInsets.only(top: 10), child: widget.child),
        ]),
      );
}

// ---------- geometry ----------

const double _dx = 0.8660254037844386 * 40; // sqrt(3)/2 * 40
const double _dy = 60;
const double _r = 38;
const Rect _viewBox = Rect.fromLTWH(-40, -44, 426.4, 448);

Path hexPath(double r) {
  final p = Path();
  for (var k = 0; k < 6; k++) {
    final a = pi / 180 * (60 * k - 90);
    final pt = Offset(r * cos(a), r * sin(a));
    k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

Offset centerOf(Cell x) => Offset(x.c * _dx, x.r * _dy);

class PlayerChip extends StatelessWidget {
  const PlayerChip({super.key, required this.game, required this.p, required this.pal, this.you = false});
  final Game game;
  final int p;
  final Palette pal;
  final bool you;

  @override
  Widget build(BuildContext context) {
    final pr = game.pressureOn(p);
    final n = game.countOf(p);
    final active = game.over == null && game.turn == p;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? pal.lineOf(p) : Colors.transparent, width: 2),
      ),
      child: Row(children: [
        CustomPaint(size: const Size(26, 30), painter: _MiniHex(pal.fill(p))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(you ? '${names[p]} (you)' : names[p]!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, height: 1.1)),
            Text('$n hex${n == 1 ? '' : 'es'}', style: TextStyle(fontSize: 13, color: pal.muted, height: 1.3)),
            Text('Home $pr of 3 lost',
                style: TextStyle(
                  fontSize: 13, height: 1.3,
                  color: pr >= 2 ? pal.lineOf(3 - p) : pal.muted,
                  fontWeight: pr >= 2 ? FontWeight.w600 : FontWeight.w400,
                )),
          ]),
        ),
      ]),
    );
  }
}

class _MiniHex extends CustomPainter {
  _MiniHex(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 40);
    canvas.drawPath(hexPath(_r * .52), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MiniHex old) => old.color != color;
}

class Board extends StatelessWidget {
  const Board({super.key, required this.game, required this.analysis, required this.pal, required this.pop, required this.onTap});
  final Game game;
  final Analysis analysis;
  final Palette pal;
  final Animation<double> pop;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _viewBox.width / _viewBox.height,
      child: LayoutBuilder(builder: (context, box) {
        final scale = box.maxWidth / _viewBox.width;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final pt = d.localPosition / scale + _viewBox.topLeft;
            final hex = hexPath(_r);
            for (var i = 0; i < game.cells.length; i++) {
              final x = game.cells[i];
              if (x.home == 0 && hex.contains(pt - centerOf(x))) onTap(i);
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: CustomPaint(
              size: Size(box.maxWidth, box.maxWidth / _viewBox.width * _viewBox.height),
              painter: BoardPainter(game, analysis, pal, pop),
            ),
          ),
        );
      }),
    );
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter(this.game, this.a, this.pal, this.pop) : super(repaint: pop);
  final Game game;
  final Analysis a;
  final Palette pal;
  final Animation<double> pop;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _viewBox.width);
    canvas.translate(-_viewBox.left, -_viewBox.top);
    final hex = hexPath(_r);
    final t = Curves.easeOut.transform(pop.value);
    final cur = game.turn;

    // Unselected hexes first, then selected ones in order so their outlines sit on top.
    final order = [
      for (var i = 0; i < game.cells.length; i++)
        if (!game.sel.contains(i)) i,
      ...game.sel,
    ];

    for (final i in order) {
      final x = game.cells[i];
      canvas.save();
      canvas.translate(centerOf(x).dx, centerOf(x).dy);

      final k = game.sel.indexOf(i);
      final selected = k > -1;
      final linked = a.linked.contains(i);
      final owned = x.owner != 0 || x.home != 0;

      Color fill = pal.hex;
      if (x.home != 0) {
        fill = pal.fill(x.home);
      } else if (x.owner != 0) {
        fill = pal.fill(x.owner);
      } else if (selected && linked) {
        fill = pal.tint(cur);
      }
      canvas.drawPath(hex, Paint()..color = fill);

      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.miter
        ..color = selected ? pal.lineOf(cur) : pal.line
        ..strokeWidth = selected ? 4.5 : 2;
      canvas.drawPath(selected && !linked ? _dashed(hex, 7, 5) : hex, stroke);

      if (x.home != 0) {
        _drawHouse(canvas, pal.fill(x.home));
      } else {
        final isFresh = game.fresh.contains(i) && t < 1;
        final s = isFresh ? .3 + .7 * t : 1.0;
        final op = isFresh ? t : 1.0;
        _text(canvas, x.letter, const Offset(0, 1), 21, FontWeight.w500,
            (owned ? Colors.white : pal.ink).withValues(alpha: op), scale: s);
        if (selected) {
          _text(canvas, '${k + 1}', const Offset(0, -22.5), 10, FontWeight.w700,
              owned ? Colors.white : pal.lineOf(cur));
        }
      }
      canvas.restore();
    }
  }

  void _text(Canvas canvas, String s, Offset c, double size, FontWeight w, Color color, {double scale = 1}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: GoogleFonts.outfit(fontSize: size, fontWeight: w, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _drawHouse(Canvas canvas, Color door) {
    final white = Paint()..color = Colors.white;
    canvas.drawPath(
      Path()..moveTo(-15, 1)..lineTo(0, -13)..lineTo(15, 1),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawRect(const Rect.fromLTWH(6, -13, 4, 8), white);
    canvas.drawPath(
        Path()..moveTo(-10, -1)..lineTo(0, -10)..lineTo(10, -1)..lineTo(10, 13)..lineTo(-10, 13)..close(), white);
    canvas.drawRect(const Rect.fromLTWH(-3.5, 4, 7, 9), Paint()..color = door);
  }

  Path _dashed(Path src, double on, double off) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, min(d + on, m.length)), Offset.zero);
        d += on + off;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}
