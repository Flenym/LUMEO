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

## Visual-чеклисты (будущие golden-критерии)

Общее для всех экранов: полноэкранный фон — solid OLED `#000000` (без blur-стека);
акцент orange `#FF6B00` — max 2 акцентных элемента above the fold;
экран понятен за 1–2 сек (один вопрос из таблицы выше);
max 1 translucent glass-слой на пиксель (только системные материалы), без «стеклянной каши».

### 1. `onboarding` — «Как войти?»
- [ ] OLED-фон `#000000`, форма входа читается за 1–2 сек (email → username → submit).
- [ ] Orange accent только на primary CTA (`onboarding.register.submit`).
- [ ] Ноль glass-слоёв на фоне (solid поверхности; клавиатура системная — не в счёт).

### 2. `home` — «Кто свободен?»
- [ ] Сетка карточек 2 в ряд, статус-доты solid (🟢 `#34C759` / 🟡 `#FFCC00` / 🔴 `#FF3B30`), не glass.
- [ ] Вопрос «кто свободен» считывается за 1–2 сек (секции + закрепы сверху).
- [ ] Glass max 1 слой — только tab bar; список и ячейки solid.
- [ ] Orange accent — max 1 (floating create-session или primary CTA, не оба).

### 3. `friends` — «С кем играть?»
- [ ] Поиск + результат + кнопка запроса видны без скролла, понятно за 1–2 сек.
- [ ] Длинный список — solid ячейки, без per-row glass.
- [ ] Orange accent только на `friends.request.send` (остальное монохром).

### 4. `session` — «Играем сейчас?»
- [ ] Баннер live-сессии + кнопка Join + таймер считываются за 1–2 сек.
- [ ] Glass только на floating Join-пилюле XOR на баннере (solid баннер предпочтителен).
- [ ] Orange accent — только Join/primary CTA; таймер монохром, контраст ≥ 4.5:1.

### 5. `chat` — «Что нового?»
- [ ] Solid фон + solid пузыри; glass только на pinned-баннере XOR на композере, никогда оба.
- [ ] Композер + send + read receipts различимы за 1–2 сек.
- [ ] Orange accent max 1 (кнопка send); пузыри без градиентов/блюра.

### 6. `squad` — «Где мои?»
- [ ] Список Squad + streak/XP читаются за 1–2 сек; строки solid, без glass.
- [ ] Orange accent только на `session.invite`/primary CTA.
- [ ] Без glass-on-glass при раскрытых карточках (max 1 слой на пиксель).

### 7. `profile` — «Кто это?»
- [ ] Системные блоки (`profile.block.system`) визуально отделены и неудаляемы (понятно за 1–2 сек).
- [ ] Edit → save → reload: один primary CTA, orange accent только на нём.
- [ ] Эффекты (showcase/награды) только здесь; фон остаётся solid OLED.

### 8. `workshop` — «Что поставить?»
- [ ] Сетка превью + статусы (`workshop.status.*`) + preview понятны за 1–2 сек.
- [ ] Превью-карточки solid; glass max 1 (только pressed-состояние или CTA).
- [ ] Orange accent только на `workshop.create`/primary CTA, не на каждой карточке.

### 9. `premium` — «Что даёт Premium?»
- [ ] Только два плана (Monthly/SixMonths) + EMBER-баланс + sandbox-note — всё above the fold.
- [ ] Orange accent на выбранном плане/CTA (max 2 акцентных элемента).
- [ ] Текст тарифов/цен контраст ≥ 4.5:1 на solid OLED, без glass-подложек под текстом.

### 10. `settings` — «Как настроить?»
- [ ] Полностью solid экран (без glass вообще): Data (удаление/экспорт) + legal-ссылки читаются за 1–2 сек.
- [ ] Текстово-плотный экран: монохром + orange только на деструктивных/ключевых действиях.
- [ ] Контраст body-текста ≥ 4.5:1 при любом освещении (проверка golden-скриншота).
