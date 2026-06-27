import 'package:meta/meta.dart';

import '../value_objects/ids.dart';
import '../value_objects/instant.dart';

/// Granular per-device delivery tracking for a message.
///
/// While [MessageStatus] on [Message] provides a summary state,
/// [MessageReceipt] tracks the exact state per recipient device.
/// This enables UI patterns like "✓ sent • ✓✓ 2 delivered • 👁 1 read".
enum ReceiptKind {
  /// Server acknowledged receipt of the envelope.
  serverAck,

  /// Recipient device has downloaded the envelope.
  deviceDelivered,

  /// Recipient has opened the conversation and seen the message.
  read,
}

@immutable
class MessageReceipt {
  const MessageReceipt({
    required this.messageId,
    required this.recipientId,
    required this.deviceId,
    required this.kind,
    required this.at,
  });

  /// The message this receipt pertains to.
  final MessageId messageId;

  /// The recipient identity that generated this receipt.
  final IdentityId recipientId;

  /// The specific device that generated this receipt.
  final DeviceId deviceId;

  /// What stage of delivery this receipt represents.
  final ReceiptKind kind;

  /// When the receipt was generated.
  final Instant at;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageReceipt &&
          messageId == other.messageId &&
          recipientId == other.recipientId &&
          deviceId == other.deviceId &&
          kind == other.kind;

  @override
  int get hashCode => Object.hash(messageId, recipientId, deviceId, kind);

  @override
  String toString() =>
      'MessageReceipt($kind for $messageId → $recipientId:$deviceId at $at)';
}

/// Aggregated receipt summary for display in message bubbles.
@immutable
class ReceiptSummary {
  const ReceiptSummary({
    required this.messageId,
    this.serverAckAt,
    this.deliveredCount = 0,
    this.readCount = 0,
    this.totalRecipients = 1,
  });

  final MessageId messageId;

  /// When the server acknowledged the envelope (null if pending).
  final Instant? serverAckAt;

  /// How many recipient devices have confirmed delivery.
  final int deliveredCount;

  /// How many recipients have read the message.
  final int readCount;

  /// Total number of recipients (for group chats).
  final int totalRecipients;

  /// Whether all recipients have read the message.
  bool get fullyRead => readCount >= totalRecipients;

  /// Whether all recipients have received the message.
  bool get fullyDelivered => deliveredCount >= totalRecipients;

  /// Whether the server has acknowledged the message.
  bool get isSent => serverAckAt != null;
}
