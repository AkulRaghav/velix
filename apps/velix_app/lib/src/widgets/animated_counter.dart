import 'package:flutter/material.dart';
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const AnimatedCounter({super.key, required this.value, this.style});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<int>(tween: IntTween(begin: 0, end: value), duration: const Duration(milliseconds: 800), curve: Curves.easeOut, builder: (_, v, __) => Text('\', style: style));
}
