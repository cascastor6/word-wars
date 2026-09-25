import 'package:flutter/material.dart';

import 'package:word_wars/presentation/common/palette.dart';

/// The "Menu" back button above the board.
class GameTopBar extends StatelessWidget {
  const GameTopBar({super.key, required this.pal});
  final Palette pal;

  @override
  Widget build(BuildContext context) => Row(children: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back, size: 20, color: pal.ink),
          label: Text('Menu', style: TextStyle(color: pal.ink, fontSize: 15)),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
        ),
      ]);
}
