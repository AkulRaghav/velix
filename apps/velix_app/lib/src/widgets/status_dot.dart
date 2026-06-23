import 'package:flutter/material.dart';
enum StatusDotState { online, away, offline, dnd }
class StatusDot extends StatelessWidget {
  final StatusDotState state;
  final double size;
  const StatusDot({super.key, required this.state, this.size = 10});
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: _color, border: Border.all(color: Colors.black, width: 2)));
  Color get _color => switch (state) { StatusDotState.online => Colors.green, StatusDotState.away => Colors.orange, StatusDotState.dnd => Colors.red, StatusDotState.offline => Colors.grey };
}
