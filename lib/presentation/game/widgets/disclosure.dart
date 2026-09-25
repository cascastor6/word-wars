import 'package:flutter/material.dart';

import 'package:word_wars/presentation/common/palette.dart';

class Disclosure extends StatefulWidget {
  const Disclosure({super.key, required this.title, required this.pal, required this.child, required this.initiallyOpen});
  final String title;
  final Palette pal;
  final Widget child;
  final bool initiallyOpen;

  @override
  State<Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<Disclosure> {
  late bool open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: widget.pal.soft))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => setState(() => open = !open),
            child: Row(children: [
              AnimatedRotation(
                turns: open ? .25 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.arrow_right, size: 22, color: widget.pal.ink),
              ),
              Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (open) Padding(padding: const EdgeInsets.only(top: 10), child: widget.child),
        ]),
      );
}
