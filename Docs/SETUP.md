# Lumeo — Setup: от нуля до сервера и 2 unsigned IPA

Цель этого файла: выполнив шаги по порядку, получить
1) рабочий backend на `http://localhost:5267` и
2) два файла `Lumeo-unsigned.ipa` + `Lumeo-Admin-unsigned.ipa`.

Требования: **Node 20+**, **npm**. Для БД — любой PostgreSQL 16 (опционально на старте:
сервер работает и без БД в in-memory/beta-режиме, `/health` покажет `db: degraded`).
Для сборки IPA нужен **Mac + Xcode latest (iOS 26 SDK)** — на Windows IPA берутся
из GitHub Actions (шаг 6).

## 1. Установка зависимостей

```bash
npm install          # корень: workspaces Backend + Shared, единый package-lock.json
npm run build        # сборка Shared (tsc) + Backend (nest build)
npm test --workspace=Backend   # 18 сьютов / 103 теста — должны быть зелёными
```

Ожидаемо: `Test Suites: 18 passed, Tests: 103 passed`.

## 2. Окружение

```bash
cp .env.example .env        # Windows PowerShell: copy .env.example .env
```

Заполнить в `.env`: `DATABASE_URL`, `JWT_SECRET`, `JWT_REFRESH_SECRET`
(`.env` не коммитить — его покрывает `.gitignore`, CI проверяет `secrets-guard`).

`API_BASE_URL` в коде НЕ зашит:
- Dev: `http://localhost:5267` (`iOSApp/Config/Development.xcconfig`);
- Beta/Prod: `https://REAL-CLOUDPUB-DOMAIN.cloudpub.ru` — заменить реальным
  CloudPub-доменом после выпуска туннеля (только xcconfig/env, см. ТЗ §58).

## 3. База данных (опционально, но рекомендуется)

```bash
DATABASE_URL=postgres://lumeo:lumeo@localhost:5432/lumeo ./scripts/seed.sh
# применяет Backend/migrations/001_init.sql → 002_constraints.sql → 003_seed.sql
```

Сид: 19 игр, 8 тем, ранги Wood..Legend, 6 ачивок, 12 feature flags.

## 4. Запуск сервера

```bash
npm run dev
# = npm --workspace Backend run start:dev → http://localhost:5267
```

Проверка в другом терминале:

```bash
curl http://localhost:5267/health
# {"status":"ok","version":"0.1.0","uptime":...,"wsConnections":0,"db":"degraded|configured"}
curl http://localhost:5267/api/v1/version
# {"version":"0.1.0","api":"v1"}
```

Если `db: degraded` — сервер работает без Postgres (in-memory beta-режим).
Офлайн-поведение iOS: баннер «Не удаётся подключиться к серверу» + «Повторить».

Windows PowerShell:

```powershell
npm run dev
curl.exe http://localhost:5267/health
```

## 5. iOS на Mac: проект, симулятор, тесты

```bash
brew install xcodegen
cd iOSApp && xcodegen generate && open Lumeo.xcodeproj        # scheme Lumeo
cd AdminApp && xcodegen generate && open LumeoAdmin.xcodeproj  # scheme LumeoAdmin
```

- Конфигурация **Development** = localhost, **Beta/Production** = CloudPub-домен.
- Симулятор: iPhone 17 (iOS 26 SDK). Подпись выключена (`CODE_SIGNING_ALLOWED=NO`).
- Unit-тесты: `StatusEngineTests … FeedbackStoreTests` (`@testable import LumeoApp`).
- UI-тесты (7 critical flows + admin ban/audit): запускаются с `--uitesting`,
  сеть стабается, элементы ищутся по `accessibilityIdentifier`.

Прогон всего из консоли (Mac):

```bash
./scripts/screenshots.sh --project iOSApp/Lumeo.xcodeproj --scheme Lumeo --device "iPhone 17"
# XCUITests на симуляторе + 10 скриншотов экранов в screenshots/
```

## 6. Две unsigned IPA (конечная цель)

**Вариант А — из GitHub Actions (работает и с Windows):**

1. Закоммить и запушить — CI `CI` стартует сам.
2. Вкладка **Actions → последний зелёный прогон → Artifacts**:
   - `Lumeo-unsigned.ipa` — Main App (`com.lumeo.app`);
   - `Lumeo-Admin-unsigned.ipa` — Admin App (`com.lumeo.admin`);
   - `ios-screenshots` — 10 экранов + `.xcresult`.
3. Или через CLI:
   ```bash
   gh run download --name Lumeo-unsigned.ipa
   gh run download --name Lumeo-Admin-unsigned.ipa
   ```

**Вариант Б — локально на Mac:**

```bash
./scripts/build-unsigned-ipa.sh --scheme Lumeo --project iOSApp/Lumeo.xcodeproj --config Production --output Lumeo-unsigned.ipa
./scripts/build-unsigned-ipa.sh --scheme LumeoAdmin --project AdminApp/LumeoAdmin.xcodeproj --config Production --output Lumeo-Admin-unsigned.ipa
# скрипт печатает размер + SHA256; генерирует .xcodeproj через xcodegen при наличии project.yml
```

⚠️ Обе IPA **unsigned**: сборка проверяется, на реальный iPhone не ставится.
Подпись/TestFlight — отдельным workflow, см. `Docs/RELEASING.md`.

## 7. Shared-контракты

```bash
npm run build --workspace=Shared      # tsc → Shared/dist
```

Swift-модели в `iOSApp` зеркалят `Shared/src/*.ts` вручную — при смене DTO
обновлять обе стороны (проверка: backend `test/*.spec.ts` + iOS `Tests/*Tests.swift`).

## 8. CloudPub-туннель (когда нужен внешний URL)

```bash
cloudpub http 5267
# выданный https://XXXX.cloudpub.ru вписать в Beta/Production xcconfig как API_BASE_URL
```

## Troubleshooting

| Симптом | Причина / лечение |
|---|---|
| `npm ci` падает в CI `unable to cache` | кэш смотрит только на корневой `package-lock.json` (workspaces) |
| xcodegen `Decoding failed at "path"` | в `info:` нужен `path: Info.plist` (`properties` без `path` не декодируются) |
| `xcodebuild: no such destination iPhone 16` | нужен iPhone 17 + Xcode latest (iOS 26 SDK) |
| `LumeoTests: no tests found` | UI-классы живут в отдельном `bundle.ui-testing` таргете (`LumeoUITests`) |
| UI-тест не находит элемент | у элемента нет `accessibilityIdentifier` — сверить id с `*UITests.swift` |
| `/health` → `db: degraded` | нет `DATABASE_URL` — ок для beta, дать Postgres через шаг 3 |
| `secrets-guard` красный | реальный секрет в коде — держать только в `.env` (не коммитить) |
