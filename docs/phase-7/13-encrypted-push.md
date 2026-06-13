# 13 — Encrypted Push

Push notifications wake a device to fetch its waiting messages. Velix's push payloads are encrypted; APNs / FCM / our own push service see only opaque ciphertext + a short routing token.

## Construction

```
For each push to a device:

1. Routing service has an envelope to deliver. Recipient device is offline.

2. Routing service publishes velix.push.requested to NATS:
     {
       device_id,
       encrypted_payload,
       routing_token,
       expires_at
     }

3. Push service consumes velix.push.requested.

4. Push service:
     - Looks up push_token by device_id.
     - Uses the encrypted_payload as-is (does NOT add encryption layers).
     - Forms the platform-specific push body.
     - Dispatches to APNs or FCM.

5. Device receives push:
     - Notification service extension (iOS) or FirebaseMessagingService (Android)
       extracts encrypted_payload and routing_token.
     - Verifies routing_token matches the device's expected hash for this payload.
     - Decrypts encrypted_payload with the device's per-device push key.
     - Renders the notification.
```

The encryption key is derived per device. Routing service has it (because it's the one preparing the encrypted payload). Push service does not.

## Per-device push key

The per-device push key is derived once per device when the device is paired:

```
push_key = HKDF(MDK_of_routing_service_for_this_device,
                salt=device_attestation_signature,
                info="velix.push.payload.v1",
                len=32)
```

Wait — the routing service can't have the device's MDK. Let me restate the actual flow.

The push key is established at device pairing time. Specifically:

```
At device pair (Phase 7 doc 10), step 18:
  Device A computes:
    push_key = HKDF(DH(A_dev_priv, B_dev_pub),
                    salt=zero,
                    info="velix.push.recipient_key.v1",
                    len=32)

  A submits push_key to the routing service (as part of its existing
  authenticated session) bound to B_device_id.

  Routing service stores push_key in its hot store keyed by B_device_id.
```

The routing service holds `push_key` for each device. The device holds the same `push_key` (derived at the same time on B's side via DH(B_dev_priv, A_dev_pub) which gives the same shared secret).

When routing service prepares a push:

```
ciphertext = AEAD-XChaCha20-Poly1305(
                 key=push_key,
                 nonce=random_24,
                 aad="velix.push.v1" || device_id,
                 plaintext={
                   conversation_id,
                   message_id,
                   sender_account_id,  // safe — encrypted to recipient
                   preview (optional),
                 })
```

The push service is a relay: it takes ciphertext + routing token + token, dispatches to APNs/FCM, returns.

This design is a deliberate trade-off:

- The routing service is in the TCB for push payloads (it sees `sender_account_id` to decide what to put in the payload).
- The push service is NOT in the TCB.
- APNs / FCM are NOT in the TCB.

If we wanted to remove routing from the TCB for push, we'd have to deliver the push payload's plaintext from the *sender's* client, which means the sender's client computes a per-recipient push payload alongside the regular ciphertext. That's expensive (extra AEAD per recipient device) and complex (the sender's client has to know what notification text to use). We accept routing-in-TCB for push payloads.

The ROUTING service is explicitly trusted with: "what notification text to render for this received-but-undelivered envelope." That's it. It doesn't see the message content.

## Routing token

A 16-byte HMAC computed by the routing service:

```
seed         = push_routing_seed for this device (Phase 7 doc 05; rotates per push)
routing_token = HMAC-SHA-256(seed, message_id) [first 16 bytes]
new_seed      = HMAC-SHA-256(seed, "velix.push.seed.rotate.v1")  (advance)
```

The push service includes the `routing_token` in the platform payload. The device's notification handler verifies the token against its expected value (the device tracks the same `seed` rotation). Tokens don't repeat across pushes.

The token's purpose: defeats long-term tracking by APNs / FCM / passive intermediaries. A push at time T cannot be linked to a push at time T+1 by the token alone.

## Notification payload

What APNs / FCM see:

```json
{
  "aps": {
    "alert": "",
    "mutable-content": 1,
    "content-available": 1
  },
  "v": {
    "rt": "<routing_token_b64>",
    "ev": "<encrypted_payload_b64>"
  }
}
```

The "alert" is empty. The device's notification service extension decrypts `ev` and rewrites the alert text locally before display.

Until decryption succeeds:
- iOS shows "Velix" (the app name).
- Android shows "New message" (a generic string).

Users opting into rich preview (Phase 8+) get content shown after decryption; default users get the generic string.

## What the device extracts

After decryption, the device knows:
- conversation_id
- message_id
- sender_account_id (the *real* sender; same as the encrypted message's `sender`)
- optional preview snippet (capped at 64 chars)

The device renders:
- Full sender name (looked up from local trusted-identity records)
- Avatar (from local cache)
- Preview snippet (if user opted in)

## Background fetch coordination

The push wakes the device. The device's `velix_data` sync queue then drains any pending envelopes from the routing service. The push is the *doorbell*; the actual message content arrives via the standard `routing.Subscribe` path.

This is important: even if the push payload is lost (APNs flaky), the message is delivered when the device next reconnects. The push is best-effort.

## Replay protection on push

A replayed push:
- Has the same routing_token (unique per push).
- Decrypts to the same encrypted_payload.
- The device's local store has already processed the corresponding message (or will refuse on duplicate message_id).

The device tracks recently-seen routing tokens for 60 seconds (Redis-equivalent on device); duplicates within that window are silently dropped.

## VoIP push (calls)

Calls use a different push class with stricter delivery semantics:

- iOS: PushKit/CallKit, `voip-pushtype`, wakes the app even from killed state.
- Android: high-priority FCM data message.

VoIP push payloads are encrypted the same way; the call ringer UI decrypts before ringing.

## Push key rotation

The push key is a long-lived key (changes only on device repair / re-attestation). The routing seed rotates per push. This separates "key compromise" (long-lived) from "linkability defense" (per-push).

If a push key is suspected of compromise:
- Device issues a "rotate push key" request to routing.
- Routing accepts a new push key bound to this device.
- Old push key is destroyed.

The user-visible flow is hidden inside Settings → Privacy → "Re-secure pushes."

## Banned

- Plaintext message bodies in push payloads.
- Push notifications without encryption.
- Using a single push key per account (we use per-device).
- Reusing a routing token across pushes.
- Storing the push key plaintext anywhere except OS keychain.
- Sharing the push token with the AI gateway (the gateway never sees push).
- Allowing the push service to decrypt the payload (it cannot — it lacks the key).
- Logging the encrypted_payload at any level — even though it's encrypted, log size leakage is a side channel.
