import 'package:flutter/material.dart';
import 'package:velix_design/velix_design.dart';

/// AI & Intelligence screen — shows AI-powered features.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      color: v.colors.surface.substrate,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(v.space.gutterScreen, v.space.insetLg, v.space.gutterScreen, 100),
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 20, color: v.colors.accent.signature),
                SizedBox(width: v.space.insetSm),
                Text('Intelligence', style: v.typography.displayS),
              ],
            ),
            SizedBox(height: v.space.s3),
            Text('AI-powered insights from your conversations', style: v.typography.bodyM.copyWith(color: v.colors.text.tertiary)),
            SizedBox(height: v.space.s7),
            _FeatureCard(v: v, icon: Icons.summarize_rounded, title: 'Conversation Summary', subtitle: 'Get a quick overview of any thread', color: v.colors.accent.signature),
            SizedBox(height: v.space.insetMd),
            _FeatureCard(v: v, icon: Icons.reply_rounded, title: 'Smart Replies', subtitle: 'AI suggests contextual responses', color: v.colors.semantic.success),
            SizedBox(height: v.space.insetMd),
            _FeatureCard(v: v, icon: Icons.search_rounded, title: 'Semantic Search', subtitle: 'Find messages by meaning, not just keywords', color: const Color(0xFFf5576c)),
            SizedBox(height: v.space.insetMd),
            _FeatureCard(v: v, icon: Icons.translate_rounded, title: 'Translate', subtitle: 'Instantly translate messages in-place', color: const Color(0xFF667eea)),
            SizedBox(height: v.space.insetMd),
            _FeatureCard(v: v, icon: Icons.checklist_rounded, title: 'Action Items', subtitle: 'Extract tasks from conversations', color: const Color(0xFFf093fb)),
            SizedBox(height: v.space.insetMd),
            _FeatureCard(v: v, icon: Icons.security_rounded, title: 'Privacy Score', subtitle: 'See how your data is protected', color: const Color(0xFF43e97b)),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.v, required this.icon, required this.title, required this.subtitle, required this.color});
  final VelixTheme v;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title — available with AI integration'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating),
        );
      },
      child: Container(
        padding: EdgeInsets.all(v.space.insetLg),
        decoration: BoxDecoration(
          color: v.colors.surface.lifted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
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
                  Text(title, style: v.typography.bodyL.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: v.typography.bodyS.copyWith(color: v.colors.text.tertiary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: v.colors.text.tertiary),
          ],
        ),
      ),
    );
  }
}
