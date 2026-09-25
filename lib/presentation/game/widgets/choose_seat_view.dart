import 'package:flutter/material.dart';

import 'package:word_wars/data/game.dart';
import 'package:word_wars/data/online.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/common/widgets/game_button.dart';

/// Shown when the game is full and this device isn't in it.
class ChooseSeatView extends StatelessWidget {
  const ChooseSeatView({super.key, required this.session, required this.pal});
  final OnlineSession session;
  final Palette pal;

  @override
  Widget build(BuildContext context) {
    final s = session;
    Widget seatButton(int p) {
      final label = 'Play as ${names[p]}${s.isOnline(p) ? ' (online now)' : ''}';
      return GameButton(label, pal: pal, turn: p, primary: true, onPressed: () => s.takeSeat(p));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Game ${s.code} already has two players',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 10),
                Text(
                  'If one of them is you in another app or browser, take over that seat. '
                  'The other device will switch to watching.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: pal.muted),
                ),
                const SizedBox(height: 20),
                seatButton(1),
                const SizedBox(height: 10),
                seatButton(2),
                const SizedBox(height: 10),
                GameButton('Just watch', pal: pal, turn: 1, onPressed: s.spectate),
                if (s.error != null) ...[
                  const SizedBox(height: 12),
                  Text(s.error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: pal.p2Line)),
                ],
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text('Back to menu', style: TextStyle(color: pal.muted)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
