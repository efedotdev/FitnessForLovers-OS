//
//  AuthManager.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import Foundation
import Combine
import AuthenticationServices
import CryptoKit

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: UserResponse?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentNonce: String?

    private init() {
        setupObservers()
        checkAuthenticationStatus()
    }

    private func setupObservers() {
        NotificationCenter.default.publisher(for: .sessionExpired)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.updateAuthState(user: nil, authenticated: false)
                    self.errorMessage = "Oturum süreniz doldu. Lütfen tekrar giriş yapın."
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Authentication Status

    func checkAuthenticationStatus() {
        Task {
            await restoreSession()
        }
    }

    private func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        guard await apiService.isAuthenticated else {
            updateAuthState(user: nil, authenticated: false)
            return
        }

        do {
            let response = try await apiService.getCurrentUser()
            updateAuthState(user: response.user, authenticated: true)
        } catch {
            updateAuthState(user: nil, authenticated: false)
            if let apiError = error as? APIServiceError,
               apiError == .unauthorized || apiError == .forbidden {
                do {
                    try await apiService.clearTokens()
                } catch {
                    errorMessage = "Oturum bilgileri güvenli biçimde silinemedi."
                }
            } else {
                errorMessage = "Oturum doğrulanamadı. Bağlantınızı kontrol edip tekrar deneyin."
            }
        }
    }

    func register(name: String, email: String, password: String) async {
        await authenticate {
            try await apiService.register(RegisterRequest(name: name, email: email, password: password))
        }
    }

    func login(email: String, password: String) async {
        await authenticate {
            try await apiService.login(LoginRequest(email: email, password: password))
        }
    }

    private func authenticate(_ operation: () async throws -> AuthResponse) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await operation()
            try await apiService.setTokens(accessToken: response.tokens.accessToken, refreshToken: response.tokens.refreshToken)
            updateAuthState(user: response.user, authenticated: true)
        } catch {
            errorMessage = authenticationErrorMessage(for: error)
        }
    }

    private func updateAuthState(user: UserResponse?, authenticated: Bool) {
        currentUser = user
        isAuthenticated = authenticated
    }

    private func authenticationErrorMessage(for error: Error) -> String {
        guard let apiError = error as? APIServiceError else {
            return "İşlem tamamlanamadı. Lütfen tekrar deneyin."
        }

        switch apiError {
        case .unauthorized:
            return "E-posta veya parola hatalı."
        case .conflict:
            return "Bu e-posta adresiyle kayıtlı bir hesap zaten var."
        case .noInternetConnection, .requestTimeout:
            return "Sunucuya bağlanılamadı. Bağlantınızı kontrol edip tekrar deneyin."
        default:
            return "İşlem tamamlanamadı. Lütfen bilgilerinizi kontrol edip tekrar deneyin."
        }
    }

    // MARK: - Apple Sign In

    func signInWithApple(authorization: ASAuthorization) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            setError("Apple hesabı doğrulanamadı. Lütfen tekrar deneyin.")
            return
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            setError("Apple hesabı doğrulanamadı. Lütfen tekrar deneyin.")
            return
        }

        let authorizationCode: String? = {
            if let authCodeData = appleIDCredential.authorizationCode {
                return String(data: authCodeData, encoding: .utf8)
            }
            return nil
        }()

        let fullName = appleIDCredential.fullName
        let email = appleIDCredential.email

        let request = AppleSignInRequest(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            fullName: fullName.map { PersonNameComponents(givenName: $0.givenName, familyName: $0.familyName) },
            email: email
        )

        do {
            let response = try await apiService.appleSignIn(request)
            try await apiService.setTokens(accessToken: response.tokens.accessToken, refreshToken: response.tokens.refreshToken)
            updateAuthState(user: response.user, authenticated: true)
        } catch let apiError as APIServiceError {
            logAPIError(apiError, context: "appleSignIn")
            setError(authenticationErrorMessage(for: apiError))
        } catch {
            logUnknownError(error, context: "appleSignIn")
            setError("Apple ile giriş yapılamadı. Lütfen tekrar deneyin.")
        }
    }

    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    // MARK: - Sign Out

    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await apiService.logout()
        } catch {
            logAPIError(error as? APIServiceError ?? APIServiceError.unknown(error), context: "logout")
        }

        do {
            try await apiService.clearTokens()
        } catch {
            setError("Oturum bilgileri güvenli biçimde silinemedi. Lütfen uygulamayı yeniden başlatmadan önce tekrar deneyin.")
        }
        updateAuthState(user: nil, authenticated: false)
    }

    // MARK: - Profile Management

    func updateProfile(name: String?, avatarUrl: String?) async throws -> UserResponse {
        let request = UpdateProfileRequest(name: name, avatarUrl: avatarUrl)
        let user = try await apiService.updateProfile(request)
        updateAuthState(user: user, authenticated: true)
        return user
    }

    func updatePreferences(_ request: UpdatePreferencesRequest) async throws -> UserPreferencesResponse {
        return try await apiService.updatePreferences(request)
    }

    // MARK: - Helpers

    func setError(_ message: String) {
        errorMessage = message
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Error Handling Helpers

    /// Log API error without sensitive data
    private func logAPIError(_ error: APIServiceError, context: String) {
        let errorDescription = error.localizedDescription
        // Sanitize: never log tokens
        let sanitized = errorDescription
            .replacingOccurrences(of: "Bearer [^\\s]+", with: "Bearer ***", options: .regularExpression)
            .replacingOccurrences(of: "accessToken[^\\s]*", with: "accessToken=***", options: .regularExpression)
            .replacingOccurrences(of: "refreshToken[^\\s]*", with: "refreshToken=***", options: .regularExpression)
            .replacingOccurrences(of: "identityToken[^\\s]*", with: "identityToken=***", options: .regularExpression)
        print("[AuthManager] \(context) API Error: \(sanitized)")
    }

    /// Log unknown error
    private func logUnknownError(_ error: Error, context: String) {
        print("[AuthManager] \(context) Unknown Error: \(error.localizedDescription)")
    }

    // MARK: - Crypto Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
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