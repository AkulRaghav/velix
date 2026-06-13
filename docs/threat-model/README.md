# Threat Model

The canonical threat model is Phase 7 doc 01:
[../phase-7/01-threat-model.md](../phase-7/01-threat-model.md).

Phase 8 doc 01 layers AI-specific threats:
[../phase-8/01-threat-model.md](../phase-8/01-threat-model.md).

This README indexes related artifacts and confirms the contract.

## Properties Velix promises (P1–P16)

Documented in Phase 7 doc 01. Surveyed for survival across all later
phases in [../phase-11/01-cross-phase-consistency.md](../phase-11/01-cross-phase-consistency.md).

## Non-promises (N1–N10)

Equally documented. Velix is explicit about what is **not** guaranteed:
- Not anonymity from a sophisticated traffic-analysis adversary at scale.
- Not protection of metadata that the routing service must observe to route.
- Not endpoint security — a fully compromised device defeats E2EE.
- Not protection if the user shares their backup passphrase.
- Not protection from sender-shaped social engineering.
- Not protection from cloud AI providers under valid legal compulsion (cloud AI is opt-in).
- Not protection if the user explicitly opts to share content with cloud features.
- Not perfect forward secrecy of historical messages decrypted on a paired device.
- Not concealment of the existence of a Velix account from network observers.
- Not protection from denial-of-service via blocking the network entirely.

## Cross-references

| Topic | Phase doc |
|---|---|
| X3DH | [Phase 7 doc 05](../phase-7/05-x3dh.md) |
| Double Ratchet | [Phase 7 doc 06](../phase-7/06-double-ratchet.md) |
| Sender Keys | [Phase 7 doc 07](../phase-7/07-sender-keys.md) |
| Sealed Sender | [Phase 7 doc 09](../phase-7/09-sealed-sender.md) |
| Multi-device pairing | [Phase 7 doc 10](../phase-7/10-multi-device.md) |
| Encrypted backup | [Phase 7 doc 14](../phase-7/14-encrypted-backup.md) |
| Encrypted media | [Phase 7 doc 15](../phase-7/15-encrypted-media.md) |
| LiveKit E2EE | [Phase 7 doc 16](../phase-7/16-livekit-e2ee.md) |
| Push privacy | [Phase 7 doc 13](../phase-7/13-push-privacy.md) |
| AI trust boundary | [Phase 8 doc 01](../phase-8/01-threat-model.md) |
| OHTTP relay | [Phase 8 doc 05](../phase-8/05-ohttp-relay.md) |
| Privacy Pass quota | [Phase 8 doc 13](../phase-8/13-privacy-pass.md) |

## Public-facing summaries

Drafts for external review live in Phase 11:
- [Security paper draft](../phase-11/03-security-paper-draft.md)
- [Privacy paper draft](../phase-11/04-privacy-paper-draft.md)
- [AI privacy disclosure draft](../phase-11/05-ai-privacy-disclosure-draft.md)
