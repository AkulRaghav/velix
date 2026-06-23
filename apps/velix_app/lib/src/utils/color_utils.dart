import 'package:flutter/material.dart';
class ColorUtils {
  static Color fromHash(String text) {
    final hash = text.hashCode;
    return Color.fromRGBO((hash & 0xFF0000) >> 16, (hash & 0x00FF00) >> 8, hash & 0x0000FF, 1.0);
  }
  static Color darken(Color c, [double amount = 0.1]) => Color.lerp(c, Colors.black, amount)!;
  static Color lighten(Color c, [double amount = 0.1]) => Color.lerp(c, Colors.white, amount)!;
}
