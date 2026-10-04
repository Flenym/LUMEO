# Lumeo — API

Base: `{API_BASE_URL}/api/v1` (dev `http://localhost:5267`, prod `https://REAL-CLOUDPUB-DOMAIN.cloudpub.ru`).
Auth: `Authorization: Bearer <jwt>` (short-lived access; refresh via `/auth/refresh`).
Errors: `ApiError { code, message, requestId }` — HTTP codes: `400` validation, `401` no/invalid token, `403` forbidden/role, `404` not found, `409` conflict (cooldown/duplicate), `422` state transition illegal, `429` rate-limited.
Pagination: `?limit=&cursor=` → `Paginated<T> { items, nextCursor }`.

## REST

| Method | Path | Body | Success | Errors |
|---|---|---|---|---|
| GET | `/health` | — | `200 { ok: true }` | — |
| POST | `/api/v1/auth/register` | `{ email, password, username }` | `201 { userId }` + verify code sent | `400` bad email/username, `409` taken |
| POST | `/api/v1/auth/login` | `{ email, password }` | `200 { access, refresh }` | `401` wrong creds, `429` brute-force |
| POST | `/api/v1/auth/refresh` | `{ refresh }` | `200 { access, refresh }` (rotation) | `401` reuse detected → family revoked |
| POST | `/api/v1/auth/verify-email` | `{ email, code }` | `200 { verified: true }` | `400` bad code, `409` cooldown active |
| POST | `/api/v1/auth/logout` | `{ refresh? }` | `200` | `401` |
| GET | `/api/v1/users/me` | — | `200 UserDTO` | `401` |
| PATCH | `/api/v1/users/me` | `{ displayName?, bio?, blocks? }` | `200 UserDTO` | `400` filter hit, `401` |
| GET | `/api/v1/users/:id` | — | `200 PublicProfileDTO` (flag-gated) | `404`, `403` private |
| GET | `/api/v1/friends` | `?status=` | `200 Paginated<FriendDTO>` | `401` |
| POST | `/api/v1/friends/requests` | `{ username }` | `201 { requestId, status: pending }` | `409` cooldown/duplicate, `404` user |
| POST | `/api/v1/friends/requests/:id/accept` | — | `200 { status: accepted }` | `404`, `422` not pending |
| POST | `/api/v1/friends/requests/:id/decline` | — | `200 { status: declined }` | `404`, `422` |
| GET | `/api/v1/status` | — | `200 StatusDTO { color, text, expiresAt }` | `401` |
| PUT | `/api/v1/status` | `{ color, text?, ttl? }` | `200 StatusDTO` | `400` text>140/filter, `401` |
| GET | `/api/v1/games` | — | `200 GameDTO[]` (19 starter) | — |
| POST | `/api/v1/games/custom` | `{ name, ... }` | `201 GameDTO` | `400` filter hit |
| POST | `/api/v1/sessions` | `CreateSessionDTO` | `201 SessionDTO (Draft)` | `400` validation, `401` |
| GET | `/api/v1/sessions/:id` | — | `200 SessionDTO` | `404`, `403` not invited |
| POST | `/api/v1/sessions/:id/accept` | — | `200` + system message + banner | `422` wrong state, `404` |
| POST | `/api/v1/sessions/:id/decline` | — | `200` | `422`, `404` |
| POST | `/api/v1/sessions/:id/ready` | `{ ready: bool }` | `200 SessionDTO` | `422` wrong state |
| POST | `/api/v1/sessions/:id/start` | — | `200 Live` + Live Activity | `422` not all ready (per rules) |
| POST | `/api/v1/sessions/:id/finish` | — | `200 Finished` + XP/streak | `422` not live |
| POST | `/api/v1/sessions/:id/cancel` | — | `200 Cancelled` | `422` terminal state |
| GET | `/api/v1/squads` | — | `200 SquadDTO[]` | `401` |
| POST | `/api/v1/squads` | `{ name, ... }` (max 200 members) | `201 SquadDTO` | `400` filter/size |
| GET | `/api/v1/squads/:id` | — | `200 SquadDTO` | `404`, `403` |
| PATCH | `/api/v1/squads/:id` | `{ name?, desc? }` (Owner/Admin) | `200 SquadDTO` | `403` role, `400` filter |
| POST | `/api/v1/squads/:id/invite-all` | `{ sessionId }` | `200 { invited: n }` | `422`, `403` |
| GET | `/api/v1/chats/:id/messages` | `?limit=&cursor=` | `200` history (E2EE ciphertext only) | `403` not member, `404` |
| POST | `/api/v1/chats/:id/messages` | `MessageMetadataDTO + ciphertext` | `201` | `400` shape, `403`, `429` flood |
| GET | `/api/v1/workshop` | `?filter=all/free/paid/popular/new/official` | `200 Paginated<ItemDTO>` | — |
| POST | `/api/v1/workshop` | `{ title, ... }` | `201 PendingModeration` | `400` filter hit |
| GET | `/api/v1/wallet` | — | `200 { balance, currency }` | `401` |
| GET | `/api/v1/wallet/transactions` | `?limit=&cursor=` | `200` ledger rows | `401` |
| GET | `/api/v1/notifications` | — | `200 NotificationDTO[]` | `401` |
| POST | `/api/v1/reports` | `{ target, reason, context? }` | `201 { clusterId }` | `400`, `429` |
| GET | `/api/v1/flags` | — | `200 { [flag]: bool }` | — |
| GET | `/api/v1/admin/*` | separate admin auth | overview/users/bans/audit/economy | `401` device, `403` role/2FA |

## WebSocket `/ws` events

Handshake: `auth { token }` → `auth.ok` or disconnect.
Client → server: `auth`, `chat.send` (metadata + ciphertext), `chat.typing`, `chat.read`, `presence.update`, `status.update`, `session.accept` / `session.decline` / `session.ready` / `session.join` / `session.leave`.
Server → client: `chat.new` (metadata + ciphertext), `chat.typing`, `chat.read`, `presence.changed`, `status.changed`, `friend.request` / `friend.accepted`, `session.invite` / `session.updated` / `session.started` / `session.finished`, `squad.updated`, `notification.new`, `flag.updated`.

Rate limits apply per user/chat on WS message events (`429`-equivalent `error.rate_limited` frame).
