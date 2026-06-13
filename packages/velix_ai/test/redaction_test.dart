import 'package:test/test.dart';
import 'package:velix_ai/velix_ai.dart';

void main() {
  group('Redactor.redact', () {
    test('replaces email addresses with <email>', () {
      final out = Redactor.redact('Contact me at quinn@example.com tomorrow.');
      expect(out, contains('<email>'));
      expect(out, isNot(contains('quinn@example.com')));
    });

    test('replaces phone-like sequences with <phone>', () {
      final out = Redactor.redact('Call 415-555-0142 if needed.');
      expect(out, contains('<phone>'));
    });

    test('replaces URLs with <url>', () {
      final out = Redactor.redact('See https://example.com/q?s=1 for details.');
      expect(out, contains('<url>'));
      expect(out, isNot(contains('example.com')));
    });

    test('replaces @handles with <handle>', () {
      final out = Redactor.redact('Ask @quinn what they think.');
      expect(out, contains('<handle>'));
      expect(out, isNot(contains('@quinn')));
    });

    test('strips zero-width characters', () {
      final out = Redactor.redact('hello\u200Bworld');
      expect(out, 'helloworld');
    });

    test('strips bidirectional control characters', () {
      final out = Redactor.redact('text\u202Eevil');
      expect(out, 'textevil');
    });

    test('strips control characters except newline and tab', () {
      final out = Redactor.redact('a\tb\nc\x00d');
      expect(out, contains('\t'));
      expect(out, contains('\n'));
      expect(out, isNot(contains('\x00')));
    });

    test('aggressive mode replaces long digit runs with <number>', () {
      final out = Redactor.redact('Account 123456789 has \$50.', aggressive: true);
      expect(out, contains('<number>'));
    });

    test('aggressive mode redacts capitalized proper-noun-like words', () {
      final out = Redactor.redact(
        'Quinn met Alice at the studio yesterday.',
        aggressive: true,
      );
      // "Quinn" at sentence start is left alone (heuristic), but "Alice"
      // should be redacted.
      expect(out, contains('<name>'));
    });

    test('redaction is idempotent', () {
      const cases = [
        'Hello world',
        'Email me at q@ex.com',
        'Call 415-555-0142',
        'Visit https://example.com today',
        'Hi @quinn',
        'a\tb\nc\x00d\u200Be',
      ];
      for (final c in cases) {
        expect(Redactor.isIdempotent(c), isTrue, reason: c);
      }
    });

    test('empty string is unchanged', () {
      expect(Redactor.redact(''), '');
    });

    test('plain text without identifiers is unchanged', () {
      const s = 'A quiet afternoon with nothing interesting in it.';
      expect(Redactor.redact(s), s);
    });
  });

  group('AIResult', () {
    test('Ok carries the value', () {
      const r = AIResult<int>.ok(42);
      final v = r.when(ok: (v) => v, failure: (_) => -1);
      expect(v, 42);
    });

    test('Failure carries the outcome', () {
      const r = AIResult<int>.failure(AIOutcome.consentDeclined);
      final outcome = r.when(ok: (_) => AIOutcome.success, failure: (o) => o);
      expect(outcome, AIOutcome.consentDeclined);
    });
  });

  group('ConsentToken / NoConsentRequired', () {
    test('NoConsentRequired returns null', () async {
      const provider = NoConsentRequired();
      final decision = await provider.requestConsent(
        feature: AIFeature.smartReply,
        redactedPreview: '',
        userExplanation: '',
      );
      expect(decision, isNull);
    });
  });
}
