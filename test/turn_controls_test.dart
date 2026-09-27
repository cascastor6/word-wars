import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_wars/data/game.dart';
import 'package:word_wars/data/word_entry.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/game/widgets/turn_controls.dart';
import 'package:word_wars/presentation/game/widgets/waiting_panel.dart';

void main() {
  Widget controls(Analysis a, {WordEntry? definition}) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        child: TurnControls(pal: Palette.dark, analysis: a, turn: 1, yourTurn: false, definition: definition),
      ),
    ),
  );

  testWidgets('a valid word shows its definition instead of the statistics', (tester) async {
    const cat = WordEntry(word: 'CAT', type: 'noun', definition: 'Feline mammal usually having thick soft fur');
    await tester.pumpWidget(controls(Analysis('CAT', {}, true, 'Play CAT to take 3 hexes.', [], 0), definition: cat));
    expect(find.textContaining('(noun) Feline mammal', findRichText: true), findsOneWidget);
    expect(find.text('Play CAT to take 3 hexes.'), findsNothing);
  });

  testWidgets('a long definition is cropped to two lines', (tester) async {
    final long = WordEntry(word: 'CAT', type: 'noun', definition: 'word ' * 200);
    await tester.pumpWidget(controls(Analysis('CAT', {}, true, '', [], 0), definition: long));
    final text = tester.widget<RichText>(find.textContaining('(noun)', findRichText: true));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an invalid word keeps its error message', (tester) async {
    await tester.pumpWidget(controls(Analysis('CXQ', {}, false, "CXQ isn't in the word list.", [], 0)));
    expect(find.text("CXQ isn't in the word list."), findsOneWidget);
  });

  testWidgets("the opponent's valid word shows its definition while you wait", (tester) async {
    const cat = WordEntry(word: 'CAT', type: 'noun', definition: 'Feline mammal usually having thick soft fur');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: WaitingPanel(pal: Palette.dark, turn: 2, word: 'CAT', thinking: true, definition: cat)),
    ));
    expect(find.textContaining('(noun) Feline mammal', findRichText: true), findsOneWidget);
  });
}
