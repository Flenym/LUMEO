# Lumeo — Screens (10 для screenshots.sh / golden)

Каждый экран — один вопрос (правило 1–2с), OLED `#000000`, max 1 glass-слой.
Файлы: `screenshots/simctl/<name>.png` (CI) ↔ `Design/golden/<name>.png` (baseline, порог 5%).

| # | name | Вопрос экрана | Ключевые элементы (accessibilityIdentifier) |
|---|---|---|---|
| 1 | `onboarding` | «Как войти?» | `onboarding.register.email`, `onboarding.register.username`, `onboarding.register.submit` |
| 2 | `home` | «Кто свободен?» | `home.freeList`, карточки 2 в ряд, `status.dot`, `tab.home` |
| 3 | `friends` | «С кем играть?» | `friends.search`, `friends.search.result`, `friends.request.send`, `tab.friends` |
| 4 | `session` | «Играем сейчас?» | `session.create`, `session.banner.live`, `session.join`, таймер |
| 5 | `chat` | «Что нового?» | `chat.thread.first`, `chat.composer`, `chat.send`, read receipts |
| 6 | `squad` | «Где мои?» | список Squad ≤200, streak/XP, `session.invite` |
| 7 | `profile` | «Кто это?» | `profile.block.system` (неудаляемые), `profile.edit`, `profile.save`, `tab.profile` |
| 8 | `workshop` | «Что поставить?» | `workshop.create`, `workshop.status.*`, `workshop.preview`, `tab.workshop` |
| 9 | `premium` | «Что даёт Premium?» | Monthly/SixMonths (только они), EMBER-баланс, sandbox-note |
| 10 | `settings` | «Как настроить?» | solid (без glass), Data (удаление/экспорт), legal-ссылки |

Admin (схема LumeoAdmin): `admin` — `admin.overview`, `admin.overview.metrics`, `admin.tab.users`, `admin.tab.audit`.
