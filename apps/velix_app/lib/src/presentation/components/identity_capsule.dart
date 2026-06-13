import 'package:flutter/widgets.dart';
import 'package:velix_design/velix_design.dart';
import 'package:velix_domain/velix_domain.dart';

enum IdentityCapsuleSize { xs, sm, md, lg }

/// Velix component contract: IdentityCapsule.
/// See `docs/phase-2/09-component-contracts.md`.
class IdentityCapsule extends StatelessWidget {
  const IdentityCapsule({
    super.key,
    required this.title,
    this.size = IdentityCapsuleSize.sm,
    this.roomColorIndex,
    this.trustState,
    this.presence,
  });

  final String title;
  final IdentityCapsuleSize size;
  final int? roomColorIndex;
  final TrustState? trustState;

  /// `true` = online, `false` = recently active, `null` = no presence shown.
  final bool? presence;

  double get _diameter => switch (size) {
        IdentityCapsuleSize.xs => 28,
        IdentityCapsuleSize.sm => 40,
        IdentityCapsuleSize.md => 56,
        IdentityCapsuleSize.lg => 96,
      };

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    final palette = v.colors.rooms;
    final color = roomColorIndex != null
        ? palette.fromHash(roomColorIndex!)
        : v.colors.surface.active;
    final initial = title.isEmpty ? '·' : title.characters.first.toUpperCase();
    final fontSize = _diameter * 0.42;
    final showPresence = presence != null && size != IdentityCapsuleSize.xs;

    return Semantics(
      label: title,
      child: SizedBox(
        width: _diameter,
        height: _diameter,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.85),
                    Color.lerp(color, v.colors.surface.substrate, 0.6)!,
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                  color: v.colors.text.primary,
                ),
              ),
            ),
            if (showPresence)
              Align(
                alignment: Alignment.bottomRight,
                child: _PresenceNotch(online: presence ?? false),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresenceNotch extends StatelessWidget {
  const _PresenceNotch({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: v.colors.surface.substrate,
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: online ? v.colors.presence.online : v.colors.presence.recently,
        ),
      ),
    );
  }
}
