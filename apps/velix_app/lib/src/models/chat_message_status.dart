enum ChatMessageStatus { sending, sent, delivered, read, failed }

extension ChatMessageStatusX on ChatMessageStatus {
  String get label => switch (this) { ChatMessageStatus.sending => 'Sending', ChatMessageStatus.sent => 'Sent', ChatMessageStatus.delivered => 'Delivered', ChatMessageStatus.read => 'Read', ChatMessageStatus.failed => 'Failed' };
  String get icon => switch (this) { ChatMessageStatus.sending => '...', ChatMessageStatus.sent => 'check', ChatMessageStatus.delivered => 'check_all', ChatMessageStatus.read => 'check_all_blue', ChatMessageStatus.failed => 'error' };
}
