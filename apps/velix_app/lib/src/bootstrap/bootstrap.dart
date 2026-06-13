import 'dart:io' show Platform;

import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:velix_data/velix_data.dart';
import 'package:velix_domain/velix_domain.dart';

/// Bootstrap orchestrates the cold-start work that must happen before the
/// app's first frame paints.
///
/// Alpha mode: if a saved [AlphaSession] is found on disk, the bootstrap
/// instantiates the remote (HTTP) repositories. Otherwise it falls back
/// to the in-memory repositories with seeded demo data, so the UI is
/// reachable for first-run signup.
@immutable
class BootstrapResult {
  const BootstrapResult({
    required this.identityRepository,
    required this.conversationRepository,
    required this.messageRepository,
    required this.bootDuration,
    required this.alphaApiClient,
    required this.sessionStore,
    required this.session,
    required this.accessibilityStore,
    required this.accessibilityPreferences,
  });

  final IdentityRepository identityRepository;
  final ConversationRepository conversationRepository;
  final MessageRepository messageRepository;
  final Duration bootDuration;
  final AlphaApiClient alphaApiClient;
  final AlphaSessionStore sessionStore;
  final AlphaSession? session;
  final AccessibilityPreferencesStore accessibilityStore;
  final AccessibilityPreferences accessibilityPreferences;
}

class Bootstrap {
  const Bootstrap();

  /// Default HTTP base URL for the alpha server.
  ///
  /// Override at compile time:
  ///   flutter run --dart-define=VELIX_ALPHA_URL=http://10.0.2.2:8080
  ///
  /// Defaults pick a sensible value per platform:
  ///   - Android emulator: http://10.0.2.2:8080
  ///   - other: http://127.0.0.1:8080
  static Uri defaultAlphaUri() {
    const fromEnv = String.fromEnvironment('VELIX_ALPHA_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return Uri.parse(fromEnv);
    }
    if (Platform.isAndroid) {
      return Uri.parse('http://10.0.2.2:8080');
    }
    return Uri.parse('http://127.0.0.1:8080');
  }

  /// Default on-disk session file path. Override via [sessionPath] for tests.
  static Future<BootstrapResult> run({
    Uri? alphaUri,
    String sessionPath = 'velix_alpha_session.json',
    String accessibilityPath = 'velix_accessibility_prefs.json',
  }) async {
    final start = DateTime.timestamp();
    final uri = alphaUri ?? defaultAlphaUri();
    final client = AlphaApiClient(baseUri: uri);

    // Resolve file paths relative to the app's writable documents directory
    // so they work on real devices (not just emulator/desktop).
    final docsDir = await getApplicationDocumentsDirectory();
    final resolvedSessionPath = '${docsDir.path}/$sessionPath';
    final resolvedAccessibilityPath = '${docsDir.path}/$accessibilityPath';

    final sessionStore = AlphaSessionStore(path: resolvedSessionPath);
    final session = await sessionStore.load();
    final accessibilityStore =
        AccessibilityPreferencesStore(path: resolvedAccessibilityPath);
    final accessibilityPreferences = await accessibilityStore.load();

    if (session == null) {
      // First run / signed out: in-memory fallback with realistic demo data
      // so the UI looks populated and showcases the app's capabilities.
      final identityRepo = InMemoryIdentityRepository();
      await identityRepo.createOrSignIn(handle: 'guest', displayName: 'Guest');

      final now = Instant.now();
      const myId = IdentityId('me');
      const sarahId = IdentityId('sarah-chen');

      const sarahConvId = ConversationId('conv-sarah');
      const devConvId = ConversationId('conv-dev-team');
      const momConvId = ConversationId('conv-mom');
      const alexConvId = ConversationId('conv-alex');
      const bookConvId = ConversationId('conv-book-club');

      final demoConversations = <Conversation>[
        Conversation(
          id: sarahConvId,
          kind: ConversationKind.direct,
          title: 'Sarah Chen',
          roomColorIndex: 2,
          trustState: TrustState.verified,
          lastActivityAt: now.minus(const Duration(minutes: 5)),
          unreadCount: 1,
          archived: false,
          lastMessagePreview: 'See you at the cafe tomorrow! ☕',
        ),
        Conversation(
          id: devConvId,
          kind: ConversationKind.group,
          title: 'Dev Team',
          roomColorIndex: 7,
          trustState: TrustState.standard,
          lastActivityAt: now.minus(const Duration(hours: 2)),
          unreadCount: 0,
          archived: false,
          lastMessagePreview: 'PR #847 merged, nice work',
        ),
        Conversation(
          id: momConvId,
          kind: ConversationKind.direct,
          title: 'Mom',
          roomColorIndex: 0,
          trustState: TrustState.verified,
          lastActivityAt: now.minus(const Duration(days: 1)),
          unreadCount: 2,
          archived: false,
          lastMessagePreview: 'Love you, call me when free 💕',
        ),
        Conversation(
          id: alexConvId,
          kind: ConversationKind.direct,
          title: 'Alex Rivera',
          roomColorIndex: 5,
          trustState: TrustState.standard,
          lastActivityAt: now.minus(const Duration(days: 2)),
          unreadCount: 0,
          archived: false,
          lastMessagePreview: 'The concert was amazing last night',
        ),
        Conversation(
          id: bookConvId,
          kind: ConversationKind.group,
          title: 'Book Club',
          roomColorIndex: 9,
          trustState: TrustState.standard,
          lastActivityAt: now.minus(const Duration(days: 3)),
          unreadCount: 0,
          archived: false,
          lastMessagePreview: 'Next meeting: Tuesday 7pm',
        ),
      ];

      // Demo messages for the Sarah Chen conversation.
      final sarahMessages = <Message>[
        Message(
          id: const MessageId('msg-s1'),
          conversationId: sarahConvId,
          senderId: sarahId,
          kind: MessageKind.text,
          body: 'Hey! Are we still on for tomorrow?',
          sentAt: now.minus(const Duration(minutes: 12)),
          receivedAt: now.minus(const Duration(minutes: 12)),
          status: MessageStatus.read,
        ),
        Message(
          id: const MessageId('msg-s2'),
          conversationId: sarahConvId,
          senderId: myId,
          kind: MessageKind.text,
          body: 'Yes! What time works?',
          sentAt: now.minus(const Duration(minutes: 10)),
          receivedAt: now.minus(const Duration(minutes: 10)),
          status: MessageStatus.read,
        ),
        Message(
          id: const MessageId('msg-s3'),
          conversationId: sarahConvId,
          senderId: sarahId,
          kind: MessageKind.text,
          body: 'How about 3pm at the usual place?',
          sentAt: now.minus(const Duration(minutes: 8)),
          receivedAt: now.minus(const Duration(minutes: 8)),
          status: MessageStatus.read,
        ),
        Message(
          id: const MessageId('msg-s4'),
          conversationId: sarahConvId,
          senderId: myId,
          kind: MessageKind.text,
          body: 'Perfect, see you there',
          sentAt: now.minus(const Duration(minutes: 6)),
          receivedAt: now.minus(const Duration(minutes: 6)),
          status: MessageStatus.read,
        ),
        Message(
          id: const MessageId('msg-s5'),
          conversationId: sarahConvId,
          senderId: sarahId,
          kind: MessageKind.text,
          body: 'See you at the cafe tomorrow! ☕',
          sentAt: now.minus(const Duration(minutes: 5)),
          receivedAt: now.minus(const Duration(minutes: 5)),
          status: MessageStatus.delivered,
        ),
      ];

      // Demo messages for the Dev Team conversation.
      const devMemberId = IdentityId('dev-member');
      final devMessages = <Message>[
        Message(
          id: const MessageId('msg-d1'),
          conversationId: devConvId,
          senderId: devMemberId,
          kind: MessageKind.text,
          body: 'PR #847 is ready for review — refactored the auth module',
          sentAt: now.minus(const Duration(hours: 3)),
          receivedAt: now.minus(const Duration(hours: 3)),
          status: MessageStatus.read,
        ),
        Message(
          id: const MessageId('msg-d2'),
          conversationId: devConvId,
          senderId: myId,
          kind: MessageKind.text,
          body: 'On it. The test coverage looks solid 👍',
          sentAt: now.minus(const Duration(hours: 2, minutes: 45)),
          receivedAt: now.minus(const Duration(hours: 2, minutes: 45)),
          status: MessageStatus.read,
        ),
        Message(
          id: const MessageId('msg-d3'),
          conversationId: devConvId,
          senderId: devMemberId,
          kind: MessageKind.text,
          body: 'Left a comment on the error handling in line 42',
          sentAt: now.minus(const Duration(hours: 2, minutes: 20)),
          receivedAt: now.minus(const Duration(hours: 2, minutes: 20)),
          status: MessageStatus.read,
        ),
        Message(
          id: const MessageId('msg-d4'),
          conversationId: devConvId,
          senderId: myId,
          kind: MessageKind.text,
          body: 'PR #847 merged, nice work',
          sentAt: now.minus(const Duration(hours: 2)),
          receivedAt: now.minus(const Duration(hours: 2)),
          status: MessageStatus.read,
        ),
      ];

      // Demo messages for the Mom conversation.
      const momId = IdentityId('mom');
      final momMessages = <Message>[
        Message(
          id: const MessageId('msg-m1'),
          conversationId: momConvId,
          senderId: momId,
          kind: MessageKind.text,
          body: 'Hi sweetheart! How was your day?',
          sentAt: now.minus(const Duration(days: 1, hours: 2)),
          receivedAt: now.minus(const Duration(days: 1, hours: 2)),
          status: MessageStatus.read,
        ),
        Message(
          id: const MessageId('msg-m2'),
          conversationId: momConvId,
          senderId: myId,
          kind: MessageKind.text,
          body: 'Great! Shipped a big feature at work today 🎉',
          sentAt: now.minus(const Duration(days: 1, hours: 1)),
          receivedAt: now.minus(const Duration(days: 1, hours: 1)),
          status: MessageStatus.read,
        ),
        Message(
          id: const MessageId('msg-m3'),
          conversationId: momConvId,
          senderId: momId,
          kind: MessageKind.text,
          body: 'Love you, call me when free 💕',
          sentAt: now.minus(const Duration(days: 1)),
          receivedAt: now.minus(const Duration(days: 1)),
          status: MessageStatus.delivered,
        ),
      ];

      // Demo messages for the Alex Rivera conversation.
      const alexId = IdentityId('alex-rivera');
      final alexMessages = <Message>[
        Message(
          id: const MessageId('msg-a1'),
          conversationId: alexConvId,
          senderId: alexId,
          kind: MessageKind.text,
          body: 'Dude the concert was amazing last night 🎸',
          sentAt: now.minus(const Duration(days: 2, hours: 3)),
          receivedAt: now.minus(const Duration(days: 2, hours: 3)),
          status: MessageStatus.read,
        ),
        Message(
          id: const MessageId('msg-a2'),
          conversationId: alexConvId,
          senderId: myId,
          kind: MessageKind.text,
          body: 'Right?! That encore was insane. We need to go again',
          sentAt: now.minus(const Duration(days: 2, hours: 2)),
          receivedAt: now.minus(const Duration(days: 2, hours: 2)),
          status: MessageStatus.read,
        ),
        Message(
          id: const MessageId('msg-a3'),
          conversationId: alexConvId,
          senderId: alexId,
          kind: MessageKind.text,
          body: 'The concert was amazing last night',
          sentAt: now.minus(const Duration(days: 2)),
          receivedAt: now.minus(const Duration(days: 2)),
          status: MessageStatus.read,
        ),
      ];

      final conversationRepo =
          InMemoryConversationRepository(seed: demoConversations);
      final messageRepo = InMemoryMessageRepository(
        seed: {
          sarahConvId: sarahMessages,
          devConvId: devMessages,
          momConvId: momMessages,
          alexConvId: alexMessages,
        },
      );
      final boot = DateTime.timestamp().difference(start);
      return BootstrapResult(
        identityRepository: identityRepo,
        conversationRepository: conversationRepo,
        messageRepository: messageRepo,
        bootDuration: boot,
        alphaApiClient: client,
        sessionStore: sessionStore,
        session: null,
        accessibilityStore: accessibilityStore,
        accessibilityPreferences: accessibilityPreferences,
      );
    }

    // Authenticated: wire the remote repositories.
    client.token = session.token;
    final identityRepo = RemoteIdentityRepository(client: client, session: session);
    final conversationRepo = RemoteConversationRepository(
      client: client,
      myAccountId: session.accountId,
    );
    final messageRepo = RemoteMessageRepository(
      client: client,
      myAccountId: session.accountId,
    );
    final boot = DateTime.timestamp().difference(start);
    return BootstrapResult(
      identityRepository: identityRepo,
      conversationRepository: conversationRepo,
      messageRepository: messageRepo,
      bootDuration: boot,
      alphaApiClient: client,
      sessionStore: sessionStore,
      session: session,
      accessibilityStore: accessibilityStore,
      accessibilityPreferences: accessibilityPreferences,
    );
  }
}
