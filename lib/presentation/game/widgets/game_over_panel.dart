import 'package:flutter/material.dart';

import 'package:word_wars/data/game.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/common/widgets/game_button.dart';

class GameOverPanel extends StatelessWidget {
  const GameOverPanel({super.key, required this.over, required this.pal, required this.turn, this.onNewBoard});
  final GameOver over;
  final Palette pal;
  final int turn;

  /// Null hides the button, e.g. for spectators.
  final VoidCallback? onNewBoard;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 6),
        Text(over.winner != 0 ? '${names[over.winner]} wins' : "It's a draw",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15)),
        const SizedBox(height: 4),
        Text(over.why, textAlign: TextAlign.center, style: TextStyle(color: pal.muted, fontSize: 16)),
        const SizedBox(height: 14),
        if (onNewBoard != null) GameButton('New board', pal: pal, turn: turn, primary: true, onPressed: onNewBoard),
      ]);
}
