import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:velix_design/velix_design.dart';
import 'package:velix_motion/velix_motion.dart';

import '../../components/glass_card.dart';

/// AIAssistantScreen — Tier B.
///
/// Sheet-shaped surface for the privacy-first assistant. Runs on-device by
/// default; any cloud invocation is gated behind explicit per-query consent
/// and routed through an OHTTP relay so the gateway never sees user identity.
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  StreamController<String>? _stream;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  void _begin() {
    _stream?.close();
    final c = StreamController<String>();
    _stream = c;
    const tokens = [
      'Velix ',
      'runs ',
      'this ',
      'assistant ',
      'on ',
      'this ',
      'device. ',
      'Nothing ',
      'leaves ',
      'unless ',
      'you ',
      'ask.',
    ];
    Future<void>.delayed(const Duration(milliseconds: 200), () async {
      for (final t in tokens) {
        if (!mounted || c.isClosed) return;
        c.add(t);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      await c.close();
    });
  }

  @override
  void dispose() {
    _stream?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      color: v.colors.surface.scrim,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: v.space.gutterScreen),
          child: Column(
            children: [
              SizedBox(height: v.space.s9),
              GlassCard(
                tier: GlassCardTier.active,
                padding: EdgeInsets.all(v.space.insetXl),
                radius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assistant', style: v.typography.titleM),
                    SizedBox(height: v.space.insetXs),
                    Text(
                      'Running on device',
                      style: v.typography.bodyS
                          .copyWith(color: v.colors.text.tertiary),
                    ),
                    SizedBox(height: v.space.insetLg),
                    if (_stream != null)
                      AIStreamingText(tokens: _stream!.stream),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
