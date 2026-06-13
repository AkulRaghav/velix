import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:velix_design/velix_design.dart';

import '../../../di/providers.dart';
import '../../../router/app_router.dart';

/// Profile — premium, animated, rich.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.velix;
    final convCount = ref.watch(chatListProvider).valueOrNull?.length ?? 0;

    return Container(
      color: v.colors.surface.substrate,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // Animated gradient header
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.2,
                  colors: [
                    v.colors.accent.signature.withValues(alpha: 0.3),
                    v.colors.accent.s10.withValues(alpha: 0.1),
                    v.colors.surface.substrate,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated avatar with glow
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [v.colors.accent.s30, v.colors.accent.signature],
                      ),
                      boxShadow: [
                        BoxShadow(color: v.colors.accent.signature.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 2),
                      ],
                    ),
                    child: Center(
                      child: Text('A', style: v.typography.displayS.copyWith(color: Colors.white, fontSize: 32)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('akulraghav', style: v.typography.titleL),
                  const SizedBox(height: 4),
                  // Animated typing bio
                  SizedBox(
                    height: 20,
                    child: DefaultTextStyle(
                      style: v.typography.bodyM.copyWith(color: v.colors.text.tertiary),
                      child: AnimatedTextKit(
                        repeatForever: true,
                        pause: const Duration(seconds: 3),
                        animatedTexts: [
                          TypewriterAnimatedText('Building the future of private messaging 🔐', speed: const Duration(milliseconds: 50)),
                          TypewriterAnimatedText('End-to-end encrypted • AI-native • Premium', speed: const Duration(milliseconds: 50)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Stats
            Padding(
              padding: EdgeInsets.symmetric(horizontal: v.space.gutterScreen),
              child: Row(
                children: [
                  _StatCard(v: v, value: '$convCount', label: 'Chats', icon: Icons.chat_bubble_rounded),
                  const SizedBox(width: 10),
                  _StatCard(v: v, value: '24', label: 'Messages', icon: Icons.send_rounded),
                  const SizedBox(width: 10),
                  _StatCard(v: v, value: '100%', label: 'Encrypted', icon: Icons.lock_rounded),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Menu items
            Padding(
              padding: EdgeInsets.symmetric(horizontal: v.space.gutterScreen),
              child: Column(
                children: [
                  _MenuItem(v: v, icon: Icons.person_rounded, label: 'Edit Profile', color: v.colors.accent.signature, onTap: () {}),
                  _MenuItem(v: v, icon: Icons.palette_rounded, label: 'Appearance', color: const Color(0xFFf093fb), onTap: () {}),
                  _MenuItem(v: v, icon: Icons.notifications_rounded, label: 'Notifications', color: const Color(0xFFf5576c), onTap: () {}),
                  _MenuItem(v: v, icon: Icons.security_rounded, label: 'Privacy & Security', color: const Color(0xFF43e97b), onTap: () => context.push(Routes.privacy)),
                  _MenuItem(v: v, icon: Icons.storage_rounded, label: 'Storage & Data', color: const Color(0xFF667eea), onTap: () {}),
                  _MenuItem(v: v, icon: Icons.devices_rounded, label: 'Linked Devices', color: const Color(0xFF4facfe), onTap: () {}),
                  _MenuItem(v: v, icon: Icons.settings_rounded, label: 'Settings', color: v.colors.text.secondary, onTap: () => context.push(Routes.settings)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Version
            Center(
              child: Text('Velix v1.0.0 • End-to-end encrypted', style: v.typography.labelS.copyWith(color: v.colors.text.tertiary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.v, required this.value, required this.label, required this.icon});
  final VelixTheme v;
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: v.colors.surface.lifted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: v.colors.accent.signature),
            const SizedBox(height: 8),
            Text(value, style: v.typography.titleM),
            const SizedBox(height: 2),
            Text(label, style: v.typography.labelS.copyWith(color: v.colors.text.tertiary)),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.v, required this.icon, required this.label, required this.color, required this.onTap});
  final VelixTheme v;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: v.typography.bodyL)),
            Icon(Icons.chevron_right_rounded, size: 20, color: v.colors.text.tertiary),
          ],
        ),
      ),
    );
  }
}
