//
//  APIModels.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import Foundation

// MARK: - Base Response

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: APIError?
    let statusCode: Int?
}

struct APIError: Codable {
    let error: String?
    let message: String?
    let statusCode: Int?
    let details: [String: String]?
}

extension JSONDecoder {
    static func backendAPIDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }

            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO-8601 date string."
            )
        }
        return decoder
    }
}

// MARK: - Authentication Models

struct RegisterRequest: Codable {
    let name: String
    let email: String
    let password: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct DevResetPasswordRequest: Codable {
    let email: String
    let newPassword: String
    let newPasswordConfirmation: String
}

struct AppleSignInRequest: Codable {
    let identityToken: String
    let authorizationCode: String?
    let fullName: PersonNameComponents?
    let email: String?
}

struct PersonNameComponents: Codable {
    let givenName: String?
    let familyName: String?
}

struct TokensResponse: Codable {
    let accessToken: String
    let refreshToken: String
}

struct UserResponse: Codable {
    let id: String
    let email: String
    let name: String?
    let avatarUrl: String?
    let createdAt: Date
    let appleUserId: String?
    let role: String?
    let emailVerified: Bool?
    let lastLoginAt: Date?
    let preferences: UserPreferencesResponse?

    var displayName: String {
        return name ?? email.components(separatedBy: "@").first ?? "User"
    }
}

struct AuthResponse: Codable {
    let user: UserResponse
    let tokens: TokensResponse
    let isNewUser: Bool?
}

struct RefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
}

struct VerifyAppleResponse: Codable {
    let valid: Bool
    let appleUserId: String?
}

struct MeResponse: Codable {
    let user: UserResponse
}

struct LogoutResponse: Codable {
    let message: String
}

// MARK: - User Preferences

struct UserPreferencesResponse: Codable {
    let id: String
    let userId: String
    let sharingScope: SharingScope
    let customDataTypes: [HealthDataType]
    let notifyOnNewData: Bool
    let notifyOnPartnerActive: Bool
    let weeklyDigest: Bool
    let timezone: String
    let language: String
    let createdAt: Date
    let updatedAt: Date
}

struct UpdateProfileRequest: Codable {
    let name: String?
    let avatarUrl: String?
}

struct UpdatePreferencesRequest: Codable {
    let sharingScope: SharingScope?
    let customDataTypes: [HealthDataType]?
    let notifyOnNewData: Bool?
    let notifyOnPartnerActive: Bool?
    let weeklyDigest: Bool?
    let timezone: String?
    let language: String?
}

// MARK: - Pairing Models

enum PairingStatus: String, Codable {
    case pending = "PENDING"
    case accepted = "ACCEPTED"
    case rejected = "REJECTED"
    case blocked = "BLOCKED"
    case expired = "EXPIRED"
}

enum RespondAction: String, Codable {
    case accept = "ACCEPT"
    case reject = "REJECT"
}

enum SharingScope: String, Codable, CaseIterable, Identifiable {
    case all = "ALL"
    case activityOnly = "ACTIVITY_ONLY"
    case heartOnly = "HEART_ONLY"
    case sleepOnly = "SLEEP_ONLY"
    case workoutOnly = "WORKOUT_ONLY"
    case custom = "CUSTOM"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All Health Data"
        case .activityOnly: return "Activity Only"
        case .heartOnly: return "Heart Data Only"
        case .sleepOnly: return "Sleep Data Only"
        case .workoutOnly: return "Workouts Only"
        case .custom: return "Custom Selection"
        }
    }

    var description: String {
        switch self {
        case .all: return "Share all health data types"
        case .activityOnly: return "Share steps, calories, exercise minutes"
        case .heartOnly: return "Share heart rate and variability"
        case .sleepOnly: return "Share sleep analysis"
        case .workoutOnly: return "Share workout sessions"
        case .custom: return "Choose specific data types to share"
        }
    }
}

struct PairingUser: Codable {
    let id: String
    let name: String?
    let avatarUrl: String?
    let email: String
}

struct PairingResponse: Codable, Identifiable {
    let id: String
    let user1Id: String
    let user2Id: String
    let status: PairingStatus
    let sharingScope: SharingScope
    let customTypes: [HealthDataType]
    let invitedAt: Date
    let acceptedAt: Date?
    let rejectedAt: Date?
    let expiresAt: Date
    let createdAt: Date
    let updatedAt: Date
    let user1: PairingUser
    let user2: PairingUser
    let partner: PairingUser
    let isInviter: Bool

    var partnerName: String {
        return partner.name ?? partner.email.components(separatedBy: "@").first ?? "Partner"
    }

    var isActive: Bool {
        return status == .accepted
    }

    var timeUntilExpiry: TimeInterval? {
        guard status == .pending else { return nil }
        return expiresAt.timeIntervalSinceNow
    }
}

struct CreatePairingRequest: Codable {
    let inviteeEmail: String
    let sharingScope: SharingScope
    let customTypes: [HealthDataType]?
}

struct RespondPairingRequest: Codable {
    let action: RespondAction
}

struct UpdatePairingRequest: Codable {
    let sharingScope: SharingScope?
    let customTypes: [HealthDataType]?
}

struct ListPairingsResponse: Codable {
    let pairings: [PairingResponse]
}

struct GetPairingResponse: Codable {
    let pairing: PairingResponse
}

struct CreatePairingResponse: Codable {
    let pairing: PairingResponse
}

struct RespondPairingResponse: Codable {
    let pairing: PairingResponse
}

struct UpdatePairingResponse: Codable {
    let pairing: PairingResponse
}

struct DeletePairingResponse: Codable {
    let message: String
}

// MARK: - Health Data Models

enum HealthDataType: String, Codable, CaseIterable, Identifiable {
    case steps = "STEPS"
    case heartRate = "HEART_RATE"
    case activeEnergy = "ACTIVE_ENERGY"
    case basalEnergy = "BASAL_ENERGY"
    case distanceWalkingRunning = "DISTANCE_WALKING_RUNNING"
    case flightsClimbed = "FLIGHTS_CLIMBED"
    case exerciseMinutes = "EXERCISE_MINUTES"
    case standHours = "STAND_HOURS"
    case sleepAnalysis = "SLEEP_ANALYSIS"
    case workout = "WORKOUT"
    case bodyMass = "BODY_MASS"
    case bodyFatPercentage = "BODY_FAT_PERCENTAGE"
    case heartRateVariability = "HEART_RATE_VARIABILITY"
    case restingHeartRate = "RESTING_HEART_RATE"
    case vo2Max = "VO2_MAX"
    case bloodPressureSystolic = "BLOOD_PRESSURE_SYSTOLIC"
    case bloodPressureDiastolic = "BLOOD_PRESSURE_DIASTOLIC"
    case bloodGlucose = "BLOOD_GLUCOSE"
    case oxygenSaturation = "OXYGEN_SATURATION"
    case respiratoryRate = "RESPIRATORY_RATE"
    case bodyTemperature = "BODY_TEMPERATURE"
    case menstrualFlow = "MENSTRUAL_FLOW"
    case custom = "CUSTOM"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .heartRate: return "Heart Rate"
        case .activeEnergy: return "Active Energy"
        case .basalEnergy: return "Basal Energy"
        case .distanceWalkingRunning: return "Walking + Running Distance"
        case .flightsClimbed: return "Flights Climbed"
        case .exerciseMinutes: return "Exercise Minutes"
        case .standHours: return "Stand Hours"
        case .sleepAnalysis: return "Sleep Analysis"
        case .workout: return "Workouts"
        case .bodyMass: return "Body Mass"
        case .bodyFatPercentage: return "Body Fat %"
        case .heartRateVariability: return "HRV"
        case .restingHeartRate: return "Resting Heart Rate"
        case .vo2Max: return "VO2 Max"
        case .bloodPressureSystolic: return "Systolic BP"
        case .bloodPressureDiastolic: return "Diastolic BP"
        case .bloodGlucose: return "Blood Glucose"
        case .oxygenSaturation: return "Oxygen Saturation"
        case .respiratoryRate: return "Respiratory Rate"
        case .bodyTemperature: return "Body Temperature"
        case .menstrualFlow: return "Menstrual Flow"
        case .custom: return "Custom"
        }
    }

    var unit: HealthDataUnit? {
        switch self {
        case .steps, .flightsClimbed, .exerciseMinutes, .standHours, .workout:
            return .count
        case .heartRate, .restingHeartRate:
            return .bpm
        case .activeEnergy, .basalEnergy:
            return .kcal
        case .distanceWalkingRunning:
            return .meters
        case .sleepAnalysis:
            return .hours
        case .bodyMass:
            return .kg
        case .bodyFatPercentage:
            return .percentage
        case .heartRateVariability:
            return nil
        case .vo2Max:
            return .mlMin
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            return .mmHg
        case .bloodGlucose:
            return .mgDl
        case .oxygenSaturation:
            return .percentage
        case .respiratoryRate:
            return .count
        case .bodyTemperature:
            return .celsius
        case .menstrualFlow:
            return .count
        case .custom:
            return .count
        }
    }

    var systemImageName: String {
        switch self {
        case .steps: return "figure.walk"
        case .heartRate, .restingHeartRate: return "heart.fill"
        case .activeEnergy: return "flame.fill"
        case .basalEnergy: return "flame"
        case .distanceWalkingRunning: return "figure.run"
        case .flightsClimbed: return "figure.stairs"
        case .exerciseMinutes: return "timer"
        case .standHours: return "figure.stand"
        case .sleepAnalysis: return "bed.double.fill"
        case .workout: return "dumbbell.fill"
        case .bodyMass: return "scalemass.fill"
        case .bodyFatPercentage: return "percent"
        case .heartRateVariability: return "waveform.path.ecg"
        case .vo2Max: return "lungs.fill"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "heart.text.square.fill"
        case .bloodGlucose: return "drop.fill"
        case .oxygenSaturation: return "lungs.fill"
        case .respiratoryRate: return "wind"
        case .bodyTemperature: return "thermometer"
        case .menstrualFlow: return "drop.circle.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    var color: String {
        switch self {
        case .steps: return "blue"
        case .heartRate, .restingHeartRate: return "red"
        case .activeEnergy: return "orange"
        case .basalEnergy: return "yellow"
        case .distanceWalkingRunning: return "green"
        case .flightsClimbed: return "purple"
        case .exerciseMinutes: return "mint"
        case .standHours: return "teal"
        case .sleepAnalysis: return "indigo"
        case .workout: return "pink"
        case .bodyMass: return "brown"
        case .bodyFatPercentage: return "gray"
        case .heartRateVariability: return "cyan"
        case .vo2Max: return "blue"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "red"
        case .bloodGlucose: return "orange"
        case .oxygenSaturation: return "blue"
        case .respiratoryRate: return "gray"
        case .bodyTemperature: return "red"
        case .menstrualFlow: return "pink"
        case .custom: return "primary"
        }
    }
}

enum HealthDataUnit: String, Codable, CaseIterable {
    case count = "COUNT"
    case bpm = "BPM"
    case kcal = "KCAL"
    case km = "KM"
    case meters = "METERS"
    case minutes = "MINUTES"
    case hours = "HOURS"
    case percentage = "PERCENTAGE"
    case kg = "KG"
    case mmHg = "MMHG"
    case mgDl = "MG_DL"
    case mlMin = "ML_MIN"
    case celsius = "CELSIUS"
    case seconds = "SECONDS"

    var displayName: String {
        switch self {
        case .count: return "count"
        case .bpm: return "bpm"
        case .kcal: return "kcal"
        case .km: return "km"
        case .meters: return "m"
        case .minutes: return "min"
        case .hours: return "hr"
        case .percentage: return "%"
        case .kg: return "kg"
        case .mmHg: return "mmHg"
        case .mgDl: return "mg/dL"
        case .mlMin: return "ml/min"
        case .celsius: return "°C"
        case .seconds: return "s"
        }
    }
}

enum AggregateType: String, Codable, CaseIterable {
    case raw = "raw"
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"

    var displayName: String {
        switch self {
        case .raw: return "Raw Data"
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

struct CreateHealthDataRequest: Codable {
    let type: HealthDataType
    let unit: HealthDataUnit
    let value: Double
    let startDate: Date
    let endDate: Date
    let sourceName: String?
    let sourceVersion: String?
    let sourceSampleId: String?
    let deviceId: String?
    let metadata: [String: AnyCodable]?
}

struct BulkHealthDataRequest: Codable {
    let data: [CreateHealthDataRequest]
}

struct HealthDataResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let type: HealthDataType
    let unit: HealthDataUnit
    let value: Double
    let startDate: Date
    let endDate: Date
    let sourceName: String?
    let sourceVersion: String?
    let sourceSampleId: String?
    let deviceId: String?
    let metadata: AnyCodable?
    let syncedAt: Date
    let createdAt: Date
}

struct AggregatedHealthData: Codable {
    let bucket: String
    let values: [String: Double]
}

struct PaginationResponse: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

struct HealthDataListResponse: Codable {
    let data: [HealthDataResponse]
    let pagination: PaginationResponse
}

struct BulkSyncResponse: Codable {
    let synced: Int?
}

struct DailySummary: Codable {
    let date: String
    let steps: Int
    let activeEnergy: Double
    let exerciseMinutes: Int
    let currentHeartRate: Int?
    let workouts: Int
}

struct SummaryResponse: Codable {
    let summary: DailySummary
}

struct PartnerSummaryMetric: Codable {
    let type: HealthDataType
    let sum: PartnerSummaryAggregate?
    let avg: PartnerSummaryAggregate?
    let max: PartnerSummaryAggregate?
    let min: PartnerSummaryAggregate?

    enum CodingKeys: String, CodingKey {
        case type
        case sum = "_sum"
        case avg = "_avg"
        case max = "_max"
        case min = "_min"
    }
}

struct PartnerSummaryAggregate: Codable {
    let value: Double?
}

struct PartnerSummaryResponse: Codable {
    let summary: PartnerSummary
}

struct PartnerSummary: Codable {
    let date: String
    let metrics: [PartnerSummaryMetric]
    let sharingScope: String
}

struct QueryHealthDataRequest: Codable {
    let offset: Int?
    let limit: Int?
    let type: HealthDataType?
    let startDate: Date?
    let endDate: Date?
    let aggregate: AggregateType?
}

struct PartnerHealthDataQuery: Codable {
    let type: HealthDataType?
    let startDate: Date?
    let endDate: Date?
    let limit: Int?
    let aggregate: AggregateType?
}

// MARK: - Goal Models

struct GoalResponse: Codable, Identifiable {
    let id: String
    let pairingId: String
    let createdById: String
    let title: String
    let targetValue: Double
    let startDate: Date
    let endDate: Date
    let createdAt: Date
    let updatedAt: Date
    let currentValue: Double
    let remainingValue: Double
    let progressPercentage: Double
    let completed: Bool

    var daysRemaining: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: endDate)
        return max(calendar.dateComponents([.day], from: today, to: end).day ?? 0, 0)
    }

    func applying(progress: GoalProgress) -> GoalResponse {
        GoalResponse(
            id: id,
            pairingId: pairingId,
            createdById: createdById,
            title: title,
            targetValue: targetValue,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            currentValue: progress.currentValue,
            remainingValue: progress.remainingValue,
            progressPercentage: progress.progressPercentage,
            completed: progress.completed
        )
    }
}

struct CreateGoalRequest: Codable {
    let pairingId: String
    let title: String
    let targetValue: Double
    let startDate: Date
    let endDate: Date
}

struct UpdateGoalRequest: Codable {
    let title: String?
    let targetValue: Double?
    let startDate: Date?
    let endDate: Date?
}

struct GoalListResponse: Codable {
    let goals: [GoalResponse]
    let pagination: PaginationResponse?
}

struct GoalProgress: Codable {
    let currentValue: Double
    let remainingValue: Double
    let progressPercentage: Double
    let completed: Bool
}

struct GoalProgressResponse: Codable {
    let progress: GoalProgress
}

// MARK: - Dashboard Models

struct DashboardSummary: Codable {
    let date: String
    let steps: Int
    let activeEnergy: Double
    let distance: Double
}

struct DashboardPartnerMetrics: Codable {
    let date: String
    let sharingScope: String
    let steps: Int?
    let activeEnergy: Double?
    let distance: Double?
}

struct DashboardPartnerSummary: Codable {
    let id: String
    let name: String?
    let avatarUrl: String?
    let sharingScope: String
    let summary: DashboardPartnerMetrics
}

struct DashboardSync: Codable {
    let lastSyncedAt: Date?
    let status: String?
}

struct DashboardResponse: Codable {
    let summary: DashboardSummary
    let partner: DashboardPartnerSummary?
    let goals: [GoalResponse]
    let sync: DashboardSync
}

// MARK: - Device Models

enum DevicePlatform: String, Codable, CaseIterable {
    case iOS = "IOS"
    case watchOS = "WATCHOS"
    case android = "ANDROID"
    case web = "WEB"
}

struct DeviceResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let deviceId: String
    let platform: DevicePlatform
    let model: String?
    let osVersion: String?
    let appVersion: String?
    let pushToken: String?
    let isActive: Bool
    let lastSyncAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

struct RegisterDeviceRequest: Codable {
    let deviceId: String
    let platform: DevicePlatform
    let model: String?
    let osVersion: String?
    let appVersion: String?
    let pushToken: String?
}

struct UpdateDeviceRequest: Codable {
    let model: String?
    let osVersion: String?
    let appVersion: String?
    let pushToken: String?
    let isActive: Bool?
}

struct DeviceListResponse: Codable {
    let devices: [DeviceResponse]
}

// MARK: - Notification Models

struct NotificationResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let body: String
    let data: AnyCodable?
    let read: Bool
    let sentAt: Date?
    let createdAt: Date
}

struct NotificationListResponse: Codable {
    let notifications: [NotificationResponse]
    let pagination: PaginationResponse
}

struct UnreadCountResponse: Codable {
    let count: Int
}

// MARK: - Helper Types

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode AnyCodable"))
        }
    }
}

// MARK: - Date Formatting

extension DateFormatter {
    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static let iso8601DateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

extension Date {
    func toISO8601String() -> String {
        return DateFormatter.iso8601Full.string(from: self)
    }

    func toDateOnlyString() -> String {
        return DateFormatter.iso8601DateOnly.string(from: self)
    }

    static func fromISO8601(_ string: String) -> Date? {
        return DateFormatter.iso8601Full.date(from: string) ?? DateFormatter.iso8601DateOnly.date(from: string)
    }
}