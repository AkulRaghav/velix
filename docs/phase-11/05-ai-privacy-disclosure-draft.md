# 05 — Public AI Privacy Disclosure (Draft)

> **Status:** Draft. Awaits cryptographer + privacy counsel review.
>
> **Will be published at:** `velix.app/security#ai`
>
> **Length:** Target 4–6 pages.
>
> **Audience:** Privacy-conscious users; researchers evaluating cloud-AI integrations in messaging products; journalists.

---

# Velix AI Privacy

## What this is for

Velix has AI features. Most messaging apps that have AI features compromise their privacy claims by sending user content to a cloud model with the user's identity attached. This document explains how Velix is different.

## What runs where

| Feature | Where it runs | Cloud opt-in required? |
|---|---|---|
| Smart-reply suggestions | On your device | No (it's on-device) |
| Language detection | On your device | No |
| Translation (per message) | On your device | No |
| Translation (long-form, optional) | Cloud, via privacy-preserving relay | Yes, per query |
| Summarization (≤ 200 messages) | On your device | No |
| Summarization (long, optional) | Cloud, via privacy-preserving relay | Yes, per query |
| Live captions on calls | On your device | No |
| AI assistant (open Q&A) | Cloud, via privacy-preserving relay | Yes, per query |
| Moderation in Spaces | On your device of the recipient | No (Space owner enables; runs on your device) |
| Search expansion | On your device | No |

The default state of every cloud-AI feature is **off**. You enable each one in Settings → AI. Once enabled, every cloud invocation still requires a fresh per-query consent gesture — we do not "remember" consent across queries.

## How cloud queries work

When you invoke a cloud AI feature:

1. Your device redacts the text. Email addresses, phone numbers, URLs, contact handles, and other identifying patterns are replaced with placeholders.
2. The redacted text is shown to you in a consent prompt. You see exactly what will be sent.
3. If you confirm, the redacted text is encrypted to our AI gateway's public key and sent through an independent privacy-preserving relay.
4. The relay sees your IP address and an opaque encrypted blob. It cannot read the content.
5. The relay forwards the encrypted blob to our AI gateway. The gateway decrypts and processes the request. The gateway sees the content but not your identity, your IP, or any link back to your account.
6. The gateway forwards the request to a model provider (Anthropic or OpenAI). The provider sees the content but not your identity.
7. The response returns through the same path: provider → gateway → relay → your device.
8. After the response is delivered, the gateway retains nothing about the query. The relay logs only that a request passed through.

This is called **OHTTP** (Oblivious HTTP, RFC 9458) — a standard mechanism for separating "who" from "what."

## What changes about this vs. typical cloud AI

A typical cloud-AI integration looks like:

```
your app (with your account ID and bearer token) → cloud provider
```

The provider knows who you are. They could be compelled to disclose your queries linked to your identity.

Velix's flow:

```
your device → independent relay → Velix gateway → provider
```

- The relay sees your IP but not the content.
- The gateway sees the content but not your IP or your account.
- The provider sees what the gateway forwards but no identity.

To link a query to your identity, an attacker would need to compromise the relay AND the gateway AND collude with the provider. None of these alone is sufficient.

## What the gateway specifically does not do

- It does not log query content.
- It does not retain queries beyond the response window (≤ 30 seconds).
- It does not associate queries with your account, device, or session.
- It does not include any of your identity material in the request to the provider.
- It does not have access to your other conversations, contacts, or settings.

We commit to these properties architecturally. They are verified by our independent privacy audit (link to report once published).

## What the AI assistant specifically cannot do

The AI assistant in Velix is a **read-only Q&A surface**. It can:
- Answer questions you ask it.
- Help you write text you are composing.

It cannot:
- Read your conversations on its own.
- Send messages on your behalf.
- Modify your settings.
- Access your contacts.
- Take any action without your explicit confirmation.
- Remember anything from previous queries.

Each query is a fresh context. There is no "memory" of you. We do not personalize the assistant based on your history.

## Quotas and metering

Cloud AI is metered. Free-tier users get a meaningful but limited number of cloud queries per month; Plus subscribers get more. This is for billing — not for privacy.

The metering itself preserves your privacy: we use anonymous credentials (Privacy Pass-style) so the gateway can verify "this user has quota remaining" without learning who you are.

When you run out of quota, the cloud features are disabled until your quota resets. We do not auto-purchase additional quota; you choose to upgrade or wait.

## What we do not promise

- We do not promise complete anonymity. If you paste a unique phrase that only you would write, your linguistic style is identifying. We redact patterns we can detect (emails, phones); we cannot redact your writing style.
- We do not promise the AI is always correct or safe. AI responses can be wrong, biased, or harmful. Use judgment. Do not rely on AI for medical, legal, or safety-critical decisions.
- We do not promise model providers will never improve their models from training data. We have contractual no-train-on-data clauses with Anthropic and OpenAI for our enterprise traffic. The contracts are linked from this page.

## Provider contracts

Our agreements with Anthropic and OpenAI prohibit:
- Training on data sent through our gateway.
- Logging queries beyond 30 days for safety/abuse purposes (their standard term).
- Sharing query data with their other customers.
- Using query data for any commercial purpose.

The contract texts are summarized at `velix.app/security/ai-provider-contracts`.

## Bandwidth costs

The privacy guarantees come at modest cost:
- Cloud query roundtrip: ~80 ms slower than direct (the OHTTP relay adds one extra HTTPS hop).
- Per-query bandwidth: ~16 KB typical (vs ~8 KB direct), due to OHTTP's padding.
- Per-query CPU: imperceptible.

We accept this trade-off. The defaults push you toward on-device features, which have neither cost.

## Banned features

To prevent future product pressure from compromising the privacy posture, we have architectural rejections for:
- Auto-summarization of conversations without explicit invocation.
- AI-driven inbox sorting based on message content.
- Sentiment analysis of conversations for any purpose.
- Cross-conversation AI context (the AI never sees your other chats).
- Tool-using assistants (in 1.0; tool use will require per-tool gating in v2).
- Federated learning on user content.

These rejections are technical, not corporate policy. The architecture has no path to enable any of them without a complete redesign visible in the open-source code.

## How to verify our claims

- The AI gateway architecture is documented at `velix.app/security/ai-spec` (technical).
- The OHTTP relay agreement is published at `velix.app/security/ai-relay`.
- The provider contracts are summarized at `velix.app/security/ai-provider-contracts`.
- The independent privacy audit of the gateway is published at `velix.app/security/audits/ai-gateway-[date]`.

## Annual privacy audit

The AI gateway is audited annually by an independent firm specializing in privacy reviews. Findings are published in full.

The first audit is scheduled for [date]. The audit firm is [TBD: to be inserted post-engagement].

## What you can do today

- Use only on-device features if you prefer maximum privacy.
- Review per-query consent prompts carefully — you see the redacted text before sending.
- Disable specific cloud features in Settings → AI if you don't want them visible at all.
- Disable AI globally in Settings → AI → Disable AI (no AI affordances appear in the app).

## What we will never do

- We will never auto-send your messages to AI.
- We will never link AI queries to your identity.
- We will never train on your messages.
- We will never sell AI usage data.
- We will never quietly change this posture without 30 days of public notice.

## Contact

- AI privacy questions: `privacy@velix.app`.
- Security issues with the AI pipeline: `security@velix.app`.

---

> **End of public AI privacy disclosure.**
>
> Reviewer notes: this draft is the strictest privacy claim of the public papers — the AI features are the most-tempting place for product pressure to compromise the privacy posture, so the document is conservative and architectural. Cryptographer review should verify (a) the OHTTP description is accurate, (b) the architectural rejections are accurate, (c) the "we do not promise" section honestly reflects limits, (d) the provider-contract terms summary matches the actual contracts when signed.
