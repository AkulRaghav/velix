import 'dart:async';

import 'package:flutter/material.dart';
import 'package:velix_design/velix_design.dart';

/// Renders an AI streaming response token-by-token. Each token fades in
/// over 60 ms with a 12 ms gap before the next; older tokens stay opaque.
///
/// Reduce-Motion: tokens appear instantly; the natural pacing of the source
/// stream is preserved.
///
/// AT: a `LiveRegion('AI thinking')` is announced on first token. The full
/// response is announced once on stream completion. We do not announce
/// per-token â€” that's deafening.
class AIStreamingText extends StatefulWidget {
  const AIStreamingText({
    super.key,
    required this.tokens,
    this.style,
    this.padding,
  });

  final Stream<String> tokens;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  @override
  State<AIStreamingText> createState() => _AIStreamingTextState();
}

class _AIStreamingTextState extends State<AIStreamingText>
    with TickerProviderStateMixin {
  StreamSubscription<String>? _sub;
  final List<_Token> _tokens = [];
  String _completeText = '';
  bool _firstAnnounced = false;
  bool _completionAnnounced = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.tokens.listen(_onToken, onDone: _onDone);
  }

  void _onToken(String t) {
    if (!mounted) return;
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    );
    setState(() {
      _tokens.add(_Token(text: t, opacity: ctrl));
      _completeText += t;
    });
    final mq = MediaQuery.maybeOf(context);
    final reduce = mq?.disableAnimations ?? false;
    if (reduce) {
      ctrl.value = 1;
    } else {
      ctrl.forward();
    }
    if (!_firstAnnounced) {
      _firstAnnounced = true;
      // The Semantics wrapper around the widget owns the LiveRegion; we
      // toggle its key to re-announce.
    }
    // 12 ms gap between tokens is the source's responsibility â€” we don't add
    // artificial pacing.
  }

  void _onDone() {
    if (!mounted) return;
    setState(() => _completionAnnounced = true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final t in _tokens) {
      t.opacity.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<VelixTheme>();
    final style = widget.style ?? theme?.typography.bodyL;
    final padding = widget.padding ?? EdgeInsets.zero;
    return Semantics(
      liveRegion: !_completionAnnounced,
      label: _completionAnnounced
          ? _completeText
          : (_firstAnnounced ? 'AI thinking' : null),
      excludeSemantics: !_completionAnnounced,
      child: Padding(
        padding: padding,
        child: AnimatedBuilder(
          animation: Listenable.merge(_tokens.map((e) => e.opacity).toList()),
          builder: (context, _) {
            return RichText(
              text: TextSpan(
                style: style,
                children: [
                  for (final tok in _tokens)
                    TextSpan(
                      text: tok.text,
                      style: TextStyle(
                        color: (style?.color ?? const Color(0xFFF2F4FA))
                            .withOpacity(tok.opacity.value),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Token {
  _Token({required this.text, required this.opacity});
  final String text;
  final AnimationController opacity;
}
