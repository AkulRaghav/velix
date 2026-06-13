# 13 — Rate Limits & Quotas

Three layers: per-device on-device throttling, per-account cloud quota, gateway-level abuse controls.

## On-device throttling

Cheap by design; mostly a battery defense.

| Feature | Limit |
|---|---|
| Smart reply suggestion refresh | 1 per 200 ms |
| Translation | unlimited (driven by user input) |
| Summarization (on-device) | 30 per minute |
| Moderation classification | 60 per minute (one per incoming message; bounded by message rate) |
| Live captions | streaming; not throttled |

Throttling happens at the `velix_ai` router. Excess requests return `RateLimited` errors which the UI ignores silently (next render produces fresh content).

## Per-account cloud quota

Cloud AI is metered. Free tier and paid tier quotas:

| Tier | Cloud invocations per month |
|---|---|
| Free | 50 |
| Plus ($5/mo) | 1,500 |
| Spaces ($10/mo) | 1,500 + per-Space pool of 5,000 |
| Teams ($8/user/mo) | 5,000 per user, pooled at the team level |

Why metered: the marginal cost of a cloud AI query is non-zero (provider API cost). Without metering, abuse drives cost. With metering, free-tier users get a meaningful sample; paid users get more headroom.

The quota is **not** a privacy boundary; it's a billing control. Privacy-relevant rate limits live below.

## Gateway-level rate limits

Per anonymous credential (the OHTTP-issued quota token), enforced at the gateway:

| Window | Limit |
|---|---|
| 1 second | 1 request |
| 1 minute | 30 requests |
| 1 hour | 200 requests |
| 1 day | 500 requests |

These are *anti-abuse* limits, not per-user usage limits. They prevent a single token from being shared across a botnet.

Excess returns `RateLimited` with a `Retry-After` header. Client backs off.

## Anonymous quota token

Phase 8 doc 05 specified the token shape. Here's the issuance + redemption ABI:

### Issue

```
Client → identity service: POST /identity/IssueAIQuotaToken
                            body: { device_id }   (auth: client bearer token)
Identity service:
  1. Looks up account_id from bearer token.
  2. Reads quota_remaining from account_quota table.
  3. Generates a Privacy-Pass-style blinded credential.
  4. Returns { quota_token, quota_remaining, expires_at }.

Client persists quota_token (15-minute lifetime).
```

### Redeem

```
Client → gateway: POST /v1/<feature>
                  body (HPKE-sealed): {
                    quota_token,
                    consent_token,
                    payload
                  }
Gateway:
  1. Verifies quota_token signature.
  2. Checks not previously redeemed (replay defense via short-TTL cache).
  3. Decrements quota_remaining (in the credential, not on identity service).
  4. Issues a fresh credential with quota_remaining - 1.
  5. Processes the request.
  6. Returns response + new quota_token.

Identity service is never contacted at gateway request time. The credentials
carry their state.
```

This is a Privacy-Pass-flavored construction (RFC 9576/9578). The gateway doesn't know which user made the request; the credential proves "this account has quota."

### Settlement

Periodically (daily), the gateway reports to the identity service the total redemptions:

```
{
  "feature": "translate",
  "credentials_redeemed": 17_421,
  "window_start": ...,
  "window_end": ...
}
```

Identity service updates aggregate statistics (no per-user attribution from this report). User-facing quota_remaining was already decremented at issuance time (we issued tokens with the user's max allowance and they get redeemed up to that count).

## Abuse defense

A user (or attacker) might try to exfiltrate content via repeated cloud queries. Mitigations:

- Per-token rate limit (above).
- Per-token total quota cap.
- Velix's contract with providers: "no training on user data" — providers are not allowed to use queries for model improvement.
- Per-feature output length caps (defeats output amplification).
- Provider-level abuse detection (independently operated).

The architectural property — gateway cannot identify users — means we cannot ban specific users from cloud AI. We can only ban specific tokens. A user with a banned token can refresh; if they're abusive, their account-level quota will exhaust eventually.

## Per-Space quota for moderation

Space-owners enabling moderation use the on-device classifier. There is no per-Space cloud quota for moderation because moderation never goes to cloud.

## Quota states in UX

When approaching quota limits, the UI shows a discreet state:

| State | UX |
|---|---|
| Quota healthy (≥ 25%) | No indication |
| Quota approaching (5-25%) | Subtle "X cloud queries remaining" in Settings → AI |
| Quota near zero (< 5%) | Inline before each cloud invocation: "X queries remaining this month" |
| Quota zero | Cloud features greyed out; "Plan resets on $date" |

We never auto-purchase. We never auto-upgrade. The user explicitly buys a plan if they want more.

## Banned

- Quotas tied to identity at the gateway level (the gateway enforces via tokens, not user IDs).
- Free unlimited tier (creates abuse incentive).
- Reset logic that requires re-auth (the user shouldn't have to sign in to refresh their quota).
- Carry-over of unused quota beyond a 1-month window (defeats abuse detection).
- Bypass paths for "VIP users" or beta testers.
- Custom quota assignments per user (we use tier-based; case-by-case is unauditable).
