import 'package:flutter/material.dart';

import 'package:word_wars/data/game.dart';
import 'package:word_wars/presentation/common/palette.dart';

/// Shown while the opponent or the computer takes their turn.
class WaitingPanel extends StatelessWidget {
  const WaitingPanel({super.key, required this.pal, required this.turn, required this.word, required this.thinking});
  final Palette pal;
  final int turn;

  /// The letters they're picking, mirrored live from their device or the computer.
  final String word;

  /// True for the computer, which is "thinking" rather than being waited for.
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final who = TextSpan(text: names[turn], style: TextStyle(color: pal.lineOf(turn), fontWeight: FontWeight.w700));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(children: [
          if (thinking) ...[who, const TextSpan(text: ' is thinking…')]
          else ...[const TextSpan(text: 'Waiting for '), who, const TextSpan(text: ' to play…')],
        ]),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: pal.muted),
      ),
      SizedBox(
        height: 48,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(word,
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: 34 * .12, color: pal.lineOf(turn))),
        ),
      ),
      const SizedBox(height: 42),
    ]);
  }
}
