import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:velix_design/velix_design.dart';

import '../../components/glass_card.dart';

/// VideoCallScreen â€” Tier C.
///
/// Scaffold of the call surface. LiveKit wiring lands in Phase 6.
class VideoCallScreen extends StatelessWidget {
  const VideoCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      color: v.colors.surface.voidBlack,
      child: SafeArea(
        child: Stack(
          children: [
            // Header.
            Positioned(
              top: v.space.insetSm,
              left: v.space.gutterList,
              right: v.space.gutterList,
              child: GlassCard(
                tier: GlassCardTier.active,
                padding: EdgeInsets.symmetric(
                  horizontal: v.space.insetLg,
                  vertical: v.space.insetSm,
                ),
                radius: 9999,
                child: Row(
                  children: [
                    Text('End-to-end encrypted', style: v.typography.labelM),
                    const Spacer(),
                    Text(
                      '00:14',
                      style: v.typography
                          .tabular(v.typography.labelM)
                          .copyWith(color: v.colors.text.secondary),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom controls.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    v.space.gutterList,
                    0,
                    v.space.gutterList,
                    v.space.insetMd,
                  ),
                  child: GlassCard(
                    tier: GlassCardTier.active,
                    padding: EdgeInsets.symmetric(
                      horizontal: v.space.insetMd,
                      vertical: v.space.insetSm,
                    ),
                    radius: 9999,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const _ControlButton(label: 'Mic'),
                        const _ControlButton(label: 'Video'),
                        const _ControlButton(label: 'Share'),
                        const _ControlButton(label: 'More'),
                        _EndCallButton(onTap: () => context.pop()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Center(child: Text('Video stream', style: TextStyle(color: Color(0x66FFFFFF)))),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: v.colors.surface.lifted,
      ),
      child: Text(
        label,
        style: v.typography.labelS.copyWith(color: v.colors.text.primary),
      ),
    );
  }
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: v.colors.semantic.danger,
        ),
        alignment: Alignment.center,
        child: Text(
          'End',
          style: v.typography.labelS.copyWith(color: v.colors.text.inverse),
        ),
      ),
    );
  }
}
