# 02 — Bench Harness

The harness is what turns "we should be fast" into "we are fast on iPhone 12 and Pixel 6." Every PR runs it; nightly runs the soak suite.

## Layout

```
benches/
  client/
    cold_start.dart                 ← cold-start launches × N, captures p95
    chat_list_scroll.dart           ← fling chat list × N, captures p99 frame
    conversation_open.dart          ← push to conversation × N
    conversation_scroll.dart        ← scroll long conversation
    bottom_sheet_drag.dart          ← detent drag × N
    modal_arrival.dart              ← modal show/dismiss × N
    composer_typing.dart            ← simulated typing speed
    waveform_continuous.dart        ← 30s recording simulation
    ai_streaming_text.dart          ← AI tokens render rate
  server/
    send_envelope_p99.k6.js         ← k6 load test
    subscribe_drain_p99.k6.js
    identity_signin_p99.k6.js
  cryptocore/
    encrypt_decrypt_bench.rs        ← criterion benches
    sealed_sender_bench.rs
    backup_roundtrip_bench.rs
  soak/
    memory_30min.dart
    memory_60min.dart
    battery_30min.dart
    battery_60min.dart
    chat_open_close_loop.dart       ← leak hunt
  fixtures/
    seed_fixtures.dart              ← representative data setup
```

## Tooling

- **Flutter integration tests:** built-in `integration_test` package, run via `flutter drive` or directly on devices.
- **Frame-time capture:** `WidgetsBinding.instance.addTimingsCallback` collects every frame's `FrameTiming`. We log build, raster, total durations.
- **Memory capture:** `developer.Service` exposes heap snapshots; we collect at intervals.
- **Battery:** `battery_plus` plugin (already in our deps) — read level at start/end of soak.
- **Server-side:** `k6` for HTTP/gRPC load tests.
- **Cryptocore:** `criterion` Rust benches.
- **Device farm:** BrowserStack App Live (primary) + Sauce Labs (failover). We pin specific OS images for reproducibility.

We do **not** use:
- Firebase Test Lab (less control over OS image pinning).
- AWS Device Farm (slower iteration).
- Custom in-house device lab (too expensive at our team size).

## Frame timing capture

The simplest, most useful primitive:

```dart
import 'dart:ui' as ui;

class FrameStats {
  FrameStats();

  final List<Duration> frames = [];
  void Function(List<ui.FrameTiming>)? _cb;

  void start() {
    _cb = (List<ui.FrameTiming> timings) {
      for (final t in timings) {
        frames.add(t.totalSpan);
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_cb!);
  }

  void stop() {
    if (_cb != null) {
      SchedulerBinding.instance.removeTimingsCallback(_cb!);
      _cb = null;
    }
  }

  Map<String, num> summary() {
    final ms = frames.map((d) => d.inMicroseconds / 1000.0).toList()..sort();
    if (ms.isEmpty) return {'count': 0};
    return {
      'count': ms.length,
      'p50_ms': ms[(ms.length * 0.50).floor()],
      'p95_ms': ms[(ms.length * 0.95).floor()],
      'p99_ms': ms[(ms.length * 0.99).floor()],
      'max_ms': ms.last,
      'over_16_6': ms.where((m) => m > 16.6).length / ms.length,
    };
  }
}
```

Bench results are emitted as JSON to stdout, parsed by the CI harness, compared against baseline.

## Cold-start bench

```dart
testWidgets('cold start', (tester) async {
  final stopwatch = Stopwatch()..start();
  // Launch fresh process; this is a separate harness flow that
  // measures from app exec to first Home frame painted.
  await launchAppFresh();
  await waitForFirstHomeFrame();
  stopwatch.stop();
  final ms = stopwatch.elapsedMilliseconds;

  print(jsonEncode({
    'metric': 'cold_start_ms',
    'value': ms,
    'budget': 800,
  }));
});
```

We run this 10 times per launch. The aggregator computes p95.

## Chat list scroll bench

```dart
testWidgets('chat list scroll p99 frame', (tester) async {
  await pumpApp(seedConversations: 50);
  await tester.tap(find.byKey(const Key('tab_chats')));
  await tester.pumpAndSettle();

  final stats = FrameStats()..start();

  // Fling 5 times. Each fling generates ~30-60 frames.
  for (var i = 0; i < 5; i++) {
    await tester.fling(find.byType(ListView), const Offset(0, -800), 1500);
    await tester.pump();
    // Let inertia run.
    for (var j = 0; j < 30; j++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  stats.stop();
  print(jsonEncode({
    'metric': 'chat_list_scroll',
    ...stats.summary(),
    'budget_p99_ms': 16.6,
  }));
});
```

Similar pattern for conversation scroll, modal arrival, sheet drag, etc.

## Memory soak bench

```dart
testWidgets('memory 30min', (tester) async {
  await pumpApp(seedConversations: 4);

  final samples = <int>[];
  for (var i = 0; i < 30; i++) {
    // Cycle: open conv 1 → conv 2 → conv 3 → conv 4 → back to chat list.
    await navigateConversation('c1');
    await scrollAndType();
    await goBack();
    await navigateConversation('c2');
    await scrollAndType();
    await goBack();
    // ... etc.

    // After each cycle, snapshot memory.
    samples.add(await rssBytes());
    await tester.pump(const Duration(minutes: 1));
  }

  print(jsonEncode({
    'metric': 'memory_30min',
    'samples_bytes': samples,
    'growth_pct': ((samples.last - samples.first) / samples.first * 100),
    'budget_growth_pct': 10,
  }));
});
```

Growth > 10% over 30 minutes → fail. (Real apps grow some; we tolerate 10%.)

## Battery soak

```dart
// Run on physical bench device with a wall-clock timer.
testWidgets('battery 30min', (tester) async {
  await pumpApp(seedConversations: 4);
  final battery = Battery();

  final startLevel = await battery.batteryLevel;
  final start = DateTime.now();

  // Simulate active use.
  while (DateTime.now().difference(start) < const Duration(minutes: 30)) {
    await navigateConversation('c1');
    await tester.pump(const Duration(seconds: 30));
    await goBack();
    await tester.pump(const Duration(seconds: 30));
  }

  final endLevel = await battery.batteryLevel;
  final drainPct = startLevel - endLevel;

  print(jsonEncode({
    'metric': 'battery_30min',
    'drain_pct': drainPct,
    'budget_pct': 1.5,  // 30 min ≈ 0.5 × hourly chat list budget
  }));
});
```

Battery soak runs on real hardware with controlled conditions: 50% screen brightness, airplane mode off, Wi-Fi connected, no notifications during the test.

## Server-side bench

```javascript
// k6 script: send_envelope_p99.k6.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    constant_rate: {
      executor: 'constant-arrival-rate',
      rate: 200,           // 200 RPS sustained
      timeUnit: '1s',
      duration: '60s',
      preAllocatedVUs: 50,
    },
  },
  thresholds: {
    http_req_duration: ['p(99)<80'],   // ms
    http_req_failed: ['rate<0.001'],   // 0.1% errors max
  },
};

export default function() {
  const payload = makeEnvelopePayload();
  const res = http.post(`${__ENV.GW}/v1/routing.SendEnvelope`, payload, {
    headers: { 'Authorization': `Bearer ${__ENV.TOKEN}` },
  });
  check(res, { 'status is 200': (r) => r.status === 200 });
}
```

Run before each release. Budget: p99 ≤ 80 ms; error rate < 0.1%.

## Cryptocore bench

```rust
use criterion::{criterion_group, criterion_main, Criterion};

fn bench_encrypt(c: &mut Criterion) {
    c.bench_function("double_ratchet_encrypt_2kb", |b| {
        let session = setup_session();
        let plaintext = vec![0u8; 2048];
        b.iter(|| session.encrypt(&plaintext))
    });
}

fn bench_decrypt(c: &mut Criterion) {
    c.bench_function("double_ratchet_decrypt_2kb", |b| {
        let (sender, mut receiver) = setup_pair();
        let envelope = sender.encrypt(&vec![0u8; 2048]);
        b.iter(|| receiver.decrypt(&envelope))
    });
}

criterion_group!(benches, bench_encrypt, bench_decrypt);
criterion_main!(benches);
```

Criterion produces stable comparable numbers across runs; > 5% regression on any bench fails CI.

## Baseline storage

Bench results are stored as JSON artifacts in CI. The aggregator:

1. Compares current run to the baseline stored on `main` branch's last green build.
2. Computes per-metric delta.
3. Fails the PR if any metric regresses beyond its threshold.
4. Updates the baseline on green main merge.

Storage: GitHub Actions artifacts + a small Postgres on the CI infra for trend analysis. Total storage cost: < $5/month.

## What gets reported on each PR

The CI bot comments:

```
Phase 9 bench results
─────────────────────
✓ cold_start_p95         784 ms (budget 800 ms; baseline 778 ms; +0.8%)
✓ chat_list_scroll_p99   12.4 ms (budget 16.6 ms; baseline 12.1 ms; +2.4%)
✓ conversation_open_p99  14.8 ms (budget 16.6 ms; baseline 14.2 ms; +4.2%)
✗ modal_arrival_p99      18.1 ms (budget 16.6 ms; baseline 13.4 ms; +35%)  REGRESSION
─────────────────────
Failing: 1 of 12 budgets

The modal_arrival regression looks like a tree-shake issue in the build.
See https://ci.velix.app/run/12345 for the full report.
```

## Banned

- Skipping the harness "for a hotfix."
- Adjusting baselines manually to "absorb" a regression.
- Disabling individual benches without an issue link.
- Running benches on premium devices instead of reference.
- Reporting averages instead of percentiles (averages hide the tail).
- Hand-rolled timing measurement that uses `DateTime.now()` (we use `Stopwatch` and Flutter's frame timings).
