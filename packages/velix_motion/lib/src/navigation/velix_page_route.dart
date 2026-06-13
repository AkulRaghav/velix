import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:velix_design/velix_design.dart';

import '../patterns/velix_lateral.dart';

/// The single page-route used by Velix. Wraps Cupertino's gesture-based
/// route to inherit edge-swipe-back behavior, then layers Velix lateral
/// animation on top.
///
/// Notes:
/// - We extend [CupertinoPageRoute] for the gesture mechanics; Apple's
///   implementation handles velocity hand-off, drag-to-cancel, and the
///   trailing-edge-only edge swipe direction (mirrored under RTL).
/// - The visual transition is overridden to match Velix's `motion.lateral`
///   spec (opacity dip on outgoing, parallax on incoming).
/// - [hidesNav] is consumed by the floating-navigation host widget;
///   the route exposes it as part of its settings.
class VelixPageRoute<T> extends CupertinoPageRoute<T> {
  VelixPageRoute({
    required Widget page,
    this.hidesNav = false,
    this.semanticLabel,
    super.settings,
  }) : super(builder: (_) => page, title: semanticLabel);

  /// Whether this route's screen suppresses the floating navigation.
  final bool hidesNav;

  final String? semanticLabel;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final mq = MediaQuery.maybeOf(context);
    final reduce = mq?.disableAnimations ?? false;
    if (reduce) {
      return FadeTransition(opacity: animation, child: child);
    }
    final theme = Theme.of(context).extension<VelixTheme>();
    if (theme == null) {
      return FadeTransition(opacity: animation, child: child);
    }
    final dir = Directionality.of(context) == TextDirection.rtl
        ? AxisDirection.left
        : AxisDirection.right;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return VelixLateral(
          direction: dir,
          progress: animation.value,
          child: child,
        );
      },
    );
  }
}
