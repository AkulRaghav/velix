# Velix Alpha Server

Self-contained, single-binary HTTP/JSON server backing the Alpha build.

**Scope**: registration, login, send message, fetch messages, list conversations.
**Storage**: in-memory + JSON snapshot to disk on graceful shutdown.
**Crypto**: server verifies Ed25519 attestation signatures from clients. Server stores message bodies as opaque base64 blobs (it never decodes them).

This module deliberately depends only on the Go standard library so it
compiles offline. Phase 6's gRPC + pgx + NATS wiring lands later.

## Run

```
go run ./cmd/alpha-server
```

Server listens on `:8080`. Override via `VELIX_ADDR=:9000`.

State is loaded from / saved to `velix-alpha-state.json` in the working
directory (override via `VELIX_STATE_PATH`).

## API

| Method | Path | Body | Auth | Purpose |
|---|---|---|---|---|
| POST | `/v1/register` | `{handle, identity_pubkey_b64}` | none | Create account; returns account id + token |
| POST | `/v1/login` | `{account_id, signature_b64, challenge_b64}` | challenge fetched first | Refresh token |
| GET | `/v1/challenge?account_id=X` | — | none | Issue a challenge for login |
| GET | `/v1/me` | — | bearer | Current account |
| GET | `/v1/users/lookup?handle=X` | — | bearer | Find a user by handle |
| GET | `/v1/conversations` | — | bearer | List conversations |
| POST | `/v1/conversations` | `{peer_account_id, title}` | bearer | Open or fetch a 1:1 conversation |
| GET | `/v1/conversations/{id}/messages` | — | bearer | List messages |
| POST | `/v1/conversations/{id}/messages` | `{ciphertext_b64, kind}` | bearer | Append a message |
| GET | `/v1/healthz` | — | none | Liveness |
| GET | `/v1/readyz` | — | none | Readiness |
