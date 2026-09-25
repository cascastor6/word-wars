import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_wars/data/cpu.dart';
import 'package:word_wars/data/game.dart';
import 'package:word_wars/data/online.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/common/widgets/game_button.dart';
import 'package:word_wars/presentation/game/game_screen.dart';
import 'package:word_wars/presentation/home/widgets/home_header.dart';
import 'package:word_wars/presentation/home/widgets/join_code_dialog.dart';
import 'package:word_wars/presentation/home/widgets/play_on_device_dialog.dart';
import 'package:word_wars/presentation/home/widgets/size_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.words, required this.onJoin});
  final Set<String> words;
  final void Function(String code) onJoin;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const _sizeKey = 'board.size';
const _levelKey = 'cpu.level';

class _HomeScreenState extends State<HomeScreen> {
  String? resume;
  BoardSize size = BoardSize.normal;
  Difficulty level = Difficulty.medium;

  @override
  void initState() {
    super.initState();
    refresh();
    loadSize();
  }

  Future<void> loadSize() async {
    final prefs = await SharedPreferences.getInstance();
    final s = BoardSize.values.asNameMap()[prefs.getString(_sizeKey)];
    final l = Difficulty.values.asNameMap()[prefs.getString(_levelKey)];
    if (!mounted) return;
    setState(() {
      if (s != null) size = s;
      if (l != null) level = l;
    });
  }

  Future<void> pickSize(BoardSize s) async {
    setState(() => size = s);
    await (await SharedPreferences.getInstance()).setString(_sizeKey, s.name);
  }

  Future<void> pickLevel(Difficulty l) async {
    setState(() => level = l);
    await (await SharedPreferences.getInstance()).setString(_levelKey, l.name);
  }

  Future<void> refresh() async {
    final r = await lastOnlineGame();
    if (mounted) setState(() => resume = r);
  }

  Future<void> open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    refresh();
  }

  /// Asks whether to play a friend on this device or the computer, then starts the game.
  Future<void> playOnDevice() async {
    final vsCpu = await showPlayOnDeviceDialog(context, level: level, onLevel: pickLevel);
    if (vsCpu == null) return;
    open(GameScreen(words: widget.words, size: size, cpu: vsCpu ? level : null));
  }

  Future<void> askForCode() async {
    final code = await showJoinCodeDialog(context);
    if (code != null) widget.onJoin(code);
  }

  @override
  Widget build(BuildContext context) {
    final pal = paletteOf(context);
    final resume = this.resume;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  HomeHeader(pal: pal),
                  const SizedBox(height: 28),
                  GameButton('Play on this device', pal: pal, turn: 1, primary: true, onPressed: playOnDevice),
                  const SizedBox(height: 10),
                  GameButton('Invite a friend with a link', pal: pal, turn: 2, primary: true,
                      onPressed: () => open(GameScreen(words: widget.words, online: OnlineSession(widget.words, size: size)))),
                  const SizedBox(height: 10),
                  GameButton('Join with a code', pal: pal, turn: 1, onPressed: askForCode),
                  if (resume != null) ...[
                    const SizedBox(height: 10),
                    GameButton('Resume online game $resume', pal: pal, turn: 1,
                        onPressed: () => widget.onJoin(resume)),
                  ],
                  const SizedBox(height: 28),
                  SizePicker(pal: pal, size: size, onPick: pickSize),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
