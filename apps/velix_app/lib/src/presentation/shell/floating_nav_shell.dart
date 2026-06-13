import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:velix_design/velix_design.dart';

import '../../router/app_router.dart';

/// Velix Glass Command Bar — a minimal floating dock with morphing active
/// indicator, glassmorphism backdrop, and spring-scaled icons.
class FloatingNavShell extends StatelessWidget {
  const FloatingNavShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  static const _tabs = <_NavItem>[
    _NavItem(route: Routes.home, label: 'Home', icon: Icons.bolt_rounded),
    _NavItem(route: Routes.chats, label: 'Chats', icon: Icons.chat_bubble_rounded),
    _NavItem(route: Routes.explore, label: 'AI', icon: Icons.auto_awesome_rounded),
    _NavItem(route: Routes.notifications, label: 'Alerts', icon: Icons.notifications_rounded),
    _NavItem(route: Routes.profile, label: 'You', icon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final hidden = routeHidesNav(location);
    final activeIndex = _tabs.indexWhere((t) => t.route == location);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: child),
        if (!hidden)
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < _tabs.length; i++)
                        _NavButton(
                          item: _tabs[i],
                          active: i == activeIndex,
                          onTap: () => context.go(_tabs[i].route),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem({required this.route, required this.label, required this.icon});
  final String route;
  final String label;
  final IconData icon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: active ? 56 : 48,
        height: active ? 40 : 36,
        decoration: BoxDecoration(
          color: active ? v.colors.accent.signature.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(
          item.icon,
          size: active ? 24 : 22,
          color: active ? v.colors.accent.signature : Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
