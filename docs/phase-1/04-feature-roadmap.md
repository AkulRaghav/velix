# 04 — Feature Roadmap

Time-bounded, gated by quality. Dates are in elapsed engineering weeks from project start. They assume a small senior team (2 client engineers, 2 backend, 1 cryptographer/security, 1 designer, 1 SRE/DevOps, 1 PM/eng-lead). Adjust proportionally for actual team shape.

## Milestone 0 — Foundations (Weeks 1–4)

**Goal.** No user-facing product yet. Everything below must exist before features can be honest.

- Phase 1 dossier (this folder) ratified
- Phase 2 design system tokens, component contracts, motion grammar
- Phase 3 3D experience scope locked (3 surfaces only)
- Monorepo skeleton (`/apps/velix_app`, `/services/*`, `/packages/*`, `/infra`)
- CI/CD baseline: lint, type-check, unit tests, container builds
- Local dev stack: docker-compose with Postgres, Redis, NATS, LiveKit, MinIO
- Cryptographic core forked from libsignal, Dart FFI bindings stubbed and tested
- Telemetry plumbing (OTel SDK in client and services)

**Audit gate.** Phase 1 + 2 + 3 audits pass. No code on user-facing features begins until then.

---

## Milestone 1 — Internal alpha (Weeks 5–8)

**Goal.** Two team members on two phones can have an end-to-end encrypted conversation that survives a process kill.

| Feature | Notes |
|---|---|
| Cryptographic identity creation | X25519 + Ed25519, hardware-backed where available |
| Pairing / device addition (within an account) | QR via existing trusted device |
| 1:1 messaging | X3DH + Double Ratchet |
| Local persistence | SQLite + SQLCipher; per-message MAC verified before render |
| Push delivery | APNs / FCM with encrypted payload, server holds only routing token |
| Presence (typing, last-active, online) | Privacy-respecting: shared only with matched contacts |
| Read receipts | Off by default, per-thread toggle |
| Login / logout / lock | Biometric unlock with fallback PIN |
| Crash reporting | Sentry, scrubbed for content |

**Quality gates.**
- Crash-free sessions ≥ 99.5%
- Send → delivered p99 ≤ 300 ms (intra-region)
- Frame stability ≥ 99% inside 16.6 ms during the 6 hero animations
- All cryptographic operations exercised by an automated test suite that includes Wycheproof vectors

---

## Milestone 2 — Closed beta (Weeks 9–16)

**Goal.** 200 invited users on real phones with real conversations.

| Feature | Notes |
|---|---|
| Group threads (≤ 50) | Sender Keys with per-device fan-out |
| Multi-device sync (history) | Encrypted history transfer between user's own devices |
| Voice notes | Opus, waveform, encrypted, scrubbable |
| Media (image, video, document) | Client-encrypted, R2 stores ciphertext, server never has key |
| Reactions | Six emoji + custom; reactions are encrypted alongside message |
| Replies and threads-within-threads | Quote-style |
| Disappearing messages | Per-thread, granular (1 hour, 1 day, 1 week, custom) |
| Stories | Personal and per-thread, 24h expiry, E2E to viewers |
| Search (on-device) | Tantivy index of decrypted local store |
| Profile (handle, avatar, bio, color) | Encrypted to contacts |
| Block / report | Report ships ciphertext + decryption key only with user consent |
| Backup (encrypted, optional) | Iron-clad: server holds ciphertext, key derives from user passphrase + hardware-bound salt |

**Quality gates.**
- Voice MOS ≥ 3.8 on adverse network
- Media upload p99 ≤ 8 s for a 10MB image on LTE
- Battery: ≤ 4% per hour of active foreground use on a 2022-era phone
- D7 retention ≥ 50% in beta cohort

---

## Milestone 3 — Public 1.0 (Weeks 17–24)

**Goal.** Open-store launch.

| Feature | Notes |
|---|---|
| 1:1 voice and video calls (E2EE) | LiveKit + Insertable Streams |
| Small group calls (≤ 8, E2EE) | Same |
| Larger group calls (≤ 50, SFU-trust) | UI clearly indicates trust mode |
| Persistent voice rooms | Per-thread, drop-in/drop-out |
| AI assistant (on-device) | Smart reply, summarization, translation, language detection |
| AI explicit cloud queries | Opt-in, OHTTP-relayed, no logs |
| Stories with reactions | Replies E2E to author |
| Cross-platform (iOS, Android, macOS, Windows, Linux, Web PWA) | Feature parity ≥ 95% |
| Privacy & security center | One screen, clear controls |
| Full settings, accessibility, localization (EN, ES, FR, DE, JA, AR launch) | RTL fully tested |
| Spaces (community rooms, up to 5,000) | New primitive — not just bigger groups |
| Channels (broadcast, no upper limit) | One-to-many with E2E to subscribers |
| Independent security audit | Pass before public launch |

**Quality gates.**
- Cold start ≤ 800 ms (mid-tier Android, release build)
- Send → delivered p99 ≤ 250 ms (same region), ≤ 600 ms (cross-region)
- 99% frames inside 16.6 ms across all 15 primary screens
- WCAG 2.2 AA for all primary flows
- App Store first-week rating ≥ 4.7

---

## Quarter +1 — Communities and Trust (Weeks 25–36)

| Feature | Notes |
|---|---|
| Communities (Spaces refinement, roles, moderation tools) | Trust-and-safety tooling matured |
| AI moderation (on-device first) | Per-room policy, never to the server |
| Live audio rooms | Like Clubhouse but persistent; LiveKit |
| 50+ participant video calls (SFU-trust mode, clearly marked) | |
| Search v2 (encrypted server-side hints) | Searchable encryption proof-of-concept |
| Web client maturity | Full feature parity inside the browser |

---

## Quarter +2 — Spatial and Federation (Weeks 37–52)

| Feature | Notes |
|---|---|
| Vision Pro client | Spatial-native: rooms become rooms |
| Wear OS / watchOS notifications | Encrypted at the watch boundary |
| ActivityPub bridging for public channels (opt-in) | Public surfaces only; private threads never federate |
| Creator tooling | Channels with built-in support for monetization (subscription only, no ads) |
| Custom material packs | Sticker / emoji / avatar economy, on-device first |

---

## Permanent backlog (always considering, never committed)

- Stickers / animated emoji marketplace
- Group governance and voting primitives
- Encrypted shared notes / docs in a thread
- Calendar integration with privacy-preserving time visibility
- Enterprise tier (audit log export, SCIM, retention controls)

## Cuts and trade-offs

If a milestone slips, we cut features in this order:
1. Stories (defer to Quarter +1)
2. Communities/Spaces (defer to Quarter +1)
3. Larger group calls (>8, defer to Quarter +1)
4. Custom emoji and sticker tooling

We do **not** cut:
- E2E encryption, ever
- Multi-device parity
- Cross-platform parity
- Accessibility
- Independent audit before public launch
