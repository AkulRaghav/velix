import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:velix_design/velix_design.dart';

import '../haptics/velix_haptics.dart';
import '../patterns/velix_arrive.dart';

/// Tier-3 modal surface. Fixed size, not draggable.
///
/// Use [VelixModal.show] to present and `Navigator.pop` to dismiss.
class VelixModal extends StatelessWidget {
  const VelixModal._({required this.child, required this.onScrimTap});

  final Widget child;
  final VoidCallback onScrimTap;

  /// Presents the modal as a transparent route that animates in via
  /// `motion.arrive`.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? semanticLabel,
  }) {
    return Navigator.of(context).push<T>(
      _VelixModalRoute<T>(
        builder: builder,
        barrierDismissible: barrierDismissible,
        semanticLabel: semanticLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    final mq = MediaQuery.of(context);
    final reduceTransparency = mq.highContrast;
    final reduceMotion = mq.disableAnimations;

    final scrim = GestureDetector(
      onTap: onScrimTap,
      behavior: HitTestBehavior.opaque,
      child: Container(color: v.colors.surface.scrim),
    );

    final modalSurface = Container(
      decoration: BoxDecoration(
        color: reduceTransparency
            ? v.colors.surface.lifted
            : v.materials.lifted.fill,
        borderRadius: v.radius.lgAll,
        boxShadow: v.shadows.elevation3,
      ),
      padding: v.space.cardPadding,
      child: child,
    );

    return Stack(
      children: [
        Positioned.fill(child: scrim),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: v.space.screenInset,
              child: VelixArrive(
                present: true,
                onArrived: reduceMotion ? null : VelixHaptics.modalOpen,
                child: reduceTransparency
                    ? modalSurface
                    : ClipRRect(
                        borderRadius: v.radius.lgAll,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: v.materials.lifted.blurSigma,
                            sigmaY: v.materials.lifted.blurSigma,
                          ),
                          child: modalSurface,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VelixModalRoute<T> extends PopupRoute<T> {
  _VelixModalRoute({
    required this.builder,
    required this.barrierDismissible,
    this.semanticLabel,
  });

  final WidgetBuilder builder;
  @override
  final bool barrierDismissible;

  final String? semanticLabel;

  @override
  Color? get barrierColor => null; // VelixModal renders its own scrim.

  @override
  String? get barrierLabel => semanticLabel ?? 'Modal';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return VelixModal._(
      child: builder(context),
      onScrimTap: () {
        if (barrierDismissible) Navigator.of(context).pop();
      },
    );
  }
}
