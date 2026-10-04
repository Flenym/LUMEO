// Lumeo — Sources/Support/UITesting.swift
// Флаги UI-тестов: `--uitesting` (стабы вместо сети) и `--reset-state` (сброс регистрации).
// В прод-сборке флаги отсутствуют — поведение обычное.

import Foundation

enum UITesting {
    /// Активен, когда апп запущен с аргументом `--uitesting` (LumeoUITests).
    static var isActive: Bool {
        CommandLine.arguments.contains("--uitesting")
    }

    /// Сбросить локальную регистрацию при старте (чистый прогон auth-flow).
    static var shouldReset: Bool {
        CommandLine.arguments.contains("--reset-state")
    }

    /// Стаб кода подтверждения email (совпадает с backend peekVerifyCode в тестах).
    static let stubVerifyCode = "123456"
}
