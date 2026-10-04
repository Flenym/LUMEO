// Lumeo — Sources/Theme/AppTheme.swift
// Dark-first / OLED-first тема. Акцент по умолчанию — оранжевый на чистом чёрном (#000000).
// Liquid Glass — только точечно (tab bar, floating controls, sheets, карточки), не «стеклянная каша».
// 10 пресетов. Dynamic Type (fontScale), Reduce Motion и high-contrast учитываются
// через ThemeManager + системные environment-значения во вью.

import SwiftUI
import Observation

// MARK: - AppTheme

/// Плоская палитра экрана. Экран должен считываться за 1–2 секунды:
// private(set) — только именованные ключи ниже, без произвольных цветов во вью.
struct AppTheme: Equatable, Hashable {
    let name: String
    var background: Color
    var surface: Color
    var surfaceSecondary: Color
    var primary: Color
    var secondary: Color
    var text: Color
    var textSecondary: Color
    var success: Color
    var warning: Color
    var danger: Color

    // MARK: Presets (10)

    /// Дефолт: OLED Black (#000000) + Orange.
    static let oledOrange = AppTheme(
        name: AppThemeName.oledOrange,
        background: Color(red: 0, green: 0, blue: 0),
        surface: Color(white: 0.07),
        surfaceSecondary: Color(white: 0.12),
        primary: Color(red: 1.0, green: 0.42, blue: 0.0),
        secondary: Color(red: 1.0, green: 0.62, blue: 0.25),
        text: .white,
        textSecondary: Color(white: 0.62),
        success: Color(red: 0.2, green: 0.85, blue: 0.4),
        warning: Color(red: 1.0, green: 0.75, blue: 0.2),
        danger: Color(red: 1.0, green: 0.3, blue: 0.3)
    )

    static let pureBlack = AppTheme(
        name: AppThemeName.pureBlack,
        background: Color(red: 0, green: 0, blue: 0),
        surface: Color(red: 0, green: 0, blue: 0),
        surfaceSecondary: Color(white: 0.09),
        primary: .white,
        secondary: Color(white: 0.7),
        text: .white,
        textSecondary: Color(white: 0.55),
        success: Color(red: 0.2, green: 0.85, blue: 0.4),
        warning: Color(red: 1.0, green: 0.75, blue: 0.2),
        danger: Color(red: 1.0, green: 0.3, blue: 0.3)
    )

    static let purpleGlass = AppTheme(
        name: AppThemeName.purpleGlass,
        background: Color(red: 0.05, green: 0.02, blue: 0.1),
        surface: Color(red: 0.12, green: 0.07, blue: 0.2),
        surfaceSecondary: Color(red: 0.18, green: 0.11, blue: 0.28),
        primary: Color(red: 0.7, green: 0.45, blue: 1.0),
        secondary: Color(red: 0.5, green: 0.8, blue: 1.0),
        text: .white,
        textSecondary: Color(white: 0.65),
        success: Color(red: 0.2, green: 0.85, blue: 0.4),
        warning: Color(red: 1.0, green: 0.75, blue: 0.2),
        danger: Color(red: 1.0, green: 0.3, blue: 0.3)
    )

    static let cyanGlass = AppTheme(
        name: AppThemeName.cyanGlass,
        background: Color(red: 0, green: 0, blue: 0),
        surface: Color(red: 0.03, green: 0.1, blue: 0.12),
        surfaceSecondary: Color(red: 0.07, green: 0.16, blue: 0.19),
        primary: Color(red: 0.2, green: 0.85, blue: 0.95),
        secondary: Color(red: 0.55, green: 0.95, blue: 1.0),
        text: .white,
        textSecondary: Color(white: 0.62),
        success: Color(red: 0.2, green: 0.85, blue: 0.4),
        warning: Color(red: 1.0, green: 0.75, blue: 0.2),
        danger: Color(red: 1.0, green: 0.3, blue: 0.3)
    )

    static let blueNight = AppTheme(
        name: AppThemeName.blueNight,
        background: Color(red: 0, green: 0, blue: 0),
        surface: Color(red: 0.04, green: 0.06, blue: 0.12),
        surfaceSecondary: Color(red: 0.08, green: 0.11, blue: 0.19),
        primary: Color(red: 0.35, green: 0.6, blue: 1.0),
        secondary: Color(red: 0.55, green: 0.8, blue: 1.0),
        text: .white,
        textSecondary: Color(white: 0.62),
        success: Color(red: 0.2, green: 0.85, blue: 0.4),
        warning: Color(red: 1.0, green: 0.75, blue: 0.2),
        danger: Color(red: 1.0, green: 0.35, blue: 0.4)
    )

    static let neonGreen = AppTheme(
        name: AppThemeName.neonGreen,
        background: Color(red: 0, green: 0, blue: 0),
        surface: Color(red: 0.04, green: 0.08, blue: 0.05),
        surfaceSecondary: Color(red: 0.08, green: 0.14, blue: 0.09),
        primary: Color(red: 0.3, green: 1.0, blue: 0.45),
        secondary: Color(red: 0.65, green: 1.0, blue: 0.7),
        text: .white,
        textSecondary: Color(white: 0.62),
        success: Color(red: 0.3, green: 1.0, blue: 0.45),
        warning: Color(red: 1.0, green: 0.75, blue: 0.2),
        danger: Color(red: 1.0, green: 0.3, blue: 0.3)
    )

    static let darkRed = AppTheme(
        name: AppThemeName.darkRed,
        background: Color(red: 0, green: 0, blue: 0),
        surface: Color(red: 0.1, green: 0.03, blue: 0.04),
        surfaceSecondary: Color(red: 0.17, green: 0.06, blue: 0.07),
        primary: Color(red: 1.0, green: 0.25, blue: 0.3),
        secondary: Color(red: 1.0, green: 0.6, blue: 0.45),
        text: .white,
        textSecondary: Color(white: 0.62),
        success: Color(red: 0.2, green: 0.85, blue: 0.4),
        warning: Color(red: 1.0, green: 0.75, blue: 0.2),
        danger: Color(red: 1.0, green: 0.3, blue: 0.3)
    )

    /// Dark-only интерпретация «белого минимализма»: чёрный OLED-фон + белый акцент.
    static let whiteMinimal = AppTheme(
        name: AppThemeName.whiteMinimal,
        background: Color(red: 0, green: 0, blue: 0),
        surface: Color(white: 0.09),
        surfaceSecondary: Color(white: 0.16),
        primary: .white,
        secondary: Color(white: 0.75),
        text: .white,
        textSecondary: Color(white: 0.6),
        success: Color(red: 0.35, green: 0.9, blue: 0.5),
        warning: Color(red: 1.0, green: 0.8, blue: 0.35),
        danger: Color(red: 1.0, green: 0.45, blue: 0.45)
    )

    static let pinkBloom = AppTheme(
        name: AppThemeName.pinkBloom,
        background: Color(red: 0, green: 0, blue: 0),
        surface: Color(red: 0.11, green: 0.04, blue: 0.09),
        surfaceSecondary: Color(red: 0.18, green: 0.08, blue: 0.15),
        primary: Color(red: 1.0, green: 0.4, blue: 0.7),
        secondary: Color(red: 1.0, green: 0.65, blue: 0.85),
        text: .white,
        textSecondary: Color(white: 0.62),
        success: Color(red: 0.2, green: 0.85, blue: 0.4),
        warning: Color(red: 1.0, green: 0.75, blue: 0.2),
        danger: Color(red: 1.0, green: 0.3, blue: 0.3)
    )

    static let midnightGold = AppTheme(
        name: AppThemeName.midnightGold,
        background: Color(red: 0, green: 0, blue: 0),
        surface: Color(red: 0.08, green: 0.07, blue: 0.04),
        surfaceSecondary: Color(red: 0.14, green: 0.12, blue: 0.07),
        primary: Color(red: 0.95, green: 0.75, blue: 0.3),
        secondary: Color(red: 1.0, green: 0.88, blue: 0.6),
        text: .white,
        textSecondary: Color(white: 0.62),
        success: Color(red: 0.2, green: 0.85, blue: 0.4),
        warning: Color(red: 1.0, green: 0.75, blue: 0.2),
        danger: Color(red: 1.0, green: 0.3, blue: 0.3)
    )

    // Легаси-имена (было 5 пресетов): маппятся на ближайшие новые.
    static let crimsonNight = AppTheme.darkRed
    static let arcticSteel = AppTheme.blueNight

    static let all: [AppTheme] = [
        .oledOrange, .pureBlack, .purpleGlass, .cyanGlass, .blueNight,
        .neonGreen, .darkRed, .whiteMinimal, .pinkBloom, .midnightGold,
    ]

    // MARK: High contrast

    /// High-contrast вариант: чистый чёрный фон, белый текст, утолщённые акценты.
    func highContrastVariant() -> AppTheme {
        AppTheme(
            name: name,
            background: Color(red: 0, green: 0, blue: 0),
            surface: Color(white: 0.05),
            surfaceSecondary: Color(white: 0.14),
            primary: primary,
            secondary: secondary,
            text: .white,
            textSecondary: Color(white: 0.8),
            success: success,
            warning: warning,
            danger: danger
        )
    }
}

// MARK: - AppThemeName

enum AppThemeName {
    static let oledOrange = "OLED Orange"
    static let pureBlack = "Pure Black"
    static let purpleGlass = "Purple Glass"
    static let cyanGlass = "Cyan Glass"
    static let blueNight = "Blue Night"
    static let neonGreen = "Neon Green"
    static let darkRed = "Dark Red"
    static let whiteMinimal = "White Minimal"
    static let pinkBloom = "Pink Bloom"
    static let midnightGold = "Midnight Gold"
    // Легаси-имена для старых сохранёнок.
    static let crimsonNight = "Crimson Night"
    static let arcticSteel = "Arctic Steel"
}

// MARK: - ThemeManager

/// Источник правды для темы + локали (RU/EN заглушка: реальный перевод — String Catalogs).
/// Персист — @AppStorage (имя темы, масштаб шрифта, high-contrast).
@Observable
final class ThemeManager {
    @ObservationIgnored @AppStorage("lumeo.themeName") var themeName: String = AppThemeName.oledOrange
    @ObservationIgnored @AppStorage("lumeo.fontScale") var fontScale: Double = 1.0
    @ObservationIgnored @AppStorage("lumeo.highContrast") var highContrastStored: Bool = false
    @ObservationIgnored @AppStorage("lumeo.reduceMotion") var reduceMotionStored: Bool = false
    @ObservationIgnored @AppStorage("lumeo.locale") var localeIdentifier: String = "ru"

    /// Базовая палитра по сохранённому имени (с миграцией легаси-имён).
    var base: AppTheme {
        if let found = AppTheme.all.first(where: { $0.name == themeName }) {
            return found
        }
        switch themeName {
        case AppThemeName.crimsonNight: return .darkRed
        case AppThemeName.arcticSteel: return .blueNight
        default: return .oledOrange
        }
    }

    /// Текущая палитра с учётом high-contrast.
    var current: AppTheme {
        highContrastEnabled ? base.highContrastVariant() : base
    }

    /// Масштаб шрифта Dynamic Type (0.85...1.35), применяется во вью через scaled(_:).
    var fontScaleClamped: Double { min(1.35, max(0.85, fontScale)) }

    /// Reduce Motion: явный флаг + системная настройка (читается во вью через environment).
    var reduceMotionEnabled: Bool { reduceMotionStored }

    var highContrastEnabled: Bool { highContrastStored }

    var locale: Locale {
        get { Locale(identifier: localeIdentifier) }
        set { localeIdentifier = newValue.identifier }
    }

    init() {}

    func apply(_ theme: AppTheme) {
        themeName = theme.name
    }

    func apply(named name: String) {
        if AppTheme.all.contains(where: { $0.name == name }) {
            themeName = name
        } else if name == AppThemeName.crimsonNight {
            themeName = AppThemeName.darkRed
        } else if name == AppThemeName.arcticSteel {
            themeName = AppThemeName.blueNight
        }
    }

    /// Масштабированный кегль под Dynamic Type (дополняет системный dynamicTypeSize).
    func scaled(_ points: CGFloat) -> CGFloat {
        points * CGFloat(fontScaleClamped)
    }

    /// Анимация с учётом Reduce Motion: при включённом — мгновенно (.none).
    func animation(_ defaultAnimation: Animation = .easeInOut(duration: 0.25)) -> Animation? {
        reduceMotionStored ? nil : defaultAnimation
    }
}

// MARK: - Availability color helper

extension Availability {
    /// Цвет статуса по палитре темы.
    func color(in theme: AppTheme) -> Color {
        switch self {
        case .green: theme.success
        case .yellow: theme.warning
        case .red: theme.danger
        }
    }
}
