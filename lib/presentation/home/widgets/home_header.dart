import 'package:flutter/material.dart';

import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/common/widgets/mini_hex.dart';

/// The logo, title and tagline at the top of the menu.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.pal});
  final Palette pal;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          CustomPaint(size: const Size(34, 38), painter: MiniHex(pal.p1)),
          const SizedBox(width: 6),
          CustomPaint(size: const Size(34, 38), painter: MiniHex(pal.p2)),
        ]),
        const SizedBox(height: 12),
        const Text('Word Wars',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Spell words to claim hexes and surround your rival’s home.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: pal.muted)),
      ]);
}
