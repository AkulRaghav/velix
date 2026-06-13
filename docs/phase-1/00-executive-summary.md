# 00 — Executive Summary

## What we are building

**Velix** is an end-to-end encrypted social messaging platform that treats privacy, performance, and cinematic interaction as non-negotiable defaults — not as features to be unlocked.

The bet: there is no product on the market today that combines Signal's cryptographic seriousness, Telegram's speed, iMessage's polish, Discord's persistent rooms, and Vision Pro's spatial sensibility. Each incumbent owns one corner. Velix lives at the intersection.

## What we are not

- Not another "secure messenger" pitch landing page with a lock icon.
- Not a chat product with a chatbot bolted on for a press cycle.
- Not a feed-and-ad surveillance product wearing dark mode.
- Not a Web3, token, or "decentralized" pitch. Velix is a centralized service operated to behave as if it were not — by knowing as little as possible.

## Why now

1. **The trust market just opened.** Signal's growth post-2021 and the steady erosion of WhatsApp/Meta's privacy posture proved a durable user appetite. Signal still owns the moral high ground but is constrained by donor-funded engineering.
2. **The interaction frontier shifted.** Vision Pro and the broader spatial-computing wave reset what "premium UI" means. Most messengers haven't moved their UI grammar in five years.
3. **On-device AI became viable.** Apple Intelligence, Gemini Nano, MediaPipe, and TFLite landed. Smart-reply, summarization, translation, and moderation can now happen on the phone. That kills the strongest argument against E2E ("but the AI needs to read your messages").
4. **The infra primitives matured.** LiveKit, libsignal-as-a-library, Postgres at scale, NATS, Flutter Impeller. None of this was production-comfortable five years ago.

## North-star principles

1. **Calm by default.** No engagement-maximizing badges, ranks, or red dots.
2. **Trust is a felt material, not a UI element.** Encryption visibility is ambient, not a lock icon.
3. **Identity is yours.** Cryptographic identity, no phone number required, portable across devices.
4. **The room is the product.** Conversation has a place, not just a list.
5. **AI is local first.** Your messages don't leave the device for an LLM unless you ask.
6. **Animation is behavior.** Motion communicates state; it does not perform.
7. **Less, but better.** One signature color. One body type. Three material tiers. Three places we use 3D.

## What ships, when (high-level)

- **Week 8 — Internal alpha:** auth, 1:1 E2E messaging, push, presence.
- **Week 16 — Closed beta:** groups, voice notes, media, multi-device, reactions.
- **Week 24 — Public 1.0:** voice/video calls, stories, AI assistant (on-device), search, app lock.
- **Quarter +1:** communities, live audio, group video calls, AI moderation.
- **Quarter +2:** spatial client (Vision Pro), federated identity, creator tools.

Detail in [04-feature-roadmap.md](./04-feature-roadmap.md).

## How we will know it is working

| Signal | Threshold by 1.0 |
|---|---|
| Cold start (release build, mid-tier Android) | < 800 ms |
| Message send → delivered (p99, same region) | < 250 ms |
| Frame stability during animations | ≥ 99% frames inside 16.6 ms (60 fps) |
| Voice call MOS (mean opinion score) | ≥ 4.0 |
| D30 retention (closed beta) | ≥ 35% |
| App Store first-week rating | ≥ 4.7 |
| Independent security audit | Pass before public 1.0 |

## What this dossier governs

Every later phase — design system, 3D, animation, frontend, backend, security, AI, performance, devops — is judged against this dossier. If a later phase contradicts it, the contradiction is resolved by either updating the dossier with explicit reasoning or by changing the later phase. Drift is the failure mode.
