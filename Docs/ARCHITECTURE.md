# Lumeo — Architecture

Monorepo layout:

```
iOSApp      — Main app (com.lumeo.app): SwiftUI, iOS 26, Widgets, LiveActivities
AdminApp    — Admin app (com.lumeo.admin): moderation, economy, flags
Backend      — NestJS API, port 5267, PostgreSQL, WebSocket, APNs, local storage (beta)
Shared       — TypeScript contracts (enums/dto/constants/feature-flags), mirror of Swift Models
Design       — theme.json + DESIGN_SYSTEM.md (Liquid Glass rules) + screens.md
Docs         — this documentation + Docs/legal + ACCEPTANCE.md + RELEASING.md
.github      — CI (shared/backend/ios-lint/ios-main/ipa/secrets-guard/visual-qa)
scripts      — build-unsigned-ipa.sh, screenshots.sh, secrets-scan.sh, seed.sh, dev.sh
```

## End-to-end flow diagram (ascii)

```
[Onboarding UI] -- email+password+username --> [Backend /auth/register]
        |                                            |  email code (cooldown+expiry)
        v                                            v
[Verify screen] <-- 200 verify ---------------- [/auth/verify-email]
        |  JWT access(short)+refresh(rotation) -> Keychain (never UserDefaults)
        v
[Home] -- GET /friends?status=free --> "who is free" in 1-2s (2-col cards, pin/sort)
        |
        +-- [Status: green/yellow/red + TTL] -- WS status.update --> friends' Home
        |
        +-- [Session Draft] -- invite card in chat --> invitee Accept/Decline
        |        | system message + banner (join/leave, timer, readiness)
        |        v  Draft→Inviting→Waiting→Ready→Live→Finished/Cancelled
        |   [Live Activity + Widgets(4) + App Intents]
        |
        +-- [Chat 1-1/Squad] -- REST history + WS realtime (typing/receipts/presence)
        |        |  E2EE: device keys + session keys + rotation, vetted stack only
        |        v  server routes opaque ciphertext; metadata = MessageMetadataDTO
        |
        +-- [Squads ≤200, Owner/Admin/Member] -- streak/XP only for REAL joint activity
        +-- [Profile constructor] -- system blocks non-removable, rest reorderable
        +-- [Workshop] -- submit → PendingModeration → Published → preview
        +-- [Wallet EMBER] -- every change via ledger row (append-only, amount≠0)

[AdminApp] -- separate Admin API auth (pre-registered device + Keychain + 2FA)
        |  overview → users → ban/mute → audit log; reports clustered by clusterId
        v  admin sees message METADATA only, never E2EE plaintext

[CloudPub] localhost:5267 --tunnel--> https://REAL-CLOUDPUB-DOMAIN.cloudpub.ru
        (real domain via env/xcconfig only, never hardcoded; TLS terminates at CloudPub)
```

## Flows

### Auth
`email+password+username` onboarding → email code verify (cooldown) → JWT access (short) + refresh rotation → Keychain storage. Optional OAuth (Apple/Google/Discord) behind feature flags; UI must not break when provider credentials are missing. Admin auth is separate: pre-registered device + admin credential in Keychain + mandatory 2FA. No public `/admin` login form.

### Friends
`request → pending → accept/decline`, resend only after cooldown. Lookup by username / QR / profile link / internal code / contacts (iOS permission-gated). Statuses with 3 colors (green/yellow/red) + TTL timers; presence online/away/offline + Last Seen privacy modes.

### Session
`CreateSessionDTO → Draft → Inviting → Waiting → Ready → Live (timer + Live Activity) → Paused/Finished/Cancelled`. Invite rendered as special chat card with Accept/Decline; acceptance posts system message + session banner (join/leave, timer, readiness). Squads (max 200, Owner/Admin/Member) reuse sessions for streak/XP.

### Chat + E2EE
Personal (1-1) and Squad group chats only, no channels. Transport: REST for history + WebSocket (`/ws`) for realtime (typing, receipts, presence, session events). Message bodies are E2EE: client encrypts with verified crypto stack (device keys + session keys + rotation), server stores/routes opaque `ciphertext` only. Server/Admin sees `MessageMetadataDTO` (id, chat, sender, keyId, kind, timestamps) — never plaintext. No dictionary filter in chats (ТЗ §12/§36: filter applies to statuses/profiles/workshop only).

> **E2EE note:** never homebrew crypto. Use a vetted stack (libsignal-style / MLS-capable lib): encrypted attachments, multi-device strategy, secure key deletion, recovery plan. E2EE negative test: server responses must contain no plaintext. Admin review is metadata-only by construction (see `Docs/SECURITY.md`).

### Ledger (wallet/economy)
Currency name configurable (`CURRENCY_NAME`, default EMBER). Beta = admin-issued sandbox, no real-money purchases; StoreKit reserved for later. Every balance change MUST go through ledger (`transaction_id/from/to/item/amount/timestamp/status`); direct SQL balance edits are forbidden (CHECK `amount != 0`, append-only; balance change without a ledger row must fail — covered by integration tests).

### Moderation (no chat filtering)
Word filter applies to: statuses, public profile blocks, squad names/descriptions, workshop titles/descriptions. Chats are NOT filtered; abuse is handled via reports (clustered by `clusterId`), admin review of metadata only, blocks/bans/verification/badges via AdminApp + Admin API. Every admin action writes an audit-log row.

### CloudPub (dev tunnel)
Local backend `http://localhost:5267` is published via CloudPub to `https://REAL-CLOUDPUB-DOMAIN.cloudpub.ru` (placeholder — real domain via env/xcconfig, never hardcoded). iOS `API_BASE_URL`: dev `http://localhost:5267` (via `iOSApp/Config/Development.xcconfig`), beta/prod = real CloudPub HTTPS domain (via `Beta.xcconfig` / `Production.xcconfig`). TLS terminates at CloudPub; backend still validates JWT, rate limits, upload limits. Info.plist keys `APIBaseURL/WSBaseURL/EmberCurrencyName` are injected from xcconfig — see `iOSApp/project.yml` + `AdminApp/project.yml` (xcodegen).
