import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:velix_design/velix_design.dart';

import '../../../router/app_router.dart';

/// Onboarding — premium, animated, minimal steps.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  static const _steps = [
    _Step(icon: Icons.lock_rounded, color: Color(0xFF3478F6), title: 'Yours, end to end.', body: 'Messages encrypted with Signal-grade cryptography. Only you and your recipient can read them.'),
    _Step(icon: Icons.auto_awesome_rounded, color: Color(0xFFf093fb), title: 'AI-native.', body: 'Smart replies, conversation summaries, and semantic search — powered by on-device AI.'),
    _Step(icon: Icons.speed_rounded, color: Color(0xFF43e97b), title: 'Built for speed.', body: 'Optimized for 120fps. Every interaction responds instantly with spring physics.'),
  ];

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    final step = _steps[_step];
    return Scaffold(
      backgroundColor: v.colors.surface.substrate,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: v.space.gutterScreen),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Animated icon with glow
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  key: ValueKey(_step),
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.color.withValues(alpha: 0.12),
                    boxShadow: [BoxShadow(color: step.color.withValues(alpha: 0.2), blurRadius: 40)],
                  ),
                  child: Icon(step.icon, size: 48, color: step.color),
                ),
              ),
              const SizedBox(height: 48),
              // Animated title
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(step.title, key: ValueKey('title$_step'), style: v.typography.displayS, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(step.body, key: ValueKey('body$_step'), style: v.typography.bodyL.copyWith(color: v.colors.text.secondary, height: 1.5), textAlign: TextAlign.center),
              ),
              const Spacer(flex: 3),
              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: i == _step ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _step ? v.colors.accent.signature : v.colors.text.tertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              // Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: v.colors.accent.signature,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(_step < _steps.length - 1 ? 'Continue' : 'Get Started', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go(Routes.auth),
                child: Text('Skip', style: v.typography.bodyM.copyWith(color: v.colors.text.tertiary)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      context.go(Routes.auth);
    }
  }
}

class _Step {
  const _Step({required this.icon, required this.color, required this.title, required this.body});
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}
