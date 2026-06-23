import 'package:flutter/material.dart';
class VelixRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  const VelixRefreshIndicator({super.key, required this.child, required this.onRefresh});
  @override
  Widget build(BuildContext context) => RefreshIndicator(onRefresh: onRefresh, color: const Color(0xFF3478F6), backgroundColor: const Color(0xFF1A1A24), child: child);
}
