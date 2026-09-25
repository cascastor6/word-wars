import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:word_wars/presentation/common/palette.dart';

class GameButton extends StatelessWidget {
  const GameButton(this.label, {super.key, required this.pal, required this.turn, this.onPressed, this.primary = false});
  final String label;
  final Palette pal;
  final int turn;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final border = primary ? pal.fill(turn) : pal.line;
    return Opacity(
      opacity: onPressed == null ? .35 : 1,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: primary ? pal.fill(turn) : Colors.transparent,
          foregroundColor: primary ? Colors.white : pal.ink,
          disabledForegroundColor: primary ? Colors.white : pal.ink,
          disabledBackgroundColor: primary ? pal.fill(turn) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: border, width: 2),
          ),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}
