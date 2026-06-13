# 10 — Critical-Path Remediation

Launch-gate remediation only. Six critical-path risks from `09-ship-decision.md`. Each row is binary.

T0 = Phase 11 sign-off (2026-05-29). All deadlines relative.

## Source of truth

- `07-launch-readiness.md` — gate checklist (rows referenced as A1, C4, etc.)
- `02-outstanding-triage.md` — triage IDs (C1, AI3, etc.)
- `09-ship-decision.md` — risk register (R1–R6)

No new gates. No new owners. Only status declarations against existing rows.

## R1 — Cryptocore FFI implementation

| Field | Value |
|---|---|
| **Current status** | Not started. `cryptocore/` ships skeleton: `Cargo.toml`, `src/lib.rs`, `src/csprng.rs`, `src/error.rs`, `tests/error_test.rs`. The 11-module libsignal FFI surface specified in P7 doc 18 is not yet authored. |
| **Blocker** | No engineering capacity assigned. Crypto-eng role unfilled or unscheduled. |
| **Owner** | Crypto eng (lead). |
| **Deadline** | End of Sprint 4 (T+8 weeks) — feature-complete; FFI compiles, runs, passes Wycheproof + libsignal upstream test vectors. |
| **Done means** | (1) X3DH, Double Ratchet, Sender Keys, Sealed Sender all wrap libsignal at the FFI boundary. (2) `velix_crypto` Dart binding compiles and passes the test vector suite. (3) `velix_data` repositories libsignal-backed; no `InMemory*Repository` in the production binary. (4) Reproducible build verified on three platforms. |
| **Gate rows** | A1, A2, A3, A4, B6 (mTLS), C5 (Wycheproof), C6 (reproducible builds), D6 (libsignal-backed repos), F5 (libsignal cache bounds), F7 (cold-start re-verify post-FFI) |
| **State today** | **Not Met** |

## R2 — Audit firm engagement (cryptocore + AI gateway)

| Field | Value |
|---|---|
| **Current status** | Not engaged. Candidate list documented in P10 doc 13: Cure53, Trail of Bits, NCC Group crypto practice, Paragon Initiative. No firm contracted. |
| **Blocker** | (1) Firm selection meeting not held. (2) Procurement budget not finalized. (3) Audit firms book ~6 weeks ahead; window narrows the longer this slips. |
| **Owner** | Security lead (firm selection + scope) + business (contract + budget). |
| **Deadline** | End of Sprint 1 (T+2 weeks) — engagement signed for both audits (cryptographic + AI privacy). |
| **Done means** | (1) One firm contracted for cryptographic audit of `cryptocore`. (2) A separate firm contracted for AI gateway privacy audit (cross-checking findings). (3) Both have a signed SOW with timeline, scope, deliverables, and re-test clause. (4) Kickoff dates land in Sprint 3 (T+5 weeks) at the latest. |
| **Gate rows** | A5, A7, C6, C7, I1 (cryptographer review of security paper) |
| **State today** | **Not Met** |
| **Mitigation if firm unavailable** | Engage two firms in parallel for the cryptographic audit (one primary, one shadow). Documented in `09-ship-decision.md` R2. |

## R3 — Cryptographic audit findings remediation

| Field | Value |
|---|---|
| **Current status** | Audit not started; findings cannot exist yet. |
| **Blocker** | Gated by R1 (FFI must be feature-complete + stable) and R2 (firm engaged). |
| **Owner** | Crypto eng (remediation) + auditor (re-test) + security lead (sign-off). |
| **Deadline** | End of Sprint 8 (T+17 weeks) — audit clean: zero unresolved Critical or High. Sprint 7 buffered for remediation; Sprint 8 for re-test. |
| **Done means** | (1) Auditor delivers report classifying findings Critical / High / Medium / Low / Informational. (2) All Critical and High remediated. (3) Auditor re-tests each Critical/High and confirms fix. (4) Medium fixed pre-launch unless explicitly tracked with rationale. (5) Public report published at `velix.app/security/audits/`. |
| **Gate rows** | A5, A6, A7 |
| **State today** | **Not Met** |
| **Slip handling** | If findings depth requires Sprint 9 for remediation, **launch slips by one cycle**. No negotiation. Documented in `08-final-verdict.md` and `09-ship-decision.md` R3. |

## R4 — OHTTP relay operator procurement

| Field | Value |
|---|---|
| **Current status** | No operator selected. Phase 8 doc 05 specifies the architecture (Velix client → independent relay → Velix AI gateway, IP-blinded). No contract. |
| **Blocker** | (1) Operator candidate list not finalized. (2) Legal review of relay-operator contract template not done. (3) Operator must be operationally + jurisdictionally independent of Velix. |
| **Owner** | Security lead (selection) + legal (contract). |
| **Deadline** | End of Sprint 2 (T+4 weeks) — contract signed; relay healthy in staging. |
| **Done means** | (1) Operator selected (criteria: independent jurisdiction, no business overlap with Velix, audit-friendly). (2) Contract signed; mutual indemnification + log-purge guarantees in place. (3) Relay endpoint live in staging. (4) Velix-side OHTTP client (Dart) verified end-to-end. (5) Gateway-side decryption verified. |
| **Gate rows** | B9 (OHTTP end-to-end), C3 (relay operator contract), C8 (trust level 4 verified) |
| **State today** | **Not Met** |
| **Fallback** | Ship 1.0 with cloud AI disabled; on-device features only. Documented in `09-ship-decision.md` R4. **This is a degradation, not a failure mode** — on-device features (smart reply, translate-local, summarize-local, language ID) are sufficient for v1.0 if the relay is genuinely unavailable. |

## R5 — Cloud AI provider contracts

| Field | Value |
|---|---|
| **Current status** | Not signed. Required clauses: no-train-on-data, log-purge ≤ 30 days, sub-processor disclosure, data-region commitments, SOC 2 / ISO 27001 attestation. |
| **Blocker** | (1) Legal review of provider standard terms not done. (2) Business negotiation for no-train-on-data clauses (standard for enterprise tier; requires the right contract level). |
| **Owner** | Legal + business (negotiation) + security lead (clause requirements). |
| **Deadline** | End of Sprint 3 (T+6 weeks) — contracts signed with at least one cloud AI provider (Anthropic OR OpenAI) covering the four cloud-AI features (long-form summarize, advanced translate, complex assistant, abuse-pattern moderation). |
| **Done means** | (1) Contract signed with at least one provider. (2) Contract explicitly covers: no training on Velix-routed content, log-purge cadence, sub-processor list, data-region commitment, audit rights. (3) Subprocessor list updated at `velix.app/privacy/subprocessors`. |
| **Gate rows** | C4 (provider contracts), K4 (subprocessor list published) |
| **State today** | **Not Met** |
| **Fallback** | Same as R4: ship 1.0 with cloud AI disabled if no provider lands clean terms. Acceptable degradation. |

## R6 — AI privacy audit findings remediation

| Field | Value |
|---|---|
| **Current status** | Audit not started; findings cannot exist yet. |
| **Blocker** | Gated by R2 (firm engaged) and by AI gateway being deployable (triage AI2). |
| **Owner** | ML eng (remediation) + auditor (re-test) + security lead (sign-off). |
| **Deadline** | End of Sprint 8 (T+17 weeks) — audit clean: zero unresolved Critical or High. |
| **Done means** | (1) Auditor verifies the trust boundary documented in P8 doc 01 is enforced in practice. (2) All Critical and High findings remediated and re-tested. (3) Public report published at `velix.app/security#ai`. |
| **Gate rows** | C6 (AI privacy audit), C7 (Critical/High remediated), C8 (trust level 4 verified) |
| **State today** | **Not Met** |
| **Slip handling** | Same as R3 — if remediation requires Sprint 9, launch slips by one cycle. |

## Launch-readiness checklist row updates

The rows touched by R1–R6, with their state declared today:

| Row | Topic | Owner | State |
|---|---|---|---|
| A1 | cryptocore feature-complete | Crypto eng | Not Met |
| A2 | velix_crypto Dart binding + Wycheproof pass | Crypto eng | Not Met |
| A3 | libsignal-backed `velix_data` repositories | Mobile | Not Met |
| A4 | Reproducible build on 3 platforms | DevOps | Not Met |
| A5 | Cryptographic audit complete | External firm + security lead | Not Met |
| A6 | Critical/High remediated and re-tested | Crypto eng + auditor | Not Met |
| A7 | Public audit report published | Security lead | Not Met |
| B9 | OHTTP relay end-to-end verified | Mobile + Backend | Not Met |
| C3 | OHTTP relay operator contract signed | Security lead + legal | Not Met |
| C4 | Cloud AI provider contracts signed | Legal + business | Not Met |
| C6 | AI privacy audit complete | External firm + security lead | Not Met |
| C7 | Critical/High AI findings remediated | ML eng + auditor | Not Met |
| C8 | Trust level 4 verified | Security lead | Not Met |
| D6 | libsignal-backed repositories in production binary | Mobile | Not Met |
| F5 | libsignal cache bounds enforced | Crypto eng | Not Met |
| F7 | Cold-start ≤ 800 ms re-verified post-FFI | Performance lead | Not Met |
| I1 | Security paper cryptographer-reviewed + published | Security lead | Not Met (draft shipped) |
| K4 | Subprocessor list published | Legal | Not Met |

**18 rows: every one Not Met today.** Expected. They flip Met across Sprints 1–8 per the plan.

## Compact blocker summary

| # | Risk | One-line blocker | Earliest Met |
|---|---|---|---|
| R1 | Cryptocore FFI | No engineer assigned | End of Sprint 4 (T+8w) |
| R2 | Audit firm engagement | No contract signed | End of Sprint 1 (T+2w) |
| R3 | Crypto audit findings clean | Audit not started; gated by R1+R2 | End of Sprint 8 (T+17w) |
| R4 | OHTTP relay operator | No operator selected | End of Sprint 2 (T+4w) |
| R5 | Cloud AI provider contracts | No-train clauses not negotiated | End of Sprint 3 (T+6w) |
| R6 | AI privacy audit findings clean | Audit not started; gated by R2 | End of Sprint 8 (T+17w) |

Three procurement blockers (R2, R4, R5) sit at the front of the path. They unblock the work that follows. **If R2 slips past Sprint 1, the whole launch slips.**

## Residual risk summary

After the six items resolve, what residual risk remains for launch:

| # | Residual risk | Mitigation |
|---|---|---|
| RR1 | Audit firm finds something material in re-test | Sprint 8 includes re-test buffer; if depth requires Sprint 9, launch slips one cycle |
| RR2 | OHTTP relay operator goes down post-launch | Per-cell HA, contracted SLO; cloud AI auto-disables on relay failure (per-query consent intercept) |
| RR3 | Provider terms change post-launch | Contracts are annual; mid-year change requires public-paper update before next claim |
| RR4 | libsignal upstream regression after our pin moves | Pin is exact; upgrades go through CI test-vector suite; no auto-bump |
| RR5 | First post-launch bug bounty submission Critical | Three-tier rollback (P10 doc 11) targets ≤ 5-min MTTR; all hands available 72h post-launch |
| RR6 | Cloud AI fallback path (R4/R5) ships in 1.0 with cloud AI disabled | Acceptable degradation; on-device features sufficient for 1.0; cloud AI in 1.1 |

None of these are architectural. All are operational. All have documented mitigations.

## Exact next-sprint actions to move from No-ship to Ship

### Sprint 1 (T+0 to T+2 weeks) — gate the procurement front

| Day | Action | Owner | Done when |
|---|---|---|---|
| T+0 | Hold firm-selection meeting; pick crypto-audit firm + AI privacy audit firm | Security lead + business | Two firms named |
| T+1 | Open SOW negotiations with both firms | Security lead + legal | SOW drafts in flight |
| T+1 | Open OHTTP relay operator candidate list; criteria meeting | Security lead | Top-3 candidates named |
| T+2 | Open cloud AI provider contract review (Anthropic + OpenAI standard enterprise terms) | Legal | Term sheets received |
| T+3 | Assign crypto eng to cryptocore FFI implementation | Crypto eng lead + business | Engineer named, started |
| T+5 | OHTTP operator selected (top-1 from candidate list) | Security lead | Operator named |
| T+7 | Provision us-east-1 cell terraform module (parallel work) | DevOps | Cell provisioned |
| T+10 | Audit firm SOW signed (both firms) — **R2 Met** | Security lead | SOWs executed |

End-of-Sprint-1 gate-row updates: **R2 Met.** All others still Not Met.

### Sprint 2 (T+3 to T+4 weeks) — close the relay; deepen the FFI

| Day | Action | Owner | Done when |
|---|---|---|---|
| T+11 | OHTTP operator contract signed; relay endpoint provisioned in staging | Security lead + legal | Endpoint up |
| T+12 | Velix-side OHTTP client (Dart) integrated; end-to-end verified in staging | Mobile + Backend | Test suite green |
| T+14 | cryptocore X3DH + Double Ratchet feature-complete in FFI | Crypto eng | `cargo test` green; first Wycheproof vectors pass |
| T+14 | Argo CD configured against the three cells | DevOps | Sync verified |
| T+18 | Audit kickoff meetings held with both firms | Security lead | Both audits scheduled to start Sprint 3 |
| T+20 | OHTTP relay end-to-end verified — **R4 Met** | Security lead | B9 + C3 + C8 partially Met |

End-of-Sprint-2 updates: **R2 Met, R4 Met.**

### Sprint 3 (T+5 to T+6 weeks) — close provider contracts; start audits

| Day | Action | Owner | Done when |
|---|---|---|---|
| T+22 | Cloud AI provider contracts signed (at least one of Anthropic / OpenAI) | Legal + business | Contracts executed |
| T+22 | Subprocessor list updated at `velix.app/privacy/subprocessors` | Legal | Page live (private until launch) |
| T+24 | Cryptographic audit kickoff | Auditor + Crypto eng | Audit live |
| T+24 | AI privacy audit kickoff | Auditor + ML eng | Audit live |
| T+28 | Sender Keys + Sealed Sender feature-complete in FFI | Crypto eng | Wycheproof vectors clean |
| T+30 | Cloud AI contracts signed — **R5 Met** | Legal | C4 + K4 Met |

End-of-Sprint-3 updates: **R2 Met, R4 Met, R5 Met.** R1 in progress; R3+R6 audits live.

### Sprint 4 (T+7 to T+8 weeks) — close the FFI

| Day | Action | Owner | Done when |
|---|---|---|---|
| T+32 | velix_crypto Dart binding compiles + passes test vector suite | Crypto eng | `flutter test` green |
| T+34 | velix_data libsignal-backed repositories live in production binary | Mobile | InMemory* removed from prod build |
| T+38 | Reproducible build verified nightly on three platforms | DevOps | Digest match green |
| T+40 | Cold-start ≤ 800 ms re-verified on iPhone 12 + Pixel 6 + Pixel 4a | Performance lead | Bench harness clean |
| T+40 | cryptocore feature-complete — **R1 Met** | Crypto eng | A1 + A2 + A3 + A4 + D6 + F5 + F7 Met |

End-of-Sprint-4 updates: **R1, R2, R4, R5 all Met.** Only R3 + R6 remaining (gated by audit progress).

### Sprints 5–7 (T+9 to T+14 weeks) — audit progress + remaining B0 work

The 3D scenes, fonts, icons, runbooks, DR drill, store onboarding work runs in parallel. R1–R6 critical-path-wise are dormant during these sprints; auditors are at work.

### Sprint 8 (T+15 to T+17 weeks) — audit re-test

| Day | Action | Owner | Done when |
|---|---|---|---|
| T+102 | Cryptographic audit report delivered | Auditor | Report received |
| T+102 | AI privacy audit report delivered | Auditor | Report received |
| T+104 | Critical + High remediation begins for both audits | Crypto eng + ML eng | Tickets opened |
| T+114 | Re-test of all Critical + High findings | Auditor | Re-test report green |
| T+115 | Public reports published at `velix.app/security/audits/` and `velix.app/security#ai` | Security lead | URLs live |
| T+117 | **R3 Met + R6 Met** | Security lead | A5 + A6 + A7 + C6 + C7 + C8 Met |

End-of-Sprint-8 updates: **R1–R6 all Met.** All 18 critical-path rows Met.

### Sprint 9 (T+18 to T+20 weeks) — launch decision

| Day | Action | Owner | Done when |
|---|---|---|---|
| T+126 | Launch decision meeting; gate run against `07-launch-readiness.md` | Release manager | Every B0 row Met or launch slips |
| T+128 | If green: phased rollout begins (1% → 10% → 50% → 100% over 96 hours) | DevOps + Mobile lead | Rollout live |
| T+140 | Public 1.0 at 100% | Release manager | **Ship.** |

## Final ship/no-ship decision

**Today: No ship.** All six critical-path items are Not Met. 18 launch-readiness rows are Not Met against this remediation alone. The wider gate has 35 B0 rows total.

**Conditional ship: end of Sprint 9 (T+20 weeks).** Conditional on the gate run in `07-launch-readiness.md` returning Met across every B0 row, including the 18 listed in this document.

The path is mechanical from here. Engage the firms in week 1, lock the relay in week 2, sign the providers in week 3, finish the FFI in weeks 4–8, run the audits in weeks 5–14, remediate in weeks 15–17, ship in weeks 18–20.

**The single non-negotiable: the cryptographic and AI privacy audits return clean (zero unresolved Critical or High) before public 1.0.** Everything else has a fallback. That one does not.

## Sign-off

Signed: principal release manager + Phase 11 audit owner.
Date: 2026-05-29.

This document supersedes nothing. It tracks the six critical-path risks documented in `09-ship-decision.md` against the gate rows in `07-launch-readiness.md`. The verdict at Phase 11 close (`08-final-verdict.md`) stands: **Pass-with-tracked.** The verdict moves to **Pass** when every row in this document and in `07-launch-readiness.md` is Met.
