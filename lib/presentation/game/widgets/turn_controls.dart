import 'package:flutter/material.dart';

import 'package:word_wars/data/game.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/common/widgets/game_button.dart';

/// The current word, its verdict, and the Clear / Pass / Play buttons.
class TurnControls extends StatelessWidget {
  const TurnControls({
    super.key,
    required this.pal,
    required this.analysis,
    required this.turn,
    required this.yourTurn,
    this.error,
    this.onClear,
    this.onPass,
    this.onPlay,
  });
  final Palette pal;
  final Analysis analysis;
  final int turn;

  /// Says "Your turn" instead of naming the player, for online and CPU games.
  final bool yourTurn;

  /// Shown in place of the word's verdict.
  final String? error;
  final VoidCallback? onClear, onPass, onPlay;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final err = error;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text.rich(
        TextSpan(children: [
          if (yourTurn)
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
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: 34 * .12)),
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
        Expanded(flex: 10, child: GameButton('Clear', pal: pal, turn: turn, onPressed: onClear)),
        const SizedBox(width: 8),
        Expanded(flex: 10, child: GameButton('Pass', pal: pal, turn: turn, onPressed: onPass)),
        const SizedBox(width: 8),
        Expanded(flex: 16, child: GameButton('Play word', pal: pal, turn: turn, primary: true, onPressed: onPlay)),
      ]),
    ]);
  }
}
