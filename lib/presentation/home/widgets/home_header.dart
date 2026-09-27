import 'package:flutter/material.dart';

import 'package:word_wars/presentation/common/palette.dart';

/// The logo, title and tagline at the top of the menu.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.pal});
  final Palette pal;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Image.asset('assets/app_logo_transparent.png', height: 92),
      const SizedBox(height: 4),
      const Text(
        'Word Wars',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        'Spell words to claim hexes and surround your rival’s home.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: pal.muted),
      ),
    ],
  );
}
