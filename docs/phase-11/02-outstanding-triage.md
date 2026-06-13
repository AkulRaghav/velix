# 02 — Outstanding-Item Triage

The consolidated, prioritized list of every "tracked," "Phase 9.5," "Phase 10.5," and "carried forward" item I logged across the ten phases. Each is classified as a launch blocker, a launch-week deliverable, or a post-launch task.

## Classification

| Class | Meaning |
|---|---|
| **B0 — Launch blocker** | Public 1.0 cannot ship without this. |
| **B1 — Launch-week** | Must be true the day before launch. Some flexibility on exact week. |
| **B2 — First quarter** | Should ship within 90 days of public launch. |
| **B3 — Permanent backlog** | Tracked annually; not on a release timeline. |

## The full triage

### Cryptography (Phase 7)

| # | Item | Source | Class | Owner | Notes |
|---|---|---|---|---|---|
| C1 | Implement libsignal Rust FFI surface (the 11 modules in `cryptocore/src/`) | P7 doc 18 | **B0** | Crypto eng | Multi-week; deepest single piece of pre-launch work |
| C2 | Wire `velix_crypto` Dart binding to the FFI surface | P7 doc 18 | **B0** | Crypto eng | Mechanical once C1 lands |
| C3 | Replace `velix_data`'s `InMemoryIdentityRepository` with libsignal-backed implementation | P7 doc 18 | **B0** | Crypto eng | Depends on C1+C2 |
| C4 | First independent third-party security audit of cryptocore | P7 doc 18, P10 doc 13 | **B0** | External firm; engagement led by security lead | 5-month lead time; engagement no later than 5 months pre-launch |
| C5 | Wycheproof + libsignal upstream test vector suite | P7 doc 18 | **B0** | Crypto eng | Verifies the wrapping |
| C6 | Reproducible build verification on three platforms | P7 doc 18 | **B0** | DevOps | Phase 10 doc 03 specifies; CI runs |
| C7 | Post-quantum hybrid (X25519 + ML-KEM-768) | P7 doc 02 | **B3** | Tracked | Adopt within 90 days of libsignal upstream landing it |

### Backend (Phase 6)

| # | Item | Source | Class | Owner | Notes |
|---|---|---|---|---|---|
| BE1 | Wire pgx + nats.go + redis/v9 to the routing reference interfaces | P6 doc 12 | **B0** | Backend | Reference handler exists; need real I/O wiring |
| BE2 | Fill in identity, media, push, call, notifier service handlers | P6 doc 12 | **B0** | Backend | Mechanical against the same contract style as routing |
| BE3 | k6 perf tests in CI | P6 doc 12, P9 doc 02 | **B0** | DevOps | Gates merges |
| BE4 | Helm charts per service | P10 doc 14 | **B0** | DevOps | Phase 10 doc 03 specifies; team authors |
| BE5 | Sealed Sender enforcement at routing handler | P7 doc 09 | **B0** | Backend | Reject envelopes carrying sender fields |
| BE6 | Push routing seed rotation per push | P7 doc 13 | **B0** | Backend | Phase 7 doc 13 spec |
| BE7 | Privacy-Pass anonymous quota credential implementation | P8 doc 13 | **B0** | Backend (AI gateway team) | For OHTTP-relayed cloud AI metering |
| BE8 | OHTTP relay client (Dart-side) and gateway-side decryption | P8 doc 05 | **B0** | Both | The single piece of cloud-AI plumbing |
| BE9 | Postgres sharding for routing (Stage C) | P1 doc 08 | **B3** | Tracked | Triggered by user count; not at launch |
| BE10 | LiveKit production cluster setup per region | P6 doc 07, P10 doc 02 | **B0** | DevOps | Per-cell |

### AI (Phase 8)

| # | Item | Source | Class | Owner | Notes |
|---|---|---|---|---|---|
| AI1 | TFLite / CoreML / Gemini Nano backend implementations | P8 doc 16 | **B0** | Mobile | Per Phase 8 doc 04 model catalog |
| AI2 | AI gateway service (Go, Phase 6 patterns) | P8 doc 16 | **B0** | Backend | Velix-operated middle |
| AI3 | OHTTP relay operator selection + signed contract | P8 doc 05, P10 doc 13 | **B0** | Security lead + legal | Multi-week procurement |
| AI4 | Provider contracts (Anthropic, OpenAI no-train-on-data clauses) | P8 doc 16, P10 doc 13 | **B0** | Legal + business | Standard enterprise terms |
| AI5 | Model authoring + signing for the 6 launch models | P8 doc 16 | **B0** | ML eng | Smart reply, translate, summarize, moderation, intent extract, language ID |
| AI6 | First independent privacy audit of the AI gateway | P8 doc 16, P10 doc 13 | **B0** | External firm | Concurrent with C4; same lead time |
| AI7 | Public AI privacy disclosure at velix.app/security#ai | P8 doc 16, P10 doc 13 | **B0** | This phase ships the draft (Phase 11 doc 05) |
| AI8 | AI model LRU eviction implementation | P8 doc 04, P9 doc 03 R11 | **B1** | Mobile | Memory hygiene |

### 3D (Phase 3)

| # | Item | Source | Class | Owner | Notes |
|---|---|---|---|---|---|
| TD1 | Filament FFI binding (or `flutter_filament` integration) | P3 doc 08, P5 doc 09 | **B1** | Mobile | 3D is opt-in via fallback; can launch with fallbacks for one cycle |
| TD2 | Eight identity-style scene assets authored | P3 doc 08 | **B1** | Designer | Profile + Space backdrops |
| TD3 | Three onboarding scenes authored | P3 doc 08 | **B0** | Designer | Onboarding's hero moment |
| TD4 | Asset pipeline CLI (`tools/velix3d/`) | P3 doc 08 | **B0** | Tooling | Required for signing |
| TD5 | Public-read R2 bucket for assets (cross-phase contradiction C1) | P11 doc 01 | **B0** | DevOps | Gated by client-side asset registry |

### Performance (Phase 9)

| # | Item | Source | Class | Owner | Notes |
|---|---|---|---|---|---|
| PF1 | Wire BrowserStack App Live + Sauce Labs into CI | P9 doc 06 | **B0** | DevOps | Required before any non-tracked perf claim |
| PF2 | FTS5 search via drift extension | P9 doc 03 R2 | **B1** | Mobile | Search isn't day-one critical |
| PF3 | Cryptocore Criterion benches in CI | P9 doc 06 | **B0** | DevOps | Catches crypto regressions |
| PF4 | Battery soak nightly | P9 doc 06 | **B0** | DevOps | Validates the battery budget |
| PF5 | Test Argon2id on Pixel 4a / Galaxy A52 | P9 doc 05 R9 | **B1** | Mobile | Floor-device verification |
| PF6 | libsignal cache bounds | P9 doc 05 R3 | **B0** | Crypto eng | Memory hygiene depends on C1 |
| PF7 | First end-to-end performance regression baseline | P9 doc 06 | **B0** | DevOps | Day-one snapshot |

### DevOps & Production (Phase 10)

| # | Item | Source | Class | Owner | Notes |
|---|---|---|---|---|---|
| OP1 | Provision the cells via terraform modules | P10 doc 14 | **B0** | DevOps | Three cells: us-east-1, eu-west-1, ap-southeast-1 |
| OP2 | Configure Argo CD across the three cells | P10 doc 14 | **B0** | DevOps | GitOps reconciliation |
| OP3 | Configure Vault production cluster | P10 doc 14 | **B0** | Security lead | Auto-unseal via cloud KMS |
| OP4 | Configure PagerDuty rotations | P10 doc 14 | **B0** | DevOps | On-call must exist before launch |
| OP5 | Configure Statuspage.io | P10 doc 14 | **B0** | DevOps | Public-facing status |
| OP6 | Author all 30+ runbooks per the alert catalog | P10 doc 14 | **B0** | DevOps + service teams | Templates exist; team writes content |
| OP7 | Run the first DR drill in staging | P10 doc 14 | **B0** | DevOps | Verifies RTO/RPO |
| OP8 | Configure HackerOne or Intigriti bug bounty | P10 doc 13 | **B0** | Security lead | Live ≥ 30 days pre-launch |
| OP9 | First public security paper | P10 doc 13 | **B0** | This phase ships the draft (Phase 11 doc 03) |
| OP10 | First public privacy paper | P10 doc 13 | **B0** | This phase ships the draft (Phase 11 doc 04) |
| OP11 | App Store Connect onboarding (one-time) | P10 doc 12 | **B0** | Mobile lead | Bundle ID, team, certs, profiles |
| OP12 | Play Console onboarding (one-time) | P10 doc 12 | **B0** | Mobile lead | Package, signing, store listing |
| OP13 | Encryption export compliance filing | P10 doc 12 | **B0** | Legal | Annual ERN + App Store Connect questionnaire |
| OP14 | Pen test of public endpoints | P10 doc 13 | **B1** | Security lead | Concurrent with audit window |
| OP15 | Cybersecurity insurance | P10 doc 13 | **B1** | Business | Recommended; not strictly blocking |
| OP16 | OWASP Top 10 review per service | P10 doc 13 | **B0** | Security lead | Internal review before audit |

### Frontend (Phase 5 carry-forwards)

| # | Item | Source | Class | Owner | Notes |
|---|---|---|---|---|---|
| FE1 | Vendor variable-font assets | P5 doc 09 | **B0** | Mobile | Inter, JetBrains Mono, Vazirmatn, Noto Sans CJK |
| FE2 | Custom icon set replacing typographic-glyph stand-ins | P5 doc 09 | **B0** | Designer | 120 icons + 8 custom identity glyphs |
| FE3 | Configurable accessibility gesture thresholds in Settings UI | P4 doc 10, P5 doc 09 | **B0** | Mobile | Phase 4 doc 10 spec |
| FE4 | Tilt source via `sensors_plus` for `VelixParallax` | P4 doc 02 | **B1** | Mobile | Parallax improvement; not blocking |
| FE5 | `VelixGlyph` widget that loads `.riv` from registry | P4 doc 04 | **B0** | Mobile | Required for trust-state glyphs |
| FE6 | Push notification handlers (APNs / FCM) | P5 doc 09 | **B0** | Mobile | Tied to BE6 |
| FE7 | Real cryptographic identity creation in `velix_data` (replacing stub) | P5 doc 09 | **B0** | Same as C3 |
| FE8 | `RepaintBoundary` placement after per-screen frame profiling | P5 doc 09 | **B1** | Mobile | Verification, not a missing feature |

### Public-facing artifacts (this phase produces drafts)

| # | Item | Source | Class | Owner | Notes |
|---|---|---|---|---|---|
| PUB1 | Public security paper at velix.app/security | P10 doc 13 | **B0** | Phase 11 doc 03 ships draft; cryptographer review required |
| PUB2 | Public privacy paper at velix.app/privacy | P10 doc 13 | **B0** | Phase 11 doc 04 ships draft; legal counsel review required |
| PUB3 | Public AI privacy disclosure at velix.app/security#ai | P10 doc 13 | **B0** | Phase 11 doc 05 ships draft |
| PUB4 | Accessibility statement at velix.app/accessibility | P2 doc 12, P10 doc 13 | **B0** | Phase 11 doc 06 ships draft |
| PUB5 | Vulnerability disclosure policy at velix.app/.well-known/security.txt | P10 doc 13 | **B0** | Security lead authors |
| PUB6 | Transparency report cadence + first issue | P7 doc 01, P10 doc 13 | **B1** | Security lead | First issue 90 days post-launch |

### Permanent backlog

| # | Item | Source | Class | Notes |
|---|---|---|---|---|
| FW1 | MLS evaluation for v2 | P7 doc 08 | **B3** | Annual review |
| FW2 | Vision Pro spatial client | P1 doc 04 | **B3** | Quarter +2 |
| FW3 | ActivityPub bridging for public surfaces | P1 doc 04 | **B3** | Quarter +2 |
| FW4 | Mixnet / cover traffic prototype | P7 doc 18 D | **B3** | Mitigates traffic-analysis |
| FW5 | Velix for Teams (enterprise tier) | P1 doc 09 | **B3** | Per demand |
| FW6 | Velix Spaces (community tier) | P1 doc 04 | **B2** | First quarter |
| FW7 | Channels (broadcast tier) | P1 doc 04 | **B2** | First quarter |
| FW8 | Federated identity research | P1 doc 04 | **B3** | v2.0 work |

## Summary by class

| Class | Count | Description |
|---|---|---|
| B0 — Launch blocker | **35** | Must complete before public 1.0 |
| B1 — Launch-week | **8** | Must complete the week before launch |
| B2 — First quarter | **2** | Within 90 days of launch |
| B3 — Permanent backlog | **8** | Annual review; not on a release timeline |

## Sequencing

The B0 list is large (35 items). Most fall on a critical path that's bound by:

1. **Audit lead time (5 months).** The cryptocore (C1, C2, C3) and AI gateway (AI1, AI2) implementations must be complete + stable enough for an audit firm to engage.
2. **Asset authoring (designer-bound).** TD2, TD3, FE1, FE2 are designer/ML-eng work that runs in parallel.
3. **Operational setup (DevOps-bound).** OP1–OP12 can be done in parallel by the DevOps team while the audit is underway.

A reasonable order:

| Sprint | Focus |
|---|---|
| Sprint 1 (weeks 1–2) | C1 (cryptocore start), AI3 (OHTTP relay procurement), OP1+OP3 (cells + Vault) |
| Sprint 2 (weeks 3–4) | C2+C3 (FFI + integration), AI1 (on-device backends), OP2+OP4+OP5 (Argo CD, PagerDuty, Statuspage), BE1 (routing wiring) |
| Sprint 3 (weeks 5–6) | C4 + AI6 audits commence; OP6 (runbooks), OP7 (DR drill), BE2 (other services) |
| Sprint 4 (weeks 7–8) | TD1+TD3 (3D onboarding scenes), AI5 (model authoring), FE1+FE2 (fonts + icons), BE3+PF1+PF3 (perf benches) |
| Sprint 5 (weeks 9–10) | TD2+TD4+TD5 (3D identity scenes), FE3+FE5 (settings + glyphs), PF4+PF5 (battery + floor benches) |
| Sprint 6 (weeks 11–12) | PUB1–PUB6 finalization + cryptographer/legal review; OP8 (bug bounty live), OP14 (pen test) |
| Sprint 7 (weeks 13–14) | Audit findings remediation; final integration; OP16 (OWASP review) |
| Sprint 8 (weeks 15–17) | Audit re-test, OP11+OP12 (store onboarding), OP13 (export compliance), beta cohort |
| Sprint 9 (weeks 18–20) | Public 1.0 launch |

That's a 5-month critical path from "Phase 11 sign-off" to "public 1.0 in stores," constrained mainly by audit lead time. It's tight but achievable.

## Banned: items that don't count as resolved

- A B0 item is not resolved by saying "it's tracked" — it ships before launch.
- A B1 item is not resolved by saying "we'll do it after the soft launch" — it ships before public 1.0.
- A B0 item cannot be downgraded to B1 without explicit security/privacy/exec sign-off.
- An item missing an owner is treated as B0 by default until owned.
