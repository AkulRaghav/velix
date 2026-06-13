import 'package:flutter/widgets.dart';
import 'package:velix_design/velix_design.dart';

import '../../components/glass_card.dart';

/// PrivacyScreen — Tier A.
///
/// Hero card with the encryption-shield glyph, a one-line affirmation, then
/// a quiet list of privacy toggles. The visual stance mirrors the product:
/// security stated plainly, without alarm.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      color: v.colors.surface.substrate,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _Header()),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: v.space.gutterScreen),
              sliver: SliverList.list(
                children: [
                  const _HeroCard(),
                  SizedBox(height: v.space.insetLg),
                  const _Group(
                    title: 'Encryption',
                    rows: [
                      _Row(label: 'End-to-end encryption', value: 'On for every chat'),
                      _Row(label: 'Sealed sender', value: 'On'),
                      _Row(label: 'Verify a contact', value: 'Scan QR'),
                    ],
                  ),
                  SizedBox(height: v.space.insetLg),
                  const _Group(
                    title: 'On this device',
                    rows: [
                      _Row(label: 'App lock', value: 'Biometric'),
                      _Row(label: 'Screenshot guard', value: 'On in private chats'),
                      _Row(label: 'Hidden chats', value: '0'),
                    ],
                  ),
                  SizedBox(height: v.space.insetLg),
                  const _Group(
                    title: 'Sessions',
                    rows: [
                      _Row(label: 'Active devices', value: '2'),
                      _Row(label: 'Last security audit', value: '2025'),
                    ],
                  ),
                  SizedBox(height: v.space.s11),
                  Text(
                    'Read more about how Velix handles your messages, '
                    'metadata, and identity in our security paper.',
                    style: v.typography.bodyS.copyWith(color: v.colors.text.tertiary),
                  ),
                  SizedBox(height: v.space.s12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        v.space.gutterScreen,
        v.space.insetMd,
        v.space.gutterScreen,
        v.space.insetLg,
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Text('\u2039', style: v.typography.titleM),
              ),
            ),
          ),
          SizedBox(width: v.space.insetSm),
          Text('Privacy & Security', style: v.typography.titleL),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return GlassCard(
      tier: GlassCardTier.active,
      tintColor: v.colors.accent.signature,
      tintOpacity: 0.05,
      padding: EdgeInsets.symmetric(
        horizontal: v.space.insetXl,
        vertical: v.space.s9,
      ),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _ShieldPainter(color: v.colors.accent.signature),
            ),
          ),
          SizedBox(height: v.space.insetMd),
          Text('End to end encrypted', style: v.typography.titleM),
          SizedBox(height: v.space.s4),
          Text(
            'Your messages are readable only by you and the people you message. '
            'Velix is technically incapable of reading them.',
            style: v.typography.bodyM.copyWith(color: v.colors.text.secondary),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;
  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: v.space.insetSm, bottom: v.space.s4),
          child: Text(
            title,
            style: v.typography.labelS.copyWith(color: v.colors.text.tertiary),
          ),
        ),
        GlassCard(
          tier: GlassCardTier.quiet,
          padding: EdgeInsets.zero,
          radius: 16,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: v.space.insetLg),
                    child: Container(
                      height: 1,
                      color: v.colors.text.primary.withValues(alpha: 0.04),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: v.space.insetLg,
          vertical: v.space.insetMd,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: v.typography.bodyL)),
            Text(
              value,
              style: v.typography.bodyM.copyWith(color: v.colors.text.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  _ShieldPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.92, h * 0.22)
      ..lineTo(w * 0.92, h * 0.55)
      ..cubicTo(w * 0.92, h * 0.78, w * 0.72, h * 0.92, w * 0.5, h * 0.95)
      ..cubicTo(w * 0.28, h * 0.92, w * 0.08, h * 0.78, w * 0.08, h * 0.55)
      ..lineTo(w * 0.08, h * 0.22)
      ..close();
    canvas.drawPath(path, paint);
    // Inner check.
    final check = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final c = Path()
      ..moveTo(w * 0.32, h * 0.52)
      ..lineTo(w * 0.46, h * 0.66)
      ..lineTo(w * 0.70, h * 0.36);
    canvas.drawPath(c, check);
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter old) => old.color != color;
}
