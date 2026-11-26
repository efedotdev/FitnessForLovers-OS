//
//  AppRootView.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct AppRootView: View {
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var goalsViewModel = GoalsViewModel()
    @StateObject private var profileViewModel = ProfileViewModel()

    @StateObject private var authManager = AuthManager.shared
    private let healthKitService = HealthKitService.shared
    private let pairingViewModel = PairingViewModel.shared

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(authManager)
                    .environmentObject(healthKitService)
                    .environmentObject(pairingViewModel)
                    .environmentObject(dashboardViewModel)
                    .environmentObject(goalsViewModel)
                    .environmentObject(profileViewModel)
                    .task {
                        await initializeApp()
                    }
            } else {
                OnboardingView()
                    .environmentObject(authManager)
                    .environmentObject(healthKitService)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }

    private func initializeApp() async {
        // Load initial data (requires authentication)
        await pairingViewModel.loadPairings()
        await dashboardViewModel.refresh()
        await goalsViewModel.loadGoals()
        await profileViewModel.fetchPreferences()

        // Start auto-refresh
        dashboardViewModel.startAutoRefresh()
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var pairingViewModel: PairingViewModel
    @EnvironmentObject var dashboardViewModel: DashboardViewModel

    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case pairing = "Partner"
        case goals = "Goals"
        case profile = "Settings"

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .goals: return "target"
            case .pairing: return "person.2.fill"
            case .profile: return "person.circle.fill"
            }
        }

        var selectedIcon: String {
            return icon
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(Tab.dashboard.rawValue, systemImage: Tab.dashboard.icon)
                }
                .tag(Tab.dashboard)

            PairingView()
                .tabItem {
                    Label(Tab.pairing.rawValue, systemImage: Tab.pairing.icon)
                }
                .tag(Tab.pairing)

            GoalsView()
                .tabItem {
                    Label(Tab.goals.rawValue, systemImage: Tab.goals.icon)
                }
                .tag(Tab.goals)
                .badge(pairingViewModel.pendingInvitations.count > 0 ? pairingViewModel.pendingInvitations.count : 0)

            ProfileView()
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .accentColor(.primary)
    }
}

// MARK: - Email Authentication

struct OnboardingView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var isRegistering = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var passwordResetMessage: String?

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSubmit: Bool {
        guard !normalizedEmail.isEmpty, normalizedEmail.contains("@"), password.count >= 8 else {
            return false
        }
        if isRegistering {
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && password == passwordConfirmation
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.pink.gradient)
                        .padding(.top, 36)

                    Text("FitnessForLovers")
                        .font(.largeTitle.bold())

                    Text(isRegistering ? "Create your account" : "Sign in to your account")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 14) {
                        if isRegistering {
                            TextField("Name", text: $name)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .textFieldStyle(.roundedBorder)
                        }

                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        SecureField("Password", text: $password)
                            .textContentType(isRegistering ? .newPassword : .password)
                            .textFieldStyle(.roundedBorder)

                        if isRegistering {
                            SecureField("Confirm password", text: $passwordConfirmation)
                                .textContentType(.newPassword)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    if let passwordResetMessage {
                        Text(passwordResetMessage)
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            passwordResetMessage = nil
                            if isRegistering {
                                await authManager.register(
                                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                    email: normalizedEmail,
                                    password: password
                                )
                            } else {
                                await authManager.login(email: normalizedEmail, password: password)
                            }
                        }
                    } label: {
                        if authManager.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        } else {
                            Text(isRegistering ? "Create account" : "Sign in")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(authManager.isLoading || !canSubmit)

                    if !isRegistering {
                        NavigationLink {
                            ForgotPasswordView(email: $email) {
                                password = ""
                                passwordConfirmation = ""
                                passwordResetMessage = "Your password was reset. Sign in with your new password."
                            }
                        } label: {
                            Text("Forgot password?")
                        }
                        .disabled(authManager.isLoading)
                    }

                    if isRegistering && password != passwordConfirmation && !passwordConfirmation.isEmpty {
                        Text("Passwords do not match.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(isRegistering ? "Already have an account? Sign in" : "Create an account") {
                        isRegistering.toggle()
                        authManager.clearError()
                    }
                    .disabled(authManager.isLoading)

                    Divider()

                    SignInWithAppleButton()
                        .frame(height: 52)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var email: String
    let onSuccess: () -> Void

    @State private var newPassword = ""
    @State private var newPasswordConfirmation = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let apiService = APIService.shared

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isValidEmail: Bool {
        let parts = normalizedEmail.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2
            && !parts[0].isEmpty
            && parts[1].contains(".")
            && !normalizedEmail.contains(where: \.isWhitespace)
    }

    private var canSubmit: Bool {
        isValidEmail
            && newPassword.count >= 8
            && newPassword == newPasswordConfirmation
    }

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("New password", text: $newPassword)
                    .textContentType(.newPassword)

                SecureField("Confirm new password", text: $newPasswordConfirmation)
                    .textContentType(.newPassword)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if !normalizedEmail.isEmpty && !isValidEmail {
                        Text("Enter a valid email address.")
                    }
                    if !newPassword.isEmpty && newPassword.count < 8 {
                        Text("Password must be at least 8 characters.")
                    }
                    if !newPasswordConfirmation.isEmpty && newPassword != newPasswordConfirmation {
                        Text("Passwords do not match.")
                    }
                }
                .foregroundStyle(.red)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    Task {
                        await resetPassword()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Reset password")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(isLoading || !canSubmit)
            }
        }
        .navigationTitle("Forgot password")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    @MainActor
    private func resetPassword() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await apiService.devResetPassword(
                DevResetPasswordRequest(
                    email: normalizedEmail,
                    newPassword: newPassword,
                    newPasswordConfirmation: newPasswordConfirmation
                )
            )
            newPassword = ""
            newPasswordConfirmation = ""
            onSuccess()
            dismiss()
        } catch {
            errorMessage = resetErrorMessage(for: error)
        }
    }

    private func resetErrorMessage(for error: Error) -> String {
        guard let apiError = error as? APIServiceError else {
            return "Password could not be reset. Please try again."
        }

        switch apiError {
        case .noInternetConnection, .requestTimeout:
            return "Unable to connect. Check your connection and try again."
        case .notFound:
            return "Password reset is unavailable for this account. Check the email and try again."
        default:
            return "Password could not be reset. Check your details and try again."
        }
    }
}

struct SignInWithAppleButton: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        SignInWithAppleButtonRepresentable { authorization in
            Task {
                await authManager.signInWithApple(authorization: authorization)
            }
        } onError: { _ in
            Task {
                authManager.setError("Apple ile giriş yapılamadı. Lütfen tekrar deneyin.")
            }
        }
        .signInWithAppleButtonStyle(.whiteOutline)
        .frame(height: 52)
    }
}

struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
    let onSuccess: (ASAuthorization) -> Void
    let onError: (Error) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .whiteOutline)
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
        button.cornerRadius = 16
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSuccess: onSuccess, onError: onError)
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let onSuccess: (ASAuthorization) -> Void
        let onError: (Error) -> Void

        init(onSuccess: @escaping (ASAuthorization) -> Void, onError: @escaping (Error) -> Void) {
            self.onSuccess = onSuccess
            self.onError = onError
        }

        @objc func handleTap() {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let nonce = randomNonceString()
            request.nonce = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            onSuccess(authorization)
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            onError(error)
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            return UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first ?? UIWindow()
        }

        private func randomNonceString(length: Int = 32) -> String {
            let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
            var result = ""
            var remainingLength = length
            var generator = SystemRandomNumberGenerator()

            while remainingLength > 0 {
                for _ in 0..<16 {
                    if remainingLength == 0 { break }
                    let random = UInt8.random(in: .min ... .max, using: &generator)
                    if random < charset.count {
                        result.append(charset[Int(random)])
                        remainingLength -= 1
                    }
                }
            }
            return result
        }

        private func sha256(_ input: String) -> String {
            let inputData = Data(input.utf8)
            let hashedData = SHA256.hash(data: inputData)
            return hashedData.compactMap { String(format: "%02x", $0) }.joined()
        }
    }
}