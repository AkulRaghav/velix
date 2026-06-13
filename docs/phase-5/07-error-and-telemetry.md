# 07 — Error Handling & Telemetry

## Error model

Every fallible operation returns `Result<Success, Error>` from `velix_domain`. We do not use exceptions across layers — exceptions are a Dart-internal concern; the API surface uses values.

```dart
sealed class Result<S, E> {
  const Result();
  T when<T>({
    required T Function(S) ok,
    required T Function(E) err,
  });
  Result<S2, E> map<S2>(S2 Function(S) f);
  Result<S, E2> mapError<E2>(E2 Function(E) f);
}

final class Ok<S, E> extends Result<S, E> { ... }
final class Err<S, E> extends Result<S, E> { ... }

extension ResultGuard<S> on Result<S, AppError> {
  static Future<Result<T, AppError>> guard<T>(
    Future<T> Function() f,
  ) async {
    try {
      return Ok(await f());
    } on PlatformException catch (e) {
      return Err(AppError.platform(e));
    } on TimeoutException catch (e) {
      return Err(AppError.timeout(e));
    } catch (e, st) {
      return Err(AppError.unknown(e, st));
    }
  }
}
```

## Error taxonomy

```dart
sealed class AppError {
  const AppError();
}

final class NetworkError extends AppError { /* offline, server-5xx, timeout */ }
final class AuthError extends AppError { /* unauthorized, expired */ }
final class CryptoError extends AppError { /* sign, verify, decrypt fail */ }
final class StorageError extends AppError { /* db full, locked */ }
final class ValidationError extends AppError { /* user input rejected */ }
final class NotFoundError extends AppError { /* entity missing */ }
final class PermissionError extends AppError { /* user has no permission */ }
final class ConflictError extends AppError { /* version mismatch */ }
final class UnknownError extends AppError { /* fallback */ }
```

Each error carries the minimum information to render a useful UX message — and never carries PII or message content.

## Error rendering

The `errorReporterProvider` is the single dispatch point. Screens never decide what to show for an error:

```dart
ref.read(errorReporterProvider).report(error, context: 'send_message');
```

The reporter:
- Logs to `velix_telemetry` (no PII)
- Shows a `VelixToast` if the error is user-actionable
- Suppresses repeats within 30 seconds for the same error class

User-facing copy is centralized in `apps/velix_app/lib/src/l10n/error_messages.arb` and translated for every supported language.

## Crash reporting

`Sentry` is wrapped in `velix_telemetry`. We capture:
- Uncaught exceptions in the root zone
- Crashed isolates
- Flutter framework errors via `FlutterError.onError`

Captures are scrubbed:
- Message bodies are stripped before sending
- Identity keys, account IDs, and device IDs are hashed (one-way, salted per release)
- Contact handles are redacted to `<contact>`
- File paths are normalized to `<app-doc>/...`

A scrubber lints every Sentry payload in transit; if a known PII pattern leaks, we drop the report.

## Telemetry framework

`velix_telemetry` wraps OpenTelemetry's Dart SDK. We export:
- Spans (operation timings)
- Counters (events)
- Histograms (frame times, network latencies)

Sinks:
- Console (debug only)
- Local breadcrumb buffer (in-memory, ring-bound)
- Remote OTel collector (production)

Event categories:

| Category | Examples | PII |
|---|---|---|
| Performance | `frame.time`, `db.query.duration`, `route.transition.duration` | none |
| Lifecycle | `app.start`, `app.background`, `db.open`, `bootstrap.duration` | none |
| Feature | `message.send.attempted`, `voice.record.started` | none |
| Error | `error.reported{class}` | none |
| Security | `secure_storage.read{key_name}` | none |

Note: every event records its **class** of action, not the specific action. We log "message sent" but not "sent to person X."

## Performance sampling

In production:
- 100% of error events
- 100% of bootstrap timings
- 5% of frame-time histograms (sampled per session)
- 10% of route transitions (sampled)

Sampling rates are server-side configurable via a remote-config-style flag.

## Frame-time tracking

A `FrameObserver` listens to `SchedulerBinding.addPersistentFrameCallback` and records:
- Build phase duration
- Raster phase duration
- Total frame time

When a frame exceeds 16.6 ms, a breadcrumb is added. When 5 frames in 1 second exceed it, a span is logged.

## Breadcrumbs

A 200-entry ring buffer of recent events, attached to any error report. Examples:
- `route.push: /chats/abc123`
- `provider.dispose: messagesProvider(...)`
- `gateway.timeout: send_message`

Breadcrumbs do not carry PII. They make debugging tractable without surveilling users.

## Production audit hooks

- All `print()` calls fail lint (we use `velix_telemetry`).
- All `Sentry.captureException` calls fail lint outside `velix_telemetry`.
- Any string in a Sentry payload longer than 256 characters is truncated automatically.
- Every error class has a `toLogString()` that does not include data.

## Banned

- `try/catch` that swallows without logging.
- Logging at `info` for every operation (we'd flood the sink).
- Sending screenshots in error reports.
- Including breadcrumbs from before the user signed in.
- Sending request bodies or response bodies in error reports.
