import 'package:flutter/material.dart';

import 'package:word_wars/data/game.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/common/widgets/game_button.dart';

class SizePicker extends StatelessWidget {
  const SizePicker({super.key, required this.pal, required this.size, required this.onPick});
  final Palette pal;
  final BoardSize size;
  final ValueChanged<BoardSize> onPick;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Field size', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: pal.muted)),
        const SizedBox(height: 8),
        Row(children: [
          for (final s in BoardSize.values) ...[
            if (s != BoardSize.values.first) const SizedBox(width: 8),
            Expanded(
              child: GameButton(s.label, pal: pal, turn: 1, primary: s == size, onPressed: () => onPick(s)),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Text('${size.rows} rows', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: pal.muted)),
      ]);
}
