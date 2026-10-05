// Lumeo — Sources/Features/Onboarding/OnboardingView.swift
// Онбординг beta (full-screen): register (email/username) → verify (код) →
// profile (display name) → Home. Тёмный OLED + оранжевое свечение + логотип.
// Beta-стаб: verify принимает stub-код 123456 (UITesting) или любой 6-значный код.

import SwiftUI

// MARK: - OnboardingStep

private enum OnboardingStep: Int, CaseIterable {
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
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, username, code, displayName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Фон: OLED + оранжевое свечение сверху + faint glow снизу.
                theme.current.background
                    .ignoresSafeArea()
                Circle()
                    .fill(theme.current.primary.opacity(0.22))
                    .frame(width: 320, height: 320)
                    .blur(radius: 90)
                    .offset(y: -260)
                    .allowsHitTesting(false)
                Circle()
                    .fill(theme.current.primary.opacity(0.08))
                    .frame(width: 260, height: 260)
                    .blur(radius: 80)
                    .offset(y: 300)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 0) {
                        // Логотип + вордмарк.
                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [theme.current.primary, theme.current.primary.opacity(0.6)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 76, height: 76)
                                    .shadow(color: theme.current.primary.opacity(0.45), radius: 24, y: 8)
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, 54)
                            Text("Lumeo")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(theme.current.text)
                            Text(String(localized: "onboarding.subtitle"))
                                .font(.subheadline)
                                .foregroundStyle(theme.current.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        // Прогресс шагов.
                        HStack(spacing: 8) {
                            ForEach(OnboardingStep.allCases, id: \.rawValue) { item in
                                Capsule()
                                    .fill(item.rawValue <= step.rawValue ? theme.current.primary : theme.current.surfaceSecondary)
                                    .frame(width: item == step ? 28 : 12, height: 6)
                                    .animation(.snappy, value: step)
                            }
                        }
                        .padding(.top, 22)
                        .accessibilityHidden(true)

                        // Заголовок шага.
                        Text(stepTitle)
                            .font(.title2.bold())
                            .foregroundStyle(theme.current.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 30)

                        // Форма шага.
                        Group {
                            switch step {
                            case .register:
                                registerForm
                            case .verify:
                                verifyForm
                            case .profile:
                                profileForm
                            }
                        }
                        .padding(.top, 14)

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(theme.current.background)
            .safeAreaInset(edge: .bottom) {
                ctaButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .background(theme.current.background.opacity(0.001))
            }
        }
        .preferredColorScheme(.dark)
        .tint(theme.current.primary)
    }

    // MARK: Titles / CTA

    private var stepTitle: String {
        switch step {
        case .register: String(localized: "onboarding.title")
        case .verify: String(localized: "verify.title")
        case .profile: String(localized: "profile.setup.title")
        }
    }

    @ViewBuilder
    private var ctaButton: some View {
        switch step {
        case .register:
            Button(String(localized: "auth.continue")) { submitRegister() }
                .buttonStyle(.borderedProminent)
                .tint(theme.current.primary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .accessibilityIdentifier("onboarding.register.submit")
        case .verify:
            Button(String(localized: "verify.submit")) { submitVerify() }
                .buttonStyle(.borderedProminent)
                .tint(theme.current.primary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .accessibilityIdentifier("verify.submit")
        case .profile:
            Button(String(localized: "profile.setup.done")) {
                Haptics.success()
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.current.primary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .accessibilityIdentifier("profile.setup.done")
        }
    }

    // MARK: Forms

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(theme.current.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.current.surfaceSecondary, lineWidth: 1)
            }
    }

    private var registerForm: some View {
        VStack(spacing: 12) {
            TextField(String(localized: "auth.email"), text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .focused($focusedField, equals: .email)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(fieldBackground)
                .accessibilityIdentifier("onboarding.register.email")
            TextField(String(localized: "auth.username"), text: $username)
                .textInputAutocapitalization(.never)
                .textContentType(.username)
                .focused($focusedField, equals: .username)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(fieldBackground)
                .accessibilityIdentifier("onboarding.register.username")
            Text(String(localized: "onboarding.register.hint"))
                .font(.footnote)
                .foregroundStyle(theme.current.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var verifyForm: some View {
        VStack(spacing: 12) {
            Text(String(localized: "verify.hint"))
                .font(.subheadline)
                .foregroundStyle(theme.current.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField(String(localized: "verify.code.hint"), text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focusedField, equals: .code)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(fieldBackground)
                .accessibilityIdentifier("verify.code.field")
            if let verifyError {
                Text(verifyError)
                    .font(.footnote)
                    .foregroundStyle(theme.current.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var profileForm: some View {
        VStack(spacing: 12) {
            Text(String(localized: "profile.setup.hint"))
                .font(.subheadline)
                .foregroundStyle(theme.current.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField(String(localized: "profile.setup.displayName"), text: $displayName)
                .textContentType(.name)
                .focused($focusedField, equals: .displayName)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(fieldBackground)
                .accessibilityIdentifier("profile.setup.displayName")
        }
    }

    // MARK: Logic (без изменений для UITests)

    private func submitRegister() {
        Haptics.selection()
        guard isValidEmail(email), username.count >= 4 else { return }
        step = .verify
        focusedField = .code
    }

    private func submitVerify() {
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
        focusedField = .displayName
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
