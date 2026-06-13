# 07 — Launch Readiness Checklist

The single ship-gate document. Public 1.0 launches when every gate below is **Met**. Until then it does not.

## How this document is read

Three columns:

| Column | Meaning |
|---|---|
| **Gate** | The condition. Phrased so you can either say "Met" or "Not Met" — no shades of grey. |
| **Source** | Which prior phase / doc / triage item this gate ties back to. |
| **Owner** | Who declares it Met. |

Every gate is binary. "In progress" = Not Met. "Mostly done" = Not Met. "Tracked for next sprint" = Not Met.

If a gate is genuinely impossible to meet (e.g., audit firm unavailable), the launch date moves. The bar does not.

## Section A — Cryptography (the deepest gate)

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| A1 | `cryptocore` Rust crate is feature-complete: X3DH, Double Ratchet, Sender Keys, Sealed Sender wrapped over libsignal | P7 doc 18, triage C1 | Crypto eng | Not Met |
| A2 | `velix_crypto` Dart binding compiles, runs, and passes the Phase 7 test vector suite (Wycheproof + libsignal upstream) | P7 doc 18, triage C2/C5 | Crypto eng | Not Met |
| A3 | `velix_data` repositories are libsignal-backed. No `InMemory*Repository` ships in the production binary. | P5 doc 09, triage C3/FE7 | Mobile | Not Met |
| A4 | Reproducible build verification passes on the three target platforms (macOS, Linux, Windows CI) | P10 doc 03, triage C6 | DevOps | Not Met |
| A5 | First independent third-party security audit of `cryptocore` complete | P7 doc 18, P10 doc 13, triage C4 | External firm + security lead | Not Met |
| A6 | All Critical and High audit findings remediated; auditor has re-tested and confirmed | P10 doc 13 | Crypto eng + auditor | Not Met |
| A7 | Public audit report published at `velix.app/security/audits/` | P10 doc 13, triage PUB1 | Security lead | Not Met |
| A8 | Cryptocore signing key issued and stored in Vault production cluster | P7 doc 18, P10 doc 06, triage OP3 | Security lead | Not Met |
| A9 | Sealed Sender enforcement verified at routing service: rejects any envelope carrying a sender field | P7 doc 09, triage BE5 | Backend | Not Met |
| A10 | Push routing seed rotation per push verified | P7 doc 13, triage BE6 | Backend | Not Met |

**A is Met only when every row is Met.** A is the longest-lead-time section of the gate.

## Section B — Backend (operability)

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| B1 | Routing service: pgx + nats.go + redis/v9 wired against the reference handler interfaces | P6 doc 12, triage BE1 | Backend | Not Met |
| B2 | Identity, media, push, call, notifier service handlers complete and contract-tested against the proto | P6 doc 12, triage BE2 | Backend | Not Met |
| B3 | Helm charts authored per service; `helm template` + `helm lint` clean; values per environment | P10 doc 14, triage BE4 | DevOps | Not Met |
| B4 | k6 perf tests live in CI; budgets per Phase 9 enforced | P6 doc 12, P9 doc 02, triage BE3 | DevOps | Not Met |
| B5 | LiveKit production cluster running per cell (us-east-1, eu-west-1, ap-southeast-1) | P6 doc 07, P10 doc 02, triage BE10 | DevOps | Not Met |
| B6 | All inter-service mTLS verified end-to-end | P6 doc 09, P10 doc 06 | Security lead | Not Met |
| B7 | OWASP Top 10 review per service complete; findings closed | P10 doc 13, triage OP16 | Security lead | Not Met |
| B8 | Privacy-Pass anonymous quota credential implementation live for AI gateway metering | P8 doc 13, triage BE7 | Backend | Not Met |
| B9 | OHTTP relay client (Dart) + gateway-side decryption end-to-end verified | P8 doc 05, triage BE8 | Mobile + Backend | Not Met |

## Section C — AI

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| C1 | TFLite + CoreML + Gemini Nano backends implemented per Phase 8 model catalog | P8 doc 16, triage AI1 | Mobile | Not Met |
| C2 | AI gateway service deployed (Go service, Phase 6 patterns) | P8 doc 16, triage AI2 | Backend | Not Met |
| C3 | OHTTP relay operator selected, contract signed, relay healthy | P8 doc 05, P10 doc 13, triage AI3 | Security lead + legal | Not Met |
| C4 | Provider contracts signed (Anthropic, OpenAI) with no-train-on-data clauses | P8 doc 16, P10 doc 13, triage AI4 | Legal + business | Not Met |
| C5 | Six launch models authored, signed, published: smart reply, translate, summarize, moderation, intent extract, language ID | P8 doc 16, triage AI5 | ML eng | Not Met |
| C6 | First independent privacy audit of the AI gateway complete | P8 doc 16, P10 doc 13, triage AI6 | External firm + security lead | Not Met |
| C7 | All Critical and High AI privacy audit findings remediated and re-tested | P10 doc 13 | ML eng + auditor | Not Met |
| C8 | Trust level 4 verified for AI gateway (gateway cannot correlate user identity with content; relay cannot read content) | P7 doc 03, P8 doc 01 | Security lead | Not Met |
| C9 | Per-query consent flow verified end-to-end: no auto-relay possible | P8 doc 03 | Mobile + Security lead | Not Met |

## Section D — Frontend

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| D1 | Variable-font assets vendored: Inter, JetBrains Mono, Vazirmatn, Noto Sans CJK | P5 doc 09, triage FE1 | Mobile | Not Met |
| D2 | Custom icon set (120 icons + 8 identity glyphs) authored and integrated | P5 doc 09, triage FE2 | Designer + Mobile | Not Met |
| D3 | `VelixGlyph` widget loads `.riv` from registry; trust-state glyphs verified | P4 doc 04, triage FE5 | Mobile | Not Met |
| D4 | Configurable accessibility gesture thresholds available in Settings UI | P4 doc 10, P5 doc 09, triage FE3 | Mobile | Not Met |
| D5 | Push notification handlers (APNs / FCM) integrated end-to-end | P5 doc 09, triage FE6 | Mobile | Not Met |
| D6 | All Phase 5 in-memory repositories replaced with libsignal-backed equivalents (ties to A3) | P5 doc 09, triage FE7 | Mobile | Not Met |
| D7 | App boots cold-start ≤ 800 ms on iPhone 12 and Pixel 6 (re-verified post-libsignal integration) | P1, P5, P9 | Performance lead | Not Met |
| D8 | Frame stability ≥ 99% inside 16.6 ms across the eight bench scenarios | P9 doc 02 | Performance lead | Not Met |

## Section E — 3D

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| E1 | Filament FFI binding integrated (or `flutter_filament` adopted) | P3 doc 08, P5 doc 09, triage TD1 | Mobile | Not Met |
| E2 | Three onboarding scenes authored, signed, hosted | P3 doc 08, triage TD3 | Designer | Not Met |
| E3 | Eight identity-style profile + space backdrop scenes authored, signed, hosted (or fallback path verified for any not yet authored) | P3 doc 08, triage TD2 | Designer | Not Met |
| E4 | Asset pipeline CLI (`tools/velix3d/`) live; signing flow verified | P3 doc 08, triage TD4 | Tooling | Not Met |
| E5 | Public-read R2 asset bucket provisioned; client asset registry pointed at it | P11 doc 01 (C1), triage TD5 | DevOps | Not Met |
| E6 | 3D scene budget ≤ 4 ms GPU verified on iPhone 12 / Pixel 6 | P3 doc 02, P9 doc 01 | Performance lead | Not Met |
| E7 | Auto-pause on visibility loss verified; low-power-mode → 2D fallback verified | P9 F12 | Performance lead | Not Met |

## Section F — Performance & device-floor verification

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| F1 | BrowserStack App Live + Sauce Labs wired into CI | P9 doc 06, triage PF1 | DevOps | Not Met |
| F2 | Cryptocore Criterion benches running in CI | P9 doc 06, triage PF3 | DevOps | Not Met |
| F3 | Battery soak test running nightly; results inside the ≤ 4% / hour budget | P9 doc 06, triage PF4 | DevOps | Not Met |
| F4 | Argon2id verified on Pixel 4a / Galaxy A52 (floor devices) ≈ 1000 ms iPhone 12 reference | P7, P9 doc 05 R9, triage PF5 | Mobile | Not Met |
| F5 | libsignal cache bounds enforced; memory hygiene verified | P9 doc 05 R3, triage PF6 | Crypto eng | Not Met |
| F6 | First end-to-end performance regression baseline captured | P9 doc 06, triage PF7 | DevOps | Not Met |
| F7 | Cold-start ≤ 800 ms verified on real devices (not just simulators) | P1, P9 | Performance lead | Not Met |
| F8 | All Phase 9 budget assertions pass on the floor devices | P9 doc 02 | Performance lead | Not Met |

## Section G — DevOps & Production

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| G1 | Three production cells provisioned via terraform: us-east-1, eu-west-1, ap-southeast-1 | P10 doc 02, P10 doc 14, triage OP1 | DevOps | Not Met |
| G2 | Argo CD configured across all three cells; reconciliation verified | P10 doc 14, triage OP2 | DevOps | Not Met |
| G3 | Vault production cluster live with auto-unseal via cloud KMS | P10 doc 06, P10 doc 14, triage OP3 | Security lead | Not Met |
| G4 | PagerDuty rotations configured; on-call rota live | P10 doc 14, triage OP4 | DevOps | Not Met |
| G5 | Statuspage.io configured; synthetic probes wired in | P10 doc 14, triage OP5 | DevOps | Not Met |
| G6 | All 30+ runbooks per the alert catalog authored and reviewed | P10 doc 07, P10 doc 14, triage OP6 | DevOps + service teams | Not Met |
| G7 | First DR drill executed in staging; RTO/RPO targets met | P10 doc 09, P10 doc 14, triage OP7 | DevOps | Not Met |
| G8 | Backup restoration drilled within last 30 days; restore time inside SLO | P10 doc 13 | DevOps | Not Met |
| G9 | DR drilled within last 90 days | P10 doc 13 | DevOps | Not Met |
| G10 | Reproducible builds verified nightly on three platforms (image digest match) | P10 doc 03 | DevOps | Not Met |
| G11 | All TLS certificates valid, pinned, rotation policy verified | P10 doc 06, P10 doc 13 | Security lead | Not Met |
| G12 | All secrets in Vault; gitleaks clean; no env-var secrets in production | P10 doc 06, P10 doc 13 | Security lead | Not Met |
| G13 | Logs verified PII-scrubbed end-to-end | P6 doc 10, P8 doc 14, P10 doc 08 | Security lead | Not Met |
| G14 | Crash reports verified PII-scrubbed end-to-end (Sentry self-hosted) | P10 doc 08 | Security lead | Not Met |
| G15 | Rate limits in production verified per Phase 6 doc 09 | P6 doc 09, P10 doc 13 | Backend | Not Met |
| G16 | DMARC + DKIM + SPF configured for `velix.app` | P10 doc 13 | DevOps | Not Met |
| G17 | HSTS preloaded for `velix.app`; CSP headers configured for the web client | P10 doc 13 | DevOps | Not Met |

## Section H — Bug bounty & external review

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| H1 | Bug bounty program (HackerOne or Intigriti) live ≥ 30 days pre-launch | P10 doc 13, triage OP8 | Security lead | Not Met |
| H2 | Penetration test of public-facing endpoints by a separate firm complete | P10 doc 13, triage OP14 | Security lead | Not Met |
| H3 | Vulnerability disclosure policy (VDP) published at `/.well-known/security.txt` | P10 doc 13, triage PUB5 | Security lead | Not Met |
| H4 | Coordinated disclosure process documented | P10 doc 13 | Security lead | Not Met |

## Section I — Public-facing papers (drafts shipped this phase)

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| I1 | Public security paper at `velix.app/security` reviewed by independent cryptographer; published | P10 doc 13, P11 doc 03, triage PUB1 | Security lead | Not Met (draft shipped) |
| I2 | Public privacy paper at `velix.app/privacy` reviewed by privacy counsel; published | P10 doc 13, P11 doc 04, triage PUB2 | Legal counsel | Not Met (draft shipped) |
| I3 | Public AI privacy disclosure at `velix.app/security#ai` reviewed and published | P10 doc 13, P11 doc 05, triage PUB3 | Security lead + legal | Not Met (draft shipped) |
| I4 | Accessibility statement at `velix.app/accessibility` reviewed by accessibility consultant; published | P2 doc 12, P11 doc 06, triage PUB4 | Accessibility consultant | Not Met (draft shipped) |
| I5 | Transparency report cadence committed publicly; first issue scheduled 90 days post-launch | P7 doc 01, P10 doc 13, triage PUB6 | Security lead | Not Met |

## Section J — Store readiness

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| J1 | App Store Connect onboarding complete: bundle ID, team, certs, profiles | P10 doc 12, triage OP11 | Mobile lead | Not Met |
| J2 | Play Console onboarding complete: package, signing, store listing, Play App Signing enrolled | P10 doc 12, triage OP12 | Mobile lead | Not Met |
| J3 | Encryption export compliance filing complete (annual ERN + App Store Connect questionnaire) | P10 doc 12, triage OP13 | Legal | Not Met |
| J4 | App Store privacy disclosures match implementation (verified line-by-line against Phase 10 doc 12) | P10 doc 12 | Mobile lead + legal | Not Met |
| J5 | Play Store data safety section matches implementation | P10 doc 12 | Mobile lead + legal | Not Met |
| J6 | TestFlight external testing observed for ≥ 7 days with no Critical or High issues open | P10 doc 12 | Mobile lead | Not Met |
| J7 | Closed testing track on Play observed for ≥ 5 days | P10 doc 12 | Mobile lead | Not Met |
| J8 | App icon, screenshots, app preview video, marketing assets per device class delivered | P10 doc 12 | Designer | Not Met |
| J9 | Localized release notes ready for all six launch locales (EN, ES, FR, DE, JA, AR) or English fallback documented | P10 doc 12 | Mobile lead | Not Met |

## Section K — Privacy & compliance

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| K1 | GDPR data export flow tested end-to-end | P10 doc 13 | Backend + legal | Not Met |
| K2 | GDPR account deletion flow tested end-to-end (30-day grace, then permanent) | P10 doc 13 | Backend + legal | Not Met |
| K3 | CCPA disclosure for California users live | P10 doc 13 | Legal | Not Met |
| K4 | Subprocessor list at `velix.app/privacy/subprocessors` published (Cloudflare R2, APNs, FCM, Anthropic, OpenAI) | P10 doc 13, P11 doc 04 | Legal | Not Met |
| K5 | All third-party SDKs reviewed; none call home with user content; none fingerprint; none track | P10 doc 13 | Security lead | Not Met |
| K6 | No advertising libraries linked; no surveillance libraries linked | P10 doc 13 | Mobile + Security lead | Not Met |
| K7 | Cybersecurity insurance bound (recommended; not strictly blocking but flagged) | P10 doc 13, triage OP15 | Business | Recommended |

## Section L — Cross-phase consistency

| # | Gate | Source | Owner | State |
|---|---|---|---|---|
| L1 | Phase 11 cross-phase consistency audit verdict is PASS | P11 doc 01 | Security lead | **Met** |
| L2 | Outstanding-item triage complete; every B0 in this checklist; every B1/B2/B3 owned | P11 doc 02 | Security lead | **Met** |
| L3 | No prior architectural, cryptographic, AI, accessibility, motion, or performance guarantee weakened in any sprint | All phases | Security lead | Met (verified by P11 doc 01) |

L1, L2, L3 are the only **Met** rows on day one of the launch run-up. They become Met as Phase 11 closes. Everything else flips Met during sprints 1-9.

## Banned: ways to declare Met that are not Met

The following do not count:

- **"It's tracked."** B0 items must ship, not be tracked.
- **"It's mostly done."** Mostly done is Not Met.
- **"It works in staging."** Staging is necessary, not sufficient. Production behavior must match.
- **"The team agrees it's fine."** Architectural sign-off is not the same as the gate. The gate has an explicit owner and an explicit artifact.
- **"We'll ship and patch."** Not for B0. The architectural commitments and the cryptographic + privacy audits do not patch-after-launch.
- **"It's behind a feature flag."** Feature flags help with rollout — they are not a substitute for completing a gate.

## How the launch decision is made

Launch decision is taken in a single meeting:

1. Open this document.
2. For each row, the named owner declares "Met" or "Not Met."
3. If every B0 row is Met: ship goes ahead.
4. If any B0 row is Not Met: launch slips. Re-evaluate weekly.

There is no "ship with risk" path through this document. B0 is either resolved or the launch waits.

## Sequencing reference

The sprint plan from `02-outstanding-triage.md` (Sprints 1–9) is the working schedule. This checklist is the gate. The plan can change; the gate cannot.

## Day-of-launch operational gates

The day public 1.0 is enabled in the stores:

| # | Gate |
|---|---|
| LAUNCH1 | All sections A–K are Met. |
| LAUNCH2 | On-call coverage confirmed for the next 72 hours. |
| LAUNCH3 | Status page set to Operational. |
| LAUNCH4 | Bug bounty inflow channel open and triaged. |
| LAUNCH5 | The phased-rollout plan from Phase 10 doc 10 is set: 1% → 10% → 50% → 100% over the first 96 hours. |
| LAUNCH6 | The three rollback paths from Phase 10 doc 11 are tested live in staging within the last 7 days. |
| LAUNCH7 | A war-room channel (`#launch-room`) is open with all leads present. |

## Post-launch first 72 hours

These don't gate launch; they gate the next decision (continue rollout, hold, or roll back):

- p99 send→deliver under 250 ms intra-region — verified.
- Crash-free rate ≥ 99.5% — verified.
- ANR rate ≤ 0.5% — verified.
- p99 cold-start ≤ 800 ms on supported devices — verified.
- No P0 incidents — verified.
- Bug bounty inflow inside expected band (none catastrophic).
- Status page remains Operational.

If any of those slip past their soft thresholds for more than one rollout window, halt rollout and triage. Per Phase 10 doc 11, the three-tier rollback (feature flag, canary halt, Argo revert) targets ≤ 5-minute MTTR.

## Sign-off line

This checklist is signed by:

- Security lead
- Crypto eng lead
- Mobile lead
- Backend lead
- DevOps lead
- ML eng lead
- Product release manager
- Legal counsel

Each owner signs only the rows they own. Launch ships only when every signature is on the page.
