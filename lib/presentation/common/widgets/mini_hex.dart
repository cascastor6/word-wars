import 'package:flutter/material.dart';

import 'package:word_wars/presentation/common/hex_geometry.dart';

class MiniHex extends CustomPainter {
  MiniHex(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 40);
    canvas.drawPath(hexPath(hexRadius * .52), Paint()..color = color);
  }

  @override
  bool shouldRepaint(MiniHex old) => old.color != color;
}
