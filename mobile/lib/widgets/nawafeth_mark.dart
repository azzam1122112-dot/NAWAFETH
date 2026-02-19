import 'package:flutter/material.dart';

class NawafethMark extends StatelessWidget {
  final double chipSize;
  final double gap;
  final double radius;

  const NawafethMark({
    super.key,
    this.chipSize = 12,
    this.gap = 3,
    this.radius = 3,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(Color c) => Container(
          width: chipSize,
          height: chipSize,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip(const Color(0xFFE97885)),
            SizedBox(width: gap),
            chip(const Color(0xFFF2B24C)),
          ],
        ),
        SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip(const Color(0xFFB68DF6)),
            SizedBox(width: gap),
            chip(const Color(0xFF7DB2F8)),
          ],
        ),
      ],
    );
  }
}
