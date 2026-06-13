# 13 — Security Readiness

What needs to be true before public 1.0. The hard prerequisites that gate launch.

## The bar

We do not ship to public 1.0 without:

1. Independent security audit of `cryptocore` (Phase 7).
2. Independent privacy audit of the AI gateway (Phase 8).
3. Public security paper at `velix.app/security`.
4. Public privacy paper at `velix.app/privacy`.
5. Public AI privacy disclosure at `velix.app/security#ai`.
6. Coordinated bug bounty program live.
7. Status page live.
8. Accessibility statement live (Phase 2 doc 12).
9. Incident response runbooks complete.
10. DR drills passed quarterly with documented results.

Each is treated as a release blocker. We will not "do this after launch" for any of them.

## Independent security audit (cryptocore)

### Scope

The audit firm reviews:

- The `cryptocore` Rust crate: source code, integration with libsignal, FFI boundary, memory hygiene.
- The protocols deployed: X3DH, Double Ratchet, Sender Keys, Sealed Sender, multi-device pairing, encrypted backup.
- The libsignal version pinning.
- The reproducible build process.
- The signing key rotation.
- The deployment of the cryptocore in the Velix client app.

We do NOT ask the firm to audit:

- libsignal upstream itself (Signal Foundation has them audited; we trust the chain).
- The web of TLS / mTLS configurations (those are routine).
- The backend services beyond their cryptographic interfaces.

### Firm selection

Criteria:
- Specialization in cryptography review (not general security firms).
- Public history of Signal Protocol audits or equivalent.
- Reasonable size (5-15 person firm; Velix isn't a Big-Four engagement).
- Willingness to publish results.

Candidates: Cure53, Trail of Bits, NCC Group's crypto practice, Paragon Initiative. We will engage one.

### Engagement

- Lead time to engage: ~6 weeks.
- Audit duration: ~4 weeks.
- Report turnaround: ~2 weeks.
- Findings remediation: ~4 weeks (depends on findings).
- Re-test of remediations: ~1 week.
- **Total elapsed: ~17 weeks** (pad to 5 months in planning).

This means the audit must be commissioned no later than **5 months before public 1.0**.

### Findings handling

- All findings categorized: Critical / High / Medium / Low / Informational.
- Critical and High: must be fixed before launch.
- Medium: fixed before launch unless explicitly tracked with rationale.
- Low / Informational: tracked, fixed in next quarterly window.

Fix verification: the firm re-tests each Critical/High finding.

### Public disclosure

After the audit:
- The audit report is published at `velix.app/security/audits/`.
- We publish the findings, fixes, and outstanding items.
- Critical findings are disclosed once fixed (responsible disclosure).
- Audit cadence: annual.

## Independent privacy audit (AI gateway)

### Scope

The privacy audit firm reviews:

- The OHTTP relay configuration.
- The gateway's logging discipline.
- The PII scrubber (prompt sanitization, telemetry).
- The provider contracts (no-train-on-data clauses).
- The anonymous quota credential implementation (Privacy Pass).

The firm verifies:

- The gateway cannot correlate user identity with content.
- The relay cannot read content.
- Logs do not leak PII.
- The trust boundary documented in Phase 8 doc 01 is enforced in practice.

### Engagement

Same shape as the security audit: ~17 weeks total. Concurrent with the security audit (different firm; the two reviewers' findings are cross-checked).

### Public disclosure

Published at `velix.app/security#ai`.

## Public security paper

A 5-10 page document at `velix.app/security`. Contents:

```
1. What Velix promises (the properties P1-P16 from Phase 7 doc 01)
2. What Velix does not promise (the non-promises N1-N10)
3. The cryptographic primitives (Phase 7 doc 02)
4. The threat model (Phase 7 doc 01)
5. The trust boundaries (Phase 7 doc 03)
6. The protocols (X3DH, Double Ratchet, Sender Keys, Sealed Sender)
7. Multi-device pairing
8. Backup security
9. The AI architecture's privacy properties
10. How to verify our claims (open source, reproducible builds, audits)
11. How to report a vulnerability (security@velix.app + bug bounty)
12. The annual audit cadence
13. Transparency report cadence
```

The paper is technical but readable by a non-cryptographer. It does not claim more than we deliver.

## Public privacy paper

A separate document at `velix.app/privacy`. Contents:

```
1. What data we collect (per category from App Store / Play Store forms)
2. What data we do NOT collect (no tracking, no surveillance)
3. How long we retain data
4. Where data is stored (per cell, per region)
5. Who can access data (architectural answer: nobody, by design)
6. Subprocessors (Cloudflare R2, APNs, FCM, Anthropic, OpenAI; their roles)
7. User rights (delete account, export data, port data)
8. Region-specific commitments (GDPR, CCPA, etc.)
9. How to contact privacy@velix.app
```

Drafted by legal counsel + reviewed by engineering. Annual update.

## Bug bounty

Tier-1 program via HackerOne or Intigriti. Scope:

- All Velix services and apps.
- Excluded: third-party services (Cloudflare R2, APNs, FCM).
- Excluded: out-of-scope assets (marketing site, blog).
- Excluded: known issues from the audits.

Payouts (suggested):

| Severity | Payout |
|---|---|
| Critical (RCE, key extraction, content decryption by server) | $10,000 - $50,000 |
| High (auth bypass, significant info disclosure) | $2,500 - $10,000 |
| Medium (XSS in admin tools, etc.) | $500 - $2,500 |
| Low | $100 - $500 |

Disclosure: coordinated. Researcher publishes after fix is shipped, not before.

## Status page

Public-facing at `status.velix.app`. Driven by:

- Synthetic probes (Phase 10 doc 07).
- Manual incident creation by on-call.
- Automated component health from Prometheus.

Statuses: Operational / Degraded / Partial Outage / Major Outage / Maintenance.

Maintenance windows: announced 7 days in advance for planned; immediately for emergencies.

## Accessibility statement

At `velix.app/accessibility`. Contents from Phase 2 doc 12:

- WCAG 2.2 AA commitment.
- VoiceOver / TalkBack / Switch Control / Voice Access supported.
- Per-platform accessibility tooling tested.
- Per-feature opt-outs available.
- How to report an accessibility issue.

Annual audit by an accessibility firm or internal QA.

## Incident response readiness

| Item | Status before launch |
|---|---|
| On-call rotation defined | required |
| PagerDuty configured | required |
| Runbooks complete | required |
| Slack channels: #incidents, #releases, #security | required |
| Postmortem template + culture | required |
| Customer comms templates (status page, blog, email) | required |
| Legal notification process for data incidents (GDPR 72-hour) | required |
| Cybersecurity insurance | recommended |

## Pre-launch security checklist

Before declaring 1.0:

- [ ] Independent security audit complete; Critical/High findings fixed; report published.
- [ ] Independent privacy audit complete; findings fixed; report published.
- [ ] Bug bounty program live for at least 30 days pre-launch.
- [ ] Penetration test of public-facing endpoints by a separate firm.
- [ ] All TLS certificates valid and pinned.
- [ ] Vault secrets verified rotating per policy.
- [ ] mTLS verified between every service pair.
- [ ] Admin access dual-control verified.
- [ ] All secrets in Vault; no env-var secrets in code.
- [ ] CSP headers configured for the web client.
- [ ] HSTS preloaded for `velix.app`.
- [ ] DMARC + DKIM + SPF for email.
- [ ] OWASP Top 10 reviewed for each service.
- [ ] Crash reports verified PII-scrubbed.
- [ ] Logs verified PII-scrubbed.
- [ ] Rate limits in production verified per Phase 6 doc 09.
- [ ] DR drilled within last 90 days.
- [ ] Backup restoration drilled within last 30 days.
- [ ] App Store / Play Store privacy disclosures honest and complete.
- [ ] Public security paper reviewed by independent cryptographer.
- [ ] Public privacy paper reviewed by privacy counsel.
- [ ] Transparency report cadence committed.
- [ ] Vulnerability disclosure policy (VDP) published.
- [ ] Coordinated disclosure process documented.

## Pre-launch privacy checklist

- [ ] App Store privacy disclosures match implementation.
- [ ] Play Store data safety section matches implementation.
- [ ] GDPR data export flow tested.
- [ ] GDPR account deletion flow tested.
- [ ] CCPA disclosure for California users.
- [ ] No "do not sell" toggle needed (we don't sell data) — but the disclosure says so.
- [ ] All third-party SDKs reviewed for telemetry. None call home with user content.
- [ ] No fingerprinting libraries linked.
- [ ] No advertising libraries linked.
- [ ] No surveillance libraries linked.
- [ ] AI privacy paper published.

## Public commitments memorialized

These are the technical commitments backed by architecture, restated for the public papers:

1. End-to-end encryption for every message, by default.
2. We never read your messages.
3. Cryptographic core is open source.
4. Annual independent audits, results published.
5. No backdoor, ever.
6. Quarterly transparency report.
7. AI features run on-device unless you explicitly invoke a cloud query.
8. We do not train on your messages; our providers don't either.
9. We do not sell user data.
10. We do not use advertising or surveillance trackers.

All ten are testable claims. The architecture enforces them; the audits verify them.

## Banned

- Launching without the security audit complete.
- Launching with Critical/High findings unfixed.
- Launching without the privacy paper published.
- Launching without the bug bounty live.
- Marketing claims that exceed engineering reality.
- Quietly launching changes that affect privacy posture (every privacy-affecting change requires a public update).
- "Compliance theater" that satisfies a checklist without changing reality.
