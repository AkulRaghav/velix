import 'package:flutter/material.dart';
class TypingAnimation extends StatefulWidget {
  const TypingAnimation({super.key});
  @override
  State<TypingAnimation> createState() => _TypingAnimationState();
}
class _TypingAnimationState extends State<TypingAnimation> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers = List.generate(3, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat(reverse: true));
  @override
  void initState() { super.initState(); for (var i = 0; i < 3; i++) Future.delayed(Duration(milliseconds: i * 150), () { if (mounted) _controllers[i].forward(); }); }
  @override
  void dispose() { for (final c in _controllers) c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 3; i++) AnimatedBuilder(animation: _controllers[i], builder: (_, __) => Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.withValues(alpha: 0.3 + _controllers[i].value * 0.7))))]);
}
