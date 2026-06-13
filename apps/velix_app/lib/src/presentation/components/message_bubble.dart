import 'package:flutter/widgets.dart';
import 'package:velix_design/velix_design.dart';
import 'package:velix_domain/velix_domain.dart';
import 'package:velix_motion/velix_motion.dart';

import 'glass_card.dart';

/// Velix component contract: MessageBubble.
/// See `docs/phase-2/09-component-contracts.md`.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isOutgoing,
    required this.roomColorIndex,
    this.showStatus = true,
  });

  final Message message;
  final bool isOutgoing;
  final int roomColorIndex;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    final align = isOutgoing
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.78;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: v.space.gutterList,
        vertical: 4,
      ),
      child: VelixArrive(
        translationOffset: 12,
        scaleAmount: 0,
        child: Column(
          crossAxisAlignment: align,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: isOutgoing
                  ? _OutgoingBubble(message: message)
                  : _IncomingBubble(
                      message: message,
                      roomColorIndex: roomColorIndex,
                    ),
            ),
            if (showStatus)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                child: _StatusLine(message: message, isOutgoing: isOutgoing),
              ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingBubble extends StatelessWidget {
  const _OutgoingBubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            v.colors.accent.s30,
            v.colors.accent.signature,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: v.colors.accent.signature.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        message.body,
        style: v.typography.bodyL.copyWith(color: v.colors.text.inverse),
      ),
    );
  }
}

class _IncomingBubble extends StatelessWidget {
  const _IncomingBubble({required this.message, required this.roomColorIndex});
  final Message message;
  final int roomColorIndex;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return GlassCard(
      tier: GlassCardTier.quiet,
      tintColor: v.colors.rooms.fromHash(roomColorIndex),
      tintOpacity: 0.06,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      radius: 16,
      child: Text(
        message.body,
        style: v.typography.bodyL.copyWith(color: v.colors.text.primary),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.message, required this.isOutgoing});
  final Message message;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    final timeStr = _formatTime(message.sentAt);
    final statusGlyph = isOutgoing ? _glyphFor(message.status) : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeStr,
          style: v.typography
              .tabular(v.typography.bodyS)
              .copyWith(color: v.colors.text.tertiary),
        ),
        if (isOutgoing) ...[
          SizedBox(width: v.space.insetSm),
          Text(
            statusGlyph,
            style: v.typography.bodyS.copyWith(color: v.colors.text.tertiary),
          ),
        ],
      ],
    );
  }
}

String _formatTime(Instant t) {
  final dt = t.toDateTime().toLocal();
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _glyphFor(MessageStatus s) => switch (s) {
      MessageStatus.pending => 'â€¦',
      MessageStatus.sent => 'âœ“',
      MessageStatus.delivered => 'âœ“âœ“',
      MessageStatus.read => 'âœ“âœ“',
      MessageStatus.failed => '!',
    };
