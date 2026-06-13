import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:velix_design/velix_design.dart';

/// Real-time audio amplitude visualization (seven bars).
///
/// Driven by a [WaveformSource]; never decorative. Reduce-Motion freezes
/// the bars at the resting amplitude (8 px each).
class Waveform extends StatefulWidget {
  const Waveform({
    super.key,
    required this.source,
    this.activeColor,
    this.inactiveColor,
    this.width = 120,
    this.height = 32,
  });

  final WaveformSource source;
  final Color? activeColor;
  final Color? inactiveColor;
  final double width;
  final double height;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> {
  @override
  void initState() {
    super.initState();
    widget.source.addListener(_repaint);
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant Waveform old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      old.source.removeListener(_repaint);
      widget.source.addListener(_repaint);
    }
  }

  @override
  void dispose() {
    widget.source.removeListener(_repaint);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<VelixTheme>();
    final mq = MediaQuery.maybeOf(context);
    final reduce = mq?.disableAnimations ?? false;

    final active = widget.activeColor ??
        theme?.colors.accent.signature ??
        const Color(0xFF3478F6);
    final inactive = widget.inactiveColor ??
        theme?.colors.text.secondary ??
        const Color(0xFFB7BBC9);

    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: _WaveformPainter(
        amps: reduce ? List<double>.filled(7, 0.25) : widget.source.amps,
        active: active,
        inactive: inactive,
        playheadFraction: widget.source.playheadFraction,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amps,
    required this.active,
    required this.inactive,
    required this.playheadFraction,
  });

  final List<double> amps; // length 7, each in [0, 1]
  final Color active;
  final Color inactive;
  final double playheadFraction; // 0..1, for playback bar coloring

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 4.0;
    const gap = 6.0;
    const minHeight = 4.0;
    final maxHeight = size.height;
    final totalWidth = barWidth * 7 + gap * 6;
    final startX = (size.width - totalWidth) / 2;
    final paint = Paint();
    for (var i = 0; i < 7; i++) {
      final amp = amps[i].clamp(0.0, 1.0);
      final h = minHeight + (maxHeight - minHeight) * amp;
      final x = startX + i * (barWidth + gap);
      final y = (size.height - h) / 2;
      paint.color = (i / 7) <= playheadFraction ? active : inactive;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      !listEquals(old.amps, amps) ||
      old.playheadFraction != playheadFraction ||
      old.active != active ||
      old.inactive != inactive;
}

/// Source of waveform amplitudes. Implementations:
/// - `MicWaveformSource` â€” wraps the platform mic, low-passed.
/// - `EnvelopeWaveformSource` â€” replays a stored envelope at the playhead rate.
abstract class WaveformSource extends ChangeNotifier {
  /// Seven values in [0, 1].
  List<double> get amps;

  /// Playhead position 0..1 for playback colouring; 1.0 for live recording
  /// (all bars active).
  double get playheadFraction;
}

/// A trivial in-memory source useful for tests and previews.
class StaticWaveformSource extends WaveformSource {
  StaticWaveformSource({
    required List<double> amps,
    double playheadFraction = 1.0,
  })  : _amps = List<double>.unmodifiable(amps),
        _playhead = playheadFraction {
    assert(_amps.length == 7);
  }

  final List<double> _amps;
  final double _playhead;

  @override
  List<double> get amps => _amps;

  @override
  double get playheadFraction => _playhead;
}

/// Plays back a pre-computed amplitude envelope (e.g., the encrypted
/// envelope shipped alongside a voice message). The envelope is sampled
/// at 50 Hz; the seven displayed bars represent a 7-sample window
/// centered on the playhead.
class EnvelopeWaveformSource extends WaveformSource {
  EnvelopeWaveformSource({required this.envelope})
      : assert(envelope.isNotEmpty);

  final List<double> envelope;
  double _playhead = 0;

  set playhead(double v) {
    _playhead = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  @override
  double get playheadFraction => _playhead;

  @override
  List<double> get amps {
    final centerIndex = (_playhead * envelope.length).round();
    const window = 7;
    final half = window ~/ 2;
    final out = <double>[];
    for (var i = -half; i <= half; i++) {
      final idx = (centerIndex + i).clamp(0, envelope.length - 1);
      out.add(envelope[idx].clamp(0.0, 1.0));
    }
    return out;
  }
}

/// Test helper: deterministic sine-wave envelope at the requested length.
List<double> debugEnvelope(int length) {
  return List<double>.generate(
    length,
    (i) => 0.5 + 0.5 * math.sin(i * 0.4),
  );
}
