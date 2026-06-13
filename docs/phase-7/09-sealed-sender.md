# 09 — Sealed Sender

A property: the routing server learns the recipient of an envelope (because it has to deliver), but it does NOT learn the sender. The sender's identity is wrapped inside the ciphertext only the recipient can decrypt.

## Why Sealed Sender

The threat model property P7 says: "Sender anonymity vs server." Without Sealed Sender, the routing service sees `sender_account_id, recipient_account_id` for every send and can build a full social graph from delivery metadata alone.

With Sealed Sender, the routing service sees only `recipient_account_id`. Building a graph requires colluding with the recipient or compromising the recipient device.

## Construction (Signal Protocol's Sealed Sender)

The sender wraps its identity into an inner envelope encrypted to the recipient. The outer envelope (what the server sees) carries:

```
recipient_account_id    (server uses to route)
recipient_device_id     (server uses to route)
sealed_sender_envelope  (opaque ciphertext)
```

No `sender_account_id` field exists in the outer envelope. The proto-level enforcement is in `routing.proto`'s `EnvelopeRecipient` message — there is no field for the sender (Phase 6 doc 03).

The sealed envelope contains:

```
sender_certificate    A short-lived certificate from the identity service that
                      attests "this account_id is registered to this device_pub".
                      Signed by the identity service's rotating signing key.

ciphertext            The Double Ratchet output as in normal sends.
```

The sender_certificate is included so the recipient can verify the sender is legitimate (vs an MITM impersonating). But the certificate is encrypted; the server doesn't see it.

## Sender certificates

The identity service issues short-lived (≤ 24h) sender certificates on demand:

```proto
message SenderCertificate {
  string account_id              = 1;  // ULID
  bytes  identity_public_key     = 2;  // 32 B Ed25519
  string device_id               = 3;
  google.protobuf.Timestamp expires_at = 4;
  bytes  signature               = 5;  // signed by identity service's rotating key
}
```

Sender certificates are not encrypted; the server signs them so any recipient can verify them with the identity service's published public key.

But the sender certificate is wrapped inside the sealed envelope — the server only sees it during issuance, not during delivery.

## Issuance

Clients fetch a fresh sender certificate when the current one expires:

```
identity.GetSenderCertificate(device_id) → SenderCertificate
```

Issued certs have a 24-hour lifetime. Clients refresh proactively at the 12-hour mark.

The issuance call requires authentication (the client's session token). The server learns the device is online. The certificate itself is bearer — once issued, it can be used to wrap any number of sends until expiry.

## Wrap (sender side)

```
1. Compute the Double Ratchet ciphertext as normal.

2. Build the inner envelope:
   InnerEnvelope {
     sender_certificate,
     ciphertext
   }

3. Serialize → InnerEnvelopeBytes.

4. Encrypt InnerEnvelopeBytes to the recipient's identity public key using
   a one-shot ECIES-style construction (libsignal's "unidentified delivery"):
     ephemeral_pub, ephemeral_priv = X25519 keypair
     shared = DH(ephemeral_priv, recipient_identity_pub)
     k = HKDF(shared, salt=zero, info="velix.sealed_sender.v1", len=32)
     sealed = ephemeral_pub || AEAD(k, nonce=0, plaintext=InnerEnvelopeBytes)

5. Send the outer envelope:
   OuterEnvelope {
     recipient_account_id,
     recipient_device_id,
     sealed
   }
```

## Unwrap (recipient side)

```
1. Receive OuterEnvelope.

2. Extract ephemeral_pub from sealed.

3. Compute shared = DH(recipient_identity_priv, ephemeral_pub).

4. k = HKDF(shared, salt=zero, info="velix.sealed_sender.v1", len=32).

5. AEAD-decrypt to get InnerEnvelopeBytes.
   - Failure → drop the envelope (legitimate sender certs don't fail integrity).

6. Parse InnerEnvelope. Extract sender_certificate.

7. Verify sender_certificate signature using identity service's published key.
   - Failure → drop the envelope.

8. Verify sender_certificate.expires_at is in the future.
   - Failure → drop the envelope.

9. Now we know the sender's identity. Look up our session with that
   sender_account_id + device_id (libsignal's protocol store).

10. Decrypt the Double Ratchet ciphertext as normal.
```

## What the server sees

For every Sealed Sender envelope:

- The recipient account ID.
- The recipient device ID.
- An opaque blob (the sealed envelope) of length ≈ ciphertext + 64 bytes overhead.
- The size and timing.

Specifically NOT:

- The sender's account ID.
- Any link between this envelope and the corresponding envelope sent by the recipient back to the sender.

## What an active attacker on the network sees

Same as the server. TLS protects both layers; the server learns nothing the network does.

## Limitations (the honest disclosure)

Sealed Sender hides the sender's account ID from the *server-side-of-routing-and-delivery*. It does NOT hide:

- The sender's IP address (visible to the routing service via the connection).
- The fact that *some* sender is sending (timing/volume).
- The recipient's account ID (visible to the routing service for delivery).

For full sender anonymity vs the server, we'd need a mixnet or onion-routed transport. That's not Phase 7. We log this in `01-threat-model.md` non-promise N1.

## Authentication challenges

A naive observer might say: "If the server doesn't know who's sending, how does the server enforce per-account rate limits?"

Answer: rate limits are enforced *at the time of send*, when the sender authenticates with their bearer token. The token contains `sub` (account_id) and `did` (device_id). Rate limit decrement happens in the `routing.SendEnvelope` interceptor. The envelope itself, after the rate limit check, is sealed and routed without the sender field.

## Replay protection inside Sealed Sender

The sealed envelope is one-shot. The ephemeral_pub inside is unique per send (a fresh X25519 keypair for every wrap). A replayed sealed envelope:

- Has the same ephemeral_pub.
- Decrypts to the same InnerEnvelope.
- The InnerEnvelope's sender_certificate is verified again.
- The Double Ratchet ciphertext inside is replayed → libsignal's session detects (Phase 7 doc 07).

The replay is detected at the inner-protocol layer, not the Sealed Sender layer.

## libsignal mapping

In libsignal terms:

- "Unidentified delivery" / "Sealed Sender" support is built-in.
- `SealedSenderEncrypt` / `SealedSenderDecrypt` are the operations.
- `SenderCertificate` is a libsignal Protobuf message.

We expose these via the FFI binding.

## Performance

- Wrap: +1 X25519 key gen + 1 DH + 1 HKDF + 1 AEAD = ≈ 1 ms additional vs non-sealed.
- Unwrap: same shape = ≈ 1 ms additional.

The cost is paid per envelope, per recipient device. For a 5,000-device group, that's ~5 seconds of additional CPU spread across batch sends. Acceptable.

## When Sealed Sender does NOT apply

- The very first message between two parties (X3DH bundle exchange) cannot be sealed because the sender's identity is needed to verify the bundle was signed correctly. The first message after X3DH is normally Sealed.
- Anonymous credentials for "I'm in this group but anonymous" — not implemented; tracked for v2.

## Banned

- Adding a `sender_account_id` field to the routing envelope, even "for debugging."
- Server-side validation that requires the sender's identity (the rate limit is the only one, and it's done via bearer token, not envelope content).
- Skipping the sender certificate verification because "the bytes are in our database, they must be ours."
- Reusing the ephemeral keypair across two sealed sends.
- Logging the sender's account ID after Sealed Sender unwrap (it's PII; subject to scrubbing rules from Phase 6 doc 10).
