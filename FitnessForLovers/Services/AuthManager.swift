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
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentNonce: String?

    private init() {
        checkAuthenticationStatus()
    }

    // MARK: - Authentication Status

    func checkAuthenticationStatus() {
        Task {
            await restoreSession()
        }
    }

    private func restoreSession() async {
        guard await apiService.isAuthenticated else {
            await updateAuthState(user: nil, authenticated: false)
            return
        }

        do {
            let response = try await apiService.getCurrentUser()
            await updateAuthState(user: response.user, authenticated: true)
        } catch {
            // Token might be expired, try to refresh
            await handleTokenRefreshFailure()
        }
    }

    private func handleTokenRefreshFailure() async {
        await apiService.clearTokens()
        await updateAuthState(user: nil, authenticated: false)
    }

    @MainActor
    private func updateAuthState(user: UserResponse?, authenticated: Bool) {
        self.currentUser = user
        self.isAuthenticated = authenticated
    }

    // MARK: - Apple Sign In

    func signInWithApple(authorization: ASAuthorization) async {
        await setLoading(true)
        defer { Task { await setLoading(false) } }

        // Check for authorization error first
        if let error = authorizationError(from: authorization) {
            logAppleAuthError(error)
            await setError(appleAuthErrorDescription(error))
            return
        }

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            await setError("Invalid Apple ID credential")
            return
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            await setError("Failed to get identity token")
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
            // Save tokens ONLY after successful backend response
            await apiService.setTokens(accessToken: response.tokens.accessToken, refreshToken: response.tokens.refreshToken)
            // Transition to authenticated state AFTER tokens are saved
            await updateAuthState(user: response.user, authenticated: true)
        } catch let apiError as APIServiceError {
            // Log API error without sensitive data
            logAPIError(apiError, context: "appleSignIn")
            await setError(apiError.localizedDescription)
        } catch {
            // Log unknown error
            logUnknownError(error, context: "appleSignIn")
            await setError("Sign in failed. Please try again.")
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
        await setLoading(true)
        defer { Task { await setLoading(false) } }

        do {
            try await apiService.logout()
        } catch {
            logAPIError(error as? APIServiceError ?? APIServiceError.unknown(error), context: "logout")
        }

        await apiService.clearTokens()
        await updateAuthState(user: nil, authenticated: false)
    }

    // MARK: - Development Login (DEBUG only)

    #if DEBUG
    func signInDevelopment(testEmail: String = "dev@fitnessforlovers.test", name: String = "Development User") async {
        await setLoading(true)
        defer { Task { await setLoading(false) } }

        do {
            let response = try await apiService.devLogin(testEmail: testEmail, name: name)
            // Save tokens ONLY after successful backend response (same as Apple Sign In)
            await apiService.setTokens(accessToken: response.tokens.accessToken, refreshToken: response.tokens.refreshToken)
            // Transition to authenticated state AFTER tokens are saved
            await updateAuthState(user: response.user, authenticated: true)
        } catch let apiError as APIServiceError {
            logAPIError(apiError, context: "devLogin")
            await setError(apiError.localizedDescription)
        } catch {
            logUnknownError(error, context: "devLogin")
            await setError("Development login failed. Please try again.")
        }
    }
    #endif

    // MARK: - Profile Management

    func updateProfile(name: String?, avatarUrl: String?) async throws -> UserResponse {
        let request = UpdateProfileRequest(name: name, avatarUrl: avatarUrl)
        let user = try await apiService.updateProfile(request)
        await updateAuthState(user: user, authenticated: true)
        return user
    }

    func updatePreferences(_ request: UpdatePreferencesRequest) async throws -> UserPreferencesResponse {
        return try await apiService.updatePreferences(request)
    }

    // MARK: - Helpers

    @MainActor
    private func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    @MainActor
    func setError(_ message: String) {
        errorMessage = message
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Error Handling Helpers

    /// Extract ASAuthorizationError from authorization if present
    private func authorizationError(from authorization: ASAuthorization) -> ASAuthorizationError? {
        // Check if authorization has an error (via userInfo)
        if let error = (authorization as? NSObject)?.value(forKey: "error") as? ASAuthorizationError {
            return error
        }
        return nil
    }

    /// Log Apple authorization error with code and safe description (NO tokens)
    private func logAppleAuthError(_ error: ASAuthorizationError) {
        let errorCode = error.code.rawValue
        let safeDescription: String

        switch error.code {
        case .canceled:
            safeDescription = "User canceled the sign in"
        case .failed:
            safeDescription = "Authorization failed"
        case .invalidResponse:
            safeDescription = "Invalid response from Apple"
        case .notHandled:
            safeDescription = "Authorization not handled"
        case .unknown:
            safeDescription = "Unknown authorization error"
        case .notInteractive:
            safeDescription = "Not interactive"
        case .matchedExcludedCredential:
            safeDescription = "Matched excluded credential"
        case .credentialImport:
            safeDescription = "Credential import error"
        case .credentialExport:
            safeDescription = "Credential export error"
        case .preferSignInWithApple:
            safeDescription = "Prefer Sign in with Apple"
        case .deviceNotConfiguredForPasskeyCreation:
            safeDescription = "Device not configured for passkey creation"
        @unknown default:
            safeDescription = "Authorization error (code: \(errorCode))"
        }

        print("[AuthManager] Apple Sign In Error - Code: \(errorCode), Description: \(safeDescription)")
    }

    /// Get user-friendly error description for Apple auth errors
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
        case .notInteractive:
            return "Sign in requires user interaction. Please try again."
        case .matchedExcludedCredential:
            return "This credential cannot be used. Please try again."
        case .credentialImport:
            return "Credential import failed. Please try again."
        case .credentialExport:
            return "Credential export failed. Please try again."
        case .preferSignInWithApple:
            return "Please use Sign in with Apple."
        case .deviceNotConfiguredForPasskeyCreation:
            return "Device not configured for passkey creation."
        @unknown default:
            return "Sign in failed with error code \(error.code.rawValue). Please try again."
        }
    }

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