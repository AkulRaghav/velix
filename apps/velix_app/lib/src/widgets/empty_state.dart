import 'package:flutter/material.dart';
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48, color: Colors.white24), const SizedBox(height: 16), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Colors.white)), if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(subtitle!, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.4)), textAlign: TextAlign.center)), if (actionLabel != null) Padding(padding: const EdgeInsets.only(top: 20), child: ElevatedButton(onPressed: onAction, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3478F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(actionLabel!)))]));
}
