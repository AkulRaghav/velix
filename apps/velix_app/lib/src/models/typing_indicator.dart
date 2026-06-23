class TypingIndicator {
  final String userId;
  final String displayName;
  final DateTime startedAt;
  const TypingIndicator({required this.userId, required this.displayName, required this.startedAt});
  bool get isExpired => DateTime.now().difference(startedAt).inSeconds > 5;
}
