import 'package:flutter/material.dart';

import 'package:word_wars/data/game.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/game/widgets/list_item.dart';

class MoveLog extends StatelessWidget {
  const MoveLog({super.key, required this.log, required this.pal});
  final List<LogEntry> log;
  final Palette pal;

  @override
  Widget build(BuildContext context) {
    if (log.isEmpty) {
      return Text('No moves yet.', style: TextStyle(fontSize: 15, color: pal.muted));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var n = 0; n < log.length; n++) ListItem(marker: '${n + 1}.', child: _line(log[n])),
    ]);
  }

  Widget _line(LogEntry e) {
    final who = TextSpan(text: names[e.p], style: TextStyle(color: pal.lineOf(e.p), fontWeight: FontWeight.w600));
    String rest;
    if (e.pass) {
      rest = ' passed.';
    } else {
      final o = names[3 - e.p];
      rest = ' played ${e.word} and took ${e.took} hex${e.took == 1 ? '' : 'es'}';
      if (e.steals > 0) rest += ', ${e.steals} from $o';
      rest += '.';
      if (e.cut > 0) rest += " ${e.cut} of $o's hex${e.cut == 1 ? ' was' : 'es were'} cut off.";
    }
    return Text.rich(TextSpan(children: [who, TextSpan(text: rest)]), style: const TextStyle(fontSize: 15));
  }
}
