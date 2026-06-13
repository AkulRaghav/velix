# 06 — Secrets

Vault as the single secret store. Short-lived per-service credentials. Per-service policies. Audit-logged.

## Vault topology

- One Vault instance per environment (dev / staging / prod). Different unseal keys per instance.
- HA mode in production: 3 replicas behind a Kubernetes Service.
- Backed by Consul or integrated storage (Raft).
- Auto-unseal via cloud KMS (AWS KMS or GCP KMS).
- Audit-logged to a write-only S3 bucket; logs retained 1 year.

## What's in Vault

| Secret class | Examples | TTL | Engine |
|---|---|---|---|
| Database creds | per-service Postgres roles | 1 hour | dynamic database secrets |
| Redis creds | per-service ACL users | 1 hour | dynamic Redis secrets |
| Service tokens (internal mTLS) | client certs | 24 hours | PKI |
| External provider keys | Anthropic API key, OpenAI API key, APNs cert, FCM token | 30 days | KV v2 |
| LiveKit API secrets | per-cluster API key + secret | 30 days | KV v2 |
| TLS certs (public) | velix.app, api.velix.app, etc. | 90 days (Let's Encrypt) | KV v2 |
| Code-signing keys (model signing, API token signing) | Ed25519 keys | annual rotation | transit |
| App Store / Play Store provisioning | iOS provisioning profile, Android keystore | annual | KV v2 |

We do not store:
- User identity private keys (those are in Phase 7's user-side OS keychain).
- User session tokens (those are short-lived JWTs, not Vault).
- LiveKit JWTs (they're signed at the call service via Vault-held API secret).

## Per-service policies

Every service has a Vault policy that grants the minimum it needs:

```hcl
# vault-policy/identity.hcl
path "database/creds/identity" {
  capabilities = ["read"]
}
path "secret/data/identity/external/*" {
  capabilities = ["read"]
}
path "pki/issue/internal-service" {
  capabilities = ["create", "update"]
}
path "transit/sign/identity-token-signer" {
  capabilities = ["update"]
}
```

A service compromise leaks only what its policy allows. The identity service cannot read media's secrets; the routing service cannot sign identity tokens.

## Kubernetes auth integration

Each pod authenticates to Vault via Kubernetes service account tokens (Vault's Kubernetes auth method):

```
1. Pod starts with a mounted ServiceAccount token.
2. Pod calls Vault: POST /v1/auth/kubernetes/login with the token.
3. Vault verifies via TokenReview API.
4. Vault returns a Vault token bound to the policy for the SA.
5. Pod uses that Vault token to fetch secrets.
6. Vault token TTL: 24 hours; renewed automatically.
```

The Kubernetes service accounts → Vault policies mapping is in Vault config; reviewed quarterly.

## Dynamic database secrets

For Postgres:

```hcl
# Vault config
database "postgres-velix-routing" {
  plugin_name = "postgresql-database-plugin"
  connection_url = "postgresql://vault_admin:<password>@host:5432/velix_routing"
  allowed_roles = ["routing"]
}

role "routing" {
  db_name = "postgres-velix-routing"
  default_ttl = "1h"
  max_ttl = "24h"
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT routing_role TO \"{{name}}\";"
  ]
}
```

When the routing service starts:

```
GET /v1/database/creds/routing
→ {
    username: "v-routing-XYZ",
    password: "<random>",
    lease_id: "...",
    lease_duration: 3600
  }
```

The service uses these creds. They expire in 1 hour. The service requests a fresh set every 30 minutes.

If the service is compromised, the leaked creds are valid for at most 1 hour. After rotation, they're useless.

## mTLS issuance

Every internal service-to-service connection uses mTLS. Certs are issued by Vault's PKI engine.

```
PKI Root CA          (offline, in cold storage)
  │
  ├── PKI Intermediate CA (Vault-held, online)
  │     │
  │     └── per-service certs (24-hour TTL)
```

cert-manager runs in each cluster, requests certs from Vault PKI, stores in Kubernetes secrets, mounts into pods.

Service-to-service traffic uses these certs for mTLS.

## App / external provider secrets

| Secret | Where used | Rotation |
|---|---|---|
| APNs auth key (iOS push) | push service | annual; track expiry |
| FCM service account JSON (Android push) | push service | annual |
| LiveKit API key/secret per cluster | call service | 30-day |
| Anthropic API key | ai_gateway | quarterly |
| OpenAI API key | ai_gateway | quarterly |
| Cloudflare R2 access key | media service | 90-day |
| AWS RDS master credentials | terraform-only; not used at runtime | annual |
| Sentry DSN | every service | annual |

## App-side secrets

Velix's Flutter client does not have any "API secret" baked into it. Specifically:

- No API key for any AI provider.
- No API key for Cloudflare R2.
- No client-shared secret for the routing service.
- No code-signing private key.

The only thing in the client is:
- The Velix model signing public key (for verifying lazy-downloaded AI models).
- The Velix gateway HPKE public key (for OHTTP, Phase 8 doc 05).
- The identity service public key (for verifying token signatures).
- The TLS pin set (for certificate pinning).

These are all public material. Their compromise is not a secret leak; it would require attacking the binary's signature.

## Secret distribution to pods

Vault secrets injected via:
- **Vault Agent sidecar** for high-frequency-rotation secrets (database creds).
- **External Secrets Operator** for less-frequent secrets (provider API keys).

Both write secrets to in-memory `tmpfs` mounts; never to disk.

A pod that fails to authenticate to Vault refuses to start. There's no fallback to env-var-based secrets.

## Rotation

| Secret | Cadence | Trigger |
|---|---|---|
| Database creds | 1 hour | automatic via Vault TTL |
| mTLS certs | 24 hours | automatic via cert-manager |
| Token signing keys | 30 days | scheduled, manual review |
| App Store / Play Store keys | annual | calendar reminder + 30-day warning |
| AI provider keys | quarterly | calendar reminder |
| LiveKit API keys | 30 days | manual rotation |
| Velix model signing key | annual | manual rotation; clients ship with rotated public key |
| Vault unseal keys | never (cold-stored) | only on disaster recovery |

## Audit trail

Every Vault read/write is logged:

```
{
  "ts": "...",
  "method": "GET",
  "path": "/v1/database/creds/routing",
  "client_token_accessor": "hashed_token_id",
  "auth_method": "kubernetes",
  "service_account": "system:serviceaccount:velix:routing",
  "result": "success",
  "request_id": "..."
}
```

Audit logs ship to a write-only S3 bucket; retained 1 year. Logs are PII-free by Vault construction.

## Break-glass access

For incident response, an engineer can request break-glass production Vault access:

```
1. Engineer pages on-call rotation; declares incident.
2. Manager approves break-glass via PagerDuty workflow.
3. Vault issues a 4-hour token with elevated read-only capabilities.
4. Token usage logs to a special audit trail.
5. Token expires; access ends.
6. Postmortem documents what was accessed.
```

Break-glass tokens cannot:
- Modify secrets.
- Issue new database creds.
- Rotate keys.
- Access user-content-related secrets (cryptocore signing).

## What break-glass cannot do

Even break-glass cannot decrypt user content. There is no path to user content via Vault. Phase 7's cryptographic architecture means the keys to user content do not exist in Vault.

## Incident: secret leakage

If a secret is suspected compromised:

```
1. Page on-call.
2. Identify the secret class.
3. Trigger rotation (most secrets rotate automatically; force-rotate for the rest).
4. Audit usage for the suspect window.
5. If user-impacting (e.g., AI provider key with billing exposure):
   - rotate the upstream key.
   - update Vault.
   - all services pick up the new key on next refresh.
6. Postmortem.
```

Mean time to rotation for the most-frequently-rotated secrets (DB creds): 1 hour automatic. For provider keys: 1 day manual.

## What we do NOT do

- Store secrets in `git`. (banned)
- Store secrets in environment variables checked into source. (banned)
- Pass secrets via command-line arguments. (banned; visible to other processes)
- Share secrets via chat. (banned)
- Email secrets. (banned)
- Use long-lived shared API tokens for service-to-service auth. (banned; mTLS instead)
- Rotate secrets less frequently than the policy. (caught by automation)

## Banned at the operational level

- "Just-this-once" hand-issued secrets.
- Engineer-machine-stored secrets that touch production.
- Per-engineer access to production Vault data.
- Vault tokens with TTL > 24 hours.
- Sharing Vault tokens via Slack.
- Skipping audit log for any path.
