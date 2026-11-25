//
//  APIService.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import Foundation

// MARK: - API Configuration

struct APIConfig {
    nonisolated static let baseURL = "http://localhost:3000" // Change for production
    nonisolated static let timeout: TimeInterval = 30
}

// MARK: - API Errors

enum APIServiceError: LocalizedError, Equatable, Sendable {
    case invalidURL
    case noInternetConnection
    case requestTimeout
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case serverError(String)
    case decodingError(String)
    case encodingError(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noInternetConnection: return "No internet connection"
        case .requestTimeout: return "Request timed out"
        case .unauthorized: return "Session expired. Please sign in again."
        case .forbidden: return "Access denied"
        case .notFound: return "Resource not found"
        case .conflict: return "This request conflicts with an existing resource"
        case .serverError(let message): return "Server error: \(message)"
        case .decodingError(let message): return "Data parsing error: \(message)"
        case .encodingError(let message): return "Data encoding error: \(message)"
        case .unknown(let error): return "Unknown error: \(error.localizedDescription)"
        }
    }

    static func == (lhs: APIServiceError, rhs: APIServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.noInternetConnection, .noInternetConnection),
             (.requestTimeout, .requestTimeout),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.conflict, .conflict):
            return true
        case (.serverError(let lhsMsg), .serverError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.decodingError(let lhsMsg), .decodingError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.encodingError(let lhsMsg), .encodingError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.unknown(let lhsErr), .unknown(let rhsErr)):
            return lhsErr.localizedDescription == rhsErr.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - API Service Implementation

actor APIService {
    static let shared = APIService()

    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private var accessToken: String?
    private var refreshToken: String?

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConfig.timeout
        configuration.timeoutIntervalForResource = APIConfig.timeout
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)

        self.jsonDecoder = .backendAPIDecoder()

        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        do {
            if let accessData = try KeychainHelper.load(key: "accessToken"),
               let refreshData = try KeychainHelper.load(key: "refreshToken"),
               let access = String(data: accessData, encoding: .utf8),
               let refresh = String(data: refreshData, encoding: .utf8) {
                self.accessToken = access
                self.refreshToken = refresh
            }
        } catch {
            print("[APIService] Unable to restore session from Keychain")
        }
    }

    // MARK: - Token Management

    func setTokens(accessToken: String, refreshToken: String) throws {
        do {
            try KeychainHelper.save(key: "accessToken", data: Data(accessToken.utf8))
            try KeychainHelper.save(key: "refreshToken", data: Data(refreshToken.utf8))
        } catch {
            try? clearTokensFromKeychain()
            throw APIServiceError.unknown(error)
        }
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func clearTokens() throws {
        self.accessToken = nil
        self.refreshToken = nil
        try clearTokensFromKeychain()
    }

    var currentAccessToken: String? {
        return accessToken
    }

    var isAuthenticated: Bool {
        return accessToken != nil
    }

    private func clearTokensFromKeychain() throws {
        try KeychainHelper.delete(key: "accessToken")
        try KeychainHelper.delete(key: "refreshToken")
    }

    // MARK: - Request Methods

    func request<T: Codable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await performRequest(endpoint)
        return try handleResponse(data: data, response: response, type: responseType)
    }

    func requestVoid(_ endpoint: Endpoint) async throws {
        let (_, response) = try await performRequest(endpoint)
        try handleVoidResponse(response: response)
    }

    // MARK: - Private Methods

    private func performRequest(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        guard let url = buildURL(for: endpoint) else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add custom headers
        endpoint.customHeaders?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add auth header
        if endpoint.requiresAuth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body
        if let body = endpoint.body {
            do {
                request.httpBody = try jsonEncoder.encode(body)
            } catch {
                throw APIServiceError.encodingError(error.localizedDescription)
            }
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.unknown(URLError(.badServerResponse))
            }

            if httpResponse.statusCode == 401 && endpoint.requiresAuth {
                guard refreshToken != nil else {
                    expireSession()
                    throw APIServiceError.unauthorized
                }

                do {
                    try await refreshAccessToken()
                } catch let refreshError as APIServiceError {
                    if refreshError == .unauthorized {
                        expireSession()
                    }
                    throw refreshError
                }

                // Retry request with new token
                guard let accessToken else {
                    expireSession()
                    throw APIServiceError.unauthorized
                }
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await session.data(for: request)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                    throw APIServiceError.unknown(URLError(.badServerResponse))
                }

                if retryHttpResponse.statusCode == 401 {
                    expireSession()
                    throw APIServiceError.unauthorized
                }
                return (retryData, retryHttpResponse)
            }

            return (data, httpResponse)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw APIServiceError.noInternetConnection
            case .timedOut:
                throw APIServiceError.requestTimeout
            default:
                throw APIServiceError.unknown(error)
            }
        } catch let error as APIServiceError {
            throw error
        } catch {
            throw APIServiceError.unknown(error)
        }
    }

    private func buildURL(for endpoint: Endpoint) -> URL? {
        endpoint.url(baseURL: APIConfig.baseURL)
    }

    private func expireSession() {
        accessToken = nil
        refreshToken = nil
        do {
            try clearTokensFromKeychain()
        } catch {
            print("[APIService] Unable to clear expired session from Keychain")
        }
        NotificationCenter.default.post(name: .sessionExpired, object: nil)
    }

    private func handleResponse<T: Codable>(
        data: Data,
        response: HTTPURLResponse,
        type: T.Type
    ) throws -> T {
        switch response.statusCode {
        case 200...299:
            do {
                // Try to decode as APIResponse first
                if let apiResponse = try? jsonDecoder.decode(APIResponse<T>.self, from: data) {
                    if apiResponse.success, let data = apiResponse.data {
                        return data
                    } else if let error = apiResponse.error?.message {
                        throw APIServiceError.serverError(error)
                    } else {
                        throw APIServiceError.serverError("Unknown API error")
                    }
                }
                // Try direct decode
                return try jsonDecoder.decode(T.self, from: data)
            } catch let error as APIServiceError {
                throw error
            } catch {
                throw APIServiceError.decodingError(error.localizedDescription)
            }
        case 401:
            throw APIServiceError.unauthorized
        case 403:
            throw APIServiceError.forbidden
        case 404:
            throw APIServiceError.notFound
        case 409:
            throw APIServiceError.conflict
        case 500...599:
            if let apiError = try? jsonDecoder.decode(APIResponse<T>.self, from: data),
               let error = apiError.error {
                throw APIServiceError.serverError(error.message ?? "Server error: \(response.statusCode)")
            }
            throw APIServiceError.serverError("Server error: \(response.statusCode)")
        default:
            throw APIServiceError.serverError("Unexpected status code: \(response.statusCode)")
        }
    }

    private func handleVoidResponse(response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw APIServiceError.unauthorized
        case 403:
            throw APIServiceError.forbidden
        case 404:
            throw APIServiceError.notFound
        case 409:
            throw APIServiceError.conflict
        case 500...599:
            throw APIServiceError.serverError("Server error: \(response.statusCode)")
        default:
            throw APIServiceError.serverError("Unexpected status code: \(response.statusCode)")
        }
    }

    private func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw APIServiceError.unauthorized
        }

        let endpoint = Endpoint(
            path: "/auth/refresh",
            method: .post,
            body: RefreshTokenRequest(refreshToken: refreshToken),
            requiresAuth: false
        )

        let url = buildURL(for: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(RefreshTokenRequest(refreshToken: refreshToken))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.unknown(URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            switch httpResponse.statusCode {
            case 401, 403:
                throw APIServiceError.unauthorized
            case 500...599:
                throw APIServiceError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                throw APIServiceError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }
        }

        let tokenResponse = try decodeSuccess(RefreshResponse.self, from: data)
        try setTokens(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
    }

    private func decodeSuccess<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        if let response = try? jsonDecoder.decode(APIResponse<T>.self, from: data) {
            guard response.success, let payload = response.data else {
                throw APIServiceError.serverError(response.error?.message ?? "Unknown API error")
            }
            return payload
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw APIServiceError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Convenience Methods

extension APIService {
    // Auth
    func register(_ registerRequest: RegisterRequest) async throws -> AuthResponse {
        let endpoint = Endpoint(
            path: "/auth/register",
            method: .post,
            body: registerRequest,
            requiresAuth: false
        )
        return try await request(endpoint, responseType: AuthResponse.self)
    }

    func login(_ loginRequest: LoginRequest) async throws -> AuthResponse {
        let endpoint = Endpoint(
            path: "/auth/login",
            method: .post,
            body: loginRequest,
            requiresAuth: false
        )
        return try await request(endpoint, responseType: AuthResponse.self)
    }

    func appleSignIn(_ signInRequest: AppleSignInRequest) async throws -> AuthResponse {
        let endpoint = Endpoint(
            path: "/auth/apple",
            method: .post,
            body: signInRequest,
            requiresAuth: false
        )
        return try await request(endpoint, responseType: AuthResponse.self)
    }

    func verifyAppleToken(_ verifyRequest: VerifyAppleRequest) async throws -> VerifyAppleResponse {
        let endpoint = Endpoint(
            path: "/auth/verify-apple",
            method: .post,
            body: verifyRequest,
            requiresAuth: false
        )
        return try await request(endpoint, responseType: VerifyAppleResponse.self)
    }

    func refreshToken() async throws -> RefreshResponse {
        guard let refreshToken = refreshToken else { throw APIServiceError.unauthorized }
        let endpoint = Endpoint(
            path: "/auth/refresh",
            method: .post,
            body: RefreshTokenRequest(refreshToken: refreshToken),
            requiresAuth: false
        )
        return try await request(endpoint, responseType: RefreshResponse.self)
    }

    func logout() async throws {
        let endpoint = Endpoint(path: "/auth/logout", method: .post)
        let _: LogoutResponse = try await request(endpoint, responseType: LogoutResponse.self)
    }

    func getCurrentUser() async throws -> MeResponse {
        let endpoint = Endpoint(path: "/auth/me")
        return try await request(endpoint, responseType: MeResponse.self)
    }

    // Pairings
    func createPairing(_ pairingRequest: CreatePairingRequest) async throws -> CreatePairingResponse {
        let endpoint = Endpoint(path: "/pairings", method: .post, body: pairingRequest)
        return try await request(endpoint, responseType: CreatePairingResponse.self)
    }

    func getPairings() async throws -> ListPairingsResponse {
        let endpoint = Endpoint(path: "/pairings")
        return try await request(endpoint, responseType: ListPairingsResponse.self)
    }

    func getPendingPairings() async throws -> ListPairingsResponse {
        let endpoint = Endpoint(path: "/pairings/pending")
        return try await request(endpoint, responseType: ListPairingsResponse.self)
    }

    func getSentPairings() async throws -> ListPairingsResponse {
        let endpoint = Endpoint(path: "/pairings/sent")
        return try await request(endpoint, responseType: ListPairingsResponse.self)
    }

    func getPairing(id: String) async throws -> GetPairingResponse {
        let endpoint = Endpoint(path: "/pairings/\(id)")
        return try await request(endpoint, responseType: GetPairingResponse.self)
    }

    func respondToPairing(id: String, action: RespondAction) async throws -> RespondPairingResponse {
        let endpoint = Endpoint(
            path: "/pairings/\(id)/respond",
            method: .post,
            body: RespondPairingRequest(action: action)
        )
        return try await request(endpoint, responseType: RespondPairingResponse.self)
    }

    func updatePairing(id: String, pairingRequest: UpdatePairingRequest) async throws -> UpdatePairingResponse {
        let endpoint = Endpoint(path: "/pairings/\(id)", method: .patch, body: pairingRequest)
        return try await request(endpoint, responseType: UpdatePairingResponse.self)
    }

    func deletePairing(id: String) async throws -> DeletePairingResponse {
        let endpoint = Endpoint(path: "/pairings/\(id)", method: .delete)
        return try await request(endpoint, responseType: DeletePairingResponse.self)
    }

    // Health Data
    func createHealthData(_ healthRequest: CreateHealthDataRequest) async throws -> HealthDataResponse {
        let endpoint = Endpoint(path: "/health-data", method: .post, body: healthRequest)
        return try await request(endpoint, responseType: HealthDataResponse.self)
    }

    func bulkSyncHealthData(_ bulkRequest: BulkHealthDataRequest) async throws -> BulkSyncResponse {
        let endpoint = Endpoint(path: "/health-data/bulk", method: .post, body: bulkRequest)
        return try await request(endpoint, responseType: BulkSyncResponse.self)
    }

    func getHealthData(query: QueryHealthDataRequest) async throws -> HealthDataListResponse {
        let queryItems = buildQueryItems(from: query)
        let endpoint = Endpoint(path: "/health-data", queryItems: queryItems)
        return try await request(endpoint, responseType: HealthDataListResponse.self)
    }

    func getDailySummary() async throws -> SummaryResponse {
        let endpoint = Endpoint(path: "/health-data/summary")
        return try await request(endpoint, responseType: SummaryResponse.self)
    }

    func getPartnerHealthData(partnerId: String, query: PartnerHealthDataQuery) async throws -> HealthDataListResponse {
        let queryItems = buildQueryItems(from: query)
        let endpoint = Endpoint(path: "/health-data/partner/\(partnerId)", queryItems: queryItems)
        return try await request(endpoint, responseType: HealthDataListResponse.self)
    }

    func getPartnerSummary(partnerId: String, date: Date? = nil) async throws -> PartnerSummaryResponse {
        var queryItems: [URLQueryItem] = []
        if let date = date {
            queryItems.append(URLQueryItem(name: "date", value: date.toDateOnlyString()))
        }
        let endpoint = Endpoint(path: "/health-data/partner/\(partnerId)/summary", queryItems: queryItems.isEmpty ? nil : queryItems)
        return try await request(endpoint, responseType: PartnerSummaryResponse.self)
    }

    // Goals
    func createGoal(_ goalRequest: CreateGoalRequest) async throws -> GoalResponse {
        let endpoint = Endpoint(path: "/goals", method: .post, body: goalRequest)
        let response: CreateGoalResponse = try await request(endpoint, responseType: CreateGoalResponse.self)
        return response.goal
    }

    func getGoals(pairingId: String) async throws -> GoalListResponse {
        let endpoint = Endpoint(path: "/goals/pairing/\(pairingId)")
        return try await request(endpoint, responseType: GoalListResponse.self)
    }

    func getGoal(id: String) async throws -> GoalResponse {
        let endpoint = Endpoint(path: "/goals/\(id)")
        let response: GetGoalResponse = try await request(endpoint, responseType: GetGoalResponse.self)
        return response.goal
    }

    func updateGoal(id: String, goalRequest: UpdateGoalRequest) async throws -> GoalResponse {
        let endpoint = Endpoint(path: "/goals/\(id)", method: .patch, body: goalRequest)
        let response: UpdateGoalResponse = try await request(endpoint, responseType: UpdateGoalResponse.self)
        return response.goal
    }

    func deleteGoal(id: String) async throws {
        let endpoint = Endpoint(path: "/goals/\(id)", method: .delete)
        try await requestVoid(endpoint)
    }

    func getGoalProgress(id: String) async throws -> GoalProgressResponse {
        let endpoint = Endpoint(path: "/goals/\(id)/progress")
        return try await request(endpoint, responseType: GoalProgressResponse.self)
    }

    // Dashboard
    func getDashboard() async throws -> DashboardResponse {
        let endpoint = Endpoint(path: "/dashboard")
        return try await request(endpoint, responseType: DashboardResponse.self)
    }

    // User
    func getProfile() async throws -> UserResponse {
        let endpoint = Endpoint(path: "/users/me")
        let response: ProfileResponse = try await request(endpoint, responseType: ProfileResponse.self)
        return response.user
    }

    func updateProfile(_ profileRequest: UpdateProfileRequest) async throws -> UserResponse {
        let endpoint = Endpoint(path: "/users/me", method: .patch, body: profileRequest)
        let response: ProfileResponse = try await request(endpoint, responseType: ProfileResponse.self)
        return response.user
    }

    func getPreferences() async throws -> UserPreferencesResponse {
        let endpoint = Endpoint(path: "/users/me/preferences")
        let response: PreferencesResponse = try await request(endpoint, responseType: PreferencesResponse.self)
        return response.preferences
    }

    func updatePreferences(_ prefsRequest: UpdatePreferencesRequest) async throws -> UserPreferencesResponse {
        let endpoint = Endpoint(path: "/users/me/preferences", method: .patch, body: prefsRequest)
        let response: PreferencesResponse = try await request(endpoint, responseType: PreferencesResponse.self)
        return response.preferences
    }

    // Devices
    func registerDevice(_ deviceRequest: RegisterDeviceRequest) async throws -> DeviceResponse {
        let endpoint = Endpoint(path: "/devices", method: .post, body: deviceRequest)
        let response: RegisterDeviceResponse = try await request(endpoint, responseType: RegisterDeviceResponse.self)
        return response.device
    }

    func getDevices() async throws -> DeviceListResponse {
        let endpoint = Endpoint(path: "/devices")
        return try await request(endpoint, responseType: DeviceListResponse.self)
    }

    func updateDevice(id: String, deviceRequest: UpdateDeviceRequest) async throws -> DeviceResponse {
        let endpoint = Endpoint(path: "/devices/\(id)", method: .patch, body: deviceRequest)
        let response: DeviceSingleResponse = try await request(endpoint, responseType: DeviceSingleResponse.self)
        return response.device
    }

    func deleteDevice(id: String) async throws {
        let endpoint = Endpoint(path: "/devices/\(id)", method: .delete)
        try await requestVoid(endpoint)
    }

    // Notifications
    func getNotifications(page: Int = 1, limit: Int = 20, unreadOnly: Bool = false) async throws -> NotificationListResponse {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if unreadOnly {
            queryItems.append(URLQueryItem(name: "unreadOnly", value: "true"))
        }
        let endpoint = Endpoint(path: "/notifications", queryItems: queryItems)
        return try await request(endpoint, responseType: NotificationListResponse.self)
    }

    func getUnreadCount() async throws -> UnreadCountResponse {
        let endpoint = Endpoint(path: "/notifications/unread-count")
        return try await request(endpoint, responseType: UnreadCountResponse.self)
    }

    func markNotificationRead(id: String) async throws -> NotificationResponse {
        let endpoint = Endpoint(path: "/notifications/\(id)/read", method: .patch)
        let response: MarkReadResponse = try await request(endpoint, responseType: MarkReadResponse.self)
        return response.notification
    }

    func markAllNotificationsRead() async throws -> Int {
        let endpoint = Endpoint(path: "/notifications/read-all", method: .post)
        let response: MarkAllReadResponse = try await request(endpoint, responseType: MarkAllReadResponse.self)
        return response.count
    }

    // MARK: - Helper Methods

    private func buildQueryItems(from encodable: Encodable) -> [URLQueryItem]? {
        guard let data = try? jsonEncoder.encode(encodable),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return dict.compactMap { key, value -> URLQueryItem? in
            if let array = value as? [Any] {
                return array.map { URLQueryItem(name: key, value: "\($0)") }.first
            }
            return URLQueryItem(name: key, value: "\(value)")
        }
    }
}

// MARK: - Missing Response Types (for API calls)

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct VerifyAppleRequest: Codable {
    let identityToken: String
}

struct CreateGoalResponse: Codable {
    let goal: GoalResponse
}

struct GetGoalResponse: Codable {
    let goal: GoalResponse
}

struct UpdateGoalResponse: Codable {
    let goal: GoalResponse
}

struct ProfileResponse: Codable {
    let user: UserResponse
}

struct PreferencesResponse: Codable {
    let preferences: UserPreferencesResponse
}

struct RegisterDeviceResponse: Codable {
    let device: DeviceResponse
}

struct DeviceSingleResponse: Codable {
    let device: DeviceResponse
}

struct MarkReadResponse: Codable {
    let notification: NotificationResponse
}

struct MarkAllReadResponse: Codable {
    let count: Int
}