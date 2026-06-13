import 'package:flutter/material.dart';
import 'package:velix_design/velix_design.dart';

/// Activity & Notifications screen.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      color: v.colors.surface.substrate,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: 100),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(v.space.gutterScreen, v.space.insetLg, v.space.gutterScreen, v.space.insetMd),
              child: Text('Activity', style: v.typography.displayS),
            ),
            _Section(v: v, label: 'TODAY'),
            _ActivityItem(v: v, icon: Icons.chat_bubble_rounded, color: v.colors.accent.signature, title: 'velix.bot', subtitle: 'Sent you a message', time: 'Just now'),
            _ActivityItem(v: v, icon: Icons.verified_rounded, color: v.colors.semantic.success, title: 'Identity verified', subtitle: 'Your encryption keys are confirmed', time: '1h ago'),
            _ActivityItem(v: v, icon: Icons.devices_rounded, color: const Color(0xFF667eea), title: 'New device', subtitle: 'This phone was added to your account', time: '2h ago'),
            _Section(v: v, label: 'THIS WEEK'),
            _ActivityItem(v: v, icon: Icons.security_rounded, color: const Color(0xFF43e97b), title: 'Security check', subtitle: 'All sessions are secure', time: '3d ago'),
            _ActivityItem(v: v, icon: Icons.auto_awesome_rounded, color: const Color(0xFFf093fb), title: 'AI ready', subtitle: 'Smart replies are available in your chats', time: '5d ago'),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.v, required this.label});
  final VelixTheme v;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(v.space.gutterScreen, v.space.insetLg, v.space.gutterScreen, v.space.insetSm),
      child: Text(label, style: v.typography.labelS.copyWith(color: v.colors.text.tertiary, letterSpacing: 1)),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.v, required this.icon, required this.color, required this.title, required this.subtitle, required this.time});
  final VelixTheme v;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: v.space.gutterScreen, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(width: v.space.insetMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: v.typography.bodyM.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: v.typography.bodyS.copyWith(color: v.colors.text.tertiary)),
              ],
            ),
          ),
          Text(time, style: v.typography.labelS.copyWith(color: v.colors.text.tertiary)),
        ],
      ),
    );
  }
}
