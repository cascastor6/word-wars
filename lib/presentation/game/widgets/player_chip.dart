import 'package:flutter/material.dart';

import 'package:word_wars/data/game.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/common/widgets/mini_hex.dart';

class PlayerChip extends StatelessWidget {
  const PlayerChip({super.key, required this.game, required this.p, required this.pal, this.tag});
  final Game game;
  final int p;
  final Palette pal;

  /// Shown after the name, like "you" or "CPU".
  final String? tag;

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
        CustomPaint(size: const Size(26, 30), painter: MiniHex(pal.fill(p))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tag != null ? '${names[p]} ($tag)' : names[p]!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, height: 1.1)),
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
