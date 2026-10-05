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
- Beta/Prod: `https://lumeo.cloudpub.ru` — реальный CloudPub-домен,
  туннель смотрит на `localhost:5262` (см. раздел «Два инстанса backend» ниже).

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

### Два инстанса backend

В beta-режиме (in-memory, без Postgres) работают ДВА инстанса:

- `:5267` — dev по ТЗ (`npm run dev`, `http://localhost:5267`);
- `:5262` — за CloudPub-туннелем `lumeo.cloudpub.ru`
  (туннель смотрит на `localhost:5262`).

Запуск второго инстанса (из собранного `dist`):

```bash
npm run build --workspace=Backend
PORT=5262 node dist/main.js
# Windows PowerShell: $env:PORT=5262; node dist/main.js
```

Проверка обоих:

```bash
curl http://localhost:5267/health
curl http://localhost:5262/health
curl https://lumeo.cloudpub.ru/health
# везде: {"status":"ok",...,"db":"degraded|configured"}
```

Оба инстанса — in-memory beta-режим, если нет `DATABASE_URL`
(`/health` покажет `db: degraded` — это ок).

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
2. Артефакты IPA доступны, как только зелёный job **`ios-build`**
   (не обязательно весь CI): вкладка **Actions → нужный прогон → Artifacts**:
   - `Lumeo-unsigned.ipa` — Main App (`com.lumeo.app`);
   - `Lumeo-Admin-unsigned.ipa` — Admin App (`com.lumeo.admin`);
   - `ios-screenshots` — 10 экранов + `.xcresult` (появляется после `ios-main`).
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

Реальный домен: `https://lumeo.cloudpub.ru` → туннель на `localhost:5262`
(второй инстанс backend, см. выше).

```bash
cloudpub http 5262
# проверка: curl https://lumeo.cloudpub.ru/health
```

Выданный домен уже вписан в Beta/Production xcconfig как `API_BASE_URL`
(только xcconfig/env, см. ТЗ §58). Локальный dev по ТЗ остаётся
`http://localhost:5267`.

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
