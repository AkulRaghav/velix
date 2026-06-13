# 05 — Cloud Relay (OHTTP)

The cloud-AI traffic flows through an OHTTP-style relay so that no single party sees both the user's identity and the user's content. This is the architectural mechanism that keeps the AI gateway at trust level 4.

## Problem

A naive cloud AI integration:

```
client (with bearer token) ──HTTPS──▶ Velix gateway ──▶ provider
```

This binds (account_id, query content) at the gateway. Even with a no-logging policy, the gateway is technically capable of correlating. We want to architecturally prevent it.

## OHTTP shape

OHTTP (RFC 9458, Oblivious HTTP) splits the request between two parties:

- **Relay:** sees the user's IP and an encrypted blob; cannot read content.
- **Gateway:** sees the content but not the user's IP, no auth bearer, no session metadata.

```
client                                         relay                           gateway                provider
──────                                         ─────                           ───────                ────────
encrypts request to gateway's HPKE pub
   │
   ──── encrypted blob over HTTPS ────────────▶
                                                   │
                                                   ─── encrypted blob over HTTPS ──▶
                                                                                       │
                                                                                       decrypts
                                                                                       processes
                                                                                       ──────▶ to provider
                                                                                       ◀───── from provider
                                                                                       encrypts response
                                                   ◀── encrypted response ──────
   ◀──────────────────────────────────────────────
decrypts response
```

The relay sees IP + opaque ciphertext. The gateway sees content + (relay's IP, not the user's). Neither can correlate.

## Concretely

### Configuration

- **Relay operator:** Cloudflare Privacy Pass (or Fastly equivalent) — an independent operator with a published OHTTP endpoint and a contractual agreement.
- **Gateway HPKE keys:** rotate every 24 hours, published at `https://ai.velix.app/.well-known/ohttp-keys`.
- **Cipher suite:** `DHKEM(X25519, HKDF-SHA256), HKDF-SHA256, ChaCha20Poly1305` per OHTTP defaults.

### Per-request flow

```
1. Client fetches the gateway's current HPKE public key.
   (Cached for ≤ 1 hour; refreshes in background.)

2. Client constructs the inner HTTP request:
   POST /v1/translate HTTP/1.1
   Content-Type: application/json
   Velix-Consent: <consent_token>
   Velix-Quota: <quota_token>
   Body: { "text": "...", "source_lang": "fr", "target_lang": "en" }

3. Client encrypts to the gateway's HPKE pubkey:
   ohttp_blob = HPKE.seal(gateway_pub, info="velix.ai.ohttp.v1", aad=null,
                          plaintext=serialized inner request)

4. Client POSTs ohttp_blob to the relay:
   POST https://ohttp-relay.example.com/relay
   Content-Type: message/ohttp-req
   Body: ohttp_blob

5. Relay forwards to https://ai.velix.app/ohttp-handler with the same body.

6. Gateway decrypts; routes inner request to /v1/translate.

7. Inner handler processes; produces response.

8. Gateway HPKE-seals the response back; returns to relay; relay returns to client.
```

### What each party sees

**Client:** everything.

**Relay:**
- User's IP
- An opaque encrypted POST body
- A response-shaped opaque encrypted body
- Cannot decrypt either

**Gateway:**
- The relay's IP (not the user's)
- The decrypted request including the consent token, quota token, and content
- Cannot link any of this to a user identity

**Provider:**
- Whatever content the gateway forwards
- The gateway's IP

## Identity decoupling

Specifically, the gateway does NOT receive:
- Any session bearer token from Velix's main auth path.
- The user's account_id.
- The user's device_id.
- Any TLS pinning info beyond standard HTTPS.

The gateway therefore cannot attribute any request to any user. Even with full collusion between Velix-the-company and the gateway operator (the same company), there is no link to identity unless the consent_token is used to derive identity — which it cannot be (HMAC over a per-device seed; no public mapping to account_id).

## Quota enforcement without identity

The user's account has a per-month quota for cloud AI invocations (Phase 8 doc 13). The quota is enforced at the *client*: the client refuses to invoke beyond its quota. The quota is also tracked at the gateway via the **anonymous quota token**.

Anonymous quota token construction:

```
At session start (post-sign-in), client requests a fresh quota token from
identity service:

  POST /identity.IssueAIQuotaToken
  body: { device_id }
  response: {
    quota_token,
    expires_at,
    quota_remaining
  }

quota_token is a Privacy Pass-style anonymous credential:
  - Signed by identity service.
  - Carries the quota_remaining as a private attribute.
  - Cannot be linked to the issuing session (blinded signature).

When client invokes cloud AI, it includes the quota token. Gateway:
  - Verifies signature.
  - Checks quota_remaining > 0.
  - Decrements via a one-shot redeem (token is single-use).
  - Issues a new quota_token with quota_remaining - 1 in the response.
```

This is Privacy Pass / VOPRF-style anonymous metering. The gateway can enforce "this user has used 3 of 100 monthly credits" without knowing which user.

For Phase 8.5 implementation, we use Cloudflare's Privacy Pass library or roll-our-own based on RFC 9576/9578 specs.

## Threat model for the relay

- **Relay compromised:** sees IPs and encrypted blobs. Cannot decrypt. We assume this is the relay's *steady state* (we don't trust the relay).
- **Relay collusion with gateway:** would compromise IP-content unlinkability. The relay agreement contractually forbids this; we choose a relay operator without commercial incentive to collude.
- **Gateway compromised:** sees content. Cannot link to identity (cannot identify the user). Plaintext-only-during-session retention (≤ 30 s response window).
- **Both compromised:** content + IP linkable. Mitigation: contractual posture + multi-party operational separation.

This is the same threat model OHTTP was designed for; we adopt it as-is.

## What this does not protect against

- A user with a unique writing style: their queries are individually identifiable. We do not promise resistance to stylometry-based identification.
- A user who pastes their own name into a query: the consent UX shows the redacted preview; the user sees what's going. If they choose to include their name, that's their choice.
- A determined active attacker who controls both the relay and the gateway: not in scope; documented in Phase 7 doc 01 N1.

## Performance

- HPKE key fetch: ≤ 200 ms cold; cached for 1h.
- HPKE seal/open: ≤ 1 ms each (ChaCha20 is fast).
- OHTTP relay roundtrip overhead: ≤ 80 ms (one extra HTTPS hop).
- Total user-visible latency vs direct: ≈ 80 ms additional.

For interactive AI features (assistant, translation), 80 ms is negligible compared to the model's inference time (500–3000 ms). Acceptable.

## Failure modes

| Failure | Behavior |
|---|---|
| Relay unavailable | Client tries the secondary relay if configured; if both fail, "AI temporarily unavailable" — never fallback to direct gateway. |
| Gateway HPKE key fetch fails | Cannot construct the request; fail closed. |
| Consent token expired | Re-prompt user. |
| Quota token rejected | Display quota state UX. |
| Provider error | Generic "Try again." Never expose provider details. |

## Banned

- Falling back to a direct (non-OHTTP) request when the relay is down.
- Caching the OHTTP encrypted blob for retry — re-encrypt with a fresh HPKE seal per attempt.
- Logging the relay's IP at the gateway (the relay's IP is not user-identifying, but logging it is a step toward correlation if multiple users share a relay).
- Tying the consent token to the account_id (it must be device-local and HMAC-derived from a non-published seed).
- Having a "developer mode" that bypasses the relay.
- Operating the relay ourselves (must be an independent operator).

## Banned for the gateway

- Logging request body content.
- Logging response body content.
- Persisting any per-query record beyond the response window.
- Storing query metadata in a way that allows reconstructing user behavior.
- Sending request headers besides the necessary HPKE-decrypted-from-the-blob ones.

## Operational

- Relay operator: contracted in Phase 8.5.
- Gateway HPKE key rotation: managed via Vault + automatic deployment.
- Quota token signing key: rotated weekly; compromised key triggers immediate rotation.
- Per-quarter audit of relay traffic: aggregate volumes, no per-request inspection.

## What gets published publicly

- Gateway HPKE public keys (via `.well-known/ohttp-keys`).
- Quota token signing public key.
- Relay operator name and contractual posture.
- The fact that we run OHTTP for AI traffic (in the security paper).

We publish the architecture so users (and security researchers) can verify the design. The contracts with the relay operator are publishable; we will publish them.
