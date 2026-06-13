# 07 — LiveKit Integration

LiveKit handles voice and video. We self-host it (one cluster per region, autoscaling). The `call` service is a thin Velix-side broker that issues JWTs, tracks call lifecycle, and publishes call events to NATS.

## Why LiveKit

- Open source, self-hostable; no per-minute SaaS bill.
- Insertable Streams support for E2EE on small calls (≤ 8 participants).
- Production-proven at scale (Discord, Atlassian, others).
- Native iOS and Android SDKs that integrate with Flutter via the official LiveKit Flutter package.

## Trust modes

| Mode | Participants | What the SFU sees |
|---|---|---|
| `e2ee` | ≤ 8 | Encrypted frames it cannot decrypt |
| `sfu_trust` | 9–50 | Plaintext frames (the SFU is in the TCB) |

The client UI is explicit about the mode. A user joining a 12-person call sees a "12 people · server-aided" indicator. We do not silently downgrade.

## Velix `call` service

Responsibilities:

1. Authenticate the caller (existing OIDC flow).
2. Decide which mode (`e2ee` if `participants ≤ 8`, `sfu_trust` otherwise).
3. Pick a LiveKit cluster (region-affinity to caller's home cell).
4. Issue a LiveKit JWT scoped to one room with appropriate grants.
5. Persist `call_session` and `call_participant` rows.
6. Publish `velix.call.started`, `velix.call.participant-joined`, etc.

The call service does NOT proxy media. Media flows directly from clients to LiveKit; Velix sees only call metadata.

## RPC surface

```proto
service CallService {
  // Begin a new call session for a conversation. Returns LiveKit JWT.
  rpc StartSession(StartSessionRequest) returns (StartSessionResponse);

  // Join an existing call session. Returns LiveKit JWT.
  rpc JoinSession(JoinSessionRequest) returns (JoinSessionResponse);

  // Leave (idempotent).
  rpc LeaveSession(LeaveSessionRequest) returns (LeaveSessionResponse);

  // Bidirectional signaling (in-band Velix-side events: raise hand, mute,
  // call control). LiveKit's own data channels handle media-related signaling.
  rpc SignalChannel(stream SignalEvent) returns (stream SignalEvent);

  // Read-only metadata about an active session.
  rpc GetSessionInfo(GetSessionInfoRequest) returns (GetSessionInfoResponse);
}
```

## JWT issuance

LiveKit JWTs are signed with the LiveKit cluster's API secret (a per-cluster Vault secret). They contain:

```json
{
  "iss": "<api_key>",
  "sub": "<account_id>:<device_id>",
  "name": "<account_handle_or_id>",
  "video": {
    "room": "<call_session_id>",
    "roomCreate": false,
    "roomJoin": true,
    "canPublish": true,
    "canSubscribe": true,
    "canPublishData": true
  },
  "metadata": "{\"velix\":{\"call_id\":\"...\",\"e2ee\":true|false}}",
  "exp": 1735689600
}
```

JWT lifetime: 30 minutes (LiveKit refreshes connection JWTs internally for longer-lived calls).

## E2EE setup (≤ 8 participants)

The Flutter client (Phase 5/6 integration) uses LiveKit's Insertable Streams API:

1. Each participant generates a per-call symmetric key.
2. Keys are exchanged via the standard E2E messaging pipeline (Phase 7) — i.e., out-of-band relative to LiveKit.
3. Each frame is encrypted client-side with that key before LiveKit sees it.
4. Receivers decrypt similarly.

The SFU sees opaque encrypted blobs. It cannot decode video or audio.

A new participant joining triggers a key rotation: the existing participants generate a new key and distribute via the E2E channel. Anyone joining mid-call cannot retroactively decrypt prior frames (forward secrecy).

## Room lifecycle

```
client A: StartSession(conversation_id=...)
  ↓
call service:
  1. Pick LiveKit cluster (region match).
  2. Insert call_session row.
  3. POST /twirp/livekit.RoomService/CreateRoom { name: <call_id> }
  4. Issue JWT to client A.
  5. Publish velix.call.started.
  ↓
client A connects to LiveKit with JWT.

client B: JoinSession(call_id=...)
  ↓
call service:
  1. Verify B is in the conversation.
  2. Insert call_participant row.
  3. Issue JWT.
  4. Publish velix.call.participant-joined.
  ↓
client B connects.

client A: LeaveSession(call_id)  [or simply disconnect]
  ↓
call service:
  1. Update call_participant.left_at.
  2. If 0 participants left, mark call_session.ended_at.
  3. POST /twirp/livekit.RoomService/DeleteRoom (cleanup).
  4. Publish velix.call.ended (or velix.call.participant-left).
```

The server does not enforce participants leaving; LiveKit emits webhooks for participant events, which the call service ingests.

## Webhooks from LiveKit

LiveKit emits webhooks for:
- `participant_joined`
- `participant_left`
- `track_published` / `track_unpublished`
- `room_finished`

The call service exposes a webhook endpoint (`/livekit/webhook`) that:
- Verifies the webhook signature using LiveKit's API key.
- Updates `call_participant` and `call_session` rows.
- Publishes corresponding `velix.call.*` events to NATS.

## Per-region clusters

Each region has its own LiveKit cluster with its own API key/secret pair (in Vault). The call service routes a new call to the cluster geographically nearest to the initiator. Clients connect to that cluster; subsequent joiners are added to the same cluster regardless of their region (we do not currently mesh regions for a single call — Phase 8+ work).

## Performance targets

- LiveKit JWT issuance p99: ≤ 100 ms (one DB write + JWT sign).
- Client → LiveKit join time p95: ≤ 700 ms.
- Voice MOS on good network: ≥ 4.2.
- Voice MOS on 200ms RTT, 1% loss: ≥ 4.0.
- Video at 720p30 sustained on 2-party calls under that adverse condition.
- Concurrent participants per LiveKit node (8 GB / 4 vCPU): ≈ 500. We plan for 50% utilization.

## Banned

- Velix call service proxying media (we don't have an SFU of our own).
- Recording calls server-side. Calls are not recorded.
- Storing call audio / video.
- Allowing E2EE downgrade silently. Always UI-explicit.
- Inviting unauthenticated participants.
- Issuing long-lived (>1h) LiveKit JWTs.
- Sharing the LiveKit API secret with any service besides `call`.
