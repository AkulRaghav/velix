# 13 — Launch-Blockers Closure

The six launch-blocking external items from `12-final-closure-report.md`,
each closed against the row format the user specified. Nothing internal
remains. Every item below requires a counterparty to act.

This document does not invent gates. It runs the six already documented:
EX2 (crypto audit), EX3 (AI privacy audit), EX6 (bug bounty 30d),
EX7 (store onboarding), EX8 (export filing), EX20 (TestFlight + Play soak).

## EX2 — Cryptographic audit of cryptocore

| Field | Value |
|---|---|
| **Status today** | Not started. No firm engaged. |
| **Blocker** | (1) Firm-selection meeting not held. (2) SOW not signed. (3) Audit firms book ~6 weeks ahead. |
| **Owner** | Security lead (firm selection + scope) + business (contract + budget). |
| **Deadline** | T+17w end of Sprint 8. **Engagement signed by T+2w** is the hard sub-deadline; slippage past Sprint 1 slips launch by the same number of weeks. |
| **Exact done criteria** | (1) One of Cure53 / Trail of Bits / NCC Group crypto practice / Paragon Initiative engaged with signed SOW. (2) Audit complete; report delivered. (3) **Zero unresolved Critical or High findings** at re-test. (4) Public report published at `velix.app/security/audits/`. |
| **Gate rows** | A5, A6, A7 |
| **Today's row state** | All Not Met. |

## EX3 — AI privacy audit of the AI gateway

| Field | Value |
|---|---|
| **Status today** | Not started. No firm engaged. Concurrent with EX2; different firm to cross-check. |
| **Blocker** | Same as EX2: no firm, no SOW. Additionally, audit cannot meaningfully begin until AI gateway is deployable (depends on EX4 OHTTP relay + EX5 provider contracts). |
| **Owner** | Security lead + business (contract + budget); ML eng (audit interface). |
| **Deadline** | T+17w end of Sprint 8. **Engagement signed by T+2w**. |
| **Exact done criteria** | (1) Independent firm engaged (different from the cryptocore firm). (2) Audit verifies: trust level 4 holds; gateway cannot correlate identity with content; relay cannot read content; logs do not leak PII. (3) Critical + High remediated and re-tested. (4) Public report published at `velix.app/security#ai`. |
| **Gate rows** | C6, C7, C8 |
| **Today's row state** | All Not Met. |

## EX6 — Bug bounty live ≥ 30 days

| Field | Value |
|---|---|
| **Status today** | Program not configured. No platform onboarded. |
| **Blocker** | (1) HackerOne or Intigriti onboarding contract not signed. (2) Scope and severity table need legal review against `docs/public/vulnerability-disclosure-policy.md`. (3) Triage capacity not staffed (security lead + at least one rotating engineer). |
| **Owner** | Security lead. |
| **Deadline** | Program live by T+12w end of Sprint 6 — the **30-day soak clock** must end before the launch-decision meeting at T+20w start. |
| **Exact done criteria** | (1) Program live on HackerOne or Intigriti with the scope from `docs/public/vulnerability-disclosure-policy.md` published. (2) Triage rota live; SLAs met for ≥ 30 consecutive days. (3) Zero unresolved Critical or High at the launch-decision meeting. (4) `velix.app/.well-known/security.txt` matches the program contact info (`docs/public/security.txt` is ready). |
| **Gate rows** | H1, H2 (concurrent pen test) |
| **Today's row state** | H1 Not Met. H2 Not Met. H3 Met (security.txt content ready). H4 Met (disclosure process documented). |

## EX7 — App Store Connect + Play Console onboarding

| Field | Value |
|---|---|
| **Status today** | Not started. No store accounts configured. |
| **Blocker** | (1) Apple Developer Program enrollment not done. (2) Google Play Console account not created. (3) Bundle ID `app.velix` and package `app.velix` not registered. (4) Signing certificates / Play App Signing not enrolled. (5) App Privacy Manifest (iOS 17+) not declared. (6) Data Safety form (Play) not filled. |
| **Owner** | Mobile lead + legal (privacy disclosures). |
| **Deadline** | Both accounts onboarded by T+15w; first TestFlight build uploaded by T+15w (start of Sprint 8); store listings finalized by T+17w. |
| **Exact done criteria** | (1) App Store Connect: bundle ID registered; team + certs + profiles in place; app record created; App Privacy Manifest declared; privacy disclosures match `docs/phase-10/12-store-submission.md`. (2) Play Console: package registered; Play App Signing enrolled; Data Safety section complete; permissions matrix matches the spec. (3) Both stores: app icon, screenshots, app preview, marketing assets uploaded. (4) Localized release notes in EN, ES, FR, DE, JA, AR (or English fallback explicitly documented). |
| **Gate rows** | J1, J2, J4, J5, J8, J9 |
| **Today's row state** | All Not Met. |

## EX8 — Encryption export compliance filing

| Field | Value |
|---|---|
| **Status today** | Not started. |
| **Blocker** | (1) Annual ERN (Encryption Registration Number) renewal not filed with BIS. (2) App Store Connect encryption questionnaire not submitted. (3) Self-classification report (CCATS not required since libsignal is on the standard list, but the year-end self-classification is). |
| **Owner** | Legal. |
| **Deadline** | Filed before first store submission — T+15w (Sprint 8). |
| **Exact done criteria** | (1) ERN current. (2) App Store Connect "Includes encryption: Yes / Standard encryption: Yes / Available for export: Yes" answered consistent with libsignal usage. (3) Year-end self-classification report calendared. (4) Documentation in `docs/legal/export-compliance.md` (post-filing). |
| **Gate rows** | J3 |
| **Today's row state** | J3 Not Met. |

## EX20 — TestFlight + Play closed-track soak

| Field | Value |
|---|---|
| **Status today** | Not possible until EX7. |
| **Blocker** | Hard chain: EX7 (store onboarding) → upload signed builds → invite beta cohort → run soak. None of those steps are repo-resolvable. |
| **Owner** | Mobile lead. |
| **Deadline** | TestFlight external testing **≥ 7 days** completed by T+18w; Play closed-track **≥ 5 days** completed by T+18w. |
| **Exact done criteria** | (1) ≥ 50 active TestFlight testers receive ≥ one build. (2) Crash-free rate ≥ 99.5% across the soak. (3) ANR rate ≤ 0.5% (Android). (4) Zero unresolved Critical or High issues at end of soak. (5) Closed-testing track on Play observed for ≥ 5 days with same thresholds. |
| **Gate rows** | J6, J7 |
| **Today's row state** | Both Not Met. |

## Updated launch-readiness rows touched

The 13 rows tied to these six blockers, with state today:

| Row | Owner | State |
|---|---|---|
| A5 — Cryptographic audit complete | Auditor + security lead | Not Met (awaits EX2) |
| A6 — Critical/High remediated and re-tested | Crypto eng + auditor | Not Met (awaits EX2) |
| A7 — Public audit report published | Security lead | Not Met (awaits EX2) |
| C6 — AI privacy audit complete | Auditor + ML eng | Not Met (awaits EX3) |
| C7 — Critical/High AI findings remediated | ML eng + auditor | Not Met (awaits EX3) |
| C8 — Trust level 4 verified | Security lead | Not Met (awaits EX3 + EX4 runtime) |
| H1 — Bug bounty live ≥ 30 days | Security lead | Not Met (awaits EX6) |
| H2 — Pen test complete | Security lead | Not Met (concurrent with EX6) |
| J1 — App Store Connect onboarded | Mobile lead | Not Met (awaits EX7) |
| J2 — Play Console onboarded | Mobile lead | Not Met (awaits EX7) |
| J3 — Encryption export filing | Legal | Not Met (awaits EX8) |
| J6 — TestFlight ≥ 7 days observed | Mobile lead | Not Met (awaits EX20) |
| J7 — Play closed-track ≥ 5 days observed | Mobile lead | Not Met (awaits EX20) |

## Final ship/no-ship state

**Today: No ship.**

**Verdict: Pass-with-tracked. Unchanged.**

**Conditional ship: end of Sprint 9 (T+20w),** conditional on every row above flipping Met.

## Remaining blocker table (all six, single page)

| # | Item | Owner | Hard sub-deadline | Real deadline | Class |
|---|---|---|---|---|---|
| EX2 | Crypto audit clean | Security lead + audit firm | Engagement signed T+2w | Audit clean T+17w | Launch-blocking |
| EX3 | AI privacy audit clean | Security lead + audit firm | Engagement signed T+2w | Audit clean T+17w | Launch-blocking |
| EX6 | Bug bounty live ≥ 30 days | Security lead | Program live T+12w | Soak ends ≥ T+15w | Launch-blocking |
| EX7 | Store onboarding | Mobile lead + legal | Accounts T+15w | Listings T+17w | Launch-blocking |
| EX8 | Export filing | Legal | Filed T+15w | Same | Launch-blocking |
| EX20 | TestFlight + Play soak | Mobile lead | Builds uploaded T+15w | Soak passes T+18w | Launch-blocking |

## What still prevents Pass

Three concurrent dependency chains. All three must reach the green at
the launch-decision meeting (start of Sprint 9, T+18w):

1. **Audit chain.** EX2 + EX3 → Critical/High remediated → re-tested → reports public.
2. **Bug-bounty chain.** EX6 program live → 30 calendar days elapsed → no unresolved Critical/High.
3. **Store chain.** EX7 + EX8 → first signed build → EX20 soak → no unresolved Critical/High.

Each chain has its own counterparty. Any one slipping past its real
deadline slips launch by the slip amount.

## Exact next action

**T+0 (today). Same-day actions:**

| # | Action | Owner | Output |
|---|---|---|---|
| 1 | Hold firm-selection meeting; pick crypto-audit firm + AI privacy audit firm (different firms) | Security lead + business | Two firms named in writing |
| 2 | Open SOW negotiations with both firms | Security lead + legal | SOW drafts in flight |
| 3 | Open HackerOne / Intigriti onboarding ticket | Security lead | Vendor confirmed; scope draft attached |
| 4 | Apple Developer Program enrollment (if not enrolled) | Mobile lead | Receipt + DUNS confirmed |
| 5 | Google Play Console account creation (if not created) | Mobile lead | Account active |
| 6 | Open BIS ERN renewal ticket with legal | Legal | Filing scheduled |

**T+1 to T+10 days:** SOWs signed for EX2 + EX3. HackerOne contract
signed. Apple + Google accounts set up to the point a build can be
uploaded (bundle ID, package, signing).

**T+10 days:** EX2 + EX3 engagements signed. EX6 program in soft launch
preparing for live. EX7 accounts active.

**T+30 days (Sprint 3):** EX5 cloud AI providers signed → unlocks EX3
audit kickoff against a deployable gateway. EX6 program goes live → 30-day
clock starts. EX8 ERN filing complete.

**T+12w (Sprint 6 end):** EX6 30-day clock has elapsed clean. Public
papers reviewed and ready to publish.

**T+15w (Sprint 8 mid):** First store builds uploaded. EX20 soak starts.

**T+17w (Sprint 8 end):** Audits return clean (Critical/High remediated
+ re-tested). Reports public.

**T+18w (Sprint 9 start):** Launch decision meeting. Every row in
`07-launch-readiness.md` declared Met or Not Met by its named owner.
If any B0 row is Not Met, launch slips weekly until clear.

**T+20w (Sprint 9 end):** Public 1.0 in stores via phased rollout
(1% → 10% → 50% → 100% over 96 hours).

## Decision rule (re-stated for the launch meeting)

The launch decision is **binary**:

- Every B0 row in `07-launch-readiness.md` is Met → ship per `docs/phase-10/10-release-process.md`.
- Any B0 row is Not Met → **no ship**. Re-evaluate weekly.

There is no "ship with risk." There is no "ship and patch." The B0 list
is the contract.

## Sign-off

Signed: principal release manager + final launch-gate closure owner.
Date: 2026-05-29.

This is the final launch-gate closure document. The next action belongs
outside this repository: the firm-selection meeting and the four
counterparty engagements named at "T+0 today" above.

The repository is complete. The verdict is fixed at **Pass-with-tracked**
until those six external chains close. The verdict will move to **Pass**
on the day every row in `07-launch-readiness.md` is Met.
