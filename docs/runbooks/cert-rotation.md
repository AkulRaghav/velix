# Cert rotation

## Symptoms
Alert `CertExpiringIn14d`. Certificate expiring in <14 days.

## Mitigations
1. cert-manager renewal: confirm Issuer is healthy; force renewal if needed:
   ```
   kubectl annotate certificate <cert> cert-manager.io/issue-temporary-certificate=true
   ```
2. Manual rotation: see docs/phase-10/06-secrets.md.

## Banned
- Allowing certs to expire. Auto-rotation should fire 30 days before expiry;
  the 14-day alert is the safety net.
