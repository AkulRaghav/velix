# Diagrams

Source-of-truth diagrams (mermaid `.mmd` files). Render via:

```
npx @mermaid-js/mermaid-cli -i system-overview.mmd -o png/system-overview.png
```

| File | Subject |
|---|---|
| [system-overview.mmd](./system-overview.mmd) | Three-cell topology, six services, external dependencies |
| [trust-boundaries.mmd](./trust-boundaries.mmd) | Phase 7 doc 03 trust levels (1–4) |
| [send-message-sequence.mmd](./send-message-sequence.mmd) | Sealed-sender send-message hot path |

PNG renders go under `png/` and are regenerated in CI on merge to main.
