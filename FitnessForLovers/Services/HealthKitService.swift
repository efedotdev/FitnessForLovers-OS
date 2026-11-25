//
//  HealthKitService.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()
    private let apiService = APIService.shared
    private let authorizationRequestedKey = "healthKitAuthorizationRequested"

    @Published var hasRequestedAuthorization: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private init() {
        loadAuthorizationRequestState()
    }

    // MARK: - Authorization

    var requiredReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeEnergy) }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(distance) }

        return types
    }

    var requiredWriteTypes: Set<HKSampleType> {
        // We only read from HealthKit, not write
        return []
    }

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            setError("Apple Health bu cihazda kullanılamıyor.")
            return false
        }

        do {
            // HealthKit does not reveal whether read access was granted; success only confirms the request completed.
            try await healthStore.requestAuthorization(toShare: requiredWriteTypes, read: requiredReadTypes)
            setAuthorizationRequested()
            return true
        } catch {
            setError("Apple Health izni alınamadı. Ayarlarınızı kontrol edip tekrar deneyin.")
            return false
        }
    }

    private func loadAuthorizationRequestState() {
        hasRequestedAuthorization = UserDefaults.standard.bool(forKey: authorizationRequestedKey)
    }

    // MARK: - Data Fetching

    func fetchHealthData(for types: [HealthDataType], startDate: Date, endDate: Date) async throws -> [CreateHealthDataRequest] {
        var allSamples: [HKSample] = []
        var requests: [CreateHealthDataRequest] = []

        for type in types {
            if type == .steps {
                requests.append(contentsOf: try await fetchDailyStepRequests(startDate: startDate, endDate: endDate))
                continue
            }

            guard let hkType = hkQuantityType(for: type) ?? hkCategoryType(for: type) else { continue }

            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let samples = try await fetchSamples(type: hkType, predicate: predicate)
            allSamples.append(contentsOf: samples)
        }

        // Also fetch workouts
        if types.contains(.workout) {
            let workoutPredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let workouts = try await fetchWorkouts(predicate: workoutPredicate)
            allSamples.append(contentsOf: workouts)
        }

        requests.append(contentsOf: convertSamplesToRequests(allSamples))
        return requests
    }

    func fetchTodayStepCount() async throws -> Double? {
        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)
        let requests = try await fetchDailyStepRequests(startDate: todayStart, endDate: now)
        return requests.first?.value
    }

    private func fetchDailyStepRequests(startDate: Date, endDate: Date) async throws -> [CreateHealthDataRequest] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return []
        }

        let calendar = Calendar.current
        let firstDayStart = calendar.startOfDay(for: startDate)
        let lastDayStart = calendar.startOfDay(for: endDate)
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: lastDayStart) else {
            throw HealthKitServiceError.invalidDateRange
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: firstDayStart,
            end: endExclusive,
            options: .strictStartDate
        )
        var intervalComponents = DateComponents()
        intervalComponents.day = 1
        intervalComponents.calendar = calendar

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: firstDayStart,
            intervalComponents: intervalComponents
        )

        return try await withCheckedThrowingContinuation { continuation in
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let collection else {
                    continuation.resume(throwing: HealthKitServiceError.missingStatistics)
                    return
                }

                var requests: [CreateHealthDataRequest] = []
                collection.enumerateStatistics(from: firstDayStart, to: endExclusive) { statistics, _ in
                    guard
                        let stepCount = statistics.sumQuantity()?.doubleValue(for: .count()),
                        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: statistics.startDate)
                    else {
                        return
                    }

                    requests.append(CreateHealthDataRequest(
                        type: .steps,
                        unit: .count,
                        value: stepCount,
                        startDate: statistics.startDate,
                        endDate: nextDayStart,
                        sourceName: "HealthKit daily aggregate",
                        sourceVersion: nil,
                        sourceSampleId: "healthkit-daily-steps-\(Int(statistics.startDate.timeIntervalSince1970))",
                        deviceId: nil,
                        metadata: nil
                    ))
                }
                continuation.resume(returning: requests)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSamples(type: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchWorkouts(predicate: NSPredicate) async throws -> [HKWorkout] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKWorkoutType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKWorkout] ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Conversion

    private func convertSamplesToRequests(_ samples: [HKSample]) -> [CreateHealthDataRequest] {
        var requests: [CreateHealthDataRequest] = []

        for sample in samples {
            guard let request = convertSampleToRequest(sample) else { continue }
            requests.append(request)
        }

        return requests
    }

    private func convertSampleToRequest(_ sample: HKSample) -> CreateHealthDataRequest? {
        let sourceName = sample.sourceRevision.source.name
        let sourceVersion = sample.sourceRevision.version
        let sourceSampleId = sample.uuid.uuidString
        let deviceId = sample.device?.name
        let metadata = sample.metadata

        switch sample {
        case let quantitySample as HKQuantitySample:
            return convertQuantitySample(quantitySample, sourceName: sourceName, sourceVersion: sourceVersion, sourceSampleId: sourceSampleId, deviceId: deviceId, metadata: metadata)

        case let categorySample as HKCategorySample:
            return convertCategorySample(categorySample, sourceName: sourceName, sourceVersion: sourceVersion, sourceSampleId: sourceSampleId, deviceId: deviceId, metadata: metadata)

        case let workout as HKWorkout:
            return convertWorkout(workout, sourceName: sourceName, sourceVersion: sourceVersion, sourceSampleId: sourceSampleId, deviceId: deviceId, metadata: metadata)

        default:
            return nil
        }
    }

    private func convertQuantitySample(_ sample: HKQuantitySample, sourceName: String, sourceVersion: String?, sourceSampleId: String, deviceId: String?, metadata: [String: Any]?) -> CreateHealthDataRequest? {
        let type = healthDataType(for: sample.quantityType)
        let unit = healthDataUnit(for: sample.quantityType)

        guard let type = type, let unit = unit else { return nil }

        let value = sample.quantity.doubleValue(for: hkUnit(for: unit))

        return CreateHealthDataRequest(
            type: type,
            unit: unit,
            value: value,
            startDate: sample.startDate,
            endDate: sample.endDate,
            sourceName: sourceName,
            sourceVersion: sourceVersion,
            sourceSampleId: sourceSampleId,
            deviceId: deviceId,
            metadata: metadata?.mapValues { AnyCodable($0) }
        )
    }

    private func convertCategorySample(_ sample: HKCategorySample, sourceName: String, sourceVersion: String?, sourceSampleId: String, deviceId: String?, metadata: [String: Any]?) -> CreateHealthDataRequest? {
        let type = healthDataType(for: sample.categoryType)

        guard let type = type else { return nil }

        // For category samples, value is the raw category value
        let value = Double(sample.value)
        let unit: HealthDataUnit = type == .sleepAnalysis ? .hours : .count

        return CreateHealthDataRequest(
            type: type,
            unit: unit,
            value: value,
            startDate: sample.startDate,
            endDate: sample.endDate,
            sourceName: sourceName,
            sourceVersion: sourceVersion,
            sourceSampleId: sourceSampleId,
            deviceId: deviceId,
            metadata: metadata?.mapValues { AnyCodable($0) }
        )
    }

    private func convertWorkout(_ workout: HKWorkout, sourceName: String, sourceVersion: String?, sourceSampleId: String, deviceId: String?, metadata: [String: Any]?) -> CreateHealthDataRequest? {
        // Create a workout summary entry
        return CreateHealthDataRequest(
            type: .workout,
            unit: .count,
            value: 1,
            startDate: workout.startDate,
            endDate: workout.endDate,
            sourceName: sourceName,
            sourceVersion: sourceVersion,
            sourceSampleId: sourceSampleId,
            deviceId: deviceId,
            metadata: [
                "workoutType": AnyCodable(workout.workoutActivityType.rawValue),
                "duration": AnyCodable(workout.duration),
                "totalEnergyBurned": AnyCodable(workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0),
                "totalDistance": AnyCodable(workout.totalDistance?.doubleValue(for: .meter()) ?? 0)
            ].mapValues { $0 }
        )
    }

    // MARK: - Type Mapping

    private func healthDataType(for quantityType: HKQuantityType) -> HealthDataType? {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue: return .steps
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue: return .activeEnergy
        case HKQuantityTypeIdentifier.basalEnergyBurned.rawValue: return .basalEnergy
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue: return .distanceWalkingRunning
        case HKQuantityTypeIdentifier.flightsClimbed.rawValue: return .flightsClimbed
        case HKQuantityTypeIdentifier.appleExerciseTime.rawValue: return .exerciseMinutes
        case HKQuantityTypeIdentifier.appleStandTime.rawValue: return .standHours
        case HKQuantityTypeIdentifier.heartRate.rawValue: return .heartRate
        case HKQuantityTypeIdentifier.restingHeartRate.rawValue: return .restingHeartRate
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: return .heartRateVariability
        case HKQuantityTypeIdentifier.vo2Max.rawValue: return .vo2Max
        case HKQuantityTypeIdentifier.bodyMass.rawValue: return .bodyMass
        case HKQuantityTypeIdentifier.bodyFatPercentage.rawValue: return .bodyFatPercentage
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue: return .bloodPressureSystolic
        case HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue: return .bloodPressureDiastolic
        case HKQuantityTypeIdentifier.bloodGlucose.rawValue: return .bloodGlucose
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue: return .oxygenSaturation
        case HKQuantityTypeIdentifier.respiratoryRate.rawValue: return .respiratoryRate
        case HKQuantityTypeIdentifier.bodyTemperature.rawValue: return .bodyTemperature
        default: return nil
        }
    }

    private func healthDataType(for categoryType: HKCategoryType) -> HealthDataType? {
        switch categoryType.identifier {
        case HKCategoryTypeIdentifier.sleepAnalysis.rawValue: return .sleepAnalysis
        case HKCategoryTypeIdentifier.menstrualFlow.rawValue: return .menstrualFlow
        default: return nil
        }
    }

    private func healthDataUnit(for quantityType: HKQuantityType) -> HealthDataUnit? {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue: return .count
        case HKQuantityTypeIdentifier.flightsClimbed.rawValue: return .count
        case HKQuantityTypeIdentifier.appleExerciseTime.rawValue: return .minutes
        case HKQuantityTypeIdentifier.appleStandTime.rawValue: return .hours
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue: return .kcal
        case HKQuantityTypeIdentifier.basalEnergyBurned.rawValue: return .kcal
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue: return .meters
        case HKQuantityTypeIdentifier.heartRate.rawValue: return .bpm
        case HKQuantityTypeIdentifier.restingHeartRate.rawValue: return .bpm
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: return nil
        case HKQuantityTypeIdentifier.vo2Max.rawValue: return .mlMin
        case HKQuantityTypeIdentifier.bodyMass.rawValue: return .kg
        case HKQuantityTypeIdentifier.bodyFatPercentage.rawValue: return .percentage
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue: return .mmHg
        case HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue: return .mmHg
        case HKQuantityTypeIdentifier.bloodGlucose.rawValue: return .mgDl
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue: return .percentage
        case HKQuantityTypeIdentifier.respiratoryRate.rawValue: return .count
        case HKQuantityTypeIdentifier.bodyTemperature.rawValue: return .celsius
        default: return .count
        }
    }

    private func hkUnit(for unit: HealthDataUnit) -> HKUnit {
        switch unit {
        case .count: return .count()
        case .bpm: return HKUnit.count().unitDivided(by: .minute())
        case .kcal: return .kilocalorie()
        case .km: return .meterUnit(with: .kilo)
        case .meters: return .meter()
        case .minutes: return .minute()
        case .hours: return .hour()
        case .percentage: return .percent()
        case .kg: return .gramUnit(with: .kilo)
        case .mmHg: return .millimeterOfMercury()
        case .mgDl: return HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        case .mlMin: return HKUnit.literUnit(with: .milli).unitDivided(by: .minute())
        case .celsius: return .degreeCelsius()
        case .seconds: return .second()
        }
    }

    // MARK: - Sync

    func syncHealthData(types: [HealthDataType], daysBack: Int = 7) async -> Bool {
        guard !isSyncing else { return false }
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        return await performHealthDataSync(types: types, daysBack: daysBack)
    }

    func syncTodayData() async -> (didSync: Bool, todayStepCount: Double?) {
        guard !isSyncing else { return (false, nil) }
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        let todayTypes: [HealthDataType] = [.steps, .activeEnergy, .distanceWalkingRunning]
        guard await performHealthDataSync(types: todayTypes, daysBack: 0) else {
            return (false, nil)
        }

        do {
            return (true, try await fetchTodayStepCount())
        } catch {
            setError("Veriler eşitlendi ancak Apple Health verileri yeniden okunamadı.")
            return (true, nil)
        }
    }

    private func performHealthDataSync(types: [HealthDataType], daysBack: Int) async -> Bool {
        guard await apiService.isAuthenticated else {
            setError("Giriş yapmadan sağlık verileri senkronize edilemez.")
            return false
        }

        guard await requestAuthorization() else {
            return false
        }

        let endDate = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: endDate)
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: todayStart) else {
            setError("Sağlık verileri için tarih aralığı oluşturulamadı.")
            return false
        }

        do {
            let requests = try await fetchHealthData(for: types, startDate: startDate, endDate: endDate)

            if !requests.isEmpty {
                for startIndex in stride(from: 0, to: requests.count, by: 1000) {
                    let endIndex = min(startIndex + 1000, requests.count)
                    let batch = Array(requests[startIndex..<endIndex])
                    _ = try await apiService.bulkSyncHealthData(BulkHealthDataRequest(data: batch))
                }
            }
            lastSyncDate = Date()
            return true
        } catch {
            setError("Sağlık verileri senkronize edilemedi. Bağlantınızı kontrol edip tekrar deneyin.")
            return false
        }
    }

    // MARK: - Helpers

    private func hkQuantityType(for type: HealthDataType) -> HKQuantityType? {
        switch type {
        case .steps: return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .activeEnergy: return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .basalEnergy: return HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)
        case .distanceWalkingRunning: return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .flightsClimbed: return HKQuantityType.quantityType(forIdentifier: .flightsClimbed)
        case .exerciseMinutes: return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        case .standHours: return HKQuantityType.quantityType(forIdentifier: .appleStandTime)
        case .heartRate: return HKQuantityType.quantityType(forIdentifier: .heartRate)
        case .restingHeartRate: return HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
        case .heartRateVariability: return HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .vo2Max: return HKQuantityType.quantityType(forIdentifier: .vo2Max)
        case .bodyMass: return HKQuantityType.quantityType(forIdentifier: .bodyMass)
        case .bodyFatPercentage: return HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)
        case .bloodPressureSystolic: return HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
        case .bloodPressureDiastolic: return HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
        case .bloodGlucose: return HKQuantityType.quantityType(forIdentifier: .bloodGlucose)
        case .oxygenSaturation: return HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)
        case .respiratoryRate: return HKQuantityType.quantityType(forIdentifier: .respiratoryRate)
        case .bodyTemperature: return HKQuantityType.quantityType(forIdentifier: .bodyTemperature)
        default: return nil
        }
    }

    private func hkCategoryType(for type: HealthDataType) -> HKCategoryType? {
        switch type {
        case .sleepAnalysis: return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case .menstrualFlow: return HKCategoryType.categoryType(forIdentifier: .menstrualFlow)
        default: return nil
        }
    }

    private func setError(_ message: String) {
        syncError = message
    }

    private func setAuthorizationRequested() {
        hasRequestedAuthorization = true
        UserDefaults.standard.set(true, forKey: authorizationRequestedKey)
    }
}

private enum HealthKitServiceError: Error {
    case invalidDateRange
    case missingStatistics
}