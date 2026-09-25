import 'dart:math';
import 'dart:ui';

import 'package:word_wars/data/game.dart';

const double hexDx = 0.8660254037844386 * 40; // sqrt(3)/2 * 40
const double hexDy = 60;
const double hexRadius = 38;

Rect viewBoxOf(BoardSize s) => Rect.fromLTWH(-40, -44, s.maxCol * hexDx + 80, (s.rows - 1) * hexDy + 88);

Path hexPath(double r) {
  final p = Path();
  for (var k = 0; k < 6; k++) {
    final a = pi / 180 * (60 * k - 90);
    final pt = Offset(r * cos(a), r * sin(a));
    k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

Offset centerOf(Cell x) => Offset(x.c * hexDx, x.r * hexDy);
