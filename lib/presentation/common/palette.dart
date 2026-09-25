import 'package:flutter/material.dart';

/// Colour tokens, mirroring the light and dark palettes of the original page.
class Palette {
  const Palette({
    required this.bg, required this.ink, required this.muted, required this.line,
    required this.hex, required this.soft,
    required this.p1, required this.p1Line, required this.p1Tint,
    required this.p2, required this.p2Line, required this.p2Tint,
  });
  final Color bg, ink, muted, line, hex, soft;
  final Color p1, p1Line, p1Tint, p2, p2Line, p2Tint;

  static const light = Palette(
    bg: Color(0xFFFFFFFF), ink: Color(0xFF1D1D1F), muted: Color(0xFF6C6C72),
    line: Color(0xFF1D1D1F), hex: Color(0xFFFFFFFF), soft: Color(0xFFF1F1F3),
    p1: Color(0xFF1B0AA6), p1Line: Color(0xFF1B0AA6), p1Tint: Color(0xFFE5E2FB),
    p2: Color(0xFFEE3535), p2Line: Color(0xFFE02424), p2Tint: Color(0xFFFDE2E2),
  );
  static const dark = Palette(
    bg: Color(0xFF131315), ink: Color(0xFFF1F1F3), muted: Color(0xFF9B9BA3),
    line: Color(0xFFD4D4DA), hex: Color(0xFF1E1E22), soft: Color(0xFF26262B),
    p1: Color(0xFF3B2DE0), p1Line: Color(0xFF8F86FF), p1Tint: Color(0xFF29245E),
    p2: Color(0xFFE23A3A), p2Line: Color(0xFFFF7B7B), p2Tint: Color(0xFF4B2126),
  );

  Color fill(int p) => p == 1 ? p1 : p2;
  Color lineOf(int p) => p == 1 ? p1Line : p2Line;
  Color tint(int p) => p == 1 ? p1Tint : p2Tint;
}

Palette paletteOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Palette.dark : Palette.light;
