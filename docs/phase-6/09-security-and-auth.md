# 09 — Security & Auth

The Phase 1 doc 07 set the threat model and protocol family. Phase 6 implements the boundary mechanics: how requests are authenticated at the edge, how services trust each other, how secrets flow, how rate limits work.

## External auth (client → server)

Velix uses **OAuth 2.0 + OIDC-style** bearer tokens issued by `identity` after a successful sign-in or pairing.

### Token shape

Tokens are JWTs (Ed25519-signed by identity's rotating signing key). Compact serialization, 1.5–2 KB on the wire.

```json
{
  "iss": "iden.velix.app",
  "sub": "<account_id>",
  "did": "<device_id>",
  "aud": "<service-name>",
  "exp": 1735689600,
  "iat": 1735688700,
  "jti": "<random-32-byte-hex>",
  "scope": "client",
  "v":   1
}
```

- 15-minute lifetime.
- Refresh via long-lived (30 day) refresh token, also issued by identity.
- `jti` allowlisted in Redis (`iden:session:<jti>`) until expiry; revocation is `DEL`.
- `aud` is the audience service. A token issued for `routing` is rejected by `media`.

### Refresh

Clients refresh at the 12-minute mark. Refresh tokens:
- Rotate on every refresh (one-time use).
- Bound to `device_id`. A refresh from a different device returns an error and logs a security event.
- Revocable per-device.

### Sign-in flow (Phase 7 cryptographic detail; Phase 6 gateway)

```
client                                  identity service
  |                                          |
  |-- CreateAccount(public_key, sig) ------->|
  |                                          |  verifies signature
  |                                          |  inserts accounts
  |                                          |  issues access + refresh
  |<-- AccessToken, RefreshToken ------------|
  |                                          |
```

The handshake is Phase 7's cryptographic concern (X3DH bundle exchange, multi-device pairing). Phase 6 owns the *transport* and the *token lifecycle*.

### Token verification (every request)

Every gRPC request through the edge passes through an auth interceptor:

```
1. Extract Authorization: Bearer <token>.
2. Verify signature using identity's published public key (cached in-process; rotates every 24h).
3. Check exp, iat, aud, iss.
4. Check jti against Redis allowlist.
5. Inject AccountID, DeviceID into request context.
6. Pass to handler.
```

Failures return `UNAUTHENTICATED` with reason code in ErrorInfo.

## Internal auth (service → service)

Two layers:

1. **mTLS** — every internal connection uses mutual TLS with per-service certificates issued by an internal CA. Certs rotate every 24h. cert-manager + a private intermediate CA in Vault.
2. **Service token** — a short-lived JWT scoped to `service`. Issued by `identity` to pre-authorized internal callers. Verifies on the receiving side via a separate Ed25519 keypair.

A service that wants to call another:
- Uses its mTLS-presented cert as the first layer of trust.
- Adds `X-Service-Token: <jwt>` for an additional logical scope ("this `routing` pod is allowed to call `push.RequestPush`").

The double-check protects against a compromised internal cert allowing arbitrary cross-service calls.

## Token signing keys

| Purpose | Algorithm | Rotation |
|---|---|---|
| Client access tokens (JWT) | Ed25519 | 30 days; previous key valid for 15 days after rotation |
| Internal service tokens (JWT) | Ed25519 (separate keypair) | 24 hours |
| Push routing tokens (HMAC) | HMAC-SHA-256, per device | rotated on each push |
| Refresh token storage | argon2id-derived from the random refresh; HMAC stored | n/a |

Keys live in Vault. Each service fetches its public-key set on startup and refreshes hourly.

## Postgres auth

- Per-service Postgres role with the minimum grants required.
- All connections TLS-only with `sslmode=verify-full`.
- Passwords are SCRAM-SHA-256.
- Credentials in Vault, not env files.

## Redis auth

- Per-service Redis user via ACL.
- Each service can only access its own DB number and key prefix.
- Velix's Redis ACLs are managed via terraform.

## Vault

- Each service has a Vault policy. The Kubernetes Vault auth method maps the pod's service account to its policy.
- Vault issues short-lived (1h) Postgres credentials per service via the database secrets engine.
- Vault issues short-lived (1h) Redis credentials similarly.
- Vault issues x509 certs for mTLS via the PKI engine.

## Rate limiting

Two layers:

### Edge layer (envoy)

- Per-IP global rate limit: 100 req/s steady, 500 burst.
- Per-IP per-route rate limit on auth endpoints: 5 req/s on `identity.SignIn`, 1 req/s on `identity.CreateAccount`.

### Service layer (identity-issued auth context)

Per-account per-route limits, applied in each service's auth interceptor via Redis sliding windows.

| Route | Limit |
|---|---|
| `identity.SignIn` | 5 req / 60 s per IP |
| `identity.CreateAccount` | 1 req / 60 s per IP |
| `identity.RefreshToken` | 30 req / 60 s per account |
| `routing.SendEnvelope` | 60 req / 60 s per account |
| `media.IssueUploadUrl` | 30 req / 60 s per account |
| `push.RegisterToken` | 5 req / 60 s per device |
| (default for unspecified routes) | 600 req / 60 s per account |

A 429 returns `RESOURCE_EXHAUSTED` with `Retry-After` header.

## Input validation

Every gRPC handler runs validation before any business logic:

- String length bounds.
- UTF-8 validity (no embedded nulls, no surrogate halves).
- ULID format check on id fields.
- Whitelist regex on handle / locale fields.
- Bytes fields: explicit length checks (e.g., ciphertext ≤ 64 KB).
- No SQL string concat — sqlc parameterized queries.

Validation runs in `validate_request.go` per service. Returns `INVALID_ARGUMENT` with the specific field that failed.

## CORS

Web client uses Connect (gRPC-HTTP). CORS is allow-listed for `https://app.velix.app` and `https://staging.velix.app`. All other origins blocked.

## CSRF

Not applicable — bearer-token auth (no cookies). The web client stores tokens in memory only; the service worker handles refresh.

## Secrets in transit

- Every external connection: TLS 1.3, HSTS preloaded.
- Every internal connection: mTLS.
- No "internal HTTP".
- No "trusted network" assumptions — even within the VPC, mTLS is required.

## Audit logging

Security-relevant events emit a NATS event on `velix.audit.<event>`:

- Sign-in success / failure
- Token refresh
- Device add / revoke
- Account suspension / deletion
- Rate-limit triggered (high-volume only — sampled)
- Internal service-token misuse (audit + alert)

These flow to `notifier` and are stored in `notification_log` for the audit window. Beyond the window, they're archived in S3.

## Threat-class mitigations

| Threat | Mitigation |
|---|---|
| Compromised single-region credential | Per-region tokens; cert rotation 24h; Vault short-lived creds |
| Replay attack on token | jti allowlist with TTL = exp |
| Session theft | Refresh token rotation on every refresh |
| Privilege escalation via service token | Audience-bound tokens; mTLS-required transport |
| Brute force on sign-in | Per-IP rate limit (5/min); account lockout after 10 failed attempts in 15 minutes |
| Malicious upload (large file DoS) | Size limit + signed presigned URL with expiry |
| Denial via slowloris | envoy connection idle timeout 30 s |
| Slow client streaming the gRPC stream open | Per-stream activity timeout 35 s |

## What's NOT in the security model

- DDoS at the network layer — that's the cloud provider's job (CloudFront / Cloudflare).
- Endpoint compromise — Phase 7 handles cryptographic mitigations; we cannot prevent a rooted device from leaking its own data.
- Government legal demands — see Phase 1 doc 07; we publish a transparency report.

## Banned

- Long-lived API keys for any service-to-service call.
- Bearer tokens stored in localStorage in the web client.
- Private keys in environment variables.
- Logging of token contents at any level.
- Logging of plaintext bodies anywhere.
- Authorization checks done in a DB trigger or stored procedure.
- "Internal endpoints unauthenticated by convention." Every endpoint requires authentication.
- A debug bypass that's "off in production" — there is no such bypass.
