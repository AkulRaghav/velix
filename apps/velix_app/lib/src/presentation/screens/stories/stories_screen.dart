import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:velix_design/velix_design.dart';

/// StoriesScreen — Tier C.
///
/// Vertical-immersive story player: full-bleed media slot, segmented
/// progress strip, and a dark void substrate. Sibling-swipe gestures and
/// live story content arrive with the social-graph feature.
class StoriesScreen extends StatelessWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      color: v.colors.surface.voidBlack,
      child: SafeArea(
        child: Stack(
          children: [
            // Segmented progress strip.
            Positioned(
              top: 0,
              left: v.space.gutterList,
              right: v.space.gutterList,
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: v.colors.text.primary.withValues(alpha: i == 0 ? 1 : 0.2),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    if (i < 2) SizedBox(width: v.space.s4),
                  ],
                ],
              ),
            ),
            Center(
              child: Text(
                'Story content',
                style: v.typography.titleL.copyWith(color: v.colors.text.primary),
              ),
            ),
            Positioned(
              top: v.space.s9,
              right: v.space.gutterList,
              child: GestureDetector(
                onTap: () => context.pop(),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Text(
                      '\u00D7',
                      style: v.typography.titleM
                          .copyWith(color: v.colors.text.primary),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
