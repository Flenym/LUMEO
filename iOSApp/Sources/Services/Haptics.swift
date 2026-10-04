// Lumeo — Sources/Services/Haptics.swift
// Точечные вибрации по ТЗ: каждое действие — свой отклик, без «вибро-каши».
// Учитывает системный флаг (Settings → hapticsEnabled, ключ UserDefaults).
// Используется из вью одной строкой: Haptics.tap() / Haptics.success() …

import UIKit

// MARK: - Haptics

/// Все вызовы — из SwiftUI (MainActor). UIKit-генераторы в новом SDK
/// MainActor-изолированы, поэтому весь enum изолирован (Swift 6).
@MainActor
enum Haptics {
    private static let enabledKey = "lumeo.hapticsEnabled"

    /// Глобальный выключатель (Settings → Appearance → Haptics).
    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    // MARK: Selection / taps

    /// Лёгкий тап: чипы фильтров, toggle, выбор игры.
    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Совместимость: Haptics.tap() == selection().
    static func tap() {
        selection()
    }

    // MARK: Impact

    /// Средний impact: центральная «🎮 Поиграем?», Войти/Выйти, pin.
    static func medium() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Тяжёлый impact: создание сессии, старт Live.
    static func heavy() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Лёгкий impact: реакции, отправка сообщения.
    static func light() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: Notifications

    /// Успех: инвайт принят, сессия создана, сообщение доставлено.
    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Предупреждение: cooldown запроса, очередь офлайн.
    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Ошибка: не удалось подключиться, отправка провалилась.
    static func error() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // MARK: Scenarios (по ТЗ)

    /// Центральная кнопка «Поиграем?» — средний impact + selection.
    static func play() {
        medium()
    }

    /// Создание сессии Draft → Inviting.
    static func sessionCreated() {
        heavy()
    }

    /// Join / Leave сессии.
    static func join() {
        medium()
    }

    static func leave() {
        selection()
    }

    /// Отправка сообщения / реакции.
    static func messageSent() {
        light()
    }

    /// Начало/конец голосовой записи.
    static func voiceStart() {
        medium()
    }

    static func voiceStop() {
        selection()
    }
}
