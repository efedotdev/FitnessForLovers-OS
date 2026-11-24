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
    let statusCode: Int
}

struct APIError: Codable {
    let error: String
    let message: String
    let statusCode: Int
    let details: [String: String]?
}

// MARK: - Authentication Models

struct AppleSignInRequest: Codable {
    let identityToken: String
    let authorizationCode: String?
    let fullName: PersonNameComponents?
    let email: String?
}

// Development Login Request (DEBUG only)
#if DEBUG
struct DevLoginRequest: Codable {
    let testEmail: String
    let name: String

    init(testEmail: String = "dev@fitnessforlovers.test", name: String = "Development User") {
        self.testEmail = testEmail
        self.name = name
    }
}
#endif

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
    let appleUserId: String?
    let role: String
    let emailVerified: Bool
    let createdAt: Date
    let lastLoginAt: Date?
    let preferences: UserPreferencesResponse?

    var displayName: String {
        return name ?? email.components(separatedBy: "@").first ?? "User"
    }
}

struct AuthResponse: Codable {
    let user: UserResponse
    let tokens: TokensResponse
    let isNewUser: Bool
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

    var unit: HealthDataUnit {
        switch self {
        case .steps, .flightsClimbed, .exerciseMinutes, .standHours, .workout:
            return .count
        case .heartRate, .restingHeartRate:
            return .bpm
        case .activeEnergy, .basalEnergy:
            return .kcal
        case .distanceWalkingRunning:
            return .km
        case .sleepAnalysis:
            return .hours
        case .bodyMass:
            return .kg
        case .bodyFatPercentage:
            return .percentage
        case .heartRateVariability:
            return .milliseconds
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
            return .custom
        case .custom:
            return .custom
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
    case milliseconds = "MILLISECONDS"
    case custom = "CUSTOM"

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
        case .milliseconds: return "ms"
        case .custom: return "custom"
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
    let synced: Int
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
    let sum: Double?
    let avg: Double?
    let max: Double?
    let min: Double?
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
    let page: Int?
    let limit: Int?
    let type: HealthDataType?
    let startDate: Date?
    let endDate: Date?
    let aggregate: AggregateType?
}

struct PartnerHealthDataQuery: Codable {
    let partnerId: String
    let type: HealthDataType?
    let startDate: Date?
    let endDate: Date?
    let limit: Int?
    let aggregate: AggregateType?
}

// MARK: - Goal Models

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case steps = "STEPS"
    case activeEnergy = "ACTIVE_ENERGY"
    case exerciseMinutes = "EXERCISE_MINUTES"
    case standHours = "STAND_HOURS"
    case distanceWalkingRunning = "DISTANCE_WALKING_RUNNING"
    case flightsClimbed = "FLIGHTS_CLIMBED"
    case workouts = "WORKOUTS"
    case sleepHours = "SLEEP_HOURS"
    case heartRateVariability = "HEART_RATE_VARIABILITY"
    case custom = "CUSTOM"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .activeEnergy: return "Active Calories"
        case .exerciseMinutes: return "Exercise Minutes"
        case .standHours: return "Stand Hours"
        case .distanceWalkingRunning: return "Distance"
        case .flightsClimbed: return "Flights Climbed"
        case .workouts: return "Workouts"
        case .sleepHours: return "Sleep Hours"
        case .heartRateVariability: return "HRV"
        case .custom: return "Custom"
        }
    }

    var healthDataType: HealthDataType {
        switch self {
        case .steps: return .steps
        case .activeEnergy: return .activeEnergy
        case .exerciseMinutes: return .exerciseMinutes
        case .standHours: return .standHours
        case .distanceWalkingRunning: return .distanceWalkingRunning
        case .flightsClimbed: return .flightsClimbed
        case .workouts: return .workout
        case .sleepHours: return .sleepAnalysis
        case .heartRateVariability: return .heartRateVariability
        case .custom: return .custom
        }
    }

    var systemImageName: String {
        return healthDataType.systemImageName
    }

    var defaultUnit: HealthDataUnit {
        return healthDataType.unit
    }
}

enum GoalPeriod: String, Codable, CaseIterable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

enum GoalStatus: String, Codable, CaseIterable {
    case active = "ACTIVE"
    case completed = "COMPLETED"
    case archived = "ARCHIVED"
    case expired = "EXPIRED"

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        case .archived: return "Archived"
        case .expired: return "Expired"
        }
    }

    var color: String {
        switch self {
        case .active: return "green"
        case .completed: return "blue"
        case .archived: return "gray"
        case .expired: return "red"
        }
    }
}

struct GoalResponse: Codable, Identifiable {
    let id: String
    let pairingId: String
    let createdById: String
    let type: GoalType
    let customType: String?
    let targetValue: Double
    let currentValue: Double
    let period: GoalPeriod
    let status: GoalStatus
    let startDate: Date
    let endDate: Date
    let createdAt: Date
    let updatedAt: Date
    let createdBy: PairingUser?
    let pairing: PairingInfo?
    let progress: Double?

    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue * 100, 100)
    }

    var isCompleted: Bool {
        return status == .completed || progressPercentage >= 100
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfEndDate = calendar.startOfDay(for: endDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfEndDate)
        return max(components.day ?? 0, 0)
    }
}

struct PairingInfo: Codable {
    let id: String
    let user1Id: String
    let user2Id: String
}

struct CreateGoalRequest: Codable {
    let pairingId: String
    let type: GoalType
    let customType: String?
    let targetValue: Double
    let period: GoalPeriod
    let startDate: Date
    let endDate: Date
}

struct UpdateGoalRequest: Codable {
    let targetValue: Double?
    let currentValue: Double?
    let status: GoalStatus?
    let endDate: Date?
}

struct QueryGoalsRequest: Codable {
    let page: Int?
    let limit: Int?
    let pairingId: String?
    let status: GoalStatus?
    let type: GoalType?
    let period: GoalPeriod?
}

struct GoalListResponse: Codable {
    let goals: [GoalResponse]
    let pagination: PaginationResponse
}

struct GoalProgressResponse: Codable {
    let goal: GoalResponse
    let partnerProgress: PartnerGoalProgress?
}

struct PartnerGoalProgress: Codable {
    let userId: String
    let name: String?
    let avatarUrl: String?
    let currentValue: Double
    let progress: Double
}

// MARK: - Dashboard Models

struct DashboardUserSummary: Codable {
    let steps: Int
    let activeEnergy: Double
    let exerciseMinutes: Int
    let standHours: Int
    let distance: Double
    let flightsClimbed: Int
    let workouts: Int
    let sleepHours: Double
    let heartRate: HeartRateSummary?
    let bodyMetrics: BodyMetricsSummary?
}

struct HeartRateSummary: Codable {
    let current: Int?
    let resting: Int?
    let variability: Double?
}

struct BodyMetricsSummary: Codable {
    let weight: Double?
    let bodyFatPercentage: Double?
}

struct DashboardPartnerSummary: Codable {
    let userId: String
    let name: String?
    let avatarUrl: String?
    let sharingScope: String
    let summary: DashboardUserSummary
}

struct DashboardGoal: Codable, Identifiable {
    let id: String
    let type: String
    let targetValue: Double
    let currentValue: Double
    let progress: Double
    let period: String
    let status: String
    let endDate: String

    var daysRemaining: Int {
        let formatter = ISO8601DateFormatter()
        guard let endDateObj = formatter.date(from: endDate) else { return 0 }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfEndDate = calendar.startOfDay(for: endDateObj)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfEndDate)
        return max(components.day ?? 0, 0)
    }
}

struct RecentActivityItem: Codable, Identifiable {
    let id: String
    let type: String
    let value: Double
    let unit: String
    let startDate: String
    let sourceName: String?
}

struct Insight: Codable, Identifiable {
    let id = UUID()
    let type: String
    let message: String
    let priority: InsightPriority
}

enum InsightPriority: String, Codable {
    case info = "info"
    case warning = "warning"
    case success = "success"
}

struct DashboardResponse: Codable {
    let date: String
    let user: DashboardUserSummary
    let partner: DashboardPartnerSummary?
    let activeGoals: [DashboardGoal]
    let recentActivity: [RecentActivityItem]
    let insights: [Insight]
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