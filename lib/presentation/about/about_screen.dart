import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:word_wars/presentation/common/palette.dart';
import 'package:word_wars/presentation/game/widgets/game_top_bar.dart';

/// Credits for the word data, plus acknowledgements and contact details.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = paletteOf(context);
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GameTopBar(pal: pal),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            'About',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _Para('Developed by Ponch Castor', pal: pal),
                          _Section(
                            'Word data',
                            pal: pal,
                            children: [
                              _Para(
                                'Definitions come from Princeton WordNet 3.1. '
                                'WordNet® is a registered trademark of Princeton University. '
                                'Princeton University, “About WordNet.” WordNet. Princeton University. 2010.',
                                pal: pal,
                              ),
                              _Para(
                                'Words WordNet doesn’t cover are defined by Webster’s Unabridged Dictionary (1913), '
                                'courtesy of Project Gutenberg.',
                                pal: pal,
                              ),
                            ],
                          ),
                          _Section(
                            'Acknowledgements',
                            pal: pal,
                            children: [
                              _Para(
                                'To my dad, because playing Capitals with him inspired me to make this.',
                                pal: pal,
                              ),
                              _ParaRichUrl(
                                [
                                  'Shout out to NimbleLLC for creating',
                                  'Capitals,',
                                  'the game that initially inspired me.',
                                ],
                                url:
                                    'https://apps.apple.com/us/app/capitals-word-game/id6499354232',
                                pal: pal,
                              ),
                              _Para(
                                'Thanks to everyone who played early versions and shared feedback.',
                                pal: pal,
                              ),
                            ],
                          ),
                          _Section(
                            'Contact',
                            pal: pal,
                            children: [
                              _Para(
                                'Questions or feedback? Get in touch at — ponchcastortest@gmail.com',
                                pal: pal,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.pal, required this.children});
  final String title;
  final Palette pal;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

class _Para extends StatelessWidget {
  const _Para(this.text, {required this.pal});
  final String text;
  final Palette pal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(fontSize: 15, height: 1.4, color: pal.muted),
    ),
  );
}

class _ParaRichUrl extends StatelessWidget {
  const _ParaRichUrl(this.textList, {required this.pal, required this.url});
  final List<String> textList;
  final String? url;
  final Palette pal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${textList[0]} ',
            style: TextStyle(fontSize: 15, height: 1.4, color: pal.muted),
          ),
          if (url != null)
            TextSpan(
              text: textList[1],
              style: TextStyle(
                color: pal.muted,
                fontSize: 15,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => launchUrl(Uri.parse(url!)),
            ),
          TextSpan(
            text: ' ${textList[2]}',
            style: TextStyle(fontSize: 15, height: 1.4, color: pal.muted),
          ),
        ],
      ),
    ),
  );
}
