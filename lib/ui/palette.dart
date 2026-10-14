import 'package:flutter/material.dart';

// Colors taken from game js/styles.css.
class Neon {
  static const panel = Color(0xD1050A1F);
  static const panelStrong = Color(0xE6040A20);
  static const border = Color(0x5769DCFF);
  static const borderBright = Color(0xFFBDFAFF);
  static const cyan = Color(0xFF68EAFF);
  static const text = Color(0xFFE8FBFF);
  static const muted = Color(0xFF9BB9D8);
  static const track = Color(0xFF18223F);
  static const pink = Color(0xFFFF4FD8);
  static const feral = Color(0xFF9CFF6B);

  static const meter = LinearGradient(
    colors: [Color(0xFF3E78FF), Color(0xFF6FF3FF), Color(0xFFF7FFFF)],
  );
  static const boss = LinearGradient(
    colors: [Color(0xFF854DFF), Color(0xFFFF4FD8), Color(0xFFFF9BEA)],
  );
  static const tailLit = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7FFFF), Color(0xFF72E8FF), Color(0xFF4388FF)],
    stops: [0.15, 0.62, 1],
  );

  static BoxDecoration panelBox({double radius = 12, Color? borderColor}) =>
      BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? border),
      );

  static const label = TextStyle(
    color: muted,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
  );
}
