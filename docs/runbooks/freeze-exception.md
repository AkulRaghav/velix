# Friday-freeze exception

## Default
No backend deploys Friday afternoon (16:00 PT) → Monday morning (06:00 PT).

## Exception conditions (any one)
- Active P0 incident.
- Critical security fix.
- Manager + on-call lead written approval in Slack `#releases`.

## Process
1. Open a thread in `#releases`. Reason. Risk assessment. Rollback plan.
2. Manager + on-call lead respond with explicit approve.
3. Deploy with three-stage canary; do NOT skip stages.
4. Stay on for the next 90 min minimum.
5. Postmortem: required if any user-impacting issue.

## Banned
- "Just push it through" without the explicit thread + approval.
