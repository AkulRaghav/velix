# 09 — Monetization

The brief: revenue without surveillance, sustainable without compromise.

## Principles

1. **No advertising.** Ever. Advertising is incompatible with our threat model and our brand.
2. **No data sale.** Ever. We have nothing to sell.
3. **No "freemium that nags."** Free tier is genuinely good. Paid is genuinely better.
4. **No paywalls on safety features.** End-to-end encryption, app lock, disappearing messages, multi-device — all free, forever.
5. **No surprise pricing.** Annual prices honest, single discount tier (annual = 2 months free), student tier.

## Tiers

### Free
Includes everything required for a full, dignified product:
- Unlimited 1:1 and small-group messaging
- E2E encryption with all safety features
- Multi-device (up to 5 devices)
- Voice and video calls (≤ 8 participants)
- Stories
- AI assistant (on-device only)
- 5 GB media storage (rolling 90-day retention; older media re-uploadable from device)

### Velix Plus — ~$5 / month, $50 / year
Adds:
- 100 GB media storage, indefinite retention
- Cloud AI invocations (privacy-preserving, OHTTP-relayed) — meaningful monthly quota
- Custom themes, accent colors, conversation backdrops
- Priority push delivery on degraded networks
- Premium voice transformations and call backgrounds
- Up to 10 devices
- Higher upload size limits (4K video, large documents)

### Velix Spaces — ~$10 / month, $100 / year (per Space owner, not per member)
For people running communities:
- Unlimited Space members up to 5,000
- Advanced moderation tools
- Custom Space branding (within design system)
- Channel monetization tools (subscription channels — creators earn, we take 10%)
- Audit log export
- Per-Space analytics (entirely about activity counts, never content)

### Velix for Teams — ~$8 / user / month
Small-business plan:
- Centralized admin
- SSO (SAML, OIDC)
- SCIM provisioning
- Retention policies (legal-compliance scenarios; user-side controlled, server still can't read)
- Audit log
- 1 TB pooled media

We are *not* targeting enterprise heavily in year 1. Velix for Teams ships if it falls naturally out of Velix Plus engineering. Otherwise, deferred.

## Price psychology

- **$5 / month is the sweet spot.** Above coffee, below Spotify, comparable to YouTube Premium Family share. Frames us as a small monthly indulgence, not a utility.
- **Annual at 2 months free** is the Apple norm and feels honest, not gamified.
- **Student tier at 50% off** is a sustainable acquisition channel for early adopters.

## Revenue projections (rough)

Conservative assumptions: 5% paid conversion of MAU, ARPU $5/month for Plus, $10/month for Spaces (10% of Spaces creators), modest Teams uptake.

| Stage | MAU | Paid users | Monthly revenue (USD) | Monthly cost (USD) | Margin |
|---|---|---|---|---|---|
| Public 1.0 | 100k | 5k | ~$25k | ~$25k | break-even |
| 1M MAU | 1M | 50k | ~$280k | ~$200k | ~30% |
| 10M MAU | 10M | 500k | ~$2.8M | ~$1.8M | ~35% |

These are deliberately conservative. The model is sustainable at 3% paid conversion if costs are managed.

## What this funds

- Continuous independent security audits ($150–250k/year)
- Bug bounty program ($500k/year reserved at scale)
- Open-source maintenance for the cryptographic core
- A team that can refuse pressure to compromise the product

## What this does not depend on

- Investor return timelines that demand 10× exits
- Any user being the product
- Any government contract
- Any single jurisdiction
