import 'package:flutter/material.dart';

import 'package:word_wars/data/online.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/common/widgets/game_button.dart';

/// Shown while creating or joining an online game, or when that failed.
class ConnectingView extends StatelessWidget {
  const ConnectingView({super.key, required this.session, required this.pal});
  final OnlineSession session;
  final Palette pal;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (s.link == Link.failed) ...[
                Text(s.error ?? "Couldn't connect.",
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 16),
                GameButton('Back to menu', pal: pal, turn: 1, primary: true,
                    onPressed: () => Navigator.of(context).maybePop()),
              ] else ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(s.code == null ? 'Creating a game…' : 'Joining game ${s.code}…',
                    style: TextStyle(fontSize: 16, color: pal.muted)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
