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

    // Use singletons directly
    private let authManager = AuthManager.shared
    private let healthKitService = HealthKitService.shared
    private let pairingViewModel = PairingViewModel.shared

    var body: some View {
        Group {
            if authManager.isAuthenticated {
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
        // Request HealthKit authorization (independent from authentication)
        if !healthKitService.isAuthorized {
            _ = await healthKitService.requestAuthorization()
        }

        // Load initial data (requires authentication)
        await pairingViewModel.loadPairings()
        await dashboardViewModel.refresh()
        await goalsViewModel.loadGoals()
        await profileViewModel.fetchPreferences()

        // Start auto-refresh
        dashboardViewModel.startAutoRefresh()

        // Enable background delivery for HealthKit
        let todayTypes: [HealthDataType] = [.steps, .activeEnergy, .exerciseMinutes, .standHours, .heartRate]
        await healthKitService.enableBackgroundDelivery(for: todayTypes)
    }

    // Separate function for HealthKit-only initialization (for development/testing)
    func initializeHealthKitOnly() async {
        if !healthKitService.isAuthorized {
            _ = await healthKitService.requestAuthorization()
        }
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
        case goals = "Goals"
        case pairing = "Partner"
        case profile = "Profile"

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

            GoalsView()
                .tabItem {
                    Label(Tab.goals.rawValue, systemImage: Tab.goals.icon)
                }
                .tag(Tab.goals)

            PairingView()
                .tabItem {
                    Label(Tab.pairing.rawValue, systemImage: Tab.pairing.icon)
                }
                .tag(Tab.pairing)
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

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var currentPage = 0

    let pages = [
        OnboardingPage(
            title: "Welcome to FitnessForLovers",
            subtitle: "Share your health journey with someone special",
            image: "heart.fill",
            color: .pink
        ),
        OnboardingPage(
            title: "Connect with Your Partner",
            subtitle: "Invite your partner to share fitness data and motivate each other",
            image: "person.2.fill",
            color: .blue
        ),
        OnboardingPage(
            title: "Set Shared Goals",
            subtitle: "Create goals together and track progress side by side",
            image: "target",
            color: .green
        ),
        OnboardingPage(
            title: "Stay in Sync",
            subtitle: "Automatic HealthKit sync keeps your data always up to date",
            image: "arrow.clockwise.heart",
            color: .orange
        )
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Continue Button
                VStack(spacing: 16) {
                    if currentPage == pages.count - 1 {
                        SignInWithAppleButton()
                            .frame(height: 56)
                            .padding(.horizontal, 32)

                        // Development Login (DEBUG only)
                        #if DEBUG
                        DevLoginButton()
                            .frame(height: 56)
                            .padding(.horizontal, 32)
                        #endif

                        // HealthKit Test (DEBUG only) - independent from auth
                        #if DEBUG
                        HealthKitTestButton()
                            .frame(height: 56)
                            .padding(.horizontal, 32)
                        #endif
                    } else {
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(pages[currentPage].color.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 32)
                    }

                    Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let image: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.image)
                .font(.system(size: 100))
                .foregroundStyle(page.color.gradient)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(page.subtitle)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

struct SignInWithAppleButton: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 12) {
            // Error message display
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            SignInWithAppleButtonRepresentable { authorization in
                Task {
                    await authManager.signInWithApple(authorization: authorization)
                }
            } onError: { error in
                Task {
                    // Handle ASAuthorizationError properly
                    if let authError = error as? ASAuthorizationError {
                        await authManager.setError(appleAuthErrorDescription(authError))
                    } else {
                        await authManager.setError(error.localizedDescription)
                    }
                }
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 56)
        }
        .animation(.easeInOut(duration: 0.2), value: authManager.errorMessage)
    }

    private func appleAuthErrorDescription(_ error: ASAuthorizationError) -> String {
        switch error.code {
        case .canceled:
            return "Sign in was canceled"
        case .failed:
            return "Sign in failed. Please try again."
        case .invalidResponse:
            return "Invalid response from Apple. Please try again."
        case .notHandled:
            return "Sign in could not be completed. Please try again."
        case .unknown:
            return "An unknown error occurred. Please try again."
        @unknown default:
            return "Sign in failed with error code \(error.code.rawValue). Please try again."
        }
    }
}

// MARK: - Development Login Button (DEBUG only)
#if DEBUG
struct DevLoginButton: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 12) {
            // Error message display
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button(action: {
                Task {
                    await authManager.signInDevelopment()
                }
            }) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .frame(width: 20, height: 20)
                            .tint(.white)
                    } else {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 18, weight: .medium))
                        Text("Development Login")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.orange.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(authManager.isLoading)
        }
        .animation(.easeInOut(duration: 0.2), value: authManager.errorMessage)
    }
}
#endif

// MARK: - HealthKit Test Button (DEBUG only)
#if DEBUG
struct HealthKitTestButton: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 12) {
            if let errorMessage = healthKitService.syncError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button(action: {
                Task {
                    _ = await healthKitService.requestAuthorization()
                }
            }) {
                HStack {
                    if healthKitService.isSyncing {
                        ProgressView()
                            .frame(width: 20, height: 20)
                            .tint(.white)
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18, weight: .medium))
                        Text(healthKitService.isAuthorized ? "HealthKit ✓ Connected" : "Test HealthKit Access")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(healthKitService.isAuthorized ? Color.green.gradient : Color.pink.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(healthKitService.isSyncing)
        }
        .animation(.easeInOut(duration: 0.2), value: healthKitService.syncError)
    }
}
#endif

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

            while remainingLength > 0 {
                let randoms: [UInt8] = (0..<16).map { _ in
                    var random: UInt8 = 0
                    SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                    return random
                }

                randoms.forEach { random in
                    if remainingLength == 0 { return }
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