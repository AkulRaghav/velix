# 04 — Public Privacy Paper (Draft)

> **Status:** Draft. Awaits review by privacy counsel + GDPR specialist. Region-specific addenda for EU, UK, California, and other applicable jurisdictions to be appended pre-launch.
>
> **Will be published at:** `velix.app/privacy`
>
> **Length:** Target 8–14 pages.
>
> **Audience:** Users with privacy concerns; auditors; data protection authorities.

---

# Velix Privacy

## What we collect

We collect only what we need to deliver the service. Nothing for advertising. Nothing for sale. Nothing for profiling.

| Category | What | When |
|---|---|---|
| Account identifier | A cryptographic hash of your identity public key. | At signup. |
| Optional handle | If you set one (e.g., `@quinn`). Stored in plaintext for discovery. | When you set it. |
| Optional email or phone | If you provide one for discovery. **Stored as a cryptographic hash, not in plaintext.** | When you provide it. |
| Device list | A list of your devices' public keys. Used to deliver messages to all your devices. | When you add a device. |
| Push tokens | The platform-provided token (APNs / FCM) for delivering notifications. | When you grant notification permission. |
| Encrypted message envelopes | The encrypted bytes of messages addressed to you, until your device acknowledges receipt. We cannot read them. | While you have undelivered messages. |
| Encrypted media | Encrypted photos, videos, voice notes, files. We cannot decrypt. | While media is shared in conversations you are in. |
| Encrypted backups | If you opt into server-side backup. Stored as ciphertext. | If and when you back up. |
| Connection metadata | Your IP address (for the duration of an active connection), the time of connection, and the device that connected. | When you connect to our servers. |
| Aggregate analytics | Anonymous counts of features used (e.g., "1.2 million users translated a message today"). No per-user data. | When you use a feature. |

## What we do not collect

| Category | Why |
|---|---|
| Message contents in plaintext. | Encrypted end-to-end; we cannot decrypt. |
| Your contacts. | Optional matching is done locally on your device with hashed identifiers. |
| Your conversation graph (who you talk to). | Sealed Sender hides this from us at the routing layer. |
| Your location. | We do not request location permission. |
| Your photos, videos, files in plaintext. | Encrypted before upload. |
| Your call audio or video. | End-to-end encrypted (≤ 8 participants); not recorded for larger calls. |
| Your search queries. | Search runs on your device. |
| Your AI queries. | Cloud queries are routed through a privacy-preserving relay so we cannot link them to your identity. |
| Browsing or web activity. | We are not a web browser. |
| Health, financial, or biometric data. | Out of scope. |
| Advertising identifiers. | We do not show ads. |

## How long we keep data

| Data | Retention |
|---|---|
| Account record | Until you delete your account; then 30 days; then permanent deletion. |
| Encrypted message envelopes | Until your device acknowledges, or 30 days unread, whichever is first. |
| Connection logs | 30 days, then aggregated and the per-connection data is deleted. |
| Encrypted media files | Per the conversation's retention policy (configurable; default 30 days post-upload). |
| Encrypted backups | Most-recent backup + previous backup for 7 days, then most-recent only. |
| Aggregate analytics | 1 year, in non-identifying form. |
| Crash reports | 30 days. |
| Audit logs (security-relevant events) | 1 year. |
| Push delivery logs | 7 days, then aggregated. |

We do not retain anything longer than this table indicates. There is no "shadow" archive of older data.

## Where data is stored

Your data lives in the geographic region of your home cell. At launch, we operate three cells:

- `us-east-1` (Northern Virginia, United States)
- `eu-west-1` (Ireland, European Union)
- `ap-southeast-1` (Singapore)

Your home cell is determined by your inferred region at signup. Once set, it is sticky — your data does not migrate to another cell unless you explicitly export and re-onboard.

Cross-cell traffic happens only when you message someone in a different cell; the encrypted envelope traverses to the recipient's cell. The content is encrypted before it leaves your device.

## Who can access data

The architectural answer: as few people and systems as possible, and never your message content.

- **Velix engineers:** access to production systems is dual-controlled and audit-logged. Engineers can read aggregate metrics, encrypted bytes, and routing metadata. They cannot decrypt message content because the keys are not on our servers.
- **Subprocessors (see below):** receive specific data types as required to deliver the service. Each is governed by a contract that prohibits secondary use.
- **Legal authorities:** receive only what we have, in response to lawful requests, after legal review. We publish numbers and categories quarterly in our transparency report. We never have message content to disclose.

We do not sell data. We do not share data with advertisers. We do not analyze data for profiling.

## Subprocessors

We work with the following service providers. Each has a specific role; none receive plaintext message content.

| Subprocessor | Role | What they see |
|---|---|---|
| Amazon Web Services / Google Cloud | Cloud infrastructure for our backend services and databases. | Encrypted bytes only; databases store ciphertext envelopes. |
| Cloudflare R2 | Encrypted media object storage. | Encrypted media files; no plaintext. |
| Cloudflare | Edge networking, DDoS protection. | TLS-terminated at our edge; no plaintext content. |
| Apple (APNs) | iOS push notification delivery. | Encrypted push payloads; routing tokens. No plaintext. |
| Google (FCM) | Android push notification delivery. | Same as APNs. |
| LiveKit | Voice and video call routing (SFU). For ≤ 8 participants, encrypted; for larger calls, server-aided (clearly indicated in UI). | Encrypted call frames (≤ 8); plaintext call frames (> 8, with user consent at call invitation). |
| Anthropic | AI provider for cloud assistant queries. | Per-query content (you opt in per query); no identity link to you due to our privacy-preserving relay. |
| OpenAI | AI provider; failover for Anthropic. | Same as Anthropic. |
| [TBD] OHTTP relay operator | Privacy-preserving relay decoupling identity from content for cloud AI queries. | Your IP and an opaque encrypted blob; cannot read content. |
| HashiCorp Vault | Internal secret management (self-hosted). | Service credentials; never user data. |
| Sentry | Internal crash reporting (self-hosted). | Crash stacks with PII removed; never message content. |

The OHTTP relay operator is independent of Velix-the-company. We will publish their identity and the contractual posture once the agreement is finalized.

## Your rights

### Access

You can export your data at any time from Settings → Account → Export. The export includes all data we hold for your account, in a machine-readable format. Encrypted content is included as ciphertext; if you have your encryption keys, you can decrypt locally.

### Deletion

You can delete your account at any time from Settings → Account → Delete. We delete:
- Immediately: your account record is marked deleted; sign-in is disabled; your devices stop receiving messages.
- After 30 days: all server-side data associated with your account is permanently deleted.

The 30-day window exists so that an accidental deletion can be reversed during that period. After 30 days, deletion is irrevocable.

If you wish to delete sooner, contact `privacy@velix.app`.

### Correction

You can update your handle, email, or phone number at any time from Settings → Account.

### Portability

The export above is in a documented format. You can carry it to another service or use it with our open-source tools. Phase 1 of "portability beyond export" — federated identity — is on our roadmap for v2.

### Objection / Restriction

You can disable specific features in Settings → AI, Settings → Display, Settings → Privacy at any time. Doing so does not require deleting your account.

You can opt out of crash reporting in Settings → Privacy → Diagnostics.

### Information

This document and supporting materials at `velix.app/security` and `velix.app/transparency` describe what we do. If you have questions: `privacy@velix.app`.

## Children

Velix is not directed at children under 13 (or under 16 in jurisdictions that require parental consent for that range). We do not knowingly collect data from children under those ages. If we become aware that we have collected such data, we delete it.

## Region-specific addenda

> [The full document will include region-specific sections compiled with region-specific counsel.]

### European Union (GDPR)

You are a Data Subject. We are the Data Controller. Our Data Protection Officer is reachable at `dpo@velix.app`.

Your rights under GDPR:
- Article 15 (access): see "Access" above; we respond within 30 days.
- Article 16 (rectification): see "Correction" above.
- Article 17 (erasure): see "Deletion" above.
- Article 18 (restriction): see "Objection / Restriction" above.
- Article 20 (portability): see "Portability" above.
- Article 21 (objection): see "Objection / Restriction" above.
- Article 22 (automated decision-making): we do not engage in automated decision-making with legal effects.

Lawful basis for processing: Article 6(1)(b) — performance of the contract you accept by signing up. Optional features (e.g., email-based discovery) require Article 6(1)(a) — consent.

Right to lodge a complaint with a supervisory authority: yes; your local data protection authority.

Data transfers outside the EU: data in the `eu-west-1` cell is processed in Ireland. Cross-cell traffic to non-EU cells is governed by Standard Contractual Clauses + supplementary measures (the encryption itself).

### United Kingdom (UK GDPR)

Substantively equivalent to GDPR. Information Commissioner's Office is the supervisory authority.

### California (CCPA / CPRA)

You have the right to know, delete, correct, and limit the use of "sensitive personal information." We do not sell or share for cross-context behavioral advertising. We do not collect sensitive personal information beyond what is described in this document. Contact `privacy@velix.app` to exercise your rights; we respond within 45 days.

### Other jurisdictions

[Brazil LGPD, Canada PIPEDA, India DPDP Act, etc., per legal counsel review.]

## Changes to this paper

Material changes to our privacy posture are announced 30 days in advance:

- Email notification to all account holders.
- In-app notification on next launch.
- Update to this page with a clear "what changed" summary.

We do not bury privacy changes. If we change our posture, you will know.

The change history is published at `velix.app/privacy/changelog`.

## Contact

- Privacy questions: `privacy@velix.app`.
- EU Data Protection Officer: `dpo@velix.app`.
- Security issues: `security@velix.app`.
- General contact: `support@velix.app`.

We respond within 7 days for general inquiries; 30 days for substantive Article 15 / Section 1798.110 requests.

---

> **End of public privacy paper.**
>
> Reviewer notes: this draft is conservative — it commits to the architectural posture from Phases 1–10 in user-readable language. The lawyer review should verify (a) data categories match what is technically collected, (b) the "we do not collect" list is exhaustive against the implementation, (c) GDPR / CCPA language is jurisdictionally correct, (d) subprocessor list is current, (e) retention table matches Phase 6 doc 04 / Phase 10 doc 09 commitments. Engineering review should verify the technical claims map to the codebase.
