# 02 — UX Gap Analysis

A structured catalog of where the messaging market is broken. Each gap is paired with the Velix response and a measurable success criterion. We will revisit this list at every phase audit and verify we have not regressed.

---

## Gap 1 — Trust is invisible until it isn't

**The problem.** In every mainstream product, encryption status is communicated either as a one-time onboarding screen or a tiny lock icon nobody reads. Users do not feel safe; they assume they are safe until something tells them otherwise. When something *does* go wrong (re-keyed device, forwarded chat, screenshot), the response is a yellow banner.

**The Velix response.** Trust is an ambient material, not a glyph.
- Verified contacts render with a different surface tint — barely perceptible until you look for it.
- A device key change produces a sustained surface tremor on the conversation, not a banner.
- Screenshots inside private chats are detected (best-effort, OS-permitting) and the surface dims with a subtle ripple to telegraph it.
- The verification flow is a 5-second QR scan, not a 12-digit number to read aloud.

**Success criterion.** In closed-beta usability testing, ≥ 80% of users correctly identify (without prompting) when a contact's device has changed.

---

## Gap 2 — Onboarding leaks identity

**The problem.** Signal and WhatsApp both notify your existing contacts when you join. This is convenient but it's a quiet privacy violation: it tells a person you may not have spoken to in five years that you have signed up for an encrypted messenger today, on this device, with this number.

**The Velix response.**
- Identity is a cryptographic key pair generated on device, not a phone number.
- Optional handles (e.g. `@quinn`) are how you find people, and discovery is **opt-in for both sides**.
- We never broadcast joins. There is no "X joined Velix."
- Phone-number sign-in is offered for usability but mapped to a hashed identifier server-side; the server never sees the plaintext number.

**Success criterion.** Independent privacy audit confirms zero passive notification of contacts on signup.

---

## Gap 3 — Notifications optimize for the wrong actor

**The problem.** Most apps optimize notifications for re-engaging the *user*, not for serving them. Defaults are loud, granularity is poor, and "Do Not Disturb" is buried.

**The Velix response.**
- Default state is **quiet**. No badge dots, no red counters, no sound for non-priority chats.
- Per-conversation priority is set via a single 3-state toggle: **Priority / Normal / Silent**.
- Smart deferral: messages from non-priority threads aggregate into a "Later" bundle delivered at user-chosen times (8am, lunch, 6pm — configurable, defaults sensible).
- Push payloads are encrypted; the server cannot see content or metadata beyond a session-rotated routing token.

**Success criterion.** Average daily push count per user in beta ≤ 30% of WhatsApp's published equivalent for the same conversation volume.

---

## Gap 4 — Multi-device is half-implemented everywhere

**The problem.** Signal partially syncs history. iMessage sometimes sees old chats. Telegram syncs cleanly but only because the cloud holds plaintext. WhatsApp's multi-device is real but the desktop client still depends on the phone for many flows.

**The Velix response.**
- Each device is a first-class member of an identity, with its own key pair.
- Group key fan-out uses Sender Keys, scaled per device.
- New devices receive history via an encrypted sync protocol (the user's own devices share via short-lived ephemeral keys; server stores ciphertext only).
- Adding a device requires confirmation from an existing trusted device. No SMS code as the only barrier.

**Success criterion.** A new device added to an account can fully reconstruct the user's last 90 days of conversation history within 60 seconds on broadband, with the server unable to read any of it.

---

## Gap 5 — The conversation has no "place"

**The problem.** Every chat is a flat list of bubbles between two avatars. Discord glimpsed a better idea (rooms you walk into) but couldn't generalize it because of dense Discord-specific UX. iMessage and WhatsApp never tried.

**The Velix response.**
- Every conversation has an **ambient scene**: a per-thread color/material identity, a subtle motion signature, optional shared spatial backdrop.
- A 1:1 thread can be promoted to a **persistent room** — voice-on-tap, shared whiteboard, drop-in expectation.
- Stories from a conversation participant surface inside the conversation's "room," not in a separate global feed, preserving context.

**Success criterion.** Beta users describe individual conversations using place metaphors ("Quinn's room," "the work space") in qualitative interviews ≥ 50% of the time.

---

## Gap 6 — Search is broken on encrypted products

**The problem.** Encryption breaks server-side search. Signal's search is purely on-device and limited to local history. Telegram's "search" works because the server holds plaintext, which is its security failure.

**The Velix response.**
- Per-user **encrypted search index** (Tantivy on device + Meilisearch with client-derived keys for cloud index of media metadata only).
- Searchable encryption: the server stores tokenized indexes encrypted with keys it does not hold; queries return ciphertext-matched candidate sets that the device decrypts and refines.
- On-device pgvector-equivalent (sqlite-vss) for semantic search of the user's own messages, never sent to the server.

**Success criterion.** Search across 100,000 personal messages returns top 10 results in < 200 ms on a 2022-era mid-tier Android phone, server-side never holding plaintext.

---

## Gap 7 — Voice and video calls are an island

**The problem.** Most messengers treat calls as a separate sub-app stitched on later. The result: inconsistent UI, inconsistent quality, and the call surface forgets the conversation context.

**The Velix response.**
- Call surfaces share the conversation's ambient scene. The room you call from looks like the room you were in.
- Calls are **rooms** in our model — they persist as long as someone is in them. Dropping out and back in is one tap, no re-ring.
- LiveKit SFU + Insertable Streams gives us E2EE for video and audio at small group sizes (≤ 8); larger calls fall back to SFU-trust mode with explicit UI affordance ("the SFU can see this call").
- Spatial audio for ≥ 3 participants, on devices with the silicon for it.

**Success criterion.** Voice MOS ≥ 4.0 on 200 ms RTT, 1% packet loss; video stays at 720p30 or better at the same network conditions for 2-party calls.

---

## Gap 8 — AI is the new surveillance vector

**The problem.** Every "AI in your messenger" product silently relays your messages to a cloud LLM. This is a categorical step backward for E2E products.

**The Velix response.**
- AI is **on-device first**. Smart reply, summarization, language detection, translation, moderation — all run via TFLite/MediaPipe/CoreML/Gemini Nano.
- Cloud AI is **explicit, per-invocation, ephemeral**: the user invokes "Ask AI" with a selection; the selection is sent to our gateway behind a privacy-preserving relay (Oblivious HTTP or equivalent), processed, response returned, no logs.
- The system never auto-relays content to AI without user invocation.

**Success criterion.** A privacy auditor can confirm that no message content reaches our AI gateway except via explicit user gesture, and that the gateway is incapable of correlating user identity with content.

---

## Gap 9 — Groups don't scale gracefully

**The problem.** Most apps make a 5-person group and a 5,000-person community feel like the same UI, then bolt on roles and broadcast modes when it breaks. The result is a chat full of muted notifications and lost context.

**The Velix response.**
- Three distinct primitives: **Threads (1:1 to ~20)**, **Spaces (community, ~20 to 5k, room hierarchy)**, **Channels (broadcast, 5k+, one-to-many with reactions/replies)**.
- Each primitive has its own UI grammar, notification model, and moderation tooling. We do not pretend they are the same surface.

**Success criterion.** No user-facing setting controls *how the UI changes between primitives* — the primitives are chosen at creation and the UI adapts automatically.

---

## Gap 10 — Cross-platform feels like a tax

**The problem.** Telegram has the best multi-platform story today, at the cost of encryption. Signal Desktop is functional but second-class. iMessage exists only inside Apple's walls.

**The Velix response.**
- One Flutter codebase covering iOS, Android, macOS, Windows, Linux, and Web (PWA).
- Spatial / Vision Pro arrives in v2.0 as a tightly-scoped client targeting the existing protocol.
- Web is a *real* client, not a thin viewer — encrypted, multi-device, full history.

**Success criterion.** Feature parity matrix shows ≥ 95% feature coverage across all platforms at 1.0, with the remaining 5% being platform-genuinely-impossible (e.g., system-level call integration on web).

---

## Gap 11 — The aesthetic of "secure" is utilitarian

**The problem.** There is an unspoken assumption in the privacy software community that beauty is suspicious — that any pixel of polish must hide a tradeoff. The result is software that respects users and looks like it doesn't like them.

**The Velix response.**
- We treat polish as a moral position: respecting the user means giving them an interface they can love.
- The cryptography is auditable, the protocol is documented, the threat model is stated. We earn trust the right way and we still ship a beautiful product.

**Success criterion.** External design coverage compares Velix favorably to iMessage and Vision Pro apps; external security coverage compares Velix favorably to Signal.

---

## Audit — what this list does NOT solve

We are deliberately *not* trying to solve:
- The social graph cold-start problem at consumer scale (we go viral by craft and word-of-mouth, not by harvesting your contacts).
- Federation in 1.0. We are a centralized service with strong properties; federation is v2.0+.
- Replacing email or SMS for transactional messaging. Out of scope.
- Embedded payments or wallets. Possible later, not in 1.0.
- Stories monetization for creators. Out of scope until scale justifies it.

This list will evolve. Any change requires updating this file and the audit.
