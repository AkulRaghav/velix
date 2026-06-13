# Hotfix release

## When
- Critical bug in production needing immediate patch.
- Friday-afternoon freeze can be bypassed (with on-call + manager approval).

## Steps
1. Branch from the production tag (`v1.0.x`), not main.
2. Cherry-pick the fix; verify locally.
3. Tag `v1.0.x+1`; CI runs.
4. Bypass freeze (one-line approval in Slack `#releases`).
5. Three-stage canary anyway: 5% → 25% → 100%.
6. Post-incident: backport to main; postmortem if user-impacting.
