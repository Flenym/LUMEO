# Lumeo — Testing

## Layers

- **Unit** (Backend jest/vitest + iOS XCTest): enums/validation (username regex, status 140 chars, squad max 200), XP/streak engines, ledger invariants, premium plans (only Monthly/SixMonths), feature-flag defaults.
- **Integration** (Backend + Postgres, CI `backend` job with throwaway DB): auth flow + refresh rotation, friends cooldown, session state machine (Draft→…→Finished/Cancelled), squad roles, workshop PendingModeration→Published, ledger append-only (balance change without ledger row must fail), reports clustering. Migrations applied via `scripts/seed.sh` logic (seed-validate step).
- **UI** (XCUITest): `iOSApp/UITests/LumeoUITests.swift` — 7 critical flows (register→verify→profile→Home; search→request→accept; green→yellow→red; create→invite→accept→join→finish; send→receive→read; edit→save→reload; create→moderation→publish→preview) with `--uitesting` launch args + accessibilityIdentifiers; `AdminApp/UITests/AdminUITests.swift` — overview→users→ban→audit (metadata-only assert). Onboarding → Home (who's free in 1–2s) → Play? → session create → accept → banner join → Live Activity; critical paths from CI: `auth/friends/status/session/chat/profile/workshop`.
- **Security**: secrets-guard (`scripts/secrets-scan.sh`, CI job), JWT rotation/reuse, rate-limit probes, upload MIME/size bypass attempts, E2EE negative test (server response contains no plaintext), admin metadata-only test.
- **Visual QA** (CI `visual-qa` job): `scripts/screenshots.sh` collects 10 screens (`Design/screens.md`) → pixel-diff current vs `Design/golden/` baselines, **threshold 5%** per screen; fail if exceeded. While `Design/golden/` is empty the job warns (no baselines yet) and uploads screenshots for review instead of failing.

## CI structure (`.github/workflows/ci.yml`, ground truth)

Concurrency: `ci-${{ github.ref }}`, `cancel-in-progress: true`.

| Job | Runner / timeout | Что делает |
|---|---|---|
| `shared` | ubuntu-latest / 10 мин | `npm ci` в корне → `build` + `typecheck` workspace Shared |
| `backend` | ubuntu-latest / 20 мин, Postgres 16 service | `build` Backend → `npm test --workspace=Backend` → seed-validate: применяет `Backend/migrations/001_init.sql → 002_constraints.sql → 003_seed.sql` на throwaway-БД |
| `ios-build` | macos-15 / 30 мин | newest Xcode + xcodegen → `build-for-testing` обеих схем (Lumeo + LumeoAdmin, iPhone 17, `CODE_SIGNING_ALLOWED=NO`), **без тестов** |
| `ios-lint` | macos-15 / 10 мин, `continue-on-error` | swiftlint best-effort (non-blocking, пропуск если не установлен) |
| `ios-main` | macos-15 / **75 мин** | xcodegen → `build-for-testing` → **unit отдельно** (`-only-testing:LumeoTests`) → **UI отдельно** (`-only-testing:LumeoUITests`, **`-retry-tests-on-failure`**) → `screenshots.sh` (10 экранов, `--no-build`) → upload `ios-screenshots` + оба `.xcresult` |
| `ipa-main` | macos-15 / 30 мин, `needs: [ios-build]` | unsigned `Lumeo-unsigned.ipa` (`build-unsigned-ipa.sh`, Production) → artifact |
| `ipa-admin` | macos-15 / 30 мин, `needs: [ios-build]` | unsigned `Lumeo-Admin-unsigned.ipa` → artifact |
| `secrets-guard` | ubuntu-latest / 5 мин | `scripts/secrets-scan.sh` (без секретов в репо) |
| `visual-qa` | ubuntu-latest / 10 мин, `needs: [ios-main]`, `continue-on-error` | pixel-diff screenshots vs `Design/golden/`, порог 5% на экран; пустой `golden/` = warning |

Ключевое: **unit и UI разделены** (`-only-testing:LumeoTests` vs `LumeoUITests`);
UI ретраится (`-retry-tests-on-failure`); `ios-main` — 75 мин timeout;
**IPA зависят только от `ios-build`**, а не от тестов/всего CI.

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
