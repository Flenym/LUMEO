# Lumeo — Security

- **TLS everywhere**: CloudPub HTTPS in prod; no plaintext auth tokens over HTTP outside localhost dev.
- **Passwords**: Argon2id/bcrypt hash (`password_hash`, never plaintext; DDL-only reference allowed in migrations), email verification codes with cooldown + expiry; login rate-limited.
- **JWT**: short-lived access + rotating refresh; refresh reuse detection → revoke family; logout-all revokes all sessions/devices.
- **Rate limits**: auth attempts, friend-request resend (cooldown), reports, uploads, WS message rate per user/chat (`429` / `error.rate_limited`).
- **Admin isolation**: separate Admin API auth, **pre-registered device** credential in **Keychain**, mandatory **2FA** for admin accounts; no public `/admin` login form; admin sees message *metadata* only (never E2EE plaintext — enforced by API shape + negative UI test). Every admin action (ban/mute/verify/economy/flags) writes an **audit-log** row (who/when/what/why).
- **E2EE**: use a vetted crypto stack (e.g. libsignal-style / MLS-capable lib), never homebrew crypto. Device keys + session keys + rotation, encrypted attachments, multi-device strategy, secure key deletion, recovery plan. Server stores opaque ciphertext; `MessageMetadataDTO` carries no plaintext. Negative tests: server history responses + admin review contain zero plaintext.
- **Upload limits**: avatar/banner/chat media — MIME allowlist, size caps, image re-encode/strip EXIF, video duration cap; local `./storage` on beta, S3-compatible later.
- **Moderation without chat filtering**: dictionary filter only on statuses / public profile fields / squad names / workshop titles; chats unfiltered, handled via clustered reports (`clusterId`) + metadata review.
- **No secrets in repo**: `.env` gitignored; only empty placeholders in root `.env.example` and dummy-only values in `Backend/.env.example`; CI `secrets-guard` (`scripts/secrets-scan.sh`) fails on real `JWT_SECRET=<secret>` values (doc placeholders like `<value>` and dummy markers excluded) / `BEGIN PRIVATE KEY` / assigned `password_hash` values (bcrypt-shaped or quoted, not bare identifiers/DDL) / APNs keys with values; `*.env.example` and migrations DDL excluded.
- **Client storage**: tokens/keys in **Keychain** (never UserDefaults), Face ID app-lock optional, sensitive push content hideable; `--uitesting` fixtures never ship in release builds.
