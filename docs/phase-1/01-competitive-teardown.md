# 01 — Competitive Teardown

For each competitor: what they own, where they bleed, what we steal, what we refuse. The point is not to beat them at their own game; it is to identify which mechanics are worth borrowing and which are pathologies disguised as features.

---

## Instagram (Meta)

**Owns**
- Story format and grammar (8–15s, vertical, ephemeral, swipe-to-skip)
- Algorithmic feed engineering (interest graph at scale)
- Creator monetization rails
- Network gravity — the social graph that makes leaving costly

**Bleeds**
- Surveillance-grade data collection. Hostile to privacy posture.
- Ad density crossing the threshold where the product feels like a mall.
- DMs are an afterthought built on a separate stack (the old Messenger fork). Encryption is partial and rolled out grudgingly.
- Engagement-maximizing patterns: pull-to-refresh, infinite scroll, dopamine intermittents.
- Authenticity collapse — power users perform; lurkers consume.

**Steal**
- Story arc (capture → review → publish flow)
- Tap-and-hold to react, double-tap to like (gestural shortcuts)
- "Close friends" concept (different audiences for different content, end-to-end private)
- The composition affordance — Instagram makes posting feel like making something

**Refuse**
- Algorithmic ranking by engagement
- Public-by-default posting
- Ad surfaces in core surfaces
- Stranger-DM defaults

---

## Signal

**Owns**
- The cryptographic gold standard. Double Ratchet, Sealed Sender, sparse metadata.
- Donor-funded — no commercial incentive to weaken security.
- Genuine moral authority in the privacy community.

**Bleeds**
- Visual design feels like a 2014 research project, and the brand knows it.
- Onboarding still leaks user identity to existing contacts ("X joined Signal").
- Group video calls limited and historically unreliable.
- No social layer — discovery, status, presence are minimal.
- Desktop is rough; multi-device sync history is partial.

**Steal**
- Protocol choices (X3DH, Double Ratchet, Sender Keys for groups, Sealed Sender)
- Threat-model honesty in the docs
- Disappearing messages with per-thread granularity
- Safety numbers / verification flow (improve the UI, keep the rigor)
- Funding/governance posture (operate the company so revenue can never compromise privacy)

**Refuse**
- Visual flatness and the "secure means utilitarian" assumption
- Phone number as identity primitive (Signal has begun moving past this; we start past it)
- Treating presence/status as feature creep

---

## Telegram

**Owns**
- Speed. Genuinely fast on commodity hardware.
- Cloud sync of regular chats (not E2E, but useful)
- Bots, channels (broadcast at scale), and 200k-member groups
- Sticker culture and creator ecosystem
- Multi-device, multi-tab, web client all just work

**Bleeds**
- Default chats are NOT E2E encrypted. Only "Secret Chats" are, and they're opt-in, single-device, and obscure.
- MTProto has not earned the same independent-audit confidence as Signal Protocol.
- Spam, scams, and channel-hijacking are systemic.
- Founder governance posture is opaque.
- The trust marketing exceeds the trust reality. Users *think* they have Signal-grade encryption. They do not.

**Steal**
- Speed-first engineering ethos
- Channel concept (one-way broadcast, can be E2E to subscribers via Sender Keys)
- Cloud-sync UX (we deliver this on top of E2E, which is harder, but doable with multi-device key fan-out)
- Sticker / GIF / media handling

**Refuse**
- Opt-in encryption. Velix is E2E by default, no exceptions.
- Marketing security claims that exceed engineering reality.
- Open public groups as a default discovery surface.

---

## Discord

**Owns**
- The persistent room metaphor. Voice channels you walk into.
- Community moderation tooling (roles, permissions, audit logs)
- Identity as a rich profile, not a phone number
- Soft real-time presence (typing, voice activity, status)
- Bot/integration ecosystem

**Bleeds**
- No encryption. Surveillance-grade by architecture.
- Dense to the point of cognitive overload, especially on mobile.
- Aggressive notification model — opt-out instead of opt-in.
- Trust & safety problems at scale (NSFW, harassment, doxxing).

**Steal**
- Persistent voice rooms (LiveKit makes this trivial for us)
- Server / community structure (we call them "Spaces")
- Rich profile with banners, status, accent colors
- Role-based permission model — but stripped down 5x for sanity

**Refuse**
- Notification-by-default
- The "everything in one server tree" cognitive model — we use cleaner room hierarchies
- Custom HTML/CSS profile experiments. Velix profiles use the design system.

---

## Threads (Meta)

**Owns**
- Identity portability from Instagram (the only thing that gave it launch-day users)
- ActivityPub federation as a stated direction
- Clean, text-first composition

**Bleeds**
- Anemic feature set at launch — no DMs, no search for months
- No trust posture distinct from the parent company
- No clear monetization other than eventually-ads
- Attempted to be Twitter without the velocity, then pivoted unclearly

**Steal**
- The willingness to ask whether ActivityPub matters (we will build optional ActivityPub bridges for *public* surfaces in v2.0)
- Clean composer focus

**Refuse**
- The launch-without-features approach

---

## iMessage

**Owns**
- Ubiquitous on the dominant US phone platform
- Excellent perceived quality (animations, tapbacks, Memoji)
- Default end-to-end encryption between Apple users
- Invisible — it just works

**Bleeds**
- Locked to Apple. SMS fallback is a leak channel.
- Closed protocol. No third-party clients, no Linux, no audit transparency.
- Federation through RCS is partial and politically constrained.
- No social layer — purely 1:1 and small-group messaging.

**Steal**
- Animation quality (Tapback, message effects)
- Stickers and Memoji-style identity expression
- The principle of "messaging that doesn't feel like a chat app"

**Refuse**
- Platform lock-in
- Closed protocol

---

## WhatsApp

**Owns**
- Global ubiquity
- Status feature (Stories clone, but everyone uses it)
- Group calls that work for most users

**Bleeds**
- Owned by Meta. Encryption is real, metadata is not protected.
- Phone number identity, with all its fragility.
- Channels feature was a half-Telegram clone.
- Backups historically broke encryption (cloud backups encryption is now opt-in but not default-strong).

**Steal**
- Status (Stories) UX is well-tuned for the family/friend audience
- Voice notes UX

**Refuse**
- Phone-number identity
- Backup-breaks-encryption pattern
- Owner concentration risk

---

## Apple HIG / visionOS / watchOS

Not a competitor — the design ceiling.

**Steal**
- The depth and material system: substrate awareness, dynamic glass, environmental shadow.
- Motion grammar: arrivals decelerate-out, departures accelerate-in, reorientations spring.
- Typography ethic: SF Pro at narrow weight range, optical sizing, tabular numerals.
- Deference (UI defers to content), Clarity (legibility-first), Depth (intentional layering).
- Spatial audio cues — even on phone, audio reinforces UI direction.
- Reduce-motion, Increase-contrast, Dynamic Type — accessibility as first-class.

---

## Linear

Not a competitor — the product-craft ceiling.

**Steal**
- Keyboard-first thinking, command palette as primary nav
- Instant transitions; nothing waits on the network
- Opinionated defaults — fewer settings, better choices
- The aesthetic of restraint. Linear could ship neon and never does.

---

## Nothing OS / Nothing Phone

**Steal**
- Confidence in monochrome
- Restraint as an aesthetic stance

**Refuse**
- The dot-matrix gimmick. We will not do glyph copy.

---

## Arc Browser

**Steal**
- Command bar as a primary navigational primitive
- Sidebar information density
- The "Spaces" concept (could inform our community organization)

---

## Synthesis

The market is currently divided three ways:
- **Trust without polish** (Signal, Session)
- **Polish without trust** (Instagram, Telegram default, Discord)
- **Polish with platform lock-in** (iMessage)

Velix occupies the empty quadrant: **trust *and* polish, cross-platform, open-source-eligible cryptographic core.** That is the strategic frame.
