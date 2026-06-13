# 02 — API Contracts

`.proto` files are the source of truth. The Flutter client (Phase 5) consumes them through generated Dart; backend services through generated Go.

## Versioning

Every package is versioned: `velix.identity.v1`, `velix.routing.v1`, etc. We bump versions only on breaking changes (the buf-breaking lint enforces). New optional fields are additive within a version; new RPCs are additive.

A v2 of any package coexists with v1 for at least a 6-month deprecation window.

## Naming

- Services: `IdentityService`, `RoutingService` — exact case, no `Velix` prefix (the package handles namespacing).
- RPCs: verb-noun, no `Get` for queries that return streams, `List` for collection queries.
- Messages: nouns. Request/response messages suffixed `Request` / `Response`.
- Events (NATS payloads): past tense, `<Noun><Verbed>Event` (e.g., `AccountCreatedEvent`).
- Field names: `snake_case` in proto, idiomatic case in generated Go / Dart.

## Error model

We do not invent errors. Every gRPC error returns one of:

| Status | When |
|---|---|
| `OK` | success |
| `INVALID_ARGUMENT` | client sent a malformed request |
| `UNAUTHENTICATED` | missing / invalid auth token |
| `PERMISSION_DENIED` | authenticated but not authorized |
| `NOT_FOUND` | the requested entity does not exist |
| `ALREADY_EXISTS` | duplicate creation attempted |
| `FAILED_PRECONDITION` | client must reconcile state first |
| `RESOURCE_EXHAUSTED` | rate-limited |
| `UNAVAILABLE` | dependent system temporarily down; client should retry |
| `INTERNAL` | a real bug — high-priority alert |

Every error response carries a `google.rpc.ErrorInfo` detail with:
- `reason`: a short stable code (e.g., `IDENTITY_HANDLE_TAKEN`)
- `domain`: `velix.identity.v1`
- `metadata`: request-specific fields (never PII)

The Flutter client's `AppError` taxonomy maps deterministically from the `(status, reason)` pair (see `02-pattern-implementations.md` of Phase 5 for the mapping table).

## Authentication

Every RPC declares its auth posture in the proto via a method-level option (`velix.options.v1.auth`):

```proto
service IdentityService {
  // Public — no auth required.
  rpc CreateAccount(CreateAccountRequest) returns (CreateAccountResponse) {
    option (velix.options.v1.auth) = AUTH_NONE;
  }

  // Requires a valid client token.
  rpc UpdateProfile(UpdateProfileRequest) returns (UpdateProfileResponse) {
    option (velix.options.v1.auth) = AUTH_CLIENT;
  }

  // Requires a valid internal service token (mTLS-only path).
  rpc PublishKeyMaterial(PublishKeyMaterialRequest) returns (PublishKeyMaterialResponse) {
    option (velix.options.v1.auth) = AUTH_SERVICE;
  }
}
```

The auth interceptor reads the option and rejects unauthenticated requests at the boundary.

## Idempotency

Every mutating RPC accepts an `idempotency_key` (UUIDv7). The server stores `(account_id, key)` for 24h and returns the cached response if the same key is replayed. This is what allows the client's offline sync queue to retry safely.

```proto
message SendMessageRequest {
  string idempotency_key = 1; // UUIDv7
  string conversation_id = 2;
  bytes  ciphertext      = 3;
  // ...
}
```

Idempotency keys are scoped per account; the server table is a `(account_id, key)` UNIQUE index with a TTL'd cleanup.

## Pagination

`List*` RPCs use cursor-based pagination, never offset:

```proto
message ListMessagesRequest {
  string conversation_id = 1;
  int32  page_size       = 2;  // 1..100, default 20
  string page_token      = 3;  // opaque, server-issued
}

message ListMessagesResponse {
  repeated Message messages = 1;
  string next_page_token    = 2;
}
```

Cursors are signed (HMAC over the cursor body) so clients can't forge cursor positions to skip ACL checks.

## Streaming RPCs

Used for:
- `routing.RoutingService.Subscribe` — server-stream of envelopes for the connected device
- `routing.RoutingService.Presence` — bidirectional stream for typing/online updates
- `call.CallService.SignalChannel` — bidirectional for in-call signaling (replaces a separate WebSocket)

Streaming RPCs MUST send a heartbeat (empty ping) every 25 seconds. The client closes connections that go silent for 35 seconds.

## Wire size limits

- Max request size: 4 MB (gRPC default)
- Max response size: 4 MB
- Larger payloads (media): clients use presigned R2 URLs from `media.MediaService.IssueUploadUrl`.

## Backward / forward compatibility

- New fields are always added with new tag numbers; old tags are never reused after a field is deprecated.
- Removed fields are renamed `reserved` and the tag added to `reserved tags`.
- Enums never have a value removed; old values stay forever, new requests use new values.
- A v1 service NEVER reads a field defined in v2.

`buf breaking` enforces all of the above on every PR.

## Per-service contract files (1.0 surface)

The .proto contracts shipped at Phase 6 are listed in `proto/SCHEMA.md` and live in `proto/velix/<service>/v1/*.proto`. Each service ships:

| Service | RPCs (1.0) |
|---|---|
| identity | CreateAccount, SignIn, RefreshToken, RevokeSession, AddDevice, ListDevices, RevokeDevice, PublishPrekeys, FetchPrekeyBundle, UpdateProfile |
| routing | SendEnvelope, Subscribe (server-stream), Presence (bidi), MarkAsRead, ReportTyping |
| media | IssueUploadUrl, IssueDownloadUrl, GetMetadata, RequestDeletion |
| push | RegisterToken, UnregisterToken, RequestPush (internal-only) |
| call | StartSession, JoinSession, LeaveSession, SignalChannel (bidi), GetSessionInfo |
| notifier | LogEvent (internal-only) |

The exact `.proto` files live in `backend/proto/velix/<service>/v1/`. Each carries its own header doc-comment with the auth matrix and rate-limit defaults.

## Generated code locations

```
buf.gen.yaml emits:
  Go    → backend/services/<svc>/internal/genproto/
  Dart  → packages/velix_data/lib/src/genproto/      (Phase 6 follow-up)
```

Generated code is committed to source control (we don't run codegen at deploy time). Re-running `buf generate` is reproducible.

## Banned

- Stringly-typed errors. Use `google.rpc.ErrorInfo`.
- Shared `Velix` prefix in service names (the package namespaces).
- `Get` RPCs that mutate state.
- Streaming RPCs without a heartbeat.
- Pagination by integer offset.
- Adding a field with the same tag as a deprecated one.
- Returning `INTERNAL` for client errors (use `INVALID_ARGUMENT` or similar).
- A single `.proto` file holding multiple services.
- Mixing event payloads (NATS) into the gRPC `.proto` files for services. Event payloads live in `proto/velix/events/v1/`.
