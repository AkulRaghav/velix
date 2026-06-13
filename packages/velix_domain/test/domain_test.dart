import 'dart:async';

import 'package:test/test.dart';
import 'package:velix_domain/velix_domain.dart';

class _FakeMessageRepo implements MessageRepository {
  final List<String> sent = [];

  @override
  Stream<List<Message>> watch(ConversationId conversationId) =>
      const Stream<List<Message>>.empty();

  @override
  Future<MessageId> sendText({
    required ConversationId conversationId,
    required IdentityId senderId,
    required String body,
    MessageId? replyToId,
  }) async {
    sent.add(body);
    return const MessageId('m1');
  }

  @override
  Future<void> addReaction({
    required MessageId messageId,
    required IdentityId byIdentityId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction({
    required MessageId messageId,
    required IdentityId byIdentityId,
    required String emoji,
  }) async {}

  @override
  Future<void> retry(MessageId messageId) async {}

  @override
  Future<void> delete(MessageId messageId) async {}
}

class _FakeIdentityRepo implements IdentityRepository {
  _FakeIdentityRepo({this.signedIn = true});

  final bool signedIn;

  @override
  Stream<Identity?> watch() async* {
    yield signedIn
        ? Identity(
            id: const IdentityId('me'),
            handle: 'me',
            publicKey: const [],
            createdAt: Instant.epoch,
          )
        : null;
  }

  @override
  Future<Identity> createOrSignIn({String? displayName, String? handle}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<void> update(Identity updated) => throw UnimplementedError();
}

void main() {
  group('Result', () {
    test('Ok and Err pattern-match correctly', () {
      const Result<int, String> ok = Ok(42);
      expect(ok.when(ok: (v) => v, err: (_) => -1), 42);
      const Result<int, String> err = Err('boom');
      expect(err.when(ok: (_) => 0, err: (e) => e.length), 4);
    });

    test('map and mapError respect variant', () {
      const Result<int, String> ok = Ok(2);
      expect(ok.map((v) => v * 3).valueOrNull, 6);
      const Result<int, String> err = Err('x');
      expect(err.mapError((e) => e + e).errorOrNull, 'xx');
    });
  });

  group('Instant', () {
    test('comparison and arithmetic', () {
      final a = Instant.fromDateTime(
        DateTime.utc(2024, 1, 1).add(const Duration(seconds: 10)),
      );
      final b = a.plus(const Duration(seconds: 5));
      expect(b.isAfter(a), isTrue);
      expect(b.since(a), const Duration(seconds: 5));
    });
  });

  group('SendMessageUseCase', () {
    test('rejects empty body', () async {
      final usecase = SendMessageUseCase(
        messages: _FakeMessageRepo(),
        identity: _FakeIdentityRepo(),
      );
      final res = await usecase.call(
        conversationId: const ConversationId('c1'),
        body: '   ',
      );
      expect(res.errorOrNull, isA<ValidationError>());
    });

    test('rejects too-long body', () async {
      final usecase = SendMessageUseCase(
        messages: _FakeMessageRepo(),
        identity: _FakeIdentityRepo(),
      );
      final res = await usecase.call(
        conversationId: const ConversationId('c1'),
        body: 'a' * 9000,
      );
      expect(res.errorOrNull, isA<ValidationError>());
    });

    test('rejects when no identity', () async {
      final usecase = SendMessageUseCase(
        messages: _FakeMessageRepo(),
        identity: _FakeIdentityRepo(signedIn: false),
      );
      final res = await usecase.call(
        conversationId: const ConversationId('c1'),
        body: 'hello',
      );
      expect(res.errorOrNull, isA<AuthError>());
    });

    test('happy path returns the new message id', () async {
      final repo = _FakeMessageRepo();
      final usecase = SendMessageUseCase(
        messages: repo,
        identity: _FakeIdentityRepo(),
      );
      final res = await usecase.call(
        conversationId: const ConversationId('c1'),
        body: 'hi',
      );
      expect(res.isOk, isTrue);
      expect(repo.sent, ['hi']);
    });
  });
}
