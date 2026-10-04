# Lumeo — Setup (step by step)

Prerequisites: **Node 20+**, **npm**, **psql** (PostgreSQL client), **Xcode 16+** with iOS 26 SDK (Mac only for iOS builds).

## 1. Install dependencies

```bash
npm install --workspace Shared
npm install --workspace Backend
# or from the root (workspaces): npm install
```

## 2. Environment

```bash
cp .env.example .env
# fill DATABASE_URL, JWT_SECRET, JWT_REFRESH_SECRET (never commit .env)
```

`API_BASE_URL` is NOT hardcoded:
- Dev: `http://localhost:5267` (via `iOSApp/Config/Development.xcconfig` / scheme env).
- Beta/Prod: `https://REAL-CLOUDPUB-DOMAIN.cloudpub.ru` — replace with the real CloudPub HTTPS domain once issued (xcconfig/env only; see ТЗ §58 — no invented URLs in code).

## 3. Database seed

```bash
DATABASE_URL=postgres://user:pass@localhost:5432/lumeo ./scripts/seed.sh
# applies Backend/migrations/*.sql in order via psql
```

Verify: `curl http://localhost:5267/health`.

## 4. Dev run (backend :5267 + iOS hints)

```bash
./scripts/dev.sh
# starts `npm --workspace Backend run dev` (http://localhost:5267)
# and prints the iOS open instructions
```

## 5. Xcodegen (Mac)

```bash
brew install xcodegen
cd iOSApp && xcodegen generate && open Lumeo.xcodeproj        # scheme Lumeo
cd AdminApp && xcodegen generate && open LumeoAdmin.xcodeproj  # scheme LumeoAdmin
```

xcconfig choice: **Development** = localhost, **Beta/Production** = CloudPub domain. Simulator: iPhone 16, iOS 18. `CODE_SIGNING_ALLOWED=NO` is set in `project.yml` so CI builds unsigned.

## 6. Unsigned IPA from CI artifacts

1. GitHub → Actions → CI run → Artifacts → download `Lumeo-unsigned.ipa` (main) or `Lumeo-Admin-unsigned.ipa` (admin), or `ios-screenshots`.
2. Unsigned IPAs are for build verification only — they do NOT install on a real iPhone without signing (see `scripts/build-unsigned-ipa.sh`, signing flow in `Docs/RELEASING.md`).
3. Checksum (`shasum -a 256`) is printed by the build script.

## 7. Simulator run

```bash
./scripts/screenshots.sh --project iOSApp/Lumeo.xcodeproj --scheme Lumeo
# runs XCUITests on iPhone 16 sim + collects 10 screens into screenshots/
```

## 8. Shared contracts

```bash
npm --workspace Shared run build      # tsc → Shared/dist
```

Swift Models in `iOSApp` mirror `Shared/src/*.ts` by hand — update both when DTOs change.

## CloudPub tunnel (example)

```bash
cloudpub http 5267
# copy the printed https://XXXX.cloudpub.ru into your Beta/Production xcconfig as API_BASE_URL
```
