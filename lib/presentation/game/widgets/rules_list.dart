import 'package:flutter/material.dart';

import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/game/widgets/list_item.dart';

class RulesList extends StatelessWidget {
  const RulesList({super.key, required this.pal});
  final Palette pal;

  static const _rules = [
    "Tap hexes in order to spell a word of 3 or more letters. Each hex can be used once per word, and the hexes don't need to touch each other.",
    'At least one hex in the word must link to your home or your hexes. Hexes can link through each other, so a chain reaching out from your territory counts.',
    'Linked hexes become yours. Unlinked hexes are just borrowed letters and stay as they were.',
    "You can only use an opponent's hex if it links to your territory, and using it takes it.",
    "Hexes that lose their connection to their owner's home turn neutral.",
    "Own 3 of the 4 hexes around your opponent's home to win. If both players pass in a row, whoever owns more hexes wins.",
  ];

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final r in _rules) ListItem(marker: '•', child: Text(r, style: const TextStyle(fontSize: 15))),
        const SizedBox(height: 4),
        Text('Keyboard: Backspace removes the last letter, Escape clears, Enter plays.',
            style: TextStyle(fontSize: 15, color: pal.muted)),
      ]);
}
