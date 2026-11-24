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
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private init() {
        checkAuthorizationStatus()
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
            try await healthStore.requestAuthorization(toShare: requiredWriteTypes, read: requiredReadTypes)
            setAuthorizationRequested()
            return true
        } catch {
            setError("Apple Health izni alınamadı. Ayarlarınızı kontrol edip tekrar deneyin.")
            return false
        }
    }

    func checkAuthorizationStatus() {
        hasRequestedAuthorization = UserDefaults.standard.bool(forKey: authorizationRequestedKey)
        authorizationStatus = .notDetermined
    }

    // MARK: - Data Fetching

    func fetchHealthData(for types: [HealthDataType], startDate: Date, endDate: Date) async throws -> [CreateHealthDataRequest] {
        var allSamples: [HKSample] = []

        for type in types {
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

        return convertSamplesToRequests(allSamples)
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

    func syncHealthData(types: [HealthDataType], daysBack: Int = 7) async {
        guard await apiService.isAuthenticated else {
            setError("Giriş yapmadan sağlık verileri senkronize edilemez.")
            return
        }

        guard hasRequestedAuthorization else {
            setError("Apple Health izni verilmedi.")
            return
        }

        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        let endDate = Date()
        let todayStart = Calendar.current.startOfDay(for: endDate)
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: todayStart) ?? todayStart

        do {
            let requests = try await fetchHealthData(for: types, startDate: startDate, endDate: endDate)

            if !requests.isEmpty {
                for startIndex in stride(from: 0, to: requests.count, by: 1000) {
                    let endIndex = min(startIndex + 1000, requests.count)
                    let batch = Array(requests[startIndex..<endIndex])
                    _ = try await apiService.bulkSyncHealthData(BulkHealthDataRequest(data: batch))
                }
                lastSyncDate = Date()
            }
        } catch {
            setError("Sağlık verileri senkronize edilemedi. Bağlantınızı kontrol edip tekrar deneyin.")
        }
    }

    func syncTodayData() async {
        let todayTypes: [HealthDataType] = [.steps, .activeEnergy, .distanceWalkingRunning]
        await syncHealthData(types: todayTypes, daysBack: 0)
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
        authorizationStatus = .notDetermined
    }
}