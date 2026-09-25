import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:word_wars/data/game.dart';
import 'package:word_wars/presentation/common/hex_geometry.dart';
import 'package:word_wars/presentation/common/palette.dart';

class Board extends StatelessWidget {
  const Board({super.key, required this.game, required this.analysis, required this.pal, required this.pop, required this.onTap});
  final Game game;
  final Analysis analysis;
  final Palette pal;
  final Animation<double> pop;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final viewBox = viewBoxOf(game.size);
    return AspectRatio(
      aspectRatio: viewBox.width / viewBox.height,
      child: LayoutBuilder(builder: (context, box) {
        final scale = box.maxWidth / viewBox.width;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final pt = d.localPosition / scale + viewBox.topLeft;
            final hex = hexPath(hexRadius);
            for (var i = 0; i < game.cells.length; i++) {
              final x = game.cells[i];
              if (x.home == 0 && hex.contains(pt - centerOf(x))) onTap(i);
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: CustomPaint(
              size: Size(box.maxWidth, box.maxWidth / viewBox.width * viewBox.height),
              painter: BoardPainter(game, analysis, pal, pop),
            ),
          ),
        );
      }),
    );
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter(this.game, this.a, this.pal, this.pop) : super(repaint: pop);
  final Game game;
  final Analysis a;
  final Palette pal;
  final Animation<double> pop;

  @override
  void paint(Canvas canvas, Size size) {
    final viewBox = viewBoxOf(game.size);
    canvas.scale(size.width / viewBox.width);
    canvas.translate(-viewBox.left, -viewBox.top);
    final hex = hexPath(hexRadius);
    final t = Curves.easeOut.transform(pop.value);
    final cur = game.turn;

    // Unselected hexes first, then selected ones in order so their outlines sit on top.
    final order = [
      for (var i = 0; i < game.cells.length; i++)
        if (!game.sel.contains(i)) i,
      ...game.sel,
    ];

    for (final i in order) {
      final x = game.cells[i];
      canvas.save();
      canvas.translate(centerOf(x).dx, centerOf(x).dy);

      final k = game.sel.indexOf(i);
      final selected = k > -1;
      final linked = a.linked.contains(i);
      final owned = x.owner != 0 || x.home != 0;

      Color fill = pal.hex;
      if (x.home != 0) {
        fill = pal.fill(x.home);
      } else if (x.owner != 0) {
        fill = pal.fill(x.owner);
      } else if (selected && linked) {
        fill = pal.tint(cur);
      }
      canvas.drawPath(hex, Paint()..color = fill);

      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.miter
        ..color = selected ? pal.lineOf(cur) : pal.line
        ..strokeWidth = selected ? 4.5 : 2;
      canvas.drawPath(selected && !linked ? _dashed(hex, 7, 5) : hex, stroke);

      if (x.home != 0) {
        _drawHouse(canvas, pal.fill(x.home));
      } else {
        final isFresh = game.fresh.contains(i) && t < 1;
        final s = isFresh ? .3 + .7 * t : 1.0;
        final op = isFresh ? t : 1.0;
        _text(canvas, x.letter, const Offset(0, 1), 21, FontWeight.w500,
            (owned ? Colors.white : pal.ink).withValues(alpha: op), scale: s);
        if (selected) {
          _text(canvas, '${k + 1}', const Offset(0, -22.5), 10, FontWeight.w700,
              owned ? Colors.white : pal.lineOf(cur));
        }
      }
      canvas.restore();
    }
  }

  void _text(Canvas canvas, String s, Offset c, double size, FontWeight w, Color color, {double scale = 1}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: GoogleFonts.outfit(fontSize: size, fontWeight: w, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _drawHouse(Canvas canvas, Color door) {
    final white = Paint()..color = Colors.white;
    canvas.drawPath(
      Path()..moveTo(-15, 1)..lineTo(0, -13)..lineTo(15, 1),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawRect(const Rect.fromLTWH(6, -13, 4, 8), white);
    canvas.drawPath(
        Path()..moveTo(-10, -1)..lineTo(0, -10)..lineTo(10, -1)..lineTo(10, 13)..lineTo(-10, 13)..close(), white);
    canvas.drawRect(const Rect.fromLTWH(-3.5, 4, 7, 9), Paint()..color = door);
  }

  Path _dashed(Path src, double on, double off) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, min(d + on, m.length)), Offset.zero);
        d += on + off;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}
