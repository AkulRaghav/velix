import 'consent.dart';
import 'redaction.dart';
import 'types.dart';

/// The single entry point for AI invocations. Decides on-device vs cloud,
/// handles consent, runs redaction, and dispatches.
///
/// Phase 8 ships the router skeleton. The on-device backends and the
/// cloud relay client are filled in during Phase 8.5 per
/// `docs/phase-8/04-on-device-models.md` and
/// `docs/phase-8/05-cloud-relay.md`.
class AIRouter {
  AIRouter({
    required ConsentProvider consent,
    required OnDeviceBackend onDevice,
    required CloudRelayBackend cloud,
  })  : _consent = consent,
        _onDevice = onDevice,
        _cloud = cloud;

  final ConsentProvider _consent;
  final OnDeviceBackend _onDevice;
  final CloudRelayBackend _cloud;

  /// Smart-reply suggestions for the active conversation. Always on-device.
  Future<AIResult<List<String>>> smartReply({
    required List<String> recentMessages,
    required String locale,
  }) async {
    if (!_onDevice.isAvailable(AIFeature.smartReply, locale)) {
      return const AIResult.failure(AIOutcome.modelUnavailable);
    }
    try {
      final candidates = await _onDevice.smartReply(recentMessages, locale);
      return AIResult.ok(candidates);
    } catch (_) {
      return const AIResult.failure(AIOutcome.inferenceFailed);
    }
  }

  /// Translation.
  ///
  /// On-device for short input. Cloud is reserved for input that genuinely
  /// exceeds the local model's capacity; failure of the on-device path does
  /// NOT silently escalate to cloud (banned per docs/phase-8/02-data-flows.md
  /// "Universal failure handling"). The user-visible cloud path is a separate
  /// affordance handled by [translateWithCloudAssist].
  Future<AIResult<String>> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    // Cloud-only path: the input genuinely exceeds the local model's capacity.
    if (text.length > 1500 ||
        !_onDevice.isAvailable(AIFeature.translation, targetLang)) {
      return translateWithCloudAssist(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
    }
    // Local path. No fallback.
    try {
      final out = await _onDevice.translate(text, sourceLang, targetLang);
      return AIResult.ok(out);
    } catch (_) {
      return const AIResult.failure(AIOutcome.inferenceFailed);
    }
  }

  /// Translation via cloud relay. Always asks per-query consent.
  /// Surfaced in UX as a separate "Translate with cloud assistance" action,
  /// or invoked by [translate] when the input genuinely exceeds local capacity.
  Future<AIResult<String>> translateWithCloudAssist({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final redacted = Redactor.redact(text);
    final decision = await _consent.requestConsent(
      feature: AIFeature.translationCloud,
      redactedPreview: redacted,
      userExplanation:
          'Translate this excerpt without identifying you. The text will be '
          'processed by Velix AI and not stored.',
    );
    if (decision == null) {
      return const AIResult.failure(AIOutcome.consentDeclined);
    }
    try {
      final out = await _cloud.translate(
        text: redacted,
        sourceLang: sourceLang,
        targetLang: targetLang,
        consent: decision,
      );
      return AIResult.ok(out);
    } catch (_) {
      return const AIResult.failure(AIOutcome.inferenceFailed);
    }
  }

  /// Summarize a thread. On-device for short threads, cloud for long with
  /// explicit per-query consent.
  Future<AIResult<String>> summarize({
    required List<String> messages,
    required String locale,
  }) async {
    final totalChars = messages.fold<int>(0, (sum, m) => sum + m.length);
    if (messages.length <= 200 &&
        totalChars <= 50000 &&
        _onDevice.isAvailable(AIFeature.summarization, locale)) {
      try {
        final out = await _onDevice.summarize(messages, locale);
        return AIResult.ok(out);
      } catch (_) {
        // Same posture as translate: don't auto-fallback to cloud.
        return const AIResult.failure(AIOutcome.inferenceFailed);
      }
    }
    // Cloud summarization with aggressive redaction.
    final redactedJoined =
        messages.map((m) => Redactor.redact(m, aggressive: true)).join('\n');
    final decision = await _consent.requestConsent(
      feature: AIFeature.summarizationCloud,
      redactedPreview: redactedJoined,
      userExplanation:
          'This thread is long. Send a redacted version to Velix AI for '
          'summarization? Names, numbers, and identifiers are replaced with '
          'placeholders before sending.',
    );
    if (decision == null) {
      return const AIResult.failure(AIOutcome.consentDeclined);
    }
    try {
      final out = await _cloud.summarize(
        redactedMessages: messages
            .map((m) => Redactor.redact(m, aggressive: true))
            .toList(growable: false),
        locale: locale,
        consent: decision,
      );
      return AIResult.ok(out);
    } catch (_) {
      return const AIResult.failure(AIOutcome.inferenceFailed);
    }
  }
}

/// Result of an AI invocation. Either a success with a value, or a failure
/// with an explicit outcome (no exception types crossing the boundary).
sealed class AIResult<T> {
  const AIResult();
  const factory AIResult.ok(T value) = _Ok<T>;
  const factory AIResult.failure(AIOutcome outcome) = _Failure<T>;

  R when<R>({
    required R Function(T value) ok,
    required R Function(AIOutcome outcome) failure,
  }) =>
      switch (this) {
        _Ok<T>(:final value) => ok(value),
        _Failure<T>(:final outcome) => failure(outcome),
      };
}

final class _Ok<T> extends AIResult<T> {
  const _Ok(this.value);
  final T value;
}

final class _Failure<T> extends AIResult<T> {
  const _Failure(this.outcome);
  final AIOutcome outcome;
}

/// On-device inference backend. Implementations wrap TFLite, CoreML, or
/// Gemini Nano per platform. Phase 8.5 fills these in.
abstract interface class OnDeviceBackend {
  bool isAvailable(AIFeature feature, String locale);
  Future<List<String>> smartReply(List<String> recentMessages, String locale);
  Future<String> translate(String text, String sourceLang, String targetLang);
  Future<String> summarize(List<String> messages, String locale);
}

/// Cloud relay backend. OHTTP-relayed connection to the Velix AI gateway.
/// Phase 8.5 fills this in.
abstract interface class CloudRelayBackend {
  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
    required ConsentDecision consent,
  });

  Future<String> summarize({
    required List<String> redactedMessages,
    required String locale,
    required ConsentDecision consent,
  });
}
