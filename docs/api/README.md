# API Documentation

Velix's API is gRPC. Source-of-truth contracts live in `backend/proto/`.
This index maps services to their proto, contract semantics, rate limits,
and auth posture.

## Services

| Service | Proto | Auth posture | Rate limits | Migrations |
|---|---|---|---|---|
| Identity | [identity.proto](../../backend/proto/velix/identity/v1/identity.proto) | NONE for create/sign-in (signature-verified), CLIENT otherwise | 10/60s create, 30/60s sign-in | [001_init.sql](../../backend/services/identity/migrations/001_init.sql) |
| Routing | [routing.proto](../../backend/proto/velix/routing/v1/routing.proto) | CLIENT for all | 60/60s send, 240/60s typing | [001_init.sql](../../backend/services/routing/migrations/001_init.sql) |
| Media | [media.proto](../../backend/proto/velix/media/v1/media.proto) | CLIENT for all | 30/60s upload, 240/60s download | [001_init.sql](../../backend/services/media/migrations/001_init.sql) |
| Push | [push.proto](../../backend/proto/velix/push/v1/push.proto) | CLIENT for all | 60/60s register | [001_init.sql](../../backend/services/push/migrations/001_init.sql) |
| Call | [call.proto](../../backend/proto/velix/call/v1/call.proto) | CLIENT for all | 30/60s create | [001_init.sql](../../backend/services/call/migrations/001_init.sql) |
| Notifier | [notifier.proto](../../backend/proto/velix/notifier/v1/notifier.proto) | INTERNAL only (mTLS, SPIFFE) | n/a (internal) | [001_init.sql](../../backend/services/notifier/migrations/001_init.sql) |
| AI Gateway | [ai.proto](../../backend/proto/velix/ai/v1/ai.proto) | Anonymous credential (Privacy Pass) | per-credential quota | n/a (cache only) |

## Events (NATS JetStream)

Past-tense events emitted by services. See [events.proto](../../backend/proto/velix/events/v1/events.proto).

## Common conventions

- **Idempotency.** Every mutation accepts an `idempotency_key`. Server caches the response for 24 hours.
- **IDs.** All IDs are ULIDs (canonical Crockford base32 form), exposed as `string` in protos.
- **Timestamps.** All timestamps are `google.protobuf.Timestamp` (UTC).
- **Sizes.** Ciphertexts ≤ 64 KB per envelope; media ≤ 100 MB; push payloads ≤ 4 KB.
- **Sealed sender.** No proto field carries `sender_account_id`. The sender is inside the ciphertext, decrypted only by the recipient.
- **Logging.** No service logs body, content, prompt, query, plaintext, message, ciphertext, secret, token, password, or private_key fields. Enforced by the velixobs filter.

## Versioning

- Proto evolution is gated by buf-breaking in CI.
- Field numbers never reused; deprecated fields kept for a full release cycle before removal.
- Service version embedded in the gRPC `service` segment (`velix.routing.v1.RoutingService`).
- Wire-incompatible changes ship as `v2` services side-by-side with `v1`.

## Generated client code

Dart binding is generated at build time into:
`packages/velix_data/lib/src/genproto/`

Go binding is generated into:
`backend/services/<svc>/internal/genproto/`

Generation is via `buf.gen.yaml` in `backend/`; CI runs `buf generate` and
verifies no unchecked diffs.
