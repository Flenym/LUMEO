// Lumeo — Sources/Features/Onboarding/OnboardingView.swift
// Онбординг beta: register (email/username) → verify (код) → profile (display name) → Home.
// Показывается, пока не выставлен флаг lumeo.registered (см. LumeoApp).
// Beta-стаб: verify принимает stub-код 123456 (UITesting) или любой 6-значный код.

import SwiftUI

// MARK: - OnboardingStep

private enum OnboardingStep {
    case register, verify, profile
}

// MARK: - OnboardingView

struct OnboardingView: View {
    // Theme параметром, а не @Environment: fullScreenCover на старте
    // иногда не видит environment-провайдер (краш "No Observable object").
    // @Observable — reference type, обновления темы доходят и так.
    var theme: ThemeManager = ThemeManager()
    var onComplete: () -> Void

    @State private var step: OnboardingStep = .register
    @State private var email = ""
    @State private var username = ""
    @State private var code = ""
    @State private var displayName = ""
    @State private var verifyError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(String(localized: "onboarding.title"))
                    .font(.title.bold())
                    .foregroundStyle(theme.current.text)
                switch step {
                case .register:
                    registerForm
                case .verify:
                    verifyForm
                case .profile:
                    profileForm
                }
                Spacer()
            }
            .padding()
            .background(theme.current.background)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Register

    private var registerForm: some View {
        VStack(spacing: 12) {
            TextField(String(localized: "auth.email"), text: $email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .accessibilityIdentifier("onboarding.register.email")
            TextField(String(localized: "auth.username"), text: $username)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("onboarding.register.username")
            Button(String(localized: "auth.continue")) {
                Haptics.selection()
                guard isValidEmail(email), username.count >= 4 else { return }
                step = .verify
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.current.primary)
            .accessibilityIdentifier("onboarding.register.submit")
        }
    }

    // MARK: Verify

    private var verifyForm: some View {
        VStack(spacing: 12) {
            Text(String(localized: "verify.title"))
                .font(.headline)
                .foregroundStyle(theme.current.text)
            Text(String(localized: "verify.hint"))
                .font(.subheadline)
                .foregroundStyle(theme.current.textSecondary)
            TextField(String(localized: "verify.title"), text: $code)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("verify.code.field")
            if let verifyError {
                Text(verifyError)
                    .font(.footnote)
                    .foregroundStyle(theme.current.danger)
            }
            Button(String(localized: "verify.submit")) {
                Haptics.selection()
                if UITesting.isActive {
                    guard code == UITesting.stubVerifyCode else {
                        verifyError = String(localized: "verify.badCode")
                        return
                    }
                } else {
                    guard code.count == 6 else {
                        verifyError = String(localized: "verify.badCode")
                        return
                    }
                }
                step = .profile
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.current.primary)
            .accessibilityIdentifier("verify.submit")
        }
    }

    // MARK: Profile

    private var profileForm: some View {
        VStack(spacing: 12) {
            Text(String(localized: "profile.setup.title"))
                .font(.headline)
                .foregroundStyle(theme.current.text)
            TextField(String(localized: "profile.setup.displayName"), text: $displayName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("profile.setup.displayName")
            Button(String(localized: "profile.setup.done")) {
                Haptics.success()
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.current.primary)
            .accessibilityIdentifier("profile.setup.done")
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        value.contains("@") && value.contains(".")
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
        .environment(ThemeManager())
}
