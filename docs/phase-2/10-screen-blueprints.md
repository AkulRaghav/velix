# 10 — Screen Blueprints

Each of the 15 primary screens is rebuilt against the design system. Each has:
- **Substrate** — what's at Z0
- **Z-stack** — what surfaces and at which tiers
- **Motion role** — calm or cinematic, and which patterns
- **Type composition** — the three (or fewer) type sizes used
- **Accessibility note** — anything specific beyond the system defaults
- **Evolution from NexusChat** — what changed and why

---

## 1. SplashScreen

**Substrate.** `substrate.gradient` — `gradient.signature` at full bleed.

**Z-stack.**
- Z0: gradient with sub-pixel grain (1 alpha noise overlay, performance-cheap, prevents banding on OLED)
- Z2: a single Velix mark (custom glyph) at 96 × 96, centered

**Motion role.** Cinematic. The most dramatic single moment in the app's life.

The gradient has three light "scanlines" of slightly higher saturation that pass diagonally across the surface in 2.4 s, once. The mark fades in via `motion.reveal` with a 200 ms delay so the gradient is the visible event, not the logo.

No spinner. The splash is held for as long as the boot takes (target ≤ 800 ms total) and dismissed via `motion.depart` upward.

**Type.** None. Splash is purely visual.

**Accessibility.**
- AT label: "Velix is loading."
- Reduce-Motion: skip scanlines, fade mark in instantly.

**Evolution from NexusChat.** The reference splash had a rotating-logo + pulsing-indicator pattern, which is the cliché. Removed. We use a single graceful gesture instead.

---

## 2. Onboarding

**Substrate.** `substrate.spatial.scene` — Phase-3 3D scene, deferred. For Phase 2 mockup, a per-step gradient backdrop with a sub-floating glass element.

**Z-stack.**
- Z0: spatial scene
- Z2: hero glass card (Tier-2) holding step content
- Z1 (subtly above the card): page indicator dots and the "Next" CTA

**Motion role.** Cinematic. Onboarding is a hero moment.

Each step transition is `motion.lateral` for the card content + `motion.parallax` on the substrate (background shifts at 0.7× the card's slide). The hero glass card's contents stagger-arrive over 240 ms, max 4 staggered children (no Christmas-tree).

**Steps (3 only — fewer than the 4–5 cliché):**
1. **"Yours, end to end."** Trust framing. Background scene: a subtle slow-rotating crystal/key form (Phase 3).
2. **"Calm by default."** Notification framing. Background scene: a soft gradient with floating "rooms" that tilt with device.
3. **"Let's begin."** Identity creation. Background scene: dawn-light gradient that subtly intensifies at this step.

**Type.** Three sizes: `type.display.m` for step heading, `type.body.l` for description, `type.label.l` on the CTA button.

**Accessibility.** Each step is a `Semantics.region` with full description; swipe gesture mirrored as keyboard arrows. Skip button is always present for AT users. Reduce-Motion replaces parallax with cross-fade.

**Evolution from NexusChat.** The reference had a 3-slide carousel with glass cards but used standard fades. We add spatial scene at Z0 (the only screen besides Profile that uses Z0 spatially) and parallax-tied transitions. We remove the small "swipe up" hint visible in the reference because it is condescending.

---

## 3. Login / Identity Creation

**Substrate.** `substrate.solid` — `surface.substrate`.

**Z-stack.**
- Z0: substrate
- Z2: the form (a Tier-2 active card, 320 px wide max, centered with vertical breathing room)
- Z3 (rare): privacy / safety modal if user requests details

**Motion role.** Calm. This is a serious moment, not a cinematic one.

The form fades in once via `motion.reveal`, 280 ms, no flourish. The biometric prompt is OS-native (no custom dialog). The "Create new identity" / "Sign in to existing" choice is a `SegmentedControl` at `type.label.l`.

**Type.** `type.title.l` for the screen title ("Welcome to Velix"); `type.body.m` for sub-instructions; `type.label.l` for the CTA.

**Accessibility.** Identity-creation flow announces each successful step via `LiveRegion`. The cryptographic-key visualization is purely decorative; AT-only users get a textual "Your identity is protected" instead.

**Evolution from NexusChat.** We remove the biometric-as-a-button pattern and route to OS-native biometric instead (Apple/Google guideline). We add a single subtle copy that frames the moment ("This identity is yours; we never see it"). We do not show the password strength meter as a colored bar — we use a copy-only "Strong / Stronger" label.

---

## 4. HomeScreen (Feed)

**Substrate.** `substrate.solid`.

**Z-stack.**
- Z0: substrate
- Z2: stack of feed cards (Tier-1 cards)
- Z2: stories rail at the top (one Tier-1 wide card containing horizontally-scrollable IdentityCapsule.lg with story-progress rings)
- Z1: floating nav

**Motion role.** Calm.

The feed scrolls with `motion.parallax` linking the story rail's background gradient (subtle, 0.5× scroll factor). Pull-to-refresh has a single elegant spring with the Velix mark (small, custom) appearing at peak tension and resolving via `motion.lift`/`motion.settle`. No infinite-scroll auto-load animations beyond a `Loader.pulse` skeleton at the bottom.

**Type.** Three sizes per card: `type.body.l` (post body), `type.body.s` (timestamp + meta), `type.label.s` (badge / count, e.g., "12 reactions").

**Accessibility.** Feed cards have full Semantics composition: author, timestamp, content, action affordances. Story-rail items announce "Story from {name}, tap to view."

**Evolution from NexusChat.** The reference had Instagram-style infinite-scroll with engagement-maximizing affordances. We re-frame: the feed is **chronological**, no algorithm, opt-in only (the user follows accounts). The "stories" rail uses our IdentityCapsule.lg pattern with our story-progress glyph (custom). Likes are per-post quiet counts; we don't show a heart that fills with neon. Reactions are the system reactions (six emojis), not Instagram-mass-likes.

---

## 5. ChatsScreen (Conversation List)

**Substrate.** `substrate.solid`.

**Z-stack.**
- Z0: substrate
- Z2: list cells (full-bleed, no card surface — visual rhythm comes from cell separation alone)
- Z1: a top header (Tier-2 active material) with title "Chats" + search trigger
- Z1: floating nav

**Motion role.** Calm. This is the most-visited surface; minimal motion.

New incoming messages cause the relevant cell to rise to the top of the list with `motion.lateral` (no scale, no flash). Unread state is a `accent.signature.30` 6 × 6 inset dot at the right of the cell, never a number badge. The conversation room color is a 4 px vertical accent bar at the leading edge of the cell, at 24% opacity (subtle).

**Type.** Three sizes per cell: `type.body.l@600` (name), `type.body.s` (preview), `type.numeric.tabular@body.s` (timestamp).

**Accessibility.**
- Each cell: `Semantics(label: "{name}, {time}, {preview}, {n} unread")`.
- Swipe-actions exposed as Semantics custom actions ("Archive", "Mute", "Delete").
- Floating AI button (lower right, partial-modal trigger): a single round Tier-2 IdentityCapsule with the AI assistant glyph; `Semantics(button: true, label: "AI assistant")`.

**Evolution from NexusChat.** The reference uses pill-shaped unread badges with numbers — we replace with a quiet inset dot and rely on cell ordering for "this is unread." The reference's online-indicator dot becomes our `AmbientPresence` notch on the avatar (negative-space rather than added decoration). The room-color accent bar is new — it gives every conversation an ambient identity beyond the avatar.

---

## 6. ChatScreen (Conversation)

**Substrate.** `RoomBackdrop` driven by the conversation's room color, optionally a user-uploaded backdrop image (subtly desaturated to 60%).

**Z-stack.**
- Z0: RoomBackdrop
- Z1: conversation header at top (Tier-2 active material, contains IdentityCapsule.sm + trust-shield + call/video buttons)
- Z2: scrollable message bubbles
- Z1: composer at bottom (Tier-2 active material with input + voice + attach + send)

The floating nav **hides** in this screen via `motion.depart` because the conversation is immersive within its own room.

**Motion role.** Mostly calm. Message arrivals are subtle `motion.arrive`. The hero moment is the *first time the user enters a verified conversation* — the room color fades up over the substrate via `motion.reveal` at 600 ms (the only deliberately-slow motion in the system). Subsequent visits skip this and use the standard 240 ms reveal.

Long-press a bubble: `motion.lift` of the bubble + `ReactionPicker` at Z3.

Send a voice note: the composer expands to a Tier-2 lifted bubble with `WaveformPlayer` + cancel + send affordances; release sends.

**Type.** Three sizes max: `type.body.l` (bubbles default), `type.body.s` (timestamps + delivery), `type.body.s@500` (system messages).

**Accessibility.**
- The conversation is announced as "{name}, conversation, {n} unread, {trust state}."
- Message bubbles read in chronological order with author + content + time + delivery state.
- Trust-state changes raise a `LiveRegion` ("encryption verified" / "device key changed").
- Voice messages have a transcript option (on-device speech-to-text) — invoked by long-press + "Transcribe."
- Reduce-Motion: bubble arrivals are pure cross-fade; reactions appear instantly without source animation.

**Evolution from NexusChat.** The reference shows standard chat-bubble UI. We add: room backdrop, trust-tinted header material, custom encryption-shield glyph (replacing the lock), reactions row using our six-emoji set, and the implicit-tail chamfer instead of glyph tails. We hide the floating nav (the reference kept it visible). The composer is restructured so voice and send are visually equal (the reference treated voice as an afterthought).

---

## 7. VoiceMessageScreen

This is *not* a separate screen in our design — it is a Tier-3 lifted overlay invoked from the composer's voice-record affordance. We list it here because the master plan does.

**Substrate.** Inherits from the underlying ChatScreen, dimmed to 70% saturation + 8 px additional blur.

**Z-stack.**
- (underlying Z0–Z2 dimmed)
- Z3: lifted overlay containing record control + WaveformPlayer + duration timer + cancel/send

**Motion role.** Cinematic in the local sense: the WaveformPlayer is the centerpiece.

Record start: WaveformPlayer fades in (`motion.reveal`), bars driven by audio amplitude. Record button has a sub-pixel halo of `accent.signature.30` at 18% (`shadow.glow` exception #2). Time counter at `type.numeric.tabular`. Drag-to-cancel (slide left) and drag-up-to-lock (Telegram-pattern, well-loved). On send, the overlay collapses into the composer's voice bubble via Hero-equivalent.

**Type.** `type.label.l` ("Recording"), `type.numeric.tabular@body.l` (timer), `type.label.m` ("Slide to cancel").

**Accessibility.**
- The record button is a press-and-hold control; AT users get an alternate "tap to start, tap to stop" mode invoked when AT is detected.
- Recording state is announced and the duration is updated as `LiveRegion` once per second, not continuously.
- Cancel and send have explicit Semantics-actions.

**Evolution from NexusChat.** The reference has a static waveform visualization; ours samples actual amplitude. We add slide-to-cancel and slide-up-to-lock (the established Telegram convention). The record-button halo is the only glow we permit on this surface.

---

## 8. StoriesScreen

**Substrate.** `substrate.media.video` or `.image` — full-bleed user content.

**Z-stack.**
- Z0: media
- Z1 (top): progress-rings strip + author overlay (Tier-2 active, narrow band)
- Z1 (bottom): reply composer, hidden until tap

**Motion role.** Cinematic. Vertical-immersive surface. The floating nav hides; the device feels in another mode.

Sibling-story navigation via `motion.lateral` with a parallax of the ring strip (it slides at 1.0×; the underlying media at 0.85×, creating a depth illusion). Tap-pause is instant; long-press scrubs. Drop down to dismiss returns to the previous screen via `motion.depart` downward, with content scaling down 0.92.

**Type.** `type.title.s` (author name), `type.body.s` (timestamp), `type.body.l` (caption if present, single-line, with a 12-px horizontal padding).

**Accessibility.**
- Each story has a textual description (alt-text) provided by the author or auto-derived.
- AT users have a "List view" alternative accessible from a long-press: shows stories as a vertical list of captions and links.
- Tap-to-pause and swipe-to-dismiss have explicit Semantics-actions.
- Reduce-Motion eliminates parallax and progress-ring fill animation; ring fills instantly.

**Evolution from NexusChat.** The reference followed Instagram's grammar. We keep the established progress-ring pattern (it's a UI primitive at this point) but our progress glyph is custom. We add the parallax and the dismissal motion. We remove the message-reaction-spam pattern (no double-tap-to-heart), reactions on stories use the six-emoji system reactions and arrive via `motion.arrive` from the bottom.

---

## 9. ProfileScreen

**Substrate.** Custom — top 320 px is a `RoomBackdrop` with a Phase-3 spatial scene (the second of three places we use 3D); below that is `substrate.solid`.

**Z-stack.**
- Z0: backdrop (top section)
- Z2: identity card overlapping the backdrop seam (40 px overlap), Tier-1 quiet
- Z2: stats row, recent activity grid
- Z1: floating nav

**Motion role.** Cinematic on first view post-edit, calm on subsequent views.

The spatial scene at top tilts subtly with device gyro (`motion.parallax` 0.7×), and on first arrival materializes via `motion.reveal` 480 ms. Edit Profile button: `motion.lift` partial on press, transitions to a Tier-3 modal for editing.

**Type.** `type.display.s` (user name), `type.body.l` (bio), `type.label.m` (action buttons), `type.numeric.tabular@body.s` (stats).

**Accessibility.** Identity card is fully announced with name + bio + verification state. Stats are individually labeled ("12 contacts," "4 active spaces"). Spatial scene is decorative; AT-only users get a textual identity affirmation in its place.

**Evolution from NexusChat.** Reference is a flat profile with stat row. We add: spatial backdrop, RoomBackdrop integration, identity overlap, separation between identity (top) and activity (bottom). We remove the "edit profile" pencil-icon-on-avatar pattern; the entire identity card has a long-press → "Edit profile" custom action.

---

## 10. NotificationsScreen

**Substrate.** `substrate.solid`.

**Z-stack.**
- Z0: substrate
- Z2: notification cells, grouped by section
- Z1: top header
- Z1: floating nav

**Motion role.** Always calm. Never cinematic.

Sections fade in once via `motion.reveal` on screen entry. New notifications arriving: subtle `motion.arrive`, never an animated unfurl. Swipe-to-dismiss with gesture-driven `motion.depart`.

**Type.** `type.body.l` (notification body), `type.body.s` (timestamp), `type.label.s` (group label, e.g., "Today").

**Accessibility.** Each cell is announced fully. Empty state ("Nothing new") is friendly but not performative.

**Evolution from NexusChat.** Reference uses categorized rows ("Today / Earlier"). We keep that. We change: no animated heart icons or confetti for "achievements" — those are banned patterns. We add: the option to auto-bundle non-priority into a single "12 routine notifications" cell that expands to detail.

---

## 11. ExploreScreen

**Substrate.** `substrate.solid`.

**Z-stack.**
- Z0: substrate
- Z2: top: search input (Tier-1 quiet, large)
- Z2: trending topics, suggested users
- Z1: floating nav

**Motion role.** Calm.

Search field focus: `motion.reveal` of an autocomplete sheet (Tier-3) anchored to the search field's bottom edge.

**Type.** `type.title.s` (section heading), `type.body.l` (topic name), `type.body.s` (description / count).

**Accessibility.** Topics are announced as "Topic, {name}, {count} discussions, tap to explore."

**Evolution from NexusChat.** Reference has a vibrant discovery feed. We dial it down: discovery is opt-in, no algorithmic "recommended for you" by default, no "trending" without the user's explicit subscription to discovery. The visual rhythm is preserved but the substance is calmer.

---

## 12. SettingsScreen

**Substrate.** `substrate.solid`.

**Z-stack.**
- Z0: substrate
- Z2: settings groups (Tier-1 quiet cards, each containing rows)
- Z1: top header

**Motion role.** Always calm. **Linear-grade restraint here**.

Tap a group row: a forward `motion.lateral` (push) to the detail screen. No "toggle row that animates a child reveal." If a setting needs sub-settings, it is a forward navigation.

**Type.** Three sizes per row: `type.body.l` (label), `type.body.s` (description, optional), and the trailing control (Toggle, chevron, or value).

**Accessibility.** Each row has `Semantics(label, hint, value, button: true)` where appropriate. Toggle rows announce both the label and the on/off state.

**Evolution from NexusChat.** Reference uses categorized groups with chevrons and toggles, which is correct. We remove ornamental icons next to every settings row (a Material vibe we don't share); icons are reserved for category headers. We add: a "Privacy & Security" entry at the top with a custom encryption-shield glyph.

---

## 13. PrivacyScreen

**Substrate.** `substrate.solid`.

**Z-stack.**
- Z0: substrate
- Z2: hero card at the top with the encryption-shield glyph, "End-to-end encrypted," and a one-line affirmation
- Z2: settings groups
- Z1: top header

**Motion role.** Calm.

The hero card's glyph has a single sub-pixel material tremor only when the user has a `trust.rekeyed` event open across any conversation; otherwise it is still. (This is the second use of the tremor in the system, after conversation surfaces.)

**Type.** `type.title.l` (hero), `type.body.l` (affirmation), `type.body.s` (helper text on toggles).

**Accessibility.**
- The hero card is announced as "End to end encrypted. Your messages are readable only by you and the people you message."
- Each privacy toggle has a long-form description available via long-press / AT custom-action ("Learn about this setting").
- Active session list is fully announced per session ("Device: {name}, last active {time}, on {region}").

**Evolution from NexusChat.** Reference uses a privacy/settings hybrid. We elevate it to a first-class screen, with the encryption-shield as hero. We add: "Read more about our security" linking to a long-form document modeled like a paper, not a settings tab.

---

## 14. VideoCallScreen

**Substrate.** `substrate.media.video` — remote video full-bleed.

**Z-stack.**
- Z0: remote video (or grid of remote videos for ≥3 participants)
- Z1 (top): minimal call header (Tier-2 active narrow band): participant count + duration + "encrypted" indicator (custom encryption-shield, not a lock)
- Z1 (bottom): call controls bar (Tier-2 active, 5 round buttons: mute, video, screen-share, leave, more)
- Z3: invoked when needed — participant info, settings, raise hand, etc.

**Motion role.** Cinematic on connect and disconnect.

Connect: `motion.reveal` of the entire scene materializing — local + remote videos cross-fade in over 480 ms while the call header and control bar slide up from the bottom. The accent.signature glow appears around the speaker's tile (`shadow.glow` exception #1) and rotates between speakers as activity changes (cross-fade between glows, not a hard switch).

Disconnect: `motion.depart` of the scene with a reverse cross-fade, 360 ms; the screen returns to the underlying surface.

**Type.** `type.label.l` (control labels, optional, on long-press info), `type.numeric.tabular@body.s` (call duration).

**Accessibility.**
- Each participant tile announces "Video from {name}, {muted/unmuted}, {speaking/silent}."
- Speaker change is announced by `LiveRegion` only on actual speaker turn-take (debounced; not on every micro-utterance).
- Call controls have explicit Semantics labels and 56 × 56 hit-targets.
- Captions are available via the More menu (Phase 8 AI).
- Reduce-Motion: connect-scene materialization becomes a single 200 ms fade.

**Evolution from NexusChat.** The reference is correct in posture (glassmorphism controls, full-bleed video). We add: trust-state header (the call header explicitly indicates whether the call is E2EE or SFU-trust mode), speaker spotlight via material rather than a colored ring, and the cinematic connect/disconnect.

---

## 15. AIAssistantScreen

**Substrate.** Tier-3 sheet over the underlying screen — meaning, the AI assistant is **not a full-screen surface** in 1.0; it is a `BottomSheet` at `medium` detent that can drag to `large`.

**Z-stack.**
- (underlying Z0–Z2 dimmed)
- Z3: BottomSheet containing AI conversation
- Optional Z3: BottomSheet expands to large detent for in-depth assistance

**Motion role.** Calm by default; AI streaming is a `motion.reveal` per token (60 ms fade per token, 12 ms gap).

Open: BottomSheet `motion.arrive`. The first invocation has a 320 ms `motion.reveal` of an "On-device assistant" affirmation banner at top of the sheet (subsequent invocations skip).

**Type.** `type.body.l` (AI response body), `type.body.s` (meta — "Running on device"), `type.label.l` (quick-action chips).

**Accessibility.**
- AI streaming responses are NOT announced token-by-token (deafening); the full response is announced once, complete.
- An "AI thinking" Semantics live-region is announced on initial query and on completion.
- Quick-action chips have explicit labels.
- The "Powered by on-device" or "Cloud invocation, ephemeral" status is announced explicitly per query.

**Evolution from NexusChat.** Reference treats AI as a separate screen. We re-frame it as a sheet so it lives *within* the user's current context (a chat, a settings screen) — the AI sees the context if and only if the user explicitly invokes it on that context. We add: per-query trust framing (on-device vs cloud), and the explicit "no logs" affirmation.

---

## Cross-screen audit checklist

Every screen must:

- [ ] Use at most 4 Z-tiers.
- [ ] Use at most 3 type sizes (label.s for badges allowed as a 4th).
- [ ] Use exactly one accent on screen (in CTAs, focus rings, or active states — not mixed).
- [ ] Respect 24 px screen edge inset (or per-screen rule above).
- [ ] Have a Reduce-Motion variant verified.
- [ ] Have a Reduce-Transparency variant verified.
- [ ] Have accessibility-tree fully composed (no `Semantics(excludeSemantics: true)` leaks).
- [ ] Pass the contrast verification grid in `12-accessibility.md`.
- [ ] Use motion patterns from the seven, no exceptions.

A screen failing any item above is reviewed before it ships.
