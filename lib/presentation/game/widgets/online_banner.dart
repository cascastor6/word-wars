import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:word_wars/data/game.dart';
import 'package:word_wars/data/online.dart';
import 'package:word_wars/presentation/common/palette.dart';

/// Connection status and invite link for an online game.
class OnlineBanner extends StatelessWidget {
  const OnlineBanner({super.key, required this.session, required this.pal});
  final OnlineSession session;
  final Palette pal;

  Future<void> _share(BuildContext context, String code) async {
    final link = inviteLink(code).toString();
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
    try {
      await SharePlus.instance.share(ShareParams(text: 'Play Word Wars with me: $link'));
    } catch (_) {
      // Copying is enough when there's no share sheet.
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    final code = s.code!;
    final seat = s.seat;
    final String status;
    if (s.link == Link.reconnecting) {
      status = 'Connection lost. Reconnecting…';
    } else if (s.link == Link.failed) {
      status = s.error ?? 'Disconnected.';
    } else if (seat == null) {
      status = s.notice ?? 'Watching game $code.';
    } else if (!s.opponentJoined) {
      status = 'Send this link to your friend. They play as ${names[3 - seat]}.';
    } else if (!s.opponentOnline) {
      status = '${names[3 - seat]} is offline. The game will continue when they come back.';
    } else {
      status = 'Online game $code. You are ${names[seat]}.';
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(color: pal.soft, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!s.opponentJoined)
              SelectableText(inviteLink(code).toString(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(status, style: TextStyle(fontSize: 14, color: pal.muted)),
          ]),
        ),
        if (seat == null)
          TextButton(
            onPressed: s.link == Link.live ? s.chooseSeat : null,
            child: Text('Take a seat', style: TextStyle(color: pal.ink, fontWeight: FontWeight.w600)),
          ),
        IconButton(
          tooltip: 'Share invite link',
          onPressed: () => _share(context, code),
          icon: Icon(Icons.ios_share, color: pal.ink),
        ),
      ]),
    );
  }
}
