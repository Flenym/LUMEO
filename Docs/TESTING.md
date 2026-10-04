# Lumeo — Testing

## Layers

- **Unit** (Backend jest/vitest + iOS XCTest): enums/validation (username regex, status 140 chars, squad max 200), XP/streak engines, ledger invariants, premium plans (only Monthly/SixMonths), feature-flag defaults.
- **Integration** (Backend + Postgres, CI `backend` job with throwaway DB): auth flow + refresh rotation, friends cooldown, session state machine (Draft→…→Finished/Cancelled), squad roles, workshop PendingModeration→Published, ledger append-only (balance change without ledger row must fail), reports clustering. Migrations applied via `scripts/seed.sh` logic (seed-validate step).
- **UI** (XCUITest): `iOSApp/UITests/LumeoUITests.swift` — 7 critical flows (register→verify→profile→Home; search→request→accept; green→yellow→red; create→invite→accept→join→finish; send→receive→read; edit→save→reload; create→moderation→publish→preview) with `--uitesting` launch args + accessibilityIdentifiers; `AdminApp/UITests/AdminUITests.swift` — overview→users→ban→audit (metadata-only assert). Onboarding → Home (who's free in 1–2s) → Play? → session create → accept → banner join → Live Activity; critical paths from CI: `auth/friends/status/session/chat/profile/workshop`.
- **Security**: secrets-guard (`scripts/secrets-scan.sh`, CI job), JWT rotation/reuse, rate-limit probes, upload MIME/size bypass attempts, E2EE negative test (server response contains no plaintext), admin metadata-only test.
- **Visual QA** (CI `visual-qa` job): `scripts/screenshots.sh` collects 10 screens (`Design/screens.md`) → pixel-diff current vs `Design/golden/` baselines, **threshold 5%** per screen; fail if exceeded. While `Design/golden/` is empty the job warns (no baselines yet) and uploads screenshots for review instead of failing.

## Acceptance criteria checklist (ТЗ п.109)

- [ ] Регистрация email/username + verify с cooldown; OAuth за флагами, UI не ломается без credentials.
- [ ] Home за 1–2 сек отвечает «кто свободен»; карточки 2 в ряд, pin/сортировка.
- [ ] Статусы 3 цвета + кастом текст ≤140 + таймеры + автовозврат; чаты НЕ фильтруются.
- [ ] Session: Draft→Live→Finished/Cancelled, accept/decline/ready, баннер, таймер, Live Activity + виджеты 4 типа + App Intents.
- [ ] Squads ≤200, Owner/Admin/Member, streak только за реальную совместную активность.
- [ ] Чаты 1-1 + Squad, E2EE проверенным стеком, сервер без plaintext; voice/waveform/реакции/reply/read receipts.
- [ ] Профиль-конструктор с неудаляемыми системными блоками; Workshop: 5 бесплатных до платных, PendingModeration.
- [ ] Бейджи 7 типов, верификация только из AdminApp; Beta Tester закрывается после релиза.
- [ ] EMBER конфигурируема, ledger на каждую операцию, sandbox без реальных денег в бете; Premium только Monthly/SixMonths.
- [ ] Push-события по списку ТЗ §49, quiet/mute/pin; статус-флуд ограничен настройкой избранного.
- [ ] Backend `localhost:5267`, CloudPub URL только через env; unsigned IPA собирается в CI, на iPhone не ставится без подписи.
- [ ] 12+, удаление/экспорт данных, жалобы с кластеризацией; legal-заглушки проверены юристом до релиза.

Full per-item status with evidence: see `Docs/ACCEPTANCE.md`.
