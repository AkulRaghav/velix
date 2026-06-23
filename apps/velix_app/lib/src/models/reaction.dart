class MessageReaction {
  final String emoji;
  final String userId;
  final DateTime createdAt;
  const MessageReaction({required this.emoji, required this.userId, required this.createdAt});
}

class ReactionSummary {
  final String emoji;
  final int count;
  final bool includesMe;
  const ReactionSummary({required this.emoji, required this.count, required this.includesMe});
}
