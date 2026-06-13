# 12 — Encrypted Media

Photos, videos, voice notes, files. Velix stores ciphertext on Cloudflare R2; the server is incapable of decoding the content. Per-recipient access is controlled by wrapping the data-encryption key with each recipient's session key.

## Construction

```
1. Sender's client picks a random 32-byte data encryption key (DEK).

2. Sender encrypts the media file with the DEK:
     ciphertext = AEAD-XChaCha20-Poly1305(
                       key=DEK,
                       nonce=random_24,
                       aad="velix.media.v1" || content_type_class,
                       plaintext=media_bytes)

3. Sender uploads ciphertext via presigned R2 URL (Phase 6 doc, media service).
   The R2 object is identified by an opaque key (not the media id; the media id
   maps to it server-side).

4. Sender wraps DEK separately for each recipient device using its existing
   Double Ratchet session:
     wrapped_dek_for_device = encrypt_via_double_ratchet(DEK, session)

5. Sender creates a media reference message in the conversation, body:
     media_ref = {
       media_id,
       content_type_class,
       size_bytes,
       wrapped_deks: [(device_id, wrapped_dek), ...],
       ciphertext_nonce
     }
   The media_ref is sent as a normal message (one envelope per recipient device).

6. Recipient receives media_ref, looks up its own wrapped_dek, decrypts via
   Double Ratchet to recover DEK.

7. Recipient downloads ciphertext via presigned R2 download URL.

8. Recipient AEAD-decrypts the ciphertext with DEK and the included nonce.

9. Recipient zeroes DEK from memory after the decrypt completes.
```

## Why per-recipient wrapping vs a shared group key

For 1:1 media this is straightforward. For groups, we wrap the DEK for each recipient device (the same way Sender Keys handles per-device fanout for messages). At 50 devices, the media_ref message is ~1.5 KB (mostly the wrapped DEKs at ~30 bytes each).

This keeps the server fully blind: it sees a media object's ciphertext and a series of "this opaque message envelope was delivered" events, and nothing more.

## Server-side metadata

The `media` table (Phase 6 doc 04) stores:

```
id                       text        media id (ULID)
owner_account_id         text        for retention/quota
content_type_class       text        image|video|audio|file (no finer)
size_bytes               bigint      for quota
ciphertext_etag          text        R2 ETag (server-side integrity)
ciphertext_object_key    text        R2 key
encryption_key_wrapped   bytea       NOT USED — wrapped DEKs live in messages
uploaded_at              timestamptz
expires_at               timestamptz retention boundary
deleted_at               timestamptz
```

The `encryption_key_wrapped` column from Phase 6 doc 04 is reserved but unused. The wrapped DEKs are inside the message envelope, not the media table. (We will remove the column in a future migration; for now it's NULL by convention.)

## Content-type-class

Server stores only a coarse classification: `image|video|audio|file`. Specifically NOT:

- The exact MIME type (would distinguish PNG from JPG, audio/m4a from audio/mp3).
- Image dimensions.
- Video duration or resolution.
- Whether the file is an executable.

Coarse classification is enough for routing decisions (e.g., images get image-specific download URL options) without leaking content detail.

## Upload flow

```
client → media.IssueUploadUrl(content_type_class, size_bytes)
                                    ↓
       returns: presigned R2 PUT URL, media_id
                                    ↓
client encrypts locally → uploads ciphertext directly to R2
                                    ↓
client → media.ConfirmUpload(media_id, etag)
                                    ↓
media service updates row, publishes velix.media.uploaded
                                    ↓
client sends media_ref message to recipients via routing.SendEnvelope
```

The media service does NOT proxy the upload. The presigned URL is direct-to-R2 (saves bandwidth, avoids server-side touch of ciphertext beyond what R2 returns).

## Download flow

```
recipient → media.IssueDownloadUrl(media_id)
                                    ↓
media service authorizes (does the recipient have a media_ref to this media_id?)
                                    ↓
       returns: presigned R2 GET URL
                                    ↓
recipient downloads ciphertext directly from R2
                                    ↓
recipient AEAD-decrypts with the recovered DEK
```

Authorization check: the recipient must have a `media_ref` for this `media_id` in its local store. The recipient's client includes a HMAC-signed proof of the media_ref in the IssueDownloadUrl request, verifiable by the media service:

```
proof = HMAC-SHA-256(
            key=device_session_with_owner,
            data="velix.media_proof.v1" || media_id || expires_at)
```

The media service maintains a session-derivation context that allows verifying this without knowing decryption material. (Detail in `media-internal.md`.)

This prevents a random user with a media_id from downloading.

## Retention

Default media retention: 30 days. The media owner can extend or shorten via per-conversation settings. Disappearing-message media inherit the conversation's retention window.

After expiry, the R2 object is deleted; future download attempts return `NOT_FOUND`. Recipients that haven't downloaded yet lose the chance.

## Voice messages

Voice messages are media with `content_type_class = audio`. Additionally:

- The amplitude envelope (50 samples/sec, 7-bit) is included in the message body, encrypted to recipients.
- The envelope plays alongside the audio for waveform visualization.
- The envelope size is bounded (e.g., 30 sec of audio = 1.5 KB envelope).

The envelope is NOT sent in cleartext; it's part of the encrypted message body.

## Image previews

A small (≤ 16 KB) preview thumbnail is computed client-side and included in the message body (encrypted). Recipients see the preview immediately; the full image downloads on tap.

The preview is NOT a separate media object; it's inline in the message envelope. The full image is the only R2 object.

## Banned

- Server-side processing of media (no thumbnail generation, no transcoding, no analysis).
- Storing decrypted media in any cache outside the OS's standard image cache (which has its own protection).
- Logging media metadata that could fingerprint the content (e.g., exact MIME type).
- Pre-fetching media before the user views it (battery + privacy concern).
- Sharing a single key across multiple media objects.
- Using a deterministic nonce for media AEAD.
- Allowing media downloads without proof of recipient.
