# Lumeo Backend

NestJS skeleton (beta): REST `/api/v1`, WebSocket `/ws`, health `/health`.
Без реальной БД — репозитории in-memory, PostgreSQL — через `migrations/001_init.sql`.

## Запуск

```bash
npm i
cp .env.example .env   # Windows: copy .env.example .env
npm run start:dev
curl http://localhost:5267/health
```

Порт: `process.env.PORT || 5267`.

## Миграции

```bash
psql $DATABASE_URL -f migrations/001_init.sql
psql $DATABASE_URL -f migrations/002_constraints.sql
psql $DATABASE_URL -f migrations/003_seed.sql
# или всё сразу: bash scripts/seed.sh
```

002: UNIQUE lower(nickname), триггер лимита Squad 200, hot-path индексы,
каталоги ThemeCatalog/RankThreshold (зеркало Shared constants).
003: 19 игр, 8 тем, ранги Wood..Legend, 6 ачивок, 12 feature flags.

## Streak / XP / Levels

Engines: `streak.engine` (UTC-дни, дубли игнорятся), `xp.engine`
(session_complete 50, message_sent 0 анти-спам, level = floor(sqrt(xp/100))+1,
ранги Wood..Legend + дивизионы I/II/III).
`LevelsService.addXp` — daily cap 200 (кроме achievement/session_complete),
auto-ачивки. Тесты: `test/streak.spec.ts`, `test/xp.spec.ts`, `test/premium.spec.ts`.

## Wallet EMBER (только ledger!)

Баланс — производное `CurrencyTransaction`, прямых UPDATE нет
(`currency-ledger.ts` + CHECK amount != 0).
`transfer` — atomic + idempotency-key, `gift/sell/trade/redeem`,
`openCase` — прозрачная очередь без рандома.
Premium: только Monthly/SixMonths (+Group 3–5, множитель xN).
Тесты: `test/ledger.spec.ts`, `test/currency.spec.ts`.

## Admin API

Guard: `X-Admin-Token` + JWT role=admin + pre-registered device.
Overview/users(ban/mute/verify)/moderation(кластеры)/verification/
economy(grant/revoke)/content/analytics/server/flags/beta.
Каждое действие — в AuditLog. BetaTester закрыт при PUBLIC_RELEASE=true.
E2EE: админ видит только metadata, plaintext запрещён (`assertNoPlaintext`).

## CloudPub заметка

Сервер только слушает `PORT`. Публичный URL задаётся на iOS-клиенте
через `API_BASE_URL` (например `https://<domain>`), на бэкенде ничего менять не нужно.
Если WS режется прокси — клиент падает на REST polling (см. комментарий в `realtime.gateway.ts`).

## API (префикс /api/v1, кроме /health)

auth, users, friends, statuses, games, sessions, squads, profiles,
workshop, wallet (ledger only!), notifications, reports, admin (X-Admin-Token).

## Проверки

```bash
npm run typecheck
npm run build
npm test
```
