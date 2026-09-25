import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:word_wars/data/cpu.dart';
import 'package:word_wars/data/game.dart';
import 'package:word_wars/data/online.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/game/widgets/board.dart';
import 'package:word_wars/presentation/game/widgets/choose_seat_view.dart';
import 'package:word_wars/presentation/game/widgets/connecting_view.dart';
import 'package:word_wars/presentation/game/widgets/disclosure.dart';
import 'package:word_wars/presentation/game/widgets/game_over_panel.dart';
import 'package:word_wars/presentation/game/widgets/game_top_bar.dart';
import 'package:word_wars/presentation/game/widgets/move_log.dart';
import 'package:word_wars/presentation/game/widgets/online_banner.dart';
import 'package:word_wars/presentation/game/widgets/player_chip.dart';
import 'package:word_wars/presentation/game/widgets/rules_list.dart';
import 'package:word_wars/presentation/game/widgets/turn_controls.dart';
import 'package:word_wars/presentation/game/widgets/waiting_panel.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.words, this.online, this.cpu, this.size = BoardSize.normal});
  final Set<String> words;

  /// Set for a game against the computer, which plays [cpuSeat].
  final Difficulty? cpu;
  static const cpuSeat = 2;

  /// Board size for a game on this device. Online games take the host's size.
  final BoardSize size;

  /// Set for a game played over a link; null for two players on one device.
  final OnlineSession? online;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final OnlineSession? online = widget.online;
  late final Game game = online?.game ?? Game(widget.words, size: widget.size);
  late final Cpu? bot = widget.cpu == null ? null : Cpu(widget.words, widget.cpu!);

  /// Bumped to cancel a computer move in progress.
  int _botRun = 0;
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
  bool get canAct => online == null ? game.over == null && !botsTurn : online!.myTurn;

  bool get botsTurn => bot != null && game.turn == GameScreen.cpuSeat;

  void act(void Function() f) {
    setState(f);
    focus.requestFocus();
  }

  /// Changes the selection and, online, lets the opponent see it.
  void select(void Function() f) {
    act(f);
    online?.shareSelection();
  }

  void doPlay() {
    act(() {
      if (online != null) return online!.play();
      if (game.play()) _popIn();
    });
    _botMove();
  }

  void doPass() {
    act(() => online != null ? online!.pass() : game.pass());
    _botMove();
  }

  void newBoard() {
    _botRun++;
    act(() => online != null ? online!.newBoard(false) : game.newGame(false));
  }

  void _popIn() {
    if (!MediaQuery.disableAnimationsOf(context)) pop.forward(from: 0);
  }

  /// Plays the computer's turn, picking its letters one by one like a person would.
  Future<void> _botMove() async {
    final bot = this.bot;
    if (bot == null || game.over != null || !botsTurn) return;
    final run = ++_botRun;
    bool cancelled() => !mounted || run != _botRun;

    // Let the board show the player's move before the computer thinks.
    await Future.delayed(const Duration(milliseconds: 600));
    if (cancelled()) return;
    final sel = bot.move(game);
    if (sel == null) {
      setState(game.pass);
      return;
    }
    for (final i in sel) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (cancelled()) return;
      setState(() => game.tap(i));
    }
    await Future.delayed(const Duration(milliseconds: 1000));
    if (cancelled()) return;
    setState(() {
      if (game.play()) {
        _popIn();
      } else {
        game.pass(); // shouldn't happen, but never leave the player stuck
      }
    });
  }

  KeyEventResult onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent || !canAct) return KeyEventResult.ignored;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.backspace:
        select(game.backspace);
      case LogicalKeyboardKey.escape:
        select(game.clear);
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
    if (online != null && !online.joined) {
      return online.choosing && online.link != Link.failed
          ? ChooseSeatView(session: online, pal: pal)
          : ConnectingView(session: online, pal: pal);
    }
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
                      GameTopBar(pal: pal),
                      if (online != null) OnlineBanner(session: online, pal: pal),
                      const SizedBox(height: 8),
                      Row(children: [
                        for (final p in [1, 2]) ...[
                          if (p == 2) const SizedBox(width: 10),
                          Expanded(
                            child: PlayerChip(game: game, p: p, pal: pal,
                                tag: online?.seat == p || (bot != null && p != GameScreen.cpuSeat)
                                    ? 'you'
                                    : bot != null ? 'CPU' : null),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 14),
                      Board(game: game, analysis: a, pal: pal, pop: pop,
                          onTap: (i) {
                            if (canAct) select(() => game.tap(i));
                          }),
                      const SizedBox(height: 6),
                      if (over == null) _playSection(pal, a, turn) else _overSection(pal, over),
                      const SizedBox(height: 18),
                      Disclosure(title: 'Rules', pal: pal, initiallyOpen: false, child: RulesList(pal: pal)),
                      const SizedBox(height: 18),
                      Disclosure(title: 'Moves', pal: pal, initiallyOpen: true, child: MoveLog(log: game.log, pal: pal)),
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

  Widget _playSection(Palette pal, Analysis a, int turn) {
    final online = this.online;
    if (online != null && online.seat != turn || botsTurn) {
      return WaitingPanel(pal: pal, turn: turn, word: a.word, thinking: botsTurn);
    }
    return TurnControls(
      pal: pal,
      analysis: a,
      turn: turn,
      yourTurn: online != null || bot != null,
      error: online?.error,
      onClear: game.sel.isEmpty || !canAct ? null : () => select(game.clear),
      onPass: canAct ? doPass : null,
      onPlay: a.ok && canAct ? doPlay : null,
    );
  }

  Widget _overSection(Palette pal, GameOver over) => GameOverPanel(
        over: over,
        pal: pal,
        turn: game.turn,
        onNewBoard: online?.spectating != true ? newBoard : null,
      );
}
