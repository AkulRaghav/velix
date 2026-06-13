import 'package:flutter/widgets.dart';
import 'package:velix_design/velix_design.dart';
import 'package:velix_motion/velix_motion.dart';

import '../../components/glass_card.dart';

/// VoiceMessageScreen — Tier B (overlay).
///
/// Presented as a `VelixModal` over the conversation. Renders the recording
/// UI — waveform, timer, and send affordance. Live microphone capture and
/// encrypted-envelope generation are wired with the media-capture feature.
class VoiceMessageScreen extends StatelessWidget {
  const VoiceMessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      color: v.colors.surface.scrim,
      child: SafeArea(
        child: Center(
          child: GlassCard(
            tier: GlassCardTier.active,
            padding: EdgeInsets.all(v.space.s9),
            radius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Recording', style: v.typography.titleM),
                SizedBox(height: v.space.insetLg),
                Waveform(
                  source: StaticWaveformSource(
                    amps: const [0.2, 0.5, 0.7, 0.9, 0.7, 0.5, 0.2],
                  ),
                ),
                SizedBox(height: v.space.insetLg),
                Text(
                  '0:04',
                  style: v.typography
                      .tabular(v.typography.bodyL)
                      .copyWith(color: v.colors.text.secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
