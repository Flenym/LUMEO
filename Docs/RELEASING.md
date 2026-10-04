# Lumeo — Releasing (как подписать IPA позже)

Beta CI собирает только **unsigned** IPA (`CODE_SIGNING_ALLOWED=NO`) — они не ставятся на iPhone.
Подпись — отдельным workflow с секретами, НЕ в beta CI.

## Что понадобится

- Apple Developer certificate (`.p12`, base64 в секрет `APPLE_CERT_P12`) + пароль (`APPLE_CERT_PASSWORD`).
- Provisioning profiles для `com.lumeo.app` (+ widgets/liveactivity) и `com.lumeo.admin` (секреты `PROFILE_MAIN`, `PROFILE_ADMIN`).
- App Store Connect API key для TestFlight (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`).

## Отдельный signing workflow (набросок, создать позже)

```yaml
# .github/workflows/release-sign.yml (создать при релизе, не сейчас)
# - import certificate (apple-actions/import-codesign-certs)
# - install profiles to ~/Library/MobileDevice/Provisioning Profiles/
# - xcodegen generate (iOSApp + AdminApp)
# - xcodebuild archive -configuration Production CODE_SIGNING_ALLOWED=YES \
#     -archivePath Lumeo.xcarchive
# - xcodebuild -exportArchive -exportOptionsPlist ExportOptions.plist
# - upload signed .ipa / submit to TestFlight (altool / app-store-connect)
```

`ExportOptions.plist` (app-store или ad-hoc) хранить в CI-секрете/репо при релизе.

## Правила

- Секреты подписи — только в GitHub Secrets окружения `release`, никогда в коде/xcconfig.
- Unsigned-артефакты beta CI остаются без подписи всегда (smoke-проверка сборки).
- Перед первым релизом: legal «проверено юристом: ДА», Terms acceptance flow включён (см. `Docs/legal/terms-*.md`).
