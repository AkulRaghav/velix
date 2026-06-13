import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:velix_design/velix_design.dart';
import 'package:velix_motion/velix_motion.dart';

import '../../../router/app_router.dart';
import '../../components/glass_card.dart';

/// SettingsScreen â€” Tier A. Linear-grade restraint.
///
/// Hierarchy from `docs/phase-5/08-screen-implementation-plan.md`:
/// Privacy & Security Â· Devices Â· Notifications Â· Display Â· Accessibility Â·
/// AI Â· Storage Â· Account Â· About.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                  _Group(
                    cells: [
                      _Cell(
                        label: 'Privacy & Security',
                        description: 'Encryption, devices, app lock',
                        onTap: () => context.push(Routes.privacy),
                      ),
                    ],
                  ),
                  SizedBox(height: v.space.insetLg),
                  const _Group(
                    cells: [
                      _Cell(label: 'Devices', description: '2 active'),
                      _Cell(
                          label: 'Notifications',
                          description: 'Quiet by default',),
                    ],
                  ),
                  SizedBox(height: v.space.insetLg),
                  _Group(
                    cells: [
                      const _Cell(
                          label: 'Display', description: 'Dark Â· 3D backdrops',),
                      _Cell(
                        label: 'Accessibility',
                        description: 'Motion Â· Gestures Â· Captions',
                        onTap: () => context.push(Routes.accessibility),
                      ),
                      const _Cell(label: 'AI', description: 'On-device only'),
                    ],
                  ),
                  SizedBox(height: v.space.insetLg),
                  const _Group(
                    cells: [
                      _Cell(label: 'Storage', description: 'Cache, backup'),
                      _Cell(
                          label: 'Account',
                          description: 'Handle, email, sign out',),
                      _Cell(
                          label: 'About',
                          description: 'Version, licenses, security paper',),
                    ],
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
                child: Text(
                  '\u2039',
                  style: v.typography.titleM,
                ),
              ),
            ),
          ),
          SizedBox(width: v.space.insetSm),
          Text('Settings', style: v.typography.titleL),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.cells});
  final List<_Cell> cells;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return GlassCard(
      tier: GlassCardTier.quiet,
      padding: EdgeInsets.zero,
      radius: 16,
      child: Column(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            cells[i],
            if (i < cells.length - 1)
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
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    this.description,
    this.onTap,
  });
  final String label;
  final String? description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Semantics(
      button: onTap != null,
      label: label,
      hint: description,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                VelixHaptics.tap();
                onTap!();
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
                    if (description != null) ...[
                      SizedBox(height: v.space.s2),
                      Text(
                        description!,
                        style: v.typography.bodyS.copyWith(
                          color: v.colors.text.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: v.space.insetSm),
              Text(
                '\u203A',
                style: v.typography.titleS.copyWith(color: v.colors.text.tertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
