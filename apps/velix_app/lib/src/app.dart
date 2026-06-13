import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velix_design/velix_design.dart';

import 'di/providers.dart';
import 'router/app_router.dart';

class VelixApp extends ConsumerStatefulWidget {
  const VelixApp({super.key});

  @override
  ConsumerState<VelixApp> createState() => _VelixAppState();
}

class _VelixAppState extends ConsumerState<VelixApp> {
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    final theme = VelixTheme.dark();
    final a11y = ref.watch(accessibilityPreferencesProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Velix',
      theme: theme.toMaterialTheme(),
      routerConfig: _router,
      scrollBehavior: const _VelixScrollBehavior(),
      builder: (context, child) {
        final base = MediaQuery.of(context);
        return MediaQuery(
          data: base.copyWith(
            disableAnimations: base.disableAnimations || a11y.reduceMotion,
            highContrast: base.highContrast || a11y.highContrast,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _VelixScrollBehavior extends ScrollBehavior {
  const _VelixScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(_, Widget child, __) => child;

  @override
  Widget buildScrollbar(_, Widget child, __) => child;
}
