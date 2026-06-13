# Velix Transparency Report — Template

Public URL: https://velix.app/transparency/<period>

We publish a transparency report **every 90 days**. The first issue ships
90 days after public 1.0. Each report covers the four categories below.

## Period

YYYY-Q1 / YYYY-Q2 / YYYY-Q3 / YYYY-Q4

## What we commit to publish

### 1. Government and law-enforcement requests

| Type | Received | Acted on | Affected accounts |
|---|---|---|---|
| Subpoena (US) | 0 | 0 | 0 |
| Court order (US) | 0 | 0 | 0 |
| National security letter (US) | n/a | n/a | n/a |
| MLAT request (international) | 0 | 0 | 0 |
| Local request (other jurisdictions) | 0 | 0 | 0 |
| Emergency request | 0 | 0 | 0 |

For each type, what we can disclose:
- Number of requests.
- Number we acted on.
- Number we challenged.
- The data we provided (architecturally limited — we cannot provide message content; that's encrypted client-to-client).

### 2. Account actions

| Action | Count |
|---|---|
| Voluntarily deleted by user | 0 |
| Deleted for policy violation | 0 |
| Suspended pending investigation | 0 |

### 3. Take-down requests

Per category: copyright, trademark, defamation, etc.

### 4. Production / security incidents

| Type | Count | Notes |
|---|---|---|
| Public security incidents | 0 | Each linked to a postmortem |
| Audits completed | n | Linked to public reports |
| Vulnerabilities disclosed via bounty | n | High/Critical disclosed after fix |

## Method note

This report is a partial reflection of operational reality. By design,
the architecture limits what we can know about user activity — we don't
read messages, we don't track location, we don't surveil contact graphs
beyond what's required for routing.

Where a number is "n/a," it is because the data does not exist on our
infrastructure (e.g., we cannot count messages because we don't see them
in plaintext).

## Sign-off

Signed by:
- The general counsel.
- The security lead.
- The product release manager.

Each issue is dated and archived; previous issues remain accessible at
`velix.app/transparency/archive`.
