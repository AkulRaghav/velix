import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:velix_design/velix_design.dart';

import 'scene_capability.dart';
import 'scene_controller.dart';
import 'scene_id.dart';
import 'scene_params.dart';

/// Embeds a 3D scene with an automatic 2D fallback.
///
/// Usage:
/// ```dart
/// VelixSceneWidget(
///   scene: SceneId.profileIdentity,
///   params: SceneParams(style: SceneStyle.quartz),
///   fallback: const ProfileIdentityFallback(),
/// )
/// ```
///
/// The widget guarantees:
/// - The fallback is shown until the controller reports healthy.
/// - Scene auto-pauses when the widget loses visibility.
/// - Reduce Motion / Reduce Transparency / Low Power are honored.
/// - Disposal is automatic.
class VelixSceneWidget extends StatefulWidget {
  const VelixSceneWidget({
    super.key,
    required this.scene,
    required this.fallback,
    this.params = const SceneParams(),
    this.controllerFactory,
    this.scrollController,
    this.visibility,
  });

  final SceneId scene;
  final Widget fallback;
  final SceneParams params;

  /// Optional factory. Defaults to a [NoopSceneController] until the Phase 5
  /// Filament binding is wired in, after which the production factory will
  /// return the FFI-backed controller.
  final VelixSceneController Function()? controllerFactory;

  /// Optional scroll controller. When provided, the scene's scroll-axis
  /// parallax is bound to this controller. Phase 5 wires it through to
  /// the controller's `setParallax` calls.
  final ScrollController? scrollController;

  /// Optional visibility-fraction listenable in `[0.0, 1.0]`.
  ///
  /// Per Phase 9 F12, the scene auto-pauses when this drops below 0.05
  /// and resumes when it rises above 0.50. Drives the most important
  /// 3D battery savings: the profile scene scrolled out of view stops
  /// consuming GPU.
  ///
  /// When null, visibility is assumed full. Hosting screens that scroll
  /// the scene off-screen should provide a [ValueListenable] driven by
  /// a `NotificationListener<ScrollNotification>` or equivalent.
  final ValueListenable<double>? visibility;

  @override
  State<VelixSceneWidget> createState() => _VelixSceneWidgetState();
}

class _VelixSceneWidgetState extends State<VelixSceneWidget>
    with WidgetsBindingObserver {
  late VelixSceneController _controller;
  bool _attempted3D = false;
  bool _hiddenByVisibility = false;

  @override
  void initState() {
    super.initState();
    _controller = (widget.controllerFactory ?? NoopSceneController.new)();
    WidgetsBinding.instance.addObserver(this);
    widget.visibility?.addListener(_onVisibility);
  }

  void _onVisibility() {
    final fraction = widget.visibility?.value ?? 1.0;
    if (fraction < 0.05 && !_hiddenByVisibility) {
      _hiddenByVisibility = true;
      _controller.pause();
    } else if (fraction > 0.50 && _hiddenByVisibility) {
      _hiddenByVisibility = false;
      _controller.resume();
    }
  }

  @override
  void didUpdateWidget(covariant VelixSceneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibility != widget.visibility) {
      oldWidget.visibility?.removeListener(_onVisibility);
      widget.visibility?.addListener(_onVisibility);
      _onVisibility();
    }
  }

  @override
  void dispose() {
    widget.visibility?.removeListener(_onVisibility);
    WidgetsBinding.instance.removeObserver(this);
    // Async dispose; we deliberately do not await inside State.dispose because
    // Flutter expects synchronous disposal. The render isolate is told to
    // tear down and any further frames are dropped.
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _controller.pause();
      case AppLifecycleState.resumed:
        _controller.resume();
      case AppLifecycleState.detached:
        // Disposal handled by `dispose`.
        break;
    }
  }

  void _maybeAttemptLoad(SceneCapability cap, bool reduceMotion) {
    if (_attempted3D) return;
    if (!cap.is3DSupported) return;
    _attempted3D = true;
    // Fire-and-forget; the `healthy` listenable drives the visible fallback.
    // Reduce-Motion routes through `startPaused: true` so the renderer
    // resolves to a static frame and never enters the active render loop.
    unawaited(
      _controller
          .load(
        widget.scene,
        params: widget.params,
        startPaused: reduceMotion,
      )
          .catchError((Object _) {
        // No-op: unhealthy state already reflects this and the fallback stays.
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    final mq = MediaQuery.of(context);
    final reduceMotion = mq.disableAnimations;
    final reduceTransparency = mq.highContrast;
    final cap = SceneCapability.detect(context);

    // Reduce Transparency or capability gating: bail to the fallback only.
    if (reduceTransparency || !cap.is3DSupported) {
      return widget.fallback;
    }

    _maybeAttemptLoad(cap, reduceMotion);

    return ValueListenableBuilder<bool>(
      valueListenable: _controller.healthy,
      builder: (context, healthy, _) {
        // Always paint the fallback as the bottom layer so the cross-fade
        // is symmetric and there is no first-frame flicker.
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.fallback,
            AnimatedOpacity(
              opacity: healthy ? 1.0 : 0.0,
              duration: v.motion.durationReveal,
              curve: v.motion.reveal,
              child: const _SceneSurface(),
            ),
          ],
        );
      },
    );
  }
}

/// Placeholder surface — Phase 5 will replace with a Filament-backed
/// `Texture` view bound to the controller's render isolate.
class _SceneSurface extends StatelessWidget {
  const _SceneSurface();

  @override
  Widget build(BuildContext context) {
    // Empty: the fallback layer paints. Once Phase 5 lands, this widget
    // becomes a `Texture(textureId)` driven by FFI.
    return const SizedBox.expand();
  }
}
