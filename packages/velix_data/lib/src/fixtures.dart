import 'package:velix_domain/velix_domain.dart';

/// Demo data for Phase 5 development and golden tests.
///
/// In Phase 6 the gateway delivers real data and these are used only by
/// tests. Until then, the chat list and conversations seed from these.
List<Conversation> demoConversations() {
  final now = Instant.now();
  return [
    Conversation(
      id: const ConversationId('c-quinn'),
      kind: ConversationKind.direct,
      title: 'Quinn',
      roomColorIndex: 0, // mist
      trustState: TrustState.verified,
      lastActivityAt: now.minus(const Duration(minutes: 4)),
      unreadCount: 2,
      archived: false,
      lastMessagePreview: 'See you at six.',
    ),
    Conversation(
      id: const ConversationId('c-team'),
      kind: ConversationKind.group,
      title: 'Studio Team',
      roomColorIndex: 5, // iris
      trustState: TrustState.standard,
      lastActivityAt: now.minus(const Duration(hours: 1)),
      unreadCount: 0,
      archived: false,
      lastMessagePreview: 'Renders are in the shared folder.',
    ),
    Conversation(
      id: const ConversationId('c-mom'),
      kind: ConversationKind.direct,
      title: 'Mom',
      roomColorIndex: 8, // sand
      trustState: TrustState.verified,
      lastActivityAt: now.minus(const Duration(hours: 6)),
      unreadCount: 1,
      archived: false,
      lastMessagePreview: 'Sending love.',
    ),
    Conversation(
      id: const ConversationId('c-source'),
      kind: ConversationKind.direct,
      title: 'A. Source',
      roomColorIndex: 11, // slate
      trustState: TrustState.rekeyed,
      lastActivityAt: now.minus(const Duration(days: 2)),
      unreadCount: 0,
      archived: false,
      lastMessagePreview: 'Verify on next encounter.',
    ),
  ];
}

Map<ConversationId, List<Message>> demoMessages(IdentityId me) {
  Instant t(Duration ago) => Instant.now().minus(ago);
  return {
    const ConversationId('c-quinn'): [
      Message(
        id: const MessageId('m1'),
        conversationId: const ConversationId('c-quinn'),
        senderId: const IdentityId('quinn'),
        kind: MessageKind.text,
        body: 'On my way.',
        sentAt: t(const Duration(minutes: 14)),
        receivedAt: t(const Duration(minutes: 14)),
        status: MessageStatus.delivered,
      ),
      Message(
        id: const MessageId('m2'),
        conversationId: const ConversationId('c-quinn'),
        senderId: me,
        kind: MessageKind.text,
        body: 'Same. Five minutes.',
        sentAt: t(const Duration(minutes: 12)),
        receivedAt: t(const Duration(minutes: 12)),
        status: MessageStatus.read,
      ),
      Message(
        id: const MessageId('m3'),
        conversationId: const ConversationId('c-quinn'),
        senderId: const IdentityId('quinn'),
        kind: MessageKind.text,
        body: 'See you at six.',
        sentAt: t(const Duration(minutes: 4)),
        receivedAt: t(const Duration(minutes: 4)),
        status: MessageStatus.delivered,
      ),
    ],
  };
}
