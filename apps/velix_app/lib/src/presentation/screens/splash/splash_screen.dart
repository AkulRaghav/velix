import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:velix_design/velix_design.dart';

import '../../../di/providers.dart';
import '../../../router/app_router.dart';

/// Splash — premium branded entry with animated logo.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _anim, curve: Curves.elasticOut));
    _opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _anim, curve: const Interval(0.3, 1.0)));

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final boot = ref.read(bootstrapProvider);
      context.go(boot.session != null ? Routes.home : Routes.home); // Always go to home (demo mode shows content)
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            v.colors.accent.signature.withValues(alpha: 0.15),
            v.colors.surface.substrate,
          ],
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [v.colors.accent.s30, v.colors.accent.signature],
                      ),
                      boxShadow: [BoxShadow(color: v.colors.accent.signature.withValues(alpha: 0.4), blurRadius: 32)],
                    ),
                    child: const Center(child: Text('V', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
                  const SizedBox(height: 20),
                  Text('Velix', style: v.typography.displayS),
                  const SizedBox(height: 6),
                  Text('Private messaging, reimagined', style: v.typography.bodyS.copyWith(color: v.colors.text.tertiary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
