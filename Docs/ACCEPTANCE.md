# Lumeo — Acceptance (ТЗ п.109)

Статусы: ✅ готово по коду (требует прогона Mac CI для подтверждения) · ⏳ требует Mac CI / ручной проверки · 🔲 за backend/iOS-агентами.

| # | Критерий (ТЗ п.109) | Статус | Чем покрыто |
|---|---|---|---|
| 1 | Регистрация email/username + verify с cooldown; OAuth за флагами, UI не ломается без credentials | ✅ backend verified | `auth.spec.ts` 10 тестов зелёные (cooldown 60с, TTL 10м, lockout 5/15м, rate 5/мин, rotation) + `LumeoUITests.testAuthRegisterVerifyHome` |
| 2 | Home за 1–2 сек «кто свободен»; карточки 2 в ряд, pin/сортировка | ✅ code, ⏳ sim-замер | `HomeView` (секции, сетка 2 в ряд, long-press pin, закрепы сверху); замер — `screenshots.sh` на Mac CI |
| 3 | Статусы 3 цвета + текст ≤140 + таймеры + автовозврат; чаты НЕ фильтруются | ✅ backend verified | `status.spec.ts` + `statuses-tier1.spec.ts` (emoji-off, модерация, expiry, inactive, lastSeen exact/recent/hidden) |
| 4 | Session Draft→Live→Finished/Cancelled, accept/decline/ready, баннер, таймер, Live Activity + 4 виджета + App Intents | ✅ backend verified | `session.spec.ts` + `sessions-tier1.spec.ts` (capacity, block, creator-only, banner/retime); iOS `SessionDetailView` + Live Activity + 10 интентов |
| 5 | Squads ≤200, Owner/Admin/Member, streak только за реальную активность | ✅ backend verified | `squads-tier1.spec.ts` (лимит 200, transfer, invite-all, XP/level/streak) + триггер `squad_member_limit_trg` в 002 |
| 6 | Чаты 1-1 + Squad, E2EE vetted stack, сервер без plaintext; voice/waveform/реакции/reply/receipts | ✅ backend verified | `reports.spec.ts` (USE_E2EE negative), `tier1-e2e` (block), gateway `/ws` 10 событий; iOS `ChatView` voice+waveform+реакции |
| 7 | Профиль-конструктор с неудаляемыми системными блоками; Workshop 5 бесплатных → платные, PendingModeration | ✅ backend verified | `premium.spec.ts` (SYSTEM_BLOCK, feedback guard), `workshop.spec.ts` (5-free, re-moderation, preview safe-data) |
| 8 | Бейджи 7 типов, верификация только из AdminApp; Beta Tester закрывается после релиза | ✅ backend verified | `premium.spec.ts` (admin-only, sponsor gradient); `admin.service.ts` `isPublicRelease()` закрывает BetaTester в 3 местах |
| 9 | EMBER конфигурируема, ledger на каждую операцию, sandbox без реальных денег; Premium только Monthly/SixMonths | ✅ backend verified | `ledger.spec.ts` (atomic, idempotency, negative-block, очередь кейсов) + `currency.spec.ts`; `CURRENCY_NAME` из env |
| 10 | Push по ТЗ §49, quiet/mute/pin; статус-флуд ограничен избранным | ✅ code, ⏳ APNs infra | `notifications.service.ts`: 15 типов, quiet-hours→delayed, mute→dropped, available только favorites, digest throttle 1/ч; доставка APNs — Mac CI + Apple key |
| 11 | Backend `localhost:5267`, CloudPub URL только через env; unsigned IPA из CI, на iPhone не ставится без подписи | ✅ verified | `seed.sh`/`dev.sh`, `build-unsigned-ipa.sh` + ipa-main/ipa-admin artifacts; `scripts/*.sh` syntax OK |
| 12 | 12+, удаление/экспорт данных, жалобы с кластеризацией (`clusterId`); legal проверены юристом до релиза | ✅ code, ⏳ юрист | `reports.spec.ts` (dedup, hash детерминирован); export/delete в Settings; legal-заглушки RU/EN «проверено юристом: НЕТ (до релиза)» |

Visual QA: 10 скринов vs `Design/golden/`, порог 5% (`visual-qa` job; пока golden пуст — warning).
Подпись релиза — отдельно, см. `Docs/RELEASING.md` (не часть beta CI).
