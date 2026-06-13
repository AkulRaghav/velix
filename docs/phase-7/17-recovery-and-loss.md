# 17 — Recovery & Loss Scenarios

Concrete, named scenarios. Each has a documented recovery path. Where recovery is impossible, we say so.

## Scenario taxonomy

| ID | Scenario | Recoverable? |
|---|---|---|
| L1 | Device lost, second trusted device available | Yes |
| L2 | Device lost, only backup passphrase remembered | Partial — messages yes, identity no |
| L3 | Device lost, no backup, no second trusted device | No (identity unrecoverable) |
| L4 | Backup passphrase forgotten | Backup unrecoverable; identity recoverable via trusted device |
| L5 | All trusted devices revoked simultaneously | Identity unrecoverable; data per backup |
| L6 | Identity service detects key change ("rekeyed") | Yes (via re-verification flow) |
| L7 | Suspect device compromise | Yes (revoke device + re-key) |
| L8 | App data corrupted (DB unreadable) | Yes if backup exists; else partial via re-pairing |
| L9 | OS keychain wiped (factory reset) | Same as device loss |
| L10 | Cryptographic vulnerability discovered in deployed primitive | Plan: phased migration via algorithm agility |

## L1 — Device lost, second trusted device available

The user's iPhone is lost. They still have their MacBook with Velix signed in.

```
On the surviving device (MacBook):
   1. Settings → Devices → revoke the lost device.
   2. The identity service:
      - marks the lost device as `revoked`
      - publishes velix.device.revoked
      - all conversations with the user fanout to remaining devices only
      - the lost device's bearer tokens are immediately revoked

If the user buys a new device:
   3. Install Velix on the new device.
   4. Multi-device pairing flow (Phase 7 doc 10):
      - Scan QR from MacBook.
      - Confirm 6 emoji.
      - MacBook signs an attestation for the new device.
   5. Optional history transfer from MacBook to the new device.
```

The lost device cannot send or receive messages from the moment of revocation. Even if recovered later, the bearer token is dead and the protocol-store keys are useless without the OS keychain.

**Loss:** the encrypted DB on the lost device may persist if the device is found and unlocked. The MDK is hardware-backed (Secure Enclave / StrongBox) and bound to the OS unlock state. If the OS unlocks, the MDK is accessible. We do not promise content protection if the device's OS is unlocked.

## L2 — Device lost, only backup passphrase remembered

The user lost everything but remembers their backup passphrase.

```
1. Buy new device.
2. Install Velix.
3. Choose "Restore from backup."
4. Enter account_id (or scan from another existing trusted device — none in this scenario).
   - If they don't have account_id: the backup endpoint is queryable by signed challenge from the user's existing identity, but the user's identity is on the lost device.
   - **This is the fundamental block.** The backup is anonymized; only the device that paired before the loss can claim it.
```

This scenario is partially recoverable:

- **If the user remembers their account handle** (`@quinn`), the backup endpoint can match it.
- **If the user doesn't remember their handle**, recovery fails. The user can create a new account and have contacts re-add them.

The handle is the recovery handle. We document this clearly in onboarding.

**Identity:** unrecoverable. The user creates a new identity. Contacts re-verify via the rekeyed state.

## L3 — Device lost, no backup, no trusted device

The user creates a new identity from scratch.

- Their old conversations are lost.
- Their contacts cannot reach the old identity (it's revoked at the identity service level once the user takes action; otherwise the contacts will see "delivery never acked" and eventually mark the identity stale).
- The user re-builds.

This is the most painful case. We show a clear "Are you sure?" dialog when revoking the last trusted device.

## L4 — Backup passphrase forgotten

The user has a trusted device, but lost the passphrase to their backup.

```
Effect:
   - The backup is unrecoverable. We cannot recover. No "passphrase recovery"
     because we do not store hints, salts in derivable form, or any escrow.
   - The user can create a new backup at any time with a new passphrase.

Loss:
   - The previous backup's data is locked.
   - But the user has the trusted device; they can pair new devices and history-transfer
     from there. The backup is a fallback; the trusted device is the primary recovery path.
```

We show a "We cannot recover this for you. Create a new backup with a passphrase you'll remember." message. We do not pretend.

## L5 — All trusted devices revoked simultaneously

A user revokes their only device, perhaps in panic.

```
Effect:
   - Identity is sequestered: no device can attest a new device.
   - Backups are still readable (by passphrase) but the recovered data has no path
     to a device with the right identity attestation.
```

This is essentially L3 — the user creates a new identity. We disallow revoking the last device unless the user explicitly confirms ("This will lock you out of this account").

## L6 — Rekeyed state detected

A peer's identity_pub changes during an ongoing conversation (genuine: peer reinstalled; or hostile: MITM tried to substitute).

```
Visual signal (Phase 2 doc 02): conversation surface gains a sub-pixel material tremor.
Inline message: "Quinn's encryption changed. Verify again."
LiveRegion announcement to AT users.

User action options:
   1. Verify again via QR scan (Phase 7 doc 15). On match → standard trust state restored.
   2. Mark as untrusted ("This isn't them" → conversation locked from sending).
   3. Continue as-is (we display sustained warning until they take action; we do not block).
```

Most rekeyed events are benign (peer reinstalled). The visual is sustained but unobtrusive.

## L7 — Suspect device compromise

The user notices unusual activity, suspects a device is compromised.

```
1. From any other trusted device, revoke the suspect device (Phase 7 doc 10).
2. Request push key rotation (Settings → Privacy → Re-secure pushes).
3. Request prekey rotation (one-tap action; client publishes a fresh signed prekey
   and 100 new one-time prekeys, retiring the old).
4. Optionally re-key all conversations:
   - Force a Double Ratchet step on all peer sessions.
   - This is one outbound message per peer; auto-fanned-out via the routing layer.
```

The compromised device:
- Cannot send (token revoked).
- Cannot receive new messages (envelopes route to remaining devices).
- Has copies of past messages on its own DB. These are persistent until the device's OS keychain is wiped.

Beyond software actions, the user should treat the compromised device as physically lost — wipe it via OS-level controls (Find My iPhone, etc.).

## L8 — App data corrupted

The local SQLCipher DB is unreadable (rare; OS-level filesystem corruption).

```
Recovery:
   1. App detects on launch (SQLCipher returns error).
   2. App offers: "Restore from backup" or "Reset and reauthenticate".
   3. Restore: downloads latest backup, decrypts via passphrase, reopens.
   4. Reset: discards local DB, pairs as new device via existing trusted device.
```

The OS keychain remains intact in this scenario. The MDK and identity_priv are unaffected. Only the DB is corrupted.

## L9 — OS keychain wiped

User factory-resets their device, or migrates phones without proper backup.

```
Effect:
   - MDK lost. Identity_priv lost.
   - Equivalent to device loss (L1).
   - Recovery via second trusted device (Phase 7 doc 10) or backup (L2).
```

iCloud Keychain restore does NOT restore Velix keys (we never sync to iCloud). On Android, Google account restore does not restore Keystore-protected keys. The user is in the same boat as L1.

## L10 — Cryptographic vulnerability

A primitive in the table at Phase 7 doc 02 is broken (X25519 broken; ChaCha20 broken; Argon2id broken). Hypothetical, but plan exists.

```
Phase 1: assess
   - Determine which primitive, what attack, what data is at risk.
   - Public statement on velix.app/security within 48 hours.

Phase 2: rotate
   - libsignal upstream releases a fix or a new primitive.
   - We adopt within 90 days of upstream.
   - All clients update; encryption boundary uses new primitives going forward.
   - Ciphertexts encrypted under the broken primitive remain readable to the
     attacker until rotated.

Phase 3: monitor
   - Annual audit explicitly tests for the new attack class.
```

The 1-byte version prefix on every encrypted blob enables this rotation. We will not accept "stay on the broken primitive for backward compatibility."

## Banned recovery paths

- "Reset password" via email or SMS link.
- Server-side passphrase store, even hashed.
- Recovery via "we'll mail you a code."
- Backup recovery via SMS / phone authentication.
- Identity recovery via federated ID (no SSO into Velix).
- Plaintext export of unrecovered messages by support staff.
- Any process that lets Velix-the-company recover a user's data.

The architectural property — server cannot read content — would be defeated by any of these. We take the hit on user friction.

## Documentation surface

The application's onboarding (Phase 5 doc) explicitly covers:
- The importance of pairing a second device immediately.
- The importance of remembering the backup passphrase.
- That we cannot recover the passphrase.
- That losing all trusted devices means starting over.

This is repeated in Settings → Privacy → "What happens if I lose my phone?"

## Audit hooks

- Quarterly: review L1-L10 against current product behavior.
- After every release: regression-test the recovery paths via integration test (an automated user flow that exercises pair → backup → lose → restore).
- Annually: include in the third-party security audit.
