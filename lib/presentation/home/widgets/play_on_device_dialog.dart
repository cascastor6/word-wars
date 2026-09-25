import 'package:flutter/material.dart';

import 'package:word_wars/data/cpu.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/common/widgets/game_button.dart';

/// Asks whether to play a friend on this device or the computer.
///
/// Returns true for the computer, false for a friend, or null if cancelled.
/// Picking a CPU level calls [onLevel] straight away.
Future<bool?> showPlayOnDeviceDialog(BuildContext context,
    {required Difficulty level, required ValueChanged<Difficulty> onLevel}) {
  var current = level;
  return showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
      final pal = paletteOf(context);
      return AlertDialog(
        title: const Text('Play on this device'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GameButton('Local versus', pal: pal, turn: 1, primary: true, onPressed: () => Navigator.pop(context, false)),
          const SizedBox(height: 10),
          GameButton('Versus CPU', pal: pal, turn: 2, primary: true, onPressed: () => Navigator.pop(context, true)),
          const SizedBox(height: 14),
          Text('CPU level', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: pal.muted)),
          const SizedBox(height: 8),
          Row(children: [
            for (final l in Difficulty.values) ...[
              if (l != Difficulty.values.first) const SizedBox(width: 8),
              Expanded(
                child: GameButton(l.label, pal: pal, turn: 2, primary: l == current,
                    onPressed: () {
                      onLevel(l);
                      setDialogState(() => current = l);
                    }),
              ),
            ],
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      );
    }),
  );
}
