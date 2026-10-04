# Название приложения и админ-приложение Lumeo

> **Быстрый старт — за 10 минут до рабочего сервера и 2 unsigned IPA:**
> 1. `npm install` — ставит Backend + Shared (workspaces).
> 2. `npm run build` — сборка Shared + Backend.
> 3. `npm run dev` — сервер на `http://localhost:5267` (проверка: `curl http://localhost:5267/health`).
> 4. IPA: локально на Windows не собираются (нужен macOS + Xcode) — забери готовые из GitHub Actions: вкладка **Actions → последний зелёный CI → Artifacts → `Lumeo-unsigned.ipa` + `Lumeo-Admin-unsigned.ipa`**. На Mac: `./scripts/build-unsigned-ipa.sh --scheme Lumeo --project iOSApp/Lumeo.xcodeproj --output Lumeo-unsigned.ipa` (и то же для `LumeoAdmin`).
> 5. Полный пошаговый runbook: [`Docs/SETUP.md`](Docs/SETUP.md). Контракты API: [`Docs/API.md`](Docs/API.md). Acceptance-чеклист: [`Docs/ACCEPTANCE.md`](Docs/ACCEPTANCE.md).
>
> ⚠️ Unsigned IPA — только для CI/инспекции, на реальный iPhone не ставится (нужна подпись, см. `Docs/RELEASING.md`).

# Техническое задание на iOS-приложение для друзей и игровых компаний

## 0. Рабочая концепция

Рабочее название проекта: `PROJECT_NAME` — финальное название выбирается отдельно.

Тип продукта: нативное iPhone-приложение для небольших компаний друзей, школьных/студенческих компаний и игровых групп.

Главная идея:

> Объединить друзей в одном месте, чтобы быстро понимать, кто сейчас свободен, кто занят, кто играет, кого можно пригласить и когда лучше собрать совместную игру.

Приложение не должно позиционироваться как «замена Telegram» или публичная социальная сеть на старте.

Основной сценарий:

`Открыл приложение → увидел друзей и их статусы → понял, кто свободен → нажал «Поиграем?» → создалась игровая Session → друзья приняли → все вошли в Session → играют вместе → Session завершилась → обновились история, XP, streak и статистика.`

На первом этапе приложение закрытое и рассчитано в первую очередь на друзей. Позже должна быть возможность включить публичный режим поиска игроков.

---

# 1. Целевые платформы

Основная платформа:

* iPhone;
* iOS 26 и выше;
* Swift;
* SwiftUI;
* современная архитектура Apple ecosystem;
* dark-first / OLED-first дизайн.

Минимальная версия:

`iOS 26.0`

Не использовать устаревшие API без необходимости.

Использовать современные возможности:

* SwiftUI;
* Observation;
* Swift Concurrency;
* WidgetKit;
* ActivityKit;
* App Intents;
* UserNotifications;
* Photos / PhotosUI;
* AVFoundation;
* CryptoKit;
* Keychain;
* URLSession;
* WebSocket;
* локальное кэширование;
* SwiftData либо эквивалентный локальный persistence layer.

App Intents должны быть заложены в архитектуру с самого начала, чтобы действия приложения можно было использовать из widgets, Shortcuts и других системных сценариев.

---

# 2. Два приложения

В репозитории должны находиться два iOS target:

## 2.1 Main App

Основное приложение для пользователей.

Bundle:
`com.projectname.app`

Функции:

* регистрация;
* авторизация;
* профиль;
* друзья;
* чаты;
* статусы;
* Session;
* Squads;
* streaks;
* XP;
* уровни;
* ранги;
* Workshop;
* внутренняя валюта;
* уведомления;
* widgets;
* Live Activities;
* настройки;
* приватность;
* безопасность.

## 2.2 Admin App

Отдельное приложение только для владельца/администраторов проекта.

Bundle:
`com.projectname.admin`

Функции:

* пользователи;
* жалобы;
* блокировки;
* верификация;
* бейджи;
* выдача валюты;
* выдача XP;
* управление рангами;
* управление Workshop;
* модерация профилей;
* управление играми;
* управление темами;
* управление наградами;
* просмотр статистики;
* серверный мониторинг;
* управление feature flags;
* управление beta;
* просмотр логов;
* диагностика.

Обычный пользователь не должен иметь доступа к Admin App.

Админ-приложение не должно иметь публичной формы логина, но API администратора всё равно обязан быть защищён. Отсутствие экранного пароля не означает отсутствие авторизации.

Администраторское устройство должно быть предварительно зарегистрировано на сервере и получать защищённый admin credential, хранящийся в Keychain. Не создавать публичный `/admin` endpoint без авторизации.

---

# 3. Основной дизайн

Главный визуальный принцип:

**OLED + минимализм + premium Apple + gaming social.**

Основной брендовый accent:

**оранжевый.**

Основной фон:

* OLED black;
* глубокий тёмно-серый;
* белый текст;
* вторичный серый;
* orange accent.

Дополнительные темы:

* Orange;
* Purple;
* Blue;
* Cyan;
* Green;
* Yellow;
* Red;
* Pink;
* White;
* Black;
* другие предсозданные комбинации.

Главная тема приложения по умолчанию:

`OLED Black + Orange`

Liquid Glass:

* tab bar;
* floating controls;
* кнопки;
* sheets;
* карточки;
* некоторые панели;
* интерактивные элементы.

Liquid Glass не должен использоваться абсолютно везде.

Запрещено превращать интерфейс в:

* стеклянную кашу;
* большое количество полупрозрачных панелей;
* интерфейс с постоянными бликами;
* чрезмерные анимации;
* экран, заполненный текстом.

Главное правило:

> Пользователь должен понимать экран за 1–2 секунды.

---

# 4. Навигация

Основная нижняя панель:

`Home · Friends · Chats · Squads · Profile`

Между основными действиями может существовать центральная floating-кнопка создания Session.

Home — главное место для игровой активности.

Friends — все друзья и их состояния.

Chats — личные и групповые чаты.

Squads — постоянные группы.

Profile — собственная страница и настройки профиля.

---

# 5. Home

Главный экран отвечает на вопрос:

> «С кем я могу поиграть сейчас?»

Верхняя часть:

* мой аватар;
* мой статус;
* online indicator;
* быстрый переход в профиль;
* уведомления.

Основной блок:

### Кто сейчас свободен

Карточки друзей.

Каждая карточка может показывать:

* аватар;
* username/display name;
* online dot;
* цвет статуса;
* текст статуса;
* игру;
* небольшой subtitle;
* время изменения статуса;
* кнопку `Поиграть`.

Пример:

`Егор`

`🟢 Свободен`

`Fortnite`

`изменено 3 мин назад`

Кнопка:

`Поиграть`

---

# 6. Карточки друзей

Основной элемент Home.

Карточки должны отображаться в сетке.

Например:

`2 карточки в ряд`

Карточку можно:

* открыть;
* нажать;
* удерживать;
* выделить;
* закрепить;
* переместить;
* добавить в избранное.

При удержании:

* карточка получает визуальное выделение;
* окружающий интерфейс слегка затемняется;
* пользователь может провести пальцем;
* доступны действия закрепления/сортировки.

Закреплённые друзья должны находиться выше остальных.

---

# 7. Друзья

Список фильтров:

`Все · Онлайн · Свободны · Играют · Избранные`

Доступна сортировка:

* по активности;
* по имени;
* по последнему онлайн;
* по частоте взаимодействия;
* закреплённые;
* вручную.

Для каждого друга:

* открыть профиль;
* написать;
* пригласить;
* посмотреть статус;
* удалить;
* заблокировать;
* отключить уведомления.

Friend request:

`Отправить запрос → ожидание → принять/отклонить`

Повторный запрос разрешается только после cooldown.

Нужны:

* QR;
* ссылка на профиль;
* username;
* внутренний код;
* поиск по username;
* импорт/поиск среди контактов в рамках разрешений iOS;
* другие безопасные способы приглашения.

QR профиля:

в Profile сверху слева иконка QR.

QR открывает карточку пользователя/ссылку на добавление.

---

# 8. Username

Формат:

`@username`

Требования:

* минимум 4 символа;
* латинские буквы;
* цифры;
* `_`;
* `-`;
* `.` только если технически безопасно для backend и URL routing.

Username должен быть уникальным.

Username можно менять.

Display Name отдельный:

`@username`

`Display Name`

---

# 9. Registration

Обязательная регистрация.

Основной вариант:

* email;
* password;
* username.

Опционально:

* phone;
* Sign in with Apple;
* Google;
* Discord.

OAuth-провайдеры должны быть feature-flagged.

Если credentials конкретного провайдера ещё не настроены, интерфейс не должен ломаться.

Email:

* обязательная проверка;
* код подтверждения;
* повторная отправка с cooldown.

Телефон:

* опциональный на бете;
* архитектурно готов к обязательному использованию позже.

2FA:

обязательная для административных аккаунтов;

для обычных аккаунтов можно реализовать обязательной после появления безопасного механизма.

Для обычного пользователя первоначальный onboarding:

1. email/password;
2. username;
3. Display Name;
4. avatar;
5. соглашения;
6. Home.

Дата рождения:

опциональная на уровне профиля, но система должна быть готова к возрастному режиму.

Возрастной режим продукта:

`12+`

Для публичного запуска возрастные требования и юридические механизмы должны быть адаптированы под действующие требования магазинов и применимое законодательство.

---

# 10. Дата рождения

Пользователь может:

* не указывать дату;
* указать дату;
* скрыть дату;
* показать друзьям;
* показать только день и месяц;
* полностью скрыть.

Если дата рождения доступна друзьям:

у пользователя в день рождения появляется:

`🎂 Сегодня день рождения`

Можно добавить:

`Поздравить`

В будущем:

* подарок;
* внутренняя валюта;
* подарок-косметика;
* birthday badge.

---

# 11. Статусы

Главная механика приложения.

Всего три базовых цвета:

### 🟢 Green

По умолчанию:

`Свободен`

### 🟡 Yellow

По умолчанию:

`Буду позже`

### 🔴 Red

По умолчанию:

`Занят`

Пользователь может менять текст.

Примеры:

🟢 `Готов играть`

🟢 `Ищу пати`

🟢 `В Fortnite`

🟡 `Буду после 18:00`

🟡 `Через 30 минут`

🟡 `Скоро освобожусь`

🔴 `Занят`

🔴 `Не играю сегодня`

🔴 `Не беспокоить`

Игровые состояния:

`🎮 Играю один`

`👥 Играю с @username`

`🔥 Играю с другой пати`

`🎮 Играю с этой группой`

---

# 12. Кастомный статус

Пользователь может задать собственный текст.

Требования:

* ограничение длины;
* только текст;
* emoji в пользовательском тексте не обязательны и по умолчанию отключаются;
* запрещённый контент не допускается.

Фильтр статусов работает на:

* пользовательские статусы;
* публичные текстовые поля профиля;
* названия/описания публичных пользовательских материалов Workshop.

ВАЖНО:

**Чаты НЕ фильтруются по словам.**

В личных и групповых чатах пользователи могут отправлять обычный текст без автоматического словарного фильтра.

---

# 13. Таймер статуса

При изменении статуса пользователь может выбрать:

`Без срока`

или:

`15 минут`

`30 минут`

`1 час`

`2 часа`

`До определённого времени`

После окончания:

* статус автоматически возвращается к предыдущему;
* либо становится стандартным;
* это задаётся в настройках.

Если человек долго не открывает приложение, статус может автоматически перейти в:

`Неактивен`

или:

`Не играю сейчас`

Но не менять игровой текст агрессивно.

---

# 14. Online / Offline

Online:

зелёная точка рядом с avatar.

Offline:

серая точка.

Last Seen:

опционально.

Настройки:

* показывать точное время;
* показывать «недавно»;
* скрывать.

Пример:

`был в сети 16:00`

или:

`был недавно`

---

# 15. Game Session

Game Session — центральная сущность продукта.

При нажатии:

`Поиграть`

открывается компактный экран создания Session.

Поля:

* игра;
* режим;
* количество игроков;
* время;
* комментарий;
* кто приглашён.

Пример:

### Fortnite

`Ranked`

`Сегодня · 18:00`

`2/4`

`Нужны ещё 2`

Кнопка:

`Отправить приглашение`

---

# 16. Запрос на игру

Вместо обычного текста создаётся специальное сообщение:

### 🎮 Егор хочет поиграть

`Fortnite · Ranked`

`Сегодня · 18:00`

`Нужно ещё 2`

[Принять]

[Отклонить]

После принятия:

* Session обновляется;
* сообщение получает статус принятия;
* открывается чат;
* вверху появляется Session banner.

Автоматическое системное сообщение:

`Егор принял запрос. Можно присоединяться к Session.`

---

# 17. Session Banner

Вверху соответствующего чата:

### Fortnite Session

`3/4 игроков`

`18:00`

`Войти`

После входа:

`Выйти`

После запуска:

`01:24:38`

Также показывать:

* участников;
* готовность;
* игру;
* режим;
* время старта.

---

# 18. Состояния Session

Состояния:

`Draft`

`Inviting`

`Waiting`

`Ready`

`Live`

`Paused`

`Finished`

`Cancelled`

Участник может:

* принять;
* отклонить;
* готов;
* не готов;
* отойти;
* выйти.

Создатель:

* изменить состав;
* удалить участника;
* изменить время;
* изменить игру;
* закрыть Session;
* завершить Session.

---

# 19. Live Session

При начале Session запускается:

* таймер;
* Live Activity;
* обновление участников;
* быстрый статус.

Пример Live Activity:

`🎮 Fortnite Squad`

`3/4 READY`

`Егор ✓`

`Даня ✓`

`Артём ✓`

`+ 00:48:21`

Live Activity должна быть доступна на Lock Screen и Dynamic Island.

---

# 20. Widgets

Минимум четыре типа.

### Small — Who's Free

`WHO'S FREE`

🟢 Егор

🟢 Артём

🟡 Даня

### Medium — Friends

`WHO'S FREE?`

Егор — свободен

Артём — Fortnite

Даня — позже

### Medium — My Squad

`MY SQUAD`

`3/5 online`

`🔥 14`

### Status Widget

`МОЙ СТАТУС`

`🟢 Свободен`

Интерактивные кнопки:

`🟢`

`🟡`

`🔴`

Нажатие меняет статус без полноценного открытия приложения.

При необходимости более подробный текст редактируется внутри приложения.

---

# 21. App Intents

Создать App Intents для:

* Set Green Status;
* Set Yellow Status;
* Set Red Status;
* Open Friends;
* Open Chats;
* Open Profile;
* Create Session;
* Open Active Session;
* Join Session;
* Leave Session.

В будущем:

* Siri;
* Shortcuts;
* Apple Intelligence;
* Action Button;
* Control Center.

---

# 22. Squads

Squad — постоянная группа друзей.

Каждая группа имеет:

* название;
* avatar;
* описание;
* участников;
* роли;
* чат;
* Squad Level;
* Squad XP;
* Squad Streak;
* кастомизацию;
* настройки.

Максимум:

`200 участников`

Роли:

`Owner`

`Admin`

`Member`

Owner может:

* менять название;
* менять аватар;
* менять описание;
* назначать Admin;
* снимать Admin;
* удалять пользователей;
* закрывать группу;
* управлять настройками.

---

# 23. Squad Streak

Общий streak группы.

Streak засчитывается не просто за открытие приложения.

Лучшее правило:

за день группа получает активность, если участники создали Session и реально подключились к совместной активности.

Пример:

`🔥 Squad Streak 14`

`14 дней подряд`

Streak должен быть устойчив к часовым поясам и повторным действиям.

---

# 24. Squad Level

Каждая Squad имеет уровень.

XP можно получать за:

* совместные Sessions;
* активность;
* достижения;
* streak;
* полезную социальную активность.

Не делать систему, где люди могут бесконечно фармить XP бессмысленным спамом.

За уровень выдаются:

* рамки;
* темы;
* косметика;
* chat backgrounds;
* эффекты.

---

# 25. Личные Streaks

Personal Streak:

пользователь сохраняет ежедневную активность.

Но основной ценный streak:

`Squad Streak`

Он связан с друзьями и совместными Sessions.

Не давать огромный XP за простой запуск приложения.

---

# 26. Чаты

Только два типа:

### Personal Chat

1-на-1.

### Group Chat

Внутри Squad.

Не создавать каналы.

Функции:

* текст;
* фото;
* видео;
* GIF;
* voice messages;
* реакции;
* reply;
* forward;
* pin;
* edit;
* delete;
* search;
* typing;
* read receipts;
* push.

---

# 27. Голосовые сообщения

Логика:

`зажал → запись`

Отпустил:

`отправить`

Свайп вверх:

`lock recording`

После блокировки появляется отдельная кнопка:

`Send`

Свайп влево:

`Cancel`

Дополнительно:

* waveform;
* длительность;
* play/pause;
* скорость 1× / 1.5× / 2×;
* прогресс;
* haptics.

Waveform должен быть визуально плавным и отражать реальную амплитуду.

---

# 28. Сообщения

Одна галочка:

`доставлено`

Две:

`прочитано`

В групповом чате на сообщение можно открыть:

`Кто посмотрел`

и получить список просмотревших.

Необходимы:

* reactions;
* кулак;
* огонь;
* лайк;
* сердце;
* dislike;
* OK.

Архитектура реакций должна быть расширяемой.

---

# 29. Работа с медиа

Фото:

* предпросмотр;
* просмотр fullscreen;
* скачивание;
* локальное кеширование.

Видео:

* встроенный preview;
* playback;
* не сохранять автоматически в Photos;
* пользователь может вручную сохранить.

GIF:

* inline playback;
* кеширование.

Файлы произвольного типа:

на первом этапе не поддерживать.

---

# 30. Чаты и E2EE

Личные и групповые сообщения должны использовать end-to-end encryption.

ВАЖНО:

не писать собственный криптографический протокол.

Использовать проверенный криптографический стек/реализацию с нормальной схемой управления ключами.

Архитектура должна поддерживать:

* device keys;
* session keys;
* key rotation;
* encrypted attachments;
* multi-device;
* безопасное удаление ключей;
* recovery strategy.

Сервер не должен иметь доступ к plaintext содержимому E2EE сообщений.

Поэтому Admin App не показывает содержимое защищённых сообщений.

Админ получает:

* message ID;
* metadata;
* delivery status;
* timestamps;
* sender/recipient metadata;
* report metadata;

но не plaintext.

---

# 31. Profile

Профиль — одна из самых красивых частей приложения.

Он должен быть длинной кастомизируемой страницей.

Пользователь может добавить:

* avatar;
* banner;
* background;
* gradient;
* фотографии;
* текстовые блоки;
* games;
* achievements;
* streak;
* links;
* Discord;
* YouTube;
* Twitch;
* Steam;
* Epic Games;
* PlayStation;
* Xbox.

Профиль должен напоминать premium gaming profile / Steam-like showcase.

---

# 32. Profile Builder / Workshop

Пользователь может полностью перестраивать профиль.

Действия:

* добавить блок;
* удалить разрешённый блок;
* переместить блок;
* изменить размер в заданных пределах;
* изменить фон;
* изменить прозрачность;
* изменить изображение;
* изменить акцент;
* добавить декоративный элемент.

Некоторые системные элементы нельзя удалить:

* основной identity block;
* friend/message action;
* safety/report;
* системные элементы профиля.

Пользовательские элементы должны сохранять ограничения, чтобы профиль не превращался в сломанный макет.

---

# 33. Profile Themes

Официальные темы приложения.

Каждая тема содержит:

* название;
* описание;
* preview;
* screenshots;
* автор;
* version;
* поддерживаемые элементы.

Примеры:

`OLED Orange`

`Pure Black`

`Purple Glass`

`Cyan Glass`

`White Minimal`

`Dark Red`

`Blue Night`

`Neon Green`

Не делать интерфейс автоматически неоновым.

---

# 34. User-made Workshop

Пользователь может создавать собственные profile showcases.

До начала продажи:

необходимо создать минимум:

`5 одобренных бесплатных работ`

После этого открывается возможность публикации платных работ.

Каждая работа:

* title;
* description;
* preview;
* screenshots;
* creator;
* version;
* price;
* category;
* language;
* compatibility;
* publish date.

Перед публикацией:

`Pending moderation`

После одобрения:

`Published`

Фильтры:

`All`

`Free`

`Paid`

`Popular`

`New`

`Official`

---

# 35. Preview

Перед применением:

`Preview`

Пользователь должен увидеть профиль в реальном окружении.

Кнопки:

`Применить`

`Назад`

`Сохранить`

Для Workshop preview должна быть доступна без покупки.

---

# 36. User-generated profile content

Публичный профиль должен проходить ограниченную модерацию.

Фильтр применяется к:

* статусам;
* username при необходимости;
* Display Name;
* публичным текстовым блокам;
* названиям профилей;
* описаниям Workshop;
* названиям групп;
* описаниям групп;
* другим публичным метаданным.

В личных и групповых чатах автоматического словарного фильтра нет.

Список запрещённого контента должен храниться отдельно и обновляться через Admin App.

---

# 37. Профильные бейджи

Система badges.

Обязательные категории:

`Developer`

`Official`

`Verified`

`Sponsor`

`Beta Tester`

`Early User`

`Founder`

Визуально:

Verified — синяя галочка.

Sponsor — переливающаяся градиентная галочка.

Developer — специальная premium badge.

Owner/Admin проекта — корона/специальный badge.

Beta Tester — отдельный градиентный beta badge.

Developer username может иметь специальный visual effect.

Developer-аккаунт нельзя отправлять в friend request обычному пользователю.

Developer может сам отправить friend request.

---

# 38. Верификация

Верификация управляется только Admin App.

Администратор может:

* выдать;
* снять;
* изменить тип;
* указать причину;
* посмотреть историю.

Verified:

подтверждение личности аккаунта.

Official:

официальный проект/организация.

Sponsor:

спонсор проекта.

Beta Tester:

выдан только участникам закрытой beta.

После публичного релиза выдача Beta Tester должна быть закрыта.

---

# 39. Profile feedback

На профиль можно добавить лёгкую социальную оценку.

Не делать публичный рейтинг «кто круче».

Вариант:

`👍 Good teammate`

`👎 Bad experience`

Показывать агрегированный visual meter.

Ограничения:

* один пользователь не может бесконечно голосовать;
* голос привязывать к взаимодействию/Squad/Session;
* защита от массовой накрутки;
* не делать глобальную таблицу популярности.

---

# 40. Уровень пользователя

Общий Profile Level:

`Level 1 …`

XP можно получать за:

* Sessions;
* Squad activity;
* streak;
* achievements;
* дружеские действия;
* завершённые игровые активности;
* другие полезные действия.

Не выдавать огромные награды за спам.

---

# 41. Ранги

Система рангов:

`Wood`

`Stone`

`Iron`

`Bronze`

`Silver`

`Gold`

`Platinum`

`Diamond`

`Master`

`Grandmaster`

`Legend`

Можно использовать несколько дивизионов внутри ранга:

`Gold I`

`Gold II`

`Gold III`

Ранг не означает игровой skill.

Он означает прогресс внутри приложения.

---

# 42. Rewards

За Level / Rank выдаются:

* avatar frames;
* profile borders;
* chat frames;
* profile effects;
* gradients;
* decorative elements;
* official cosmetic items.

Некоторые награды:

`Free`

Некоторые:

`Workshop`

Некоторые:

`Official Store`

Некоторые:

`Achievement reward`

---

# 43. Chat Frames

Пользователь может получать декоративное оформление карточек/чатов.

Например:

* gradient;
* particles;
* glass;
* glow;
* shine;
* animated border.

Все эффекты должны быть GPU-efficient и не убивать FPS.

---

# 44. Внутренняя валюта

Рабочее название:

**EMBER**

Единица:

`1 Ember`

Название должно быть легко заменяемым через configuration layer.

В бете покупки за реальные деньги не активны.

Admin App позволяет выдавать:

* Ember;
* косметику;
* предметы;
* награды.

Позже Ember можно приобретать за реальные деньги в соответствии с правилами App Store.

Для цифровых покупок архитектура должна поддерживать StoreKit/In-App Purchase.

Нельзя проектировать бизнес-модель, которая полностью зависит от внешней оплаты через сайт.

---

# 45. Marketplace / Gifts

Пользователь может:

* купить предмет;
* получить предмет;
* подарить предмет;
* продать ненужный предмет;
* обменять предмет.

Для beta можно сделать экономику в режиме sandbox:

`admin-issued currency`

и ручную модерацию.

Все транзакции через ledger:

`transaction_id`

`from_user`

`to_user`

`item`

`amount`

`timestamp`

`status`

Нельзя изменять баланс пользователя простой SQL-операцией без записи в ledger.

---

# 46. Кейсы / Drops

За:

* Level;
* Rank;
* achievements;
* Squad activity;
* специальные события

можно выдавать:

`Case`

Внутри:

* cosmetic;
* frame;
* profile effect;
* chat theme;
* background.

Избегать механики, которая превращает цифровую валюту в азартную систему.

Лучше использовать заранее известные награды или прозрачные reward tables.

---

# 47. Premium

Premium — подписка.

Планы:

* Monthly;
* Six Months.

Не делать:

* Annual;
* Lifetime;
* Free Trial.

Premium не должен блокировать фундаментальную социальную функцию.

Бесплатно:

* friends;
* statuses;
* chats;
* Session;
* basic Squads.

Premium:

* расширенная profile customization;
* дополнительные профильные блоки;
* больше тем;
* дополнительные card backgrounds;
* дополнительные widget styles;
* дополнительные эффекты;
* расширенные cosmetic options;
* дополнительные Workshop features;
* расширенная персонализация Home.

---

# 48. Group Premium

Для Squads можно иметь отдельную подписку/пакет.

Цена планируется примерно в 3–5 раз выше обычного Premium в пересчёте на единицу периода.

Group Premium открывает:

* расширенную кастомизацию Squad;
* больше cosmetic slots;
* специальные squad themes;
* расширенные group widgets;
* дополнительные administrative features.

Финальная цена определяется после анализа экономики.

---

# 49. Уведомления

Push:

* новое сообщение;
* голосовое;
* friend request;
* friend request accepted;
* Session invite;
* Session accepted;
* Session declined;
* user joined Session;
* user left Session;
* Squad invite;
* mention/reply;
* birthday;
* streak reminder;
* Workshop purchase;
* gift received;
* verification;
* admin action;
* system notifications.

Статус friend:

не отправлять push каждый раз всем друзьям без ограничений.

В настройках:

`Уведомлять только об избранных друзьях`

и:

`Notify when friend becomes available`

---

# 50. Quiet Mode

Пользователь может:

* отключить push;
* отключить конкретный чат;
* отключить конкретного пользователя;
* отключить группу;
* задать Quiet Hours;
* скрыть содержание уведомлений;
* отключить игровые приглашения.

Swipe actions:

по чату:

`Mute`

`Pin`

`Mark as read`

---

# 51. Social actions

Добавить:

`Invite all`

в Squad.

При нажатии:

`Fortnite · сейчас`

получают приглашение выбранные участники.

Можно сделать быстрые действия:

`Play`

`Chat`

`Profile`

`Invite`

---

# 52. Игры

Backend должен иметь каталог игр.

Каждая игра:

* id;
* name;
* slug;
* logo;
* icon;
* cover;
* color;
* platforms;
* modes;
* status.

Стартовый каталог:

* Fortnite;
* Minecraft;
* Valorant;
* Counter-Strike 2;
* Roblox;
* Apex Legends;
* Call of Duty;
* GTA;
* Rocket League;
* Overwatch;
* PUBG;
* Terraria;
* Sea of Thieves;
* Rainbow Six Siege;
* Destiny 2;
* The Finals;
* Fall Guys;
* Among Us;
* EA Sports FC;
* другие популярные игры.

Пользователь может добавить собственную игру.

Пользователь может выбрать:

`Favorite Games`

и:

`Main Game`

---

# 53. Game Modes

Игра может иметь:

* Ranked;
* Casual;
* Creative;
* Duo;
* Trio;
* Squad;
* Custom;
* другие.

Но пользователь может создать собственный mode.

---

# 54. Game integrations

Архитектура должна поддерживать в будущем:

* Discord;
* Twitch;
* YouTube;
* Steam;
* Epic;
* PlayStation;
* Xbox.

На первом этапе интеграции могут быть обычными profile links.

Нельзя делать зависимость beta от API, которого у проекта ещё нет.

---

# 55. Settings

Настройки должны быть большим структурированным разделом.

Категории:

### Account

* email;
* password;
* username;
* phone;
* date of birth.

### Privacy

* online status;
* Last Seen;
* profile visibility;
* friend requests;
* messages;
* birthday;
* games.

### Notifications

* messages;
* sessions;
* friends;
* squads;
* streaks;
* Workshop.

### Appearance

* theme;
* accent;
* OLED;
* animations;
* reduce motion.

### Security

* Face ID;
* active sessions;
* devices;
* logout all;
* 2FA;
* keys.

### Data

* export;
* cache;
* storage;
* media.

### Language

* Russian;
* English.

### Subscription

* Premium;
* purchases;
* restore purchases.

---

# 56. Face ID

Не обязательный.

Опционально:

`Lock App with Face ID`

При включении:

* приложение блокируется;
* push остаются;
* sensitive content можно скрывать.

---

# 57. Data / multi-device

Данные должны синхронизироваться.

После нового iPhone пользователь получает:

* friends;
* profile;
* squads;
* statuses;
* chats;
* Session history;
* levels;
* streaks;
* Workshop;
* currency;
* purchases;
* settings.

Криптографические ключи должны иметь отдельную multi-device strategy.

---

# 58. Server

Первый backend запускается на личном компьютере разработчика.

Порт:

`5267`

Local service:

`localhost:5267`

CloudPub публикует локальный HTTP/HTTPS сервис наружу.

Использовать HTTPS endpoint CloudPub.

Не вшивать в приложение выдуманный URL вида `https://projectname.cloudpub.ru`, пока реальный endpoint не существует.

URL должен задаваться через environment/config.

Пример конфигурации:

`API_BASE_URL=https://REAL-CLOUDPUB-DOMAIN.cloudpub.ru`

CloudPub может дать публичный HTTPS адрес поверх локального сервиса.

---

# 59. Backend stack

Рекомендуемый стек:

### API

Node.js + TypeScript

Fastify либо NestJS.

Выбрать один основной фреймворк.

### Database

PostgreSQL.

### Realtime

WebSocket.

### Push

APNs.

### Storage

На beta:

local filesystem.

В будущем:

S3-compatible object storage.

### Cache

Добавить Redis только когда он действительно нужен.

### Reverse proxy

Не обязателен при прямом CloudPub HTTP tunnel.

---

# 60. Архитектура проекта

Репозиторий:

```text
/project
    /iOSApp
    /AdminApp
    /Backend
    /Shared
    /Design
    /Docs
    /.github
```

`Shared`:

* DTO;
* enums;
* networking contracts;
* constants;
* feature flags.

Не смешивать серверный код и Swift-код без необходимости.

---

# 61. Database entities

Минимум:

* User;
* UserDevice;
* UserSession;
* FriendRequest;
* Friendship;
* Status;
* Game;
* UserGame;
* GameSession;
* GameSessionParticipant;
* Squad;
* SquadMember;
* MessageMetadata;
* MessageRecipient;
* Attachment;
* Reaction;
* ReadReceipt;
* Profile;
* ProfileBlock;
* ProfileTheme;
* WorkshopItem;
* WorkshopSubmission;
* WorkshopPurchase;
* CurrencyWallet;
* CurrencyTransaction;
* InventoryItem;
* Gift;
* Trade;
* Badge;
* UserBadge;
* Achievement;
* UserAchievement;
* Level;
* Rank;
* Streak;
* Notification;
* Report;
* ModerationAction;
* VerificationRequest;
* AdminAction;
* AuditLog;
* FeatureFlag.

---

# 62. Realtime

WebSocket должен использоваться для:

* chat messages;
* typing;
* online state;
* status update;
* Session changes;
* Squad changes;
* read receipts;
* reactions;
* message edits;
* message deletion.

При отсутствии WebSocket:

fallback на polling только для аварийных сценариев.

---

# 63. Online presence

Система:

`online`

`away`

`offline`

Last Seen.

Heartbeat.

Если приложение долго не отвечает:

status → inactive.

Не держать постоянное соединение без необходимости.

---

# 64. Media

Изображения и видео:

* upload;
* compression;
* thumbnails;
* encrypted-at-rest where appropriate;
* resumable upload для больших видео;
* content type validation;
* size limits.

Голосовые:

* AAC/Opus по ситуации;
* waveform metadata;
* duration;
* upload progress.

---

# 65. API

REST:

`/auth`

`/users`

`/friends`

`/statuses`

`/games`

`/sessions`

`/squads`

`/profiles`

`/workshop`

`/wallet`

`/notifications`

`/reports`

`/admin`

WebSocket:

`/ws`

API должен иметь:

* versioning;
* validation;
* consistent error format;
* pagination;
* rate limits;
* request IDs;
* logging.

---

# 66. Security

Обязательно:

* TLS;
* password hashing;
* secure token storage;
* access/refresh tokens;
* rotation;
* rate limiting;
* brute-force protection;
* device session management;
* input validation;
* image validation;
* upload limits;
* SQL parameterization/ORM;
* no secrets in repository.

Admin API:

отдельный auth layer.

Никогда не хранить:

* passwords;
* private keys;
* API secrets

в GitHub repository.

---

# 67. Admin App

Главный экран:

### Overview

* users;
* online;
* active sessions;
* messages metadata;
* reports;
* new users;
* beta testers;
* server health.

### Users

* search;
* profile;
* status;
* badges;
* level;
* rank;
* currency;
* inventory;
* ban;
* mute;
* verify;
* grant/revoke.

### Moderation

* reports;
* duplicate collapsing;
* status/profile moderation;
* Workshop moderation;
* user restrictions.

### Verification

* requests;
* Verified;
* Official;
* Sponsor;
* Beta Tester;
* Developer.

### Economy

* Ember;
* grants;
* revokes;
* item creation;
* gifting;
* Workshop prices.

### Content

* games;
* themes;
* rewards;
* badges;
* achievements.

### Analytics

* DAU;
* WAU;
* users;
* new users;
* active Sessions;
* accepted Session invites;
* declined Session invites;
* messages;
* active Squads;
* retention;
* widget usage;
* notification delivery.

### Server

* CPU;
* RAM;
* storage;
* database;
* WebSocket connections;
* errors;
* uptime;
* CloudPub connectivity.

---

# 68. Reports

Report types:

* user;
* profile;
* status;
* message;
* Workshop item;
* avatar;
* group.

Повторная жалоба на тот же объект не должна создавать бесконечную очередь.

Система должна объединять дубликаты:

`report_cluster_id`

Все дополнительные репорты добавляются к существующему кластеру.

---

# 69. Admin audit log

Каждое действие администратора:

* admin;
* action;
* target;
* timestamp;
* reason;
* old value;
* new value.

Пример:

`Admin granted 500 EMBER to @username`

---

# 70. Beta

Размер первой beta:

примерно:

`10–20 пользователей`

Основная аудитория:

* друзья;
* школьная/студенческая компания;
* знакомые.

Invite code не нужен.

Beta Tester badge выдаётся вручную через Admin App.

После публичного релиза выдача Beta badge новым пользователям запрещается.

---

# 71. Feature Flags

Все крупные функции должны управляться feature flags.

Например:

`public_player_search`

`discord_login`

`apple_login`

`google_login`

`phone_auth`

`premium`

`workshop_marketplace`

`currency_purchases`

`trading`

`public_profiles`

`live_activities`

`widgets`

Это позволит тестировать функции без пересборки приложения.

Но beta-версия должна содержать весь согласованный функциональный фундамент; feature flag используется только для безопасного включения/выключения отдельных интеграций.

---

# 72. GitHub

Создать публичный GitHub repository.

Репозиторий должен содержать:

* полный исходный код;
* README;
* архитектуру;
* документацию;
* setup instructions;
* `.env.example`;
* database schema/migrations;
* API docs;
* screenshots;
* GitHub Actions.

НИКАКИХ секретов в repository.

---

# 73. GitHub Actions

Создать workflows:

### `ci.yml`

Запускается:

* push;
* pull request.

Выполняет:

* checkout;
* dependency resolution;
* build;
* unit tests;
* UI tests;
* static checks.

GitHub-hosted macOS runner.

---

# 74. iOS Simulator testing

CI должен запускать:

* приложение;
* onboarding;
* login;
* Home;
* Friends;
* Chat;
* Session;
* Squad;
* Profile;
* Workshop;
* Settings.

UI tests должны проверять основные пользовательские сценарии.

Минимальные critical paths:

### Auth

`register → verify → profile → Home`

### Friends

`search → request → accept`

### Status

`green → yellow → red`

### Session

`create → invite → accept → join → finish`

### Chat

`send → receive → read`

### Profile

`edit → save → reload`

### Workshop

`create → moderation → publish → preview`

---

# 75. Автоматические screenshots

CI должен создавать скриншоты основных экранов.

Использовать iOS Simulator.

Скриншоты:

* onboarding;
* Home;
* Friends;
* Session;
* Chat;
* Squad;
* Profile;
* Workshop;
* Premium;
* Settings;
* Admin Dashboard.

Скриншоты сохраняются как GitHub Actions artifacts.

Также хранить golden screenshots для visual regression.

---

# 76. Visual QA

Для ключевых экранов:

* baseline screenshot;
* current screenshot;
* comparison;
* optional pixel-diff.

Если visual regression превышает threshold:

CI должен отмечать job как failed.

---

# 77. IPA build

GitHub Actions должен автоматически собирать unsigned IPA без сертификатов/provisioning profiles.

Workflow:

1. build iOS app;
2. disable code signing;
3. получить `.app`;
4. создать `Payload/`;
5. положить `.app` внутрь;
6. zip → `.ipa`;
7. загрузить `.ipa` как Actions artifact.

Такая IPA является unsigned artifact.

Она нужна для:

* хранения;
* передачи;
* CI;
* проверки структуры;
* дальнейшего ручного подписывания.

Не считать unsigned IPA готовой к обычной установке на реальный iPhone.

Для установки на устройство позже добавить отдельный signed workflow с Apple Developer credentials.

---

# 78. Admin IPA

Admin App тоже должен собираться в CI:

`PROJECT_NAME-Admin-unsigned.ipa`

и публиковаться как artifact.

---

# 79. GitHub Actions — запрет на секреты

CI не должен требовать:

* Apple certificate;
* provisioning profile;
* App Store Connect API key;
* private signing key

для обычной beta CI-сборки.

Но финальная App Store release pipeline позже сможет использовать GitHub Secrets.

Для публичного repository нельзя хранить секреты в исходниках.

---

# 80. Local development

Backend запускается:

`localhost:5267`

Main app development config:

```text
API_BASE_URL=http://localhost:5267
```

Production/beta config:

```text
API_BASE_URL=https://REAL-CLOUDPUB-DOMAIN.cloudpub.ru
```

Приложение должно проверять здоровье API.

Endpoint:

`/health`

Если сервер недоступен:

Home показывает минимальное системное состояние:

`Не удаётся подключиться к серверу`

Не показывать огромную страницу ошибки.

Кнопка:

`Повторить`

---

# 81. CloudPub

Подготовить конфигурацию для публикации локального backend через CloudPub.

Internal port:

`5267`

В приложении никогда не хардкодить случайный CloudPub subdomain.

Все окружения:

`development`

`beta`

`production`

должны иметь отдельный конфиг.

---

# 82. Error handling

При серверных проблемах:

* graceful fallback;
* local cache;
* retry;
* exponential backoff;
* offline queue там, где возможно.

Нельзя показывать пользователю raw stack trace.

Ошибки:

`Что-то пошло не так`

вместе с:

`Повторить`

Для разработчика:

* error code;
* request ID;
* logging.

---

# 83. Local cache

Кешировать:

* friends;
* statuses;
* profiles;
* recent chats metadata;
* game catalog;
* workshop preview metadata.

Конфиденциальные данные:

хранить безопасно.

---

# 84. Localization

Полностью поддерживать:

`Русский`

`English`

Никаких hardcoded strings.

Каждая UI-строка через localization system.

---

# 85. Accessibility

Поддержать:

* Dynamic Type;
* Reduce Motion;
* VoiceOver;
* high contrast;
* minimum tappable areas.

Но основная визуальная композиция остаётся компактной.

---

# 86. Haptics

Использовать аккуратно:

* статус changed;
* friend added;
* Session accepted;
* Session joined;
* streak milestone;
* level up;
* reward received;
* gift received;
* successful save.

Не вибрировать на каждом чихе.

---

# 87. Animations

Анимации:

* карточек;
* статусов;
* badges;
* levels;
* streaks;
* profile workshop;
* Liquid Glass;
* Session transitions;
* Live Activity.

Анимации должны быть:

* быстрыми;
* плавными;
* interruptible;
* без перегрузки.

---

# 88. Main visual identity

Основной accent:

`Orange`

OLED background:

`#000000`

Но цвета не должны быть жёстко зашиты во View.

Использовать Theme system:

```text
AppTheme
    background
    surface
    surfaceSecondary
    primary
    secondary
    text
    textSecondary
    success
    warning
    danger
```

---

# 89. Profile themes architecture

Profile theme хранится как data/configuration.

Не зашивать каждый профиль как отдельный SwiftUI screen.

Использовать renderer:

`ProfileLayoutRenderer`

который получает:

* blocks;
* positions;
* sizes;
* theme;
* assets;
* effects.

И отображает профиль.

Это позволит делать Workshop без переписывания приложения.

---

# 90. Profile blocks

Базовые блоки:

* identity;
* avatar;
* banner;
* bio;
* status;
* games;
* links;
* stats;
* achievements;
* badges;
* streak;
* squads;
* photos;
* custom text;
* session history.

Каждый block:

* id;
* type;
* position;
* width;
* height;
* visibility;
* theme;
* data.

---

# 91. Drag & Drop Profile Editor

Редактор:

* long press;
* drag;
* drop;
* resize;
* reorder.

Ограничения:

* safe area;
* grid;
* minimum/maximum sizes;
* no overlap for critical blocks;
* automatic snapping.

---

# 92. Profile storage

Профильные assets:

* avatar;
* banner;
* media;
* theme assets;
* workshop assets

хранятся на backend storage.

На устройстве:

local cache.

Каждый asset имеет:

* UUID;
* hash;
* URL;
* size;
* mime;
* version.

---

# 93. Workshop moderation

Workflow:

`Draft`

→ `Submit`

→ `Pending`

→ `Moderator review`

→ `Approved`

→ `Published`

или:

`Rejected`

с причиной.

После публикации creator может обновить item.

Новая версия снова проходит moderation.

---

# 94. Gifts

Подарок:

`Send Gift`

Получателю:

`🎁 Вам отправили подарок`

Открыть:

`Посмотреть`

Можно:

`Принять`

`Продать`

`Использовать`

`Передарить`

если конкретный item это разрешает.

---

# 95. Economy anti-abuse

Баланс никогда не редактировать напрямую.

Каждое изменение:

`CurrencyTransaction`

Админские выдачи:

`AdminGrant`

С возможностью аудита.

Trade/gift:

atomic transaction.

Никаких отрицательных/дублирующих операций.

---

# 96. Friends privacy

Настройки:

Кто может:

* находить;
* добавлять;
* писать;
* приглашать;
* видеть Last Seen;
* видеть игры;
* видеть birthday;
* видеть профиль.

В beta default:

`Only friends`

---

# 97. Blocking

Block:

пользователь не может:

* писать;
* добавлять;
* приглашать;
* взаимодействовать;
* видеть ограниченные данные.

Системная функция.

---

# 98. Reports

Репорт должен быть доступен:

* из профиля;
* из сообщения;
* из группы;
* из Workshop;
* из статуса.

Дубликаты объединяются.

---

# 99. Moderation of chats

Ещё раз зафиксировать:

**личные и групповые чаты не используют автоматический word filter.**

Не сканировать текст сообщений для запрета отдельных слов.

E2EE действует независимо от moderation system.

При жалобах администратор не должен автоматически получать plaintext E2EE сообщения.

---

# 100. Legal / documents

Создать в проекте:

`Terms of Service`

`Privacy Policy`

`Community Guidelines`

`Cookie Policy` при необходимости для web-сервисов.

`Child/Minor Safety rules` при необходимости.

Тексты должны быть полными и понятными.

Они должны быть локализованы:

* русский;
* английский.

До публичного релиза legal texts должны быть проверены человеком, потому что приложение рассчитано также на несовершеннолетних пользователей и будет работать с аккаунтами, сообщениями, профилями и пользовательским контентом.

На регистрации:

`Я принимаю Пользовательское соглашение`

`Я ознакомлен с Политикой конфиденциальности`

Ссылки должны быть доступны до подтверждения.

---

# 101. Privacy by design

Собирать только необходимое.

Разделить:

* account data;
* profile data;
* social graph;
* metadata;
* encrypted content;
* analytics.

Для аналитики использовать обезличенные/минимально необходимые идентификаторы.

Пользователь должен иметь:

`Export my data`

`Delete my account`

---

# 102. Analytics

Собирать продуктовые события:

* app_open;
* login;
* register;
* friend_request_sent;
* friend_request_accepted;
* status_changed;
* session_created;
* session_accepted;
* session_started;
* session_finished;
* message_sent;
* squad_created;
* streak_updated;
* widget_used;
* profile_customized;
* workshop_viewed;
* workshop_purchased.

Не собирать содержание E2EE сообщений.

---

# 103. Core success metrics

Главные метрики:

`friends_added_per_user`

`session_invite_rate`

`session_accept_rate`

`active_squads`

`squad_streak_rate`

`D1`

`D7`

`D30`

`weekly_active_users`

`percentage_of_users_with_2+ friends`

Главная продуктовая метрика:

> сколько созданных игровых Session превращаются в реально принятую/завершённую совместную активность.

---

# 104. First beta success

Первоначально достаточно:

10–20 пользователей.

Успех beta:

* друзья реально устанавливают приложение;
* добавляют друг друга;
* регулярно меняют статусы;
* смотрят статус друзей;
* создают Sessions;
* хотя бы несколько раз возвращаются без напоминаний;
* используют приложение вместо лишних сообщений «играешь?».

Не требовать огромных чисел.

---

# 105. README

README должен объяснять:

* что делает приложение;
* architecture;
* setup;
* backend launch;
* database;
* environment variables;
* CloudPub;
* GitHub Actions;
* unsigned IPA;
* testing;
* screenshots;
* admin app;
* security notes.

---

# 106. `.env.example`

Например:

```env
PORT=5267
DATABASE_URL=
JWT_SECRET=
APNS_KEY_ID=
APNS_TEAM_ID=
CLOUDPUB_DOMAIN=
STORAGE_PATH=
```

Реальные значения не коммитить.

---

# 107. Environment separation

Использовать:

`Development`

`Beta`

`Production`

У каждого:

* API URL;
* DB;
* storage;
* push config;
* feature flags.

---

# 108. Testing layers

Unit:

* status engine;
* Session engine;
* streak engine;
* XP;
* ranks;
* permissions;
* currency ledger.

Integration:

* auth;
* friend request;
* Session;
* WebSocket;
* media;
* push.

UI:

* onboarding;
* Home;
* Chats;
* Session;
* Profile;
* Workshop.

Security:

* auth;
* rate limits;
* access control;
* upload validation;
* admin authorization.

---

# 109. Acceptance criteria

Проект считается базово готовым, если:

### Registration

Пользователь может зарегистрироваться и попасть в Home.

### Friends

Два пользователя могут найти друг друга и подтвердить friend request.

### Status

Пользователь может поставить:

🟢 / 🟡 / 🔴

и кастомный текст.

### Widget

Статус можно менять через widget.

### Chat

Два пользователя могут безопасно обмениваться сообщениями.

### Voice

Можно записывать голосовые через удержание и lock-свайп.

### Session

Пользователь может создать игровую Session и пригласить друга.

### Session acceptance

Друг может принять/отклонить приглашение.

### Session Live

После входа начинается Live Session.

### Squad

Можно создать Squad и добавить участников.

### Profile

Можно открыть и изменить профиль.

### Workshop

Можно создать/сохранить/предпросмотреть профильную тему.

### XP

XP корректно начисляется.

### Streak

Personal и Squad streak работают.

### Badges

Admin может выдавать badges.

### Admin

Администратор может модерировать систему.

### Sync

Данные сохраняются после перезахода.

### Server offline

При выключенном сервере приложение показывает компактное сообщение о недоступности.

### CI

GitHub Actions собирает:

* Main unsigned IPA;
* Admin unsigned IPA;
* simulator tests;
* screenshots.

---

# 110. Главный UX-принцип

Никогда не заставлять пользователя читать длинные инструкции.

Вместо:

> «Для того чтобы создать игровую сессию, выберите игру, режим, количество участников...»

показывать:

`🎮 Поиграем?`

→

`Игра`

`Время`

`Игроки`

→

`Создать`

Все сложные настройки находятся внутри дополнительных экранов.

---

# 111. Главный Home flow

Пользователь должен понимать Home так:

```text
HOME

[ Мой статус ]

Кто свободен?

[ Егор 🟢 ]
[ Артём 🟢 ]

Кто играет?

[ Даня 🎮 Fortnite ]

Кто позже?

[ Макс 🟡 ]

[ + Поиграем ]
```

Это пример композиции, а не строгий пиксельный layout.

---

# 112. Главная идея бренда

Приложение должно ощущаться как:

> «Моя игровая компания всегда у меня под рукой.»

Не:

> «Ещё одна социальная сеть.»

Не:

> «Ещё один мессенджер.»

Не:

> «Ещё один Discord.»

---

# 113. Приоритет функций

Несмотря на то что весь согласованный функционал должен присутствовать в beta-ветке, архитектурный приоритет:

### Tier 1 — ядро

* account;
* friends;
* status;
* Home;
* Session;
* push;
* chat;
* squads.

### Tier 2 — удержание

* streak;
* XP;
* levels;
* ranks;
* achievements;
* badges.

### Tier 3 — identity

* profile builder;
* themes;
* Workshop;
* profile cosmetics.

### Tier 4 — монетизация

* Premium;
* Ember;
* gifts;
* marketplace.

### Tier 5 — системный iOS experience

* widgets;
* App Intents;
* Live Activities;
* Shortcuts;
* advanced system integration.

Все Tier присутствуют в проектной архитектуре.

---

# 114. Что агент-разработчик обязан сделать

Агент не должен просто написать несколько SwiftUI экранов.

Он обязан:

1. Создать полноценный проект.
2. Создать оба iOS target.
3. Создать backend.
4. Создать database migrations.
5. Создать realtime.
6. Создать auth.
7. Создать E2EE architecture.
8. Создать push architecture.
9. Создать profile renderer.
10. Создать Workshop.
11. Создать Admin API.
12. Создать Admin App.
13. Создать GitHub repository.
14. Создать GitHub Actions.
15. Сделать unsigned IPA.
16. Запустить unit tests.
17. Запустить UI tests.
18. Сделать screenshots.
19. Исправить найденные проблемы.
20. Проверить clean build.
21. Проверить отсутствие секретов в репозитории.
22. Проверить backend health.
23. Проверить offline state.
24. Проверить миграции DB.
25. Обновить README.

---

# 115. Что агент НЕ должен делать

Не делать:

* WebView вместо SwiftUI;
* Telegram clone;
* огромные текстовые экраны;
* случайные UI-компоненты без дизайн-системы;
* plaintext passwords;
* публичный admin API;
* hardcoded secrets;
* самописную криптографию;
* бессмысленный XP farming;
* бесконечные push notifications;
* обязательные платные функции для базовой дружеской коммуникации;
* фальшивую «установочную» unsigned IPA как будто она подписана.

---

# 116. Definition of Done

Финальный результат:

```text
✅ Main iOS App
✅ Admin iOS App
✅ Backend
✅ PostgreSQL
✅ WebSocket
✅ Authentication
✅ E2EE architecture
✅ Push
✅ Friends
✅ Status
✅ Sessions
✅ Chats
✅ Voice
✅ Squads
✅ Profiles
✅ Profile Workshop
✅ XP
✅ Levels
✅ Ranks
✅ Streaks
✅ Badges
✅ Verification
✅ Currency
✅ Gifts
✅ Premium architecture
✅ Widgets
✅ App Intents
✅ Live Activities
✅ Settings
✅ Privacy
✅ Moderation
✅ Analytics
✅ Admin tools
✅ GitHub repository
✅ CI
✅ Unsigned IPA
✅ UI screenshots
✅ Automated tests
✅ README
```

---

# 117. Ключевой продуктовый принцип

Вся система должна возвращаться к одной простой мысли:

## «Кто может играть?»

Статус отвечает:

**кто свободен.**

Friends отвечает:

**с кем.**

Session отвечает:

**во что и когда.**

Squad отвечает:

**с какой компанией.**

Chat отвечает:

**что сказать.**

Widget отвечает:

**что происходит прямо сейчас.**

Streak отвечает:

**почему возвращаться.**

Level отвечает:

**зачем продолжать.**

Profile отвечает:

**кто ты внутри этой компании.**

Workshop отвечает:

**как сделать это своим.**

Premium отвечает:

**как получить больше кастомизации.**

Именно эта связь должна сохраняться во всей архитектуре продукта.
