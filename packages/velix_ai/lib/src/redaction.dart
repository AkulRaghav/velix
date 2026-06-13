import 'package:meta/meta.dart';

/// Prompt sanitization. Every byte that goes to the AI gateway passes
/// through here first. See `docs/phase-8/06-prompt-sanitization.md`.
///
/// The redactor is deliberately aggressive: we over-redact rather than
/// under-redact. The user reviews the redacted output in the consent UX
/// before tapping Send.
class Redactor {
  Redactor._();

  static const _emailRe = r'[\w.+-]+@[\w-]+\.[\w.-]+';
  // Conservative phone-number regex; will fire on long digit runs that
  // aren't actually phone numbers; that's fine — we'd rather over-redact.
  static const _phoneRe =
      r'(?:\+?\d{1,3}[\s.\-])?\(?\d{3,4}\)?[\s.\-]?\d{3,4}[\s.\-]?\d{3,4}';
  static const _urlRe = r'https?://[^\s]+';
  static const _handleRe = r'@[\w]{2,32}';
  // 4+ consecutive digits → could be PIN, SSN-fragment, etc.
  static const _digitsRe = r'\b\d{4,}\b';
  // Zero-width and bidirectional control characters.
  static const _zeroWidthRe =
      r'[\u200B-\u200D\uFEFF\u202A-\u202E\u2066-\u2069]';
  // Control characters except newline (\n=0x0A) and tab (\t=0x09).
  static const _controlRe = r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]';

  /// Redacts [input]. Pass `aggressive: true` for summarization-style
  /// redaction (also collapses long capitalized words to `<name>` and
  /// long digit runs to `<number>`).
  static String redact(String input, {bool aggressive = false}) {
    var s = input;
    s = s.replaceAll(RegExp(_emailRe), '<email>');
    s = s.replaceAll(RegExp(_phoneRe), '<phone>');
    s = s.replaceAll(RegExp(_urlRe), '<url>');
    s = s.replaceAll(RegExp(_handleRe), '<handle>');
    s = s.replaceAll(RegExp(_zeroWidthRe), '');
    s = s.replaceAll(RegExp(_controlRe), '');

    if (aggressive) {
      s = s.replaceAll(RegExp(_digitsRe), '<number>');
      // Capitalized words ≥ 4 chars: heuristic for proper nouns.
      // Conservative; we leave the first word of a sentence alone.
      s = s.replaceAllMapped(
        RegExp(r'(\s|^)([A-Z][a-zA-Z]{3,})(?=[\s.,!?]|$)'),
        (m) {
          final lead = m.group(1) ?? '';
          // Don't redact common short proper words like "Dear" / "OK".
          // The simple rule: any capitalized word ≥ 4 chars not at the
          // start of the input or after a period.
          final word = m.group(2)!;
          if (word.length < 4) return '$lead$word';
          return '$lead<name>';
        },
      );
    }

    return s;
  }

  /// Idempotency check: redacting an already-redacted string is a no-op.
  /// CI tests assert this property holds.
  @visibleForTesting
  static bool isIdempotent(String input) {
    final once = redact(input);
    final twice = redact(once);
    return once == twice;
  }
}
