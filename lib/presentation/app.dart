import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:word_wars/data/online.dart';
import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/game/game_screen.dart';
import 'package:word_wars/presentation/home/home_screen.dart';

class HexWordDuelApp extends StatefulWidget {
  const HexWordDuelApp({super.key, required this.words});
  final Set<String> words;

  @override
  State<HexWordDuelApp> createState() => _HexWordDuelAppState();
}

class _HexWordDuelAppState extends State<HexWordDuelApp> {
  final nav = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? links;
  String? lastOpened;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // On the web an invite link is simply the page address.
      final code = codeFromLink(Uri.base);
      if (code != null) WidgetsBinding.instance.addPostFrameCallback((_) => openInvite(code));
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      // The stream also delivers the link that launched the app.
      links = AppLinks().uriLinkStream.listen((uri) {
        final code = codeFromLink(uri);
        if (code != null) openInvite(code);
      });
    }
  }

  @override
  void dispose() {
    links?.cancel();
    super.dispose();
  }

  void openInvite(String code) {
    final n = nav.currentState;
    if (n == null) return;
    if (code == lastOpened && n.canPop()) return; // already in that game
    lastOpened = code;
    n.popUntil((r) => r.isFirst);
    n.push(MaterialPageRoute(
        builder: (_) => GameScreen(words: widget.words, online: OnlineSession(widget.words, code: code))));
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) {
      final pal = b == Brightness.dark ? Palette.dark : Palette.light;
      return ThemeData(
        brightness: b,
        scaffoldBackgroundColor: pal.bg,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData(brightness: b).textTheme)
            .apply(bodyColor: pal.ink, displayColor: pal.ink),
      );
    }

    return MaterialApp(
      title: 'Word Wars',
      navigatorKey: nav,
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: HomeScreen(words: widget.words, onJoin: openInvite),
    );
  }
}
