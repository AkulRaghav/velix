import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velix_data/velix_data.dart';
import 'package:velix_design/velix_design.dart';
import 'package:velix_motion/velix_motion.dart';

import '../../../di/providers.dart';
import '../../components/glass_card.dart';

/// AccessibilityScreen — Tier A.
///
/// Surfaces the configurable accessibility preferences (launch-readiness D4):
/// reduce motion, reduce transparency, high contrast, configurable
/// long-press and swipe gesture thresholds, and captions. Every change is
/// persisted immediately through [AccessibilityPreferencesController].
class AccessibilityScreen extends ConsumerWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.velix;
    final prefs = ref.watch(accessibilityPreferencesProvider);
    final controller = ref.read(accessibilityPreferencesProvider.notifier);

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
                  GlassCard(
                    tier: GlassCardTier.quiet,
                    padding: EdgeInsets.zero,
                    radius: 16,
                    child: Column(
                      children: [
                        _ToggleCell(
                          label: 'Reduce motion',
                          description: 'Collapse animations to a quiet fade',
                          value: prefs.reduceMotion,
                          onChanged: controller.setReduceMotion,
                        ),
                        const _Divider(),
                        _ToggleCell(
                          label: 'Reduce transparency',
                          description: 'Use opaque surfaces instead of glass',
                          value: prefs.reduceTransparency,
                          onChanged: controller.setReduceTransparency,
                        ),
                        const _Divider(),
                        _ToggleCell(
                          label: 'High contrast',
                          description: 'Stronger text and border contrast',
                          value: prefs.highContrast,
                          onChanged: controller.setHighContrast,
                        ),
                        const _Divider(),
                        _ToggleCell(
                          label: 'Captions',
                          description: 'Show captions for voice and video',
                          value: prefs.captionsEnabled,
                          onChanged: controller.setCaptionsEnabled,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: v.space.insetLg),
                  Padding(
                    padding: EdgeInsets.only(
                      left: v.space.insetSm,
                      bottom: v.space.insetSm,
                    ),
                    child: Text(
                      'Gesture timing',
                      style: v.typography.bodyS.copyWith(
                        color: v.colors.text.secondary,
                      ),
                    ),
                  ),
                  GlassCard(
                    tier: GlassCardTier.quiet,
                    padding: EdgeInsets.zero,
                    radius: 16,
                    child: Column(
                      children: [
                        _SliderCell(
                          label: 'Long-press hold',
                          value: prefs.longPressMultiplier,
                          onChanged: controller.setLongPressMultiplier,
                        ),
                        const _Divider(),
                        _SliderCell(
                          label: 'Swipe distance',
                          value: prefs.swipeMultiplier,
                          onChanged: controller.setSwipeMultiplier,
                        ),
                      ],
                    ),
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
              child: Center(child: Text('\u2039', style: v.typography.titleM)),
            ),
          ),
          SizedBox(width: v.space.insetSm),
          Text('Accessibility', style: v.typography.titleL),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: v.space.insetLg),
      child: Container(
        height: 1,
        color: v.colors.text.primary.withValues(alpha: 0.04),
      ),
    );
  }
}

class _ToggleCell extends StatelessWidget {
  const _ToggleCell({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Semantics(
      toggled: value,
      label: label,
      hint: description,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          VelixHaptics.tap();
          onChanged(!value);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: v.space.insetLg,
            vertical: v.space.insetMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: v.typography.bodyL),
                    SizedBox(height: v.space.s2),
                    Text(
                      description,
                      style: v.typography.bodyS.copyWith(
                        color: v.colors.text.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: v.space.insetSm),
              _Switch(value: value),
            ],
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: value ? v.colors.accent.signature : v.colors.text.primary.withValues(alpha: 0.12),
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.all(3),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: v.colors.surface.substrate,
        ),
      ),
    );
  }
}

class _SliderCell extends StatelessWidget {
  const _SliderCell({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  String _describe(double mul) {
    if (mul < 0.85) return 'Quicker';
    if (mul > 1.15) return 'Slower';
    return 'Default';
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    const min = AccessibilityPreferences.minMultiplier;
    const max = AccessibilityPreferences.maxMultiplier;
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);

    return Semantics(
      label: label,
      value: _describe(value),
      slider: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: v.space.insetLg,
          vertical: v.space.insetMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: v.typography.bodyL)),
                Text(
                  _describe(value),
                  style: v.typography.bodyS.copyWith(
                    color: v.colors.text.secondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: v.space.insetSm),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    final f = (d.localPosition.dx / width).clamp(0.0, 1.0);
                    VelixHaptics.tap();
                    onChanged(min + f * (max - min));
                  },
                  onHorizontalDragUpdate: (d) {
                    final f = (d.localPosition.dx / width).clamp(0.0, 1.0);
                    onChanged(min + f * (max - min));
                  },
                  child: SizedBox(
                    height: 24,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: v.colors.text.primary.withValues(alpha: 0.10),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: v.colors.accent.signature,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment(fraction * 2 - 1, 0),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: v.colors.accent.signature,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
