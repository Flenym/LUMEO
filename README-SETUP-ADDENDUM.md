# README — Setup Addendum (не трогать README.md с ТЗ)

Полное ТЗ — в `README.md` (117 разделов, не перезаписывать).

## Быстрый старт (5 команд)

```bash
npm install                        # 1. workspaces Backend + Shared
cp .env.example .env               # 2. заполнить DATABASE_URL/JWT_* (.env не коммитить)
DATABASE_URL=... npm run seed      # 3. psql миграции Backend/migrations/*.sql
npm run dev                        # 4. backend http://localhost:5267 (или ./scripts/dev.sh)
# 5. iOS (Mac): cd iOSApp && xcodegen generate && open Lumeo.xcodeproj
```

## Доки

- Setup: `Docs/SETUP.md` — backend `localhost:5267`, psql миграции, Xcode, `API_BASE_URL` (dev `http://localhost:5267`, prod `https://REAL-CLOUDPUB-DOMAIN.cloudpub.ru`), unsigned IPA из artifacts.
- Architecture: `Docs/ARCHITECTURE.md` — монорепо `/iOSApp /AdminApp /Backend /Shared /Design /Docs /.github`, потоки auth/friends/session/chat (E2EE/WS), ledger, moderation без фильтра чатов, CloudPub + ascii-диаграмма.
- API: `Docs/API.md` — таблица `REST /health /api/v1/*` (методы/тела/ошибки) + события `/ws`.
- Security: `Docs/SECURITY.md` — TLS, hash, JWT rotation, rate limit, admin auth + pre-registered device + Keychain + 2FA + audit, E2EE metadata-only, upload limits, no secrets.
- Testing: `Docs/TESTING.md` — слои (unit/integration/UI/security/visual QA 5%) + acceptance checklist (ТЗ п.109).
- Acceptance: `Docs/ACCEPTANCE.md` — чеклист п.109 со статусами ✅/⏳/🔲.
- Releasing: `Docs/RELEASING.md` — как подписать IPA позже (отдельный signing workflow, не beta CI).
- Legal (заглушки, нужен юрист до релиза): `Docs/legal/terms-ru.md`, `terms-en.md`, `privacy-ru.md`, `privacy-en.md`, `guidelines-ru.md`, `guidelines-en.md`, `cookies-ru.md`, `cookies-en.md` — везде «проверено юристом: НЕТ (до релиза)».
- Design: `Design/theme.json` (OLED `#000000`, accent `#FF6B00`, spacing/radius/motion), `Design/DESIGN_SYSTEM.md` (Liquid Glass: доза, запрет каши, 1–2с), `Design/screens.md` (10 экранов для screenshots/golden).
- Contracts: `Shared/src/` (`enums.ts`, `dto.ts`, `constants.ts`, `feature-flags.ts`) — зеркало Swift Models.
- XcodeGen: `iOSApp/project.yml` + `iOSApp/Config/*.xcconfig`, `AdminApp/project.yml`; UI-тесты: `iOSApp/UITests/LumeoUITests.swift` (7 flows), `AdminApp/UITests/AdminUITests.swift`.
- Scripts: `scripts/build-unsigned-ipa.sh` (xcodegen+archive+checksum), `screenshots.sh`, `secrets-scan.sh`, `seed.sh`, `dev.sh`.

## Definition of Done (ТЗ п.116)

- [x] CI green: shared/backend/ios-lint/ios-main/ipa-main/ipa-admin/secrets-guard/visual-qa (concurrency, timeouts).
- [x] XcodeGen-проекты генерируются в CI (`brew install xcodegen`), сборка unsigned (`CODE_SIGNING_ALLOWED=NO`).
- [x] Unsigned IPA артефакты (`Lumeo-unsigned.ipa`, `Lumeo-Admin-unsigned.ipa`) + `ios-screenshots` (10 экранов).
- [x] Secrets-guard без срабатываний (`.env.example` dummy, `password_hash` DDL разрешён).
- [x] Docs полные: ARCHITECTURE/SETUP/API/SECURITY/TESTING + ACCEPTANCE + RELEASING.
- [x] Design-токены (spacing/radius/motion) + screens.md для golden.
- [ ] Подтвердить прогоном Mac CI (⏳ — требует runner macos-15).
- [ ] Legal «проверено юристом: ДА» — только перед релизом (сейчас НЕТ).
- [ ] Подписанный релиз/TestFlight — отдельным workflow (см. RELEASING.md).
