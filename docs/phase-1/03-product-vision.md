# 03 — Product Vision & USP

## One-line vision

**Velix is the calmest, most beautiful, and most trustworthy place to talk on the internet.**

If two of those three slip, we have failed.

## Three-line vision

A cross-platform encrypted messenger built on Flutter and Signal-grade cryptography, with a cinematic, spatially-aware interface that treats motion and material as primary communication. AI lives on the device, not the server. Identity is cryptographic, not phone-number-based. Conversation is a place, not a list.

## Strategic frame

We are not winning by adding features to an existing category. We are winning by re-deciding what the category should feel like.

```
                              POLISH ↑
                                      │
                              iMessage•│ • (Velix target)
                                      │
                                      │
                    Telegram •        │
                  Discord •           │
                  WhatsApp •          │
                                      │
                                      │
    ──────────────────────────────────┼────────────────────────── TRUST →
                                      │
                                      │ Signal •
                              Threads •│
                              Snapchat•│
                                      │
                              Instagram•│
                                      │
```

The empty upper-right quadrant — high polish, high trust — has no occupant because the two cultures rarely overlap. Privacy engineers ship utilitarian UIs; consumer designers ship surveillance products. Velix is staffed and architected to live in that quadrant deliberately.

## Unique selling propositions

In priority order. The first three are the marketing line. The rest are why people stay.

### 1. Cinematic encryption
Velix is the first messenger where end-to-end encryption is part of the visual language, not a checkbox. Material, motion, and color carry trust state — verified contacts feel different to the touch. The cryptography is Signal-grade. The experience is iMessage-grade.

### 2. Conversations as rooms
Every thread is a place with its own light, color, motion signature, and optional spatial backdrop. Voice rooms are persistent — you walk in, you walk out, no ringing. Calls share the room's identity.

### 3. AI on your phone, not on our servers
On-device language models do smart reply, summarization, translation, and moderation. Cloud AI is opt-in per query and runs through a privacy-preserving relay we cannot correlate. We never train on your messages because we never see them.

### 4. Identity without the phone number
Your account is a cryptographic key. You can attach a handle, an email, or a phone number for discovery, but none of those are the account itself. Multi-device works without a phone being the master.

### 5. Calm by default
No engagement-maximizing notifications, no infinite feed, no streaks, no badge dots competing for attention. Notifications are quiet unless you mark a thread as Priority. The product respects your day.

### 6. Cross-platform parity that is real
One client codebase. iOS, Android, macOS, Windows, Linux, and Web at 1.0. Vision Pro at 2.0. Feature parity across platforms is a release-blocking metric, not a stretch goal.

### 7. Open and auditable
The cryptographic core is open source under a permissive license, the wire protocol is documented, and the threat model is published. Independent audits are commissioned annually and the results are public.

## Anti-USPs

We will be tempted to do these. We will not.

- ❌ "AI summarizes your group chats automatically" — categorical privacy regression, even if the model is local, because of the implicit always-on dynamic.
- ❌ "Streaks and engagement gamification" — disrespect for the user.
- ❌ "Public discoverable groups" in v1 — leads to spam, scams, and a moderation problem we are not yet staffed for.
- ❌ "Business accounts and shop integrations" — forks the experience and pulls us toward a Meta-shaped product.
- ❌ "Web3, tokens, decentralized identity tied to a chain." Cryptographic identity, yes. Crypto-identity, no.

## What "winning" looks like

Twelve months after public 1.0:
- 500k MAU, paid plus free
- ≥ 4.7 average store rating
- Press cycle that compares us to iMessage and Signal — never to "yet another secure messenger"
- An active independent security audit cadence
- A product where designers from Apple, Linear, and Vision Pro teams ask their friends, "have you tried Velix?"

Three years after:
- Spatial client on Vision Pro and Quest with native interaction model
- Selective ActivityPub bridging for public channels
- Profitable on subscription and small-team plans alone
- Continuing to refuse advertising as a revenue source
