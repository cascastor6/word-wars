import 'package:flutter/material.dart';

import 'package:word_wars/data/word_entry.dart';
import 'package:word_wars/presentation/common/palette.dart';

/// "(noun) Feline mammal…", cropped to two lines.
class DefinitionText extends StatelessWidget {
  const DefinitionText(this.entry, {super.key, required this.pal});
  final WordEntry entry;
  final Palette pal;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(children: [
      TextSpan(text: '(${entry.type}) ', style: TextStyle(color: pal.muted, fontStyle: FontStyle.italic)),
      TextSpan(text: entry.definition),
    ]),
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 15, color: pal.ink),
  );
}
