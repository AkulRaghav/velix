# 12 — Store Submission

Apple App Store + Google Play Store. The checklist that turns a tagged build into a published app.

## App Store Connect (iOS)

### One-time setup (before first submission)

- [ ] App Store Connect account: `apps@velix.app`.
- [ ] Bundle ID registered: `app.velix`.
- [ ] App record created in App Store Connect.
- [ ] App Privacy Manifest declared (iOS 17+ requirement).
- [ ] App Tracking Transparency: not requesting tracking permission (we don't track).
- [ ] Sign In with Apple: not used (Velix has its own identity).
- [ ] Push entitlements: standard + VoIP (for calls).
- [ ] Background modes: audio (calls), background fetch, voip.
- [ ] App Group: `app.velix.shared` (for notification service extension).
- [ ] Capabilities: Keychain Sharing (within `app.velix.shared`), Push Notifications, Background Modes.
- [ ] Privacy descriptions in `Info.plist`:
  - `NSCameraUsageDescription`: "Velix uses the camera for video calls and to capture photos to send."
  - `NSMicrophoneUsageDescription`: "Velix uses the microphone for voice and video calls and voice messages."
  - `NSPhotoLibraryUsageDescription`: "Velix accesses photos when you choose to send them."
  - `NSContactsUsageDescription`: "Velix accesses contacts only if you choose to find people you know on Velix. Contact details are matched locally and never sent to our servers in plaintext."
  - `NSFaceIDUsageDescription`: "Velix uses Face ID to unlock your account and verify identity-sensitive actions."

### App Privacy details (App Store Connect form)

We're filling in the privacy questionnaire honestly:

| Category | Collected? | Used for tracking? | Linked to identity? |
|---|---|---|---|
| Contact info (email/phone) | Optional only; HMAC server-side | No | No (server stores HMAC) |
| Health & fitness | No | n/a | n/a |
| Financial info | No | n/a | n/a |
| Location | No | n/a | n/a |
| Sensitive info | No | n/a | n/a |
| Contacts | Optional; on-device matching only | No | No (never sent in plaintext) |
| User content | Yes (encrypted) | No | No (server stores ciphertext) |
| Browsing history | No | n/a | n/a |
| Search history | No (search is on-device) | n/a | n/a |
| Identifiers (account ID) | Yes | No | Yes (it IS the identity) |
| Purchases | Only for in-app purchase via Apple | No | Yes (account ID for entitlement) |
| Usage data | Yes (aggregate, anonymous) | No | No |
| Diagnostics | Yes (crashes, performance) | No | No (PII-scrubbed) |
| Other | None | n/a | n/a |

We are **not** an "advertising" app. We do **not** collect data for tracking. Apple's ATT does not apply.

### Submission per release

Per release (every 2 weeks typically):

- [ ] Build version updated: `1.0.3` (matches semver tag).
- [ ] Build number incremented (monotonic).
- [ ] Localizations updated (release notes per locale at launch: EN, ES, FR, DE, JA, AR).
- [ ] Screenshots updated if UI changed (10 screenshots per device class).
- [ ] App preview video updated if hero flows changed.
- [ ] What's New text drafted.
- [ ] Test instructions for Apple reviewer ("Sign in with test account: ...").
- [ ] Demo account credentials provided to reviewer.
- [ ] Encryption export compliance:
   - Includes encryption: **Yes**.
   - Standard encryption: **Yes** (we use libsignal which is on the standard list).
   - Available for export: **Yes**.
- [ ] App Review notes (any special review instructions).
- [ ] Submit for review.

### Apple review questions we expect

Velix's privacy posture is unusual; we expect Apple to ask:

> "How does the user contact a friend if you don't read their contacts?"

Answer: We offer optional contact discovery (off by default). When enabled, the user's contacts are hashed locally and matched server-side via blinded lookups. The server does not see plaintext contacts.

> "Where is the user's data stored?"

Answer: User content is end-to-end encrypted. Velix's servers store ciphertext only. Local data on the device is encrypted via SQLCipher with a hardware-backed key.

> "Can the user delete their account?"

Answer: Yes. Settings → Account → Delete Account. We honor a 30-day grace period (the user can recover during that time), then delete all server-side data permanently.

### TestFlight before submission

Every release goes through TestFlight first:

```
internal testing → external testing → submit
```

External testing has ~50 active testers (Velix beta cohort). Crashes and feedback observed for 3-7 days before submission.

## Google Play Console (Android)

### One-time setup

- [ ] Play Console account: `apps@velix.app`.
- [ ] Package name: `app.velix`.
- [ ] Signing key: Play App Signing enrolled (Google holds the upload key; we use the upload key locally).
- [ ] Internal testing track set up.
- [ ] Closed testing track for beta.
- [ ] Production track for release.
- [ ] Data safety section completed (parallel to Apple's privacy questions).
- [ ] Permissions declared:
  - INTERNET, ACCESS_NETWORK_STATE
  - RECORD_AUDIO, CAMERA (calls)
  - READ_MEDIA_IMAGES, READ_MEDIA_VIDEO (Android 13+)
  - POST_NOTIFICATIONS (Android 13+)
  - USE_BIOMETRIC, USE_FINGERPRINT (legacy)
  - FOREGROUND_SERVICE (calls)
  - WAKE_LOCK
- [ ] No background-location, no SMS, no call-log, no exact-alarm permissions (we don't need them).

### Data safety form

| Data type | Collected? | Shared? | Optional? |
|---|---|---|---|
| Personal info | name optional, email optional | Not shared | Optional |
| Financial info | none | n/a | n/a |
| Health & fitness | none | n/a | n/a |
| Messages | content end-to-end encrypted | Not shared | Required for the app |
| Photos & videos | only when user attaches; encrypted | Not shared | User-initiated |
| Audio | only during calls / voice messages; on-device or encrypted | Not shared | User-initiated |
| Files & docs | only when user attaches; encrypted | Not shared | User-initiated |
| Calendar | none | n/a | n/a |
| Contacts | optional matching, hashed | Not shared | Optional |
| App activity | aggregate analytics, anonymous | Not shared | Required |
| Web browsing | none | n/a | n/a |
| App info & performance | crash logs, diagnostics | Shared with Sentry (self-hosted) | Required |
| Device or other identifiers | account_id (Velix identity hash) | Not shared | Required for the app |

We declare: data is encrypted in transit, encrypted at rest, the user can request deletion, and **the user's data is end-to-end encrypted**.

### Submission per release

- [ ] versionCode incremented (monotonic).
- [ ] versionName matches semver tag.
- [ ] Release notes per locale.
- [ ] Internal testing track upload first.
- [ ] Internal testing observed for ≥ 24 hours.
- [ ] Promote to closed testing (50-100 beta testers).
- [ ] Beta observation: 3-5 days.
- [ ] Promote to production with staged rollout: 1% → 10% → 50% → 100%.

## Cross-platform considerations

### Compatibility

- iOS minimum: iOS 16. We don't ship to older iOS — Phase 7 cryptographic features rely on Secure Enclave + modern Keychain APIs.
- Android minimum: Android 11. Older versions get a "please update" screen.
- iPad: full support.
- macOS via Mac Catalyst: full support.
- watchOS / tvOS: not in 1.0.

### Localizations at launch

| Locale | App Store metadata | Play Store metadata | App UI |
|---|---|---|---|
| English | yes | yes | yes |
| Spanish | yes | yes | yes |
| French | yes | yes | yes |
| German | yes | yes | yes |
| Japanese | yes | yes | yes |
| Arabic (RTL) | yes | yes | yes |
| Portuguese | post-launch | post-launch | post-launch |

### Marketing assets

- App icon: 1024x1024.
- Screenshots: 10 per device class (iPhone 14 Pro, iPhone SE, iPad Pro 12.9, iPad mini, Android phone, Android tablet).
- App preview video: 30 seconds, no narration, captions only.
- Privacy paper URL: `velix.app/security`.
- Support URL: `velix.app/help`.
- Marketing URL: `velix.app`.

## App review failure handling

If Apple or Google rejects:

```
1. Read the rejection notice carefully.
2. Common reasons + fixes:
   - 4.0 Design: requires UX changes; address in next build.
   - 5.1.1 Privacy: address privacy disclosures (rare; we're conservative).
   - Encryption export compliance: ensure forms match our use of libsignal.
3. Submit fix in the next release; respond to the reviewer's notes.
4. If urgent (security fix), use expedited review (Apple) or escalate to Google.
```

## Release notes localization

Apple and Google both require release notes per locale. We generate:

- English from PR titles.
- Other locales: human translation by a localization vendor or in-house native speaker. Lead time: 24-48 hours.

If we can't get translations in time, fall back to English for all locales (Apple/Google accept this).

## Encryption export compliance

We use libsignal (standard cryptography). Apple's "Year-end self-classification report" is filed annually.

Annual filing tasks:
- Confirm cryptography unchanged (or document changes).
- Submit ERN (Encryption Registration Number) renewal if applicable.
- Update App Store Connect's encryption questionnaire.

## Submission cadence

| Cadence | Driven by |
|---|---|
| Backend: continuous | per Phase 10 doc 10 |
| Mobile: every 2 weeks | natural feature batches |
| Major release: quarterly | feature roadmap |
| Hotfix: as needed | incident response |

## Banned

- Submitting without internal + closed testing.
- Submitting on Friday (Apple's review cycle skips weekends, but the app sits in review longer).
- Submitting during freeze windows.
- Submitting without privacy disclosures complete.
- Submitting binaries built outside CI.
- Submitting without release notes per locale (or English fallback).
- Allowing Apple/Google to hold both the upload + signing keys (we always use Play App Signing).
- Submitting binaries without staged rollout configured.
