# 09 — Ship Decision

The principal release manager's gate run, executed against the Phase 11 audit package. Decision-oriented; nothing new.

## Decision

**No ship today. Verdict: Pass-with-tracked. Recommended launch: end of Sprint 9 (T+20 weeks), gated on every B0 going Met and the cryptographic + AI privacy audits returning clean.**

This is not a soft-no. It is a structured no with a dated path to yes.

## Source of truth

This document does not invent gates. It runs the gates already documented:

- `01-cross-phase-consistency.md` — verdict on architectural soundness
- `02-outstanding-triage.md` — the 53-item classification and Sprint 1–9 plan
- `03-security-paper-draft.md`, `04-privacy-paper-draft.md`, `05-ai-privacy-disclosure-draft.md`, `06-accessibility-statement-draft.md` — the four public-facing artifacts
- `07-launch-readiness.md` — the binary gate per row
- `08-final-verdict.md` — Pass-with-tracked verdict

The release manager's job here is to read those, run the columns, and call it.

## A. Tracked items resolved by priority

Resolution = "classified, owned, sequenced." The work itself runs in Sprints 1–9.

| Priority | Count | Status | Path |
|---|---|---|---|
| **B0 — Launch blocker** | 35 | Classified, owned, sequenced | Sprints 1–8; gates declared Met in 07 |
| **B1 — Launch-week** | 8 | Classified, owned | Sprints 5–8; gates declared Met in 07 |
| **B2 — First quarter** | 2 | Classified, owned | Within 90 days post-launch |
| **B3 — Permanent backlog** | 8 | Classified | Annual review; no release timeline |

Every B0 has a single named owner. Every B0 has a Phase-N source. Every B0 maps to a row in `07-launch-readiness.md`. Resolved as far as Phase 11 is empowered to resolve.

## B. The single day-one checklist

`07-launch-readiness.md` is the canonical checklist. Twelve sections (A–L), each row binary, each row owned.

For the gate run, the rolled-up state today:

| Section | Topic | Owner | Met today? |
|---|---|---|---|
| A | Cryptography (10 rows) | Crypto eng + Security lead + Auditor | **No** |
| B | Backend (9 rows) | Backend + DevOps + Security lead | **No** |
| C | AI (9 rows) | Mobile + Backend + ML eng + Legal | **No** |
| D | Frontend (8 rows) | Mobile + Designer | **No** |
| E | 3D (7 rows) | Designer + Mobile + DevOps | **No** |
| F | Performance & device-floor (8 rows) | Performance lead + DevOps | **No** |
| G | DevOps & Production (17 rows) | DevOps + Security lead | **No** |
| H | Bug bounty & external review (4 rows) | Security lead | **No** |
| I | Public-facing papers (5 rows) | Security lead + Legal + Accessibility consultant | **No (drafts shipped, external review pending)** |
| J | Store readiness (9 rows) | Mobile lead + Legal + Designer | **No** |
| K | Privacy & compliance (7 rows) | Backend + Legal + Security lead | **No** |
| L | Cross-phase consistency (3 rows) | Security lead | **Yes** |

Section L is the only Met section. That is expected on day one of the launch run-up. The other eleven sections flip Met during Sprints 1–9.

## C. Pass / Pass-with-tracked / Hold per dimension

The user's six guarantee dimensions, evaluated against Phase 11:

| Dimension | Phase 11 status | Notes |
|---|---|---|
| **Encryption** | Pass-with-tracked | Architecture intact (P7 doc 01–18). All 16 properties P1–P16 survive Phases 8–11 (P11 doc 01). FFI implementation is B0 (triage C1–C3); audit is B0 (C4); both gated. |
| **Privacy** | Pass-with-tracked | Architecture intact. Sealed sender, no-content-on-server, on-device-first AI all hold (P11 doc 01). External privacy review of papers is B0 (PUB1, PUB2, PUB3). Audit of AI gateway is B0 (AI6). |
| **Accessibility** | Pass-with-tracked | WCAG 2.2 AA commitment intact (P2 doc 12). Statement drafted (P11 doc 06). External accessibility review is B0 (PUB4). Configurable gesture thresholds in Settings UI is B0 (FE3). |
| **Performance** | Pass-with-tracked | Budgets unchanged from P1/P9. Fixes F1–F14 applied. Real-device verification on iPhone 12 / Pixel 6 / Pixel 4a / Galaxy A52 is B0 (F4, PF5, PF7) post-libsignal integration. |
| **Motion quality** | Pass | Seven motion patterns, three loops, max 500 ms / 600 ms cinematic, ≤ 8% bounce-overshoot — implemented in `velix_motion`, verified in P11 doc 01. No tracked items affecting motion quality. |
| **Production reliability** | Pass-with-tracked | Three-cell topology, Argo CD GitOps, three-tier rollback, 5-min MTTR target, runbooks templated. Cell provisioning, runbook authoring, DR drill, and bug-bounty-live are B0 (G1–G9, H1). |

**No dimension is Hold.** Every dimension is either Pass (motion) or Pass-with-tracked (the other five), where the "tracked" items are execution work, not architectural rethink.

## D. Public-facing documents — completeness check

| Artifact | Phase 11 file | Bytes | External review needed | Status |
|---|---|---|---|---|
| Security paper | `03-security-paper-draft.md` | 11,404 | Independent cryptographer | Draft complete; review pending |
| Privacy paper | `04-privacy-paper-draft.md` | 12,083 | Privacy counsel | Draft complete; review pending |
| AI privacy disclosure | `05-ai-privacy-disclosure-draft.md` | 9,323 | Security lead + legal | Draft complete; review pending |
| Accessibility statement | `06-accessibility-statement-draft.md` | 9,502 | Accessibility consultant | Draft complete; review pending |

All four artifacts are complete as drafts. Each is conservative, technically accurate, and aligned with the architecture from Phases 1–10. None over-promises. Each will be reviewed by the named external party in Sprint 6 before publication. None ships before the gate is Met.

## E. Prior-guarantee survival check

Re-running the cross-phase trace from `01-cross-phase-consistency.md`, with Phase 11 in scope:

| Guarantee | First documented | Phase 11 effect | Survives? |
|---|---|---|---|
| End-to-end encryption by default | P1 doc 07 | None — Phase 11 ships docs only | ✓ |
| Server cannot decrypt user content | P1 doc 07, P7 doc 03 | None | ✓ |
| Sealed sender (no `sender_account_id` on routing proto) | P7 doc 09 | None | ✓ |
| AI cloud calls require per-query consent | P8 doc 03 | Reaffirmed in P11 doc 05 | ✓ |
| AI gateway holds trust level 4 | P7 doc 03, P8 doc 01 | Reaffirmed | ✓ |
| Color is never the sole differentiator of meaning | P2 doc 12 | Reaffirmed in P11 doc 06 | ✓ |
| No animations during scroll | P4 doc 00 | None | ✓ |
| ≤ 800 ms cold start, ≥ 99% frame stability inside 16.6 ms | P1, P9 | None | ✓ |
| ≤ 4 ms GPU on iPhone 12 / Pixel 6 for 3D scenes | P3 doc 02 | None | ✓ |
| ≤ 4% / hour battery active foreground | P1, P9 | None | ✓ |
| Annual independent audits, results published | P7 doc 18, P10 doc 13 | Reaffirmed in P11 doc 03 | ✓ |
| Open-source cryptographic core (Apache 2.0) | P7 doc 04 | Reaffirmed in P11 doc 03 | ✓ |
| Three-tier rollback, 5-min MTTR target | P10 doc 11 | None | ✓ |
| Reproducible builds verified nightly | P10 doc 03 | None | ✓ |

**Zero guarantees weakened by Phase 11.** Phase 11 is consolidation only, by design.

## F. Remaining risks, owners, deadlines

The risks are not architectural. They are execution risks against the Sprint 1–9 plan.

### Critical-path risks (could slip launch by ≥ 1 sprint)

| # | Risk | Mitigation | Owner | Deadline (relative to T0 = Phase 11 sign-off) |
|---|---|---|---|---|
| R1 | `cryptocore` libsignal FFI implementation late | Cryptographer engaged Sprint 1; second pair-programmer if Sprint 2 slips | Crypto eng | End of Sprint 4 (week 8) |
| R2 | Independent cryptographic audit firm unavailable in window | Engage two firms in parallel (one primary, one shadow) | Security lead + business | Engagement signed end of Sprint 1 (week 2) |
| R3 | Critical/High audit findings late in cycle | Sprint 7 buffered for remediation; if depth requires Sprint 8, slip launch by one cycle (no negotiation) | Crypto eng + Auditor | Audit clean by end of Sprint 8 (week 17) |
| R4 | OHTTP relay operator procurement drags | Fallback: ship 1.0 with cloud AI disabled, on-device only | Security lead + legal | Contract signed end of Sprint 2 (week 4) |
| R5 | Provider contracts (Anthropic/OpenAI no-train clauses) drag | Same fallback as R4 | Legal + business | Signed end of Sprint 3 (week 6) |
| R6 | AI privacy audit Critical/High findings late | Same buffering as R3 | ML eng + Auditor | Audit clean by end of Sprint 8 (week 17) |

### Non-critical-path risks (recoverable in 1.1)

| # | Risk | Mitigation | Owner | Deadline |
|---|---|---|---|---|
| R7 | Custom icon set / 3D identity scenes miss Sprint 5 | Ship with provisional assets; replace in 1.1 | Designer | End of Sprint 5 (week 10), or 1.1 |
| R8 | Variable-font vendoring blocked | Ship with system fonts; replace in 1.1 | Mobile | Same |
| R9 | TestFlight / closed-track soak surfaces a P0 in week 17 | Phase 10 doc 11 three-tier rollback; halt and fix | Mobile lead | Pre-launch |
| R10 | Bug bounty inflow overwhelms triage | HackerOne managed-triage service from day one | Security lead | Sprint 6 (week 12), bug bounty live |
| R11 | App Store / Play Store rejection | Phase 10 doc 12 expected-questions list; expedited review path; 1-cycle buffer in Sprint 8 | Mobile lead | Sprint 8 (week 17) |

### Operational risks (live indefinitely)

| # | Risk | Mitigation | Owner |
|---|---|---|---|
| R12 | Post-launch P0 incident in first 72 hours | Phase 10 doc 11 three-tier rollback; 5-min MTTR target; on-call ready 72h | DevOps + Security lead |
| R13 | Audit firm finds something material in re-test | Phase 10 doc 11 rollback paths; Sprint 8 includes a re-test buffer | Crypto eng + Auditor |
| R14 | Public papers diverge from reality after a quiet code change | Privacy-affecting changes require public-paper update before merge (P10 doc 13) | Security lead |

## G. Final ship/no-ship recommendation

**No ship today.**

**Recommend launch at end of Sprint 9 (T+20 weeks), conditional on every B0 in `07-launch-readiness.md` going Met.**

The path is:

1. Engage cryptographic + AI privacy audit firms (Sprint 1; T+2 weeks).
2. Implement `cryptocore` libsignal FFI (Sprints 1–2; T+4 weeks).
3. Provision cells, Vault, Argo CD, PagerDuty, Statuspage (Sprints 1–2).
4. Wire the six backend services against the proto contracts (Sprints 1–3).
5. Implement on-device AI backends; sign launch models (Sprints 2–4).
6. Author and integrate variable fonts, custom icons, 3D scenes (Sprints 4–5).
7. Run audits (Sprints 3–7; gated remediation).
8. Bug bounty live ≥ 30 days; pen test (Sprint 6+).
9. Get external reviews of public papers (Sprint 6).
10. Onboard App Store + Play Store; encryption export filing; beta cohort (Sprint 8).
11. Ship public 1.0 with phased rollout (Sprint 9).

The bar to flip from Pass-with-tracked to Pass:

- Every B0 row in `07-launch-readiness.md` is Met.
- Cryptographic audit clean: Critical + High remediated and re-tested.
- AI privacy audit clean: Critical + High remediated and re-tested.
- Bug bounty live ≥ 30 days, no unresolved Critical or High findings.
- All four public-facing documents reviewed by the named external party and published.
- All six prior-guarantee dimensions still Pass or Pass-with-tracked-and-resolved at the moment of the launch decision meeting.

## H. The launch decision meeting

When Sprint 9 begins, this is the meeting:

1. The release manager opens `07-launch-readiness.md`.
2. For each row, the named owner declares Met or Not Met.
3. If every B0 is Met → ship per Phase 10 doc 10 (1% → 10% → 50% → 100% over 96 hours).
4. If any B0 is Not Met → no ship. Re-meet weekly until clear.

There is no negotiation in that meeting. No "ship with risk." No "ship and patch." The B0 list is the contract, and the contract is what the public papers, the architecture, the audits, and the user's trust are built on.

## I. Operational obligations after launch

These don't gate launch; they keep the verdict alive after launch:

- Annual cryptographic + privacy audits (P7 doc 18, P10 doc 13).
- Quarterly DR drill, monthly backup-restore drill (P10 doc 09).
- Quarterly transparency report (first issue 90 days post-launch; PUB6).
- Quarterly accessibility re-audit (P11 doc 06).
- Per-release reproducibility nightly (P10 doc 03).
- Post-quantum hybrid adoption when libsignal upstream lands it (B3 / FW1 review for v2).
- MLS evaluation for v2 (B3 / FW1).

If any of these slip past their cadence, the public papers must be updated before the next public claim is made.

## Sign-off

**Verdict at Phase 11 close: Pass-with-tracked.**

**Ship recommendation today: no ship.**

**Conditional ship recommendation: end of Sprint 9 (T+20 weeks), conditional on the gate run in `07-launch-readiness.md` returning Met across all B0 rows.**

Signed: principal release manager (Phase 11 audit owner).
Date: 2026-05-29.

Co-signers required at launch decision meeting (Sprint 9):

- Security lead
- Crypto eng lead
- Mobile lead
- Backend lead
- DevOps lead
- ML eng lead
- Legal counsel

Each owner signs only the rows they own. Launch ships only when every signature is on the page.
