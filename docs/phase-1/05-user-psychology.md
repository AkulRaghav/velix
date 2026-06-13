# 05 — User Psychology

We are not optimizing for engagement. We are optimizing for the emotional state of the user during and after using Velix. This document defines who we are designing for, what they feel, and what behaviors we deliberately discourage.

## Personas

We use three. They are not market segments — they are mental models for design decisions. Every screen and interaction is judged against them.

### Persona 1 — Maya, 27, designer, Brooklyn

**Pattern.** Three close-friend chats. One family group. A studio Slack. A Signal install she uses with one journalist source. She has muted Instagram DMs entirely. She loves iMessage tapbacks, hates the green-bubble divide.

**Pain.** "I want to feel close to four people, not connected to four hundred." Notifications are a cognitive tax she pays for fear of missing one important message in a sea of unimportant ones.

**What she values.** Aesthetic quality, identity expression, calm.
**What she fears.** Being on a "weird privacy app" that her friends won't join.
**Velix wins her by.** Looking better than iMessage. Inviting friends with a single QR scan, not a phone-number lookup.

**Design implication.** Velix must look beautiful on first launch. Onboarding is a hero moment. The first message thread must render with a genuine sense of arrival.

---

### Persona 2 — Daniel, 34, software engineer, Berlin

**Pattern.** Daily Signal user. Reads cryptography papers for fun. Has opinions about Matrix vs XMPP. Convinces friends to use Signal and watches them switch back to WhatsApp within a month because Signal "feels old."

**Pain.** He cares deeply about privacy and is tired of choosing between trust and craft.

**What he values.** Auditability, protocol documentation, openness, honesty about threat models, no marketing inflation.
**What he fears.** Marketing claims that exceed engineering reality. Closed protocols. Jurisdictional risk.
**Velix wins him by.** Open-sourcing the cryptographic core under a permissive license, publishing the threat model, commissioning audits, and *not lying* in marketing. He becomes our most effective evangelist.

**Design implication.** A "Privacy & Security" screen that reads like a paper, not like a settings tab. A `/about` page in the app linking to the protocol spec.

---

### Persona 3 — Aisha, 41, journalist, Cairo

**Pattern.** Uses Signal because her sources demand it. WhatsApp for family. Telegram for breaking-news channels she follows. Three burner SIMs.

**Pain.** Operational security is exhausting. She manages three apps with three identity models because none does all the things she needs.

**What she values.** Strong default encryption, disappearing messages with surgical control, multi-device that doesn't break, channels for news consumption, the ability to compartmentalize.
**What she fears.** Forensic adversaries with access to her phone. Metadata leakage. A platform turning hostile under government pressure.
**Velix wins her by.** Being the one app that has all the modes — 1:1 E2E, groups, channels, disappearing — without the trust erosion of opening Telegram.

**Design implication.** Locked profiles, "panic dismiss" gestures, app-lock with biometric, hidden chats, screenshot detection, decoy mode (deferred, but architecturally allowed).

---

## What users feel, in order

Across all three personas, in priority order:

1. **Calm.** This is not a stimulating product. It is a focused product.
2. **Trust.** Confidence that the system is doing what it claims.
3. **Recognition.** That their identity, voice, and aesthetic are theirs.
4. **Care.** That somebody has thought about every screen they see.
5. **Delight.** Sparingly. The product is mostly serene; moments of beauty are earned.

## Behaviors we deliberately discourage

These patterns make money for incumbents. They harm users. We will not chase them.

| Pattern | Why incumbents use it | Why we refuse |
|---|---|---|
| Streaks | Drives daily return | Manufactures anxiety |
| Read receipts on by default | Implies obligation | Conversation isn't a contract |
| Badges and red dots on app icon for non-priority threads | Drives re-open | Most messages are not urgent |
| Infinite scroll feeds inside the messenger | Drives session length | We are not a feed product |
| Public discoverable usernames as default | Easier growth | Spam, harassment surface |
| "Last active" timestamps as the default | Performs presence | Surveillance-grade |
| Algorithmic "important" sorting of threads | Increases re-engagement | Users know which threads matter |
| Notification escalation if ignored | Increases open rate | Hostile to attention |

## Behaviors we deliberately reward

| Pattern | Why |
|---|---|
| Marking a thread as Priority | The user has told us what matters; we honor it |
| Verifying a contact (QR scan) | Material trust state shifts subtly; the relationship feels different |
| Using disappearing messages | We celebrate (silently) that the user thought about retention |
| Adding a second device | Multi-device is liberating; we make it feel like progress |
| Joining a small Space | Communities are healthier small; we make small feel right |

## Onboarding emotional arc

| Moment | Feeling we want |
|---|---|
| App icon tap (cold start) | "Oh — that's quick." |
| Splash | A breath. Not a logo show. |
| Welcome | Curiosity. "This isn't like the others." |
| Identity creation | Quiet competence. "This is mine, and only mine." |
| Pair / import contacts (optional) | Choice, not coercion. |
| First room | Arrival. The app rewards me for being here. |
| Empty state | Possibility, not pressure. |
| First message sent | Tactile satisfaction. |

We will write a separate document in Phase 2 (`onboarding-storyboard.md`) detailing each of these moments at the frame level.

## The "calm" test

Before any feature ships, we ask: **does this make Velix feel calmer or louder?** If louder, the feature has to earn its loudness. Most features cannot.
