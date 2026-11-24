//
//  DashboardViewModel.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var dashboard: DashboardResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let apiService = APIService.shared
    private let healthKitService = HealthKitService.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    init() {
        setupObservers()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func setupObservers() {
        // Listen for health data sync completion
        NotificationCenter.default.publisher(for: .healthDataSynced)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)

        // Listen for pairing changes
        NotificationCenter.default.publisher(for: .pairingChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)
    }

    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.getDashboard()
            self.dashboard = response
            self.lastUpdated = Date()
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func startAutoRefresh(interval: TimeInterval = 300) { // 5 minutes
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Computed Properties for UI

    var userSummary: DashboardUserSummary? {
        return dashboard?.user
    }

    var partnerSummary: DashboardPartnerSummary? {
        return dashboard?.partner
    }

    var activeGoals: [DashboardGoal] {
        return dashboard?.activeGoals ?? []
    }

    var recentActivity: [RecentActivityItem] {
        return dashboard?.recentActivity ?? []
    }

    var insights: [Insight] {
        return dashboard?.insights ?? []
    }

    var hasPartner: Bool {
        return partnerSummary != nil
    }

    var primaryMetrics: [MetricCard] {
        guard let user = userSummary else { return [] }

        return [
            MetricCard(
                title: "Steps",
                value: "\(user.steps.formatted())",
                unit: "steps",
                icon: "figure.walk",
                color: .blue,
                progress: partnerSummary != nil ? calculatePartnerProgress(for: .steps, userValue: Double(user.steps)) : nil
            ),
            MetricCard(
                title: "Active Calories",
                value: "\(Int(user.activeEnergy))",
                unit: "kcal",
                icon: "flame.fill",
                color: .orange,
                progress: partnerSummary != nil ? calculatePartnerProgress(for: .activeEnergy, userValue: user.activeEnergy) : nil
            ),
            MetricCard(
                title: "Exercise",
                value: "\(user.exerciseMinutes)",
                unit: "min",
                icon: "timer",
                color: .green,
                progress: partnerSummary != nil ? calculatePartnerProgress(for: .exerciseMinutes, userValue: Double(user.exerciseMinutes)) : nil
            ),
            MetricCard(
                title: "Stand Hours",
                value: "\(user.standHours)",
                unit: "hrs",
                icon: "figure.stand",
                color: .teal,
                progress: partnerSummary != nil ? calculatePartnerProgress(for: .standHours, userValue: Double(user.standHours)) : nil
            )
        ]
    }

    var secondaryMetrics: [MetricCard] {
        guard let user = userSummary else { return [] }

        return [
            MetricCard(
                title: "Distance",
                value: String(format: "%.1f", user.distance),
                unit: "km",
                icon: "figure.run",
                color: .mint,
                progress: partnerSummary != nil ? calculatePartnerProgress(for: .distanceWalkingRunning, userValue: user.distance) : nil
            ),
            MetricCard(
                title: "Flights",
                value: "\(user.flightsClimbed)",
                unit: "flights",
                icon: "figure.stairs",
                color: .purple,
                progress: partnerSummary != nil ? calculatePartnerProgress(for: .flightsClimbed, userValue: Double(user.flightsClimbed)) : nil
            ),
            MetricCard(
                title: "Workouts",
                value: "\(user.workouts)",
                unit: "sessions",
                icon: "dumbbell.fill",
                color: .pink,
                progress: partnerSummary != nil ? calculatePartnerProgress(for: .workout, userValue: Double(user.workouts)) : nil
            ),
            MetricCard(
                title: "Sleep",
                value: String(format: "%.1f", user.sleepHours),
                unit: "hrs",
                icon: "bed.double.fill",
                color: .indigo,
                progress: partnerSummary != nil ? calculatePartnerProgress(for: .sleepAnalysis, userValue: user.sleepHours) : nil
            )
        ]
    }

    var heartRateMetrics: [MetricCard] {
        guard let user = userSummary, let hr = user.heartRate else { return [] }

        var metrics: [MetricCard] = []

        if let current = hr.current {
            metrics.append(MetricCard(
                title: "Current HR",
                value: "\(current)",
                unit: "bpm",
                icon: "heart.fill",
                color: .red,
                progress: nil
            ))
        }

        if let resting = hr.resting {
            metrics.append(MetricCard(
                title: "Resting HR",
                value: "\(resting)",
                unit: "bpm",
                icon: "heart",
                color: .pink,
                progress: nil
            ))
        }

        if let hrv = hr.variability {
            metrics.append(MetricCard(
                title: "HRV",
                value: String(format: "%.0f", hrv),
                unit: "ms",
                icon: "waveform.path.ecg",
                color: .cyan,
                progress: nil
            ))
        }

        return metrics
    }

    var bodyMetrics: [MetricCard] {
        guard let user = userSummary, let body = user.bodyMetrics else { return [] }

        var metrics: [MetricCard] = []

        if let weight = body.weight {
            metrics.append(MetricCard(
                title: "Weight",
                value: String(format: "%.1f", weight),
                unit: "kg",
                icon: "scalemass.fill",
                color: .brown,
                progress: nil
            ))
        }

        if let bodyFat = body.bodyFatPercentage {
            metrics.append(MetricCard(
                title: "Body Fat",
                value: String(format: "%.1f", bodyFat),
                unit: "%",
                icon: "percent",
                color: .gray,
                progress: nil
            ))
        }

        return metrics
    }

    // MARK: - Helper Methods

    private func calculatePartnerProgress(for type: HealthDataType, userValue: Double) -> Double? {
        guard let partner = partnerSummary else { return nil }

        let partnerValue: Double?
        switch type {
        case .steps:
            partnerValue = Double(partner.summary.steps)
        case .activeEnergy:
            partnerValue = partner.summary.activeEnergy
        case .exerciseMinutes:
            partnerValue = Double(partner.summary.exerciseMinutes)
        case .standHours:
            partnerValue = Double(partner.summary.standHours)
        case .distanceWalkingRunning:
            partnerValue = partner.summary.distance
        case .flightsClimbed:
            partnerValue = Double(partner.summary.flightsClimbed)
        case .workout:
            partnerValue = Double(partner.summary.workouts)
        case .sleepAnalysis:
            partnerValue = partner.summary.sleepHours
        default:
            partnerValue = nil
        }

        guard let pValue = partnerValue, pValue > 0 else { return nil }
        return min(userValue / pValue * 100, 200) // Cap at 200%
    }
}

// MARK: - Supporting Types

struct MetricCard: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: SwiftUI.Color
    let progress: Double? // Percentage compared to partner
}

// MARK: - HealthDataType Extension for Dashboard

extension HealthDataType {
    var metrics: [HealthDataType] {
        switch self {
        case .steps: return [.steps]
        case .activeEnergy: return [.activeEnergy]
        case .exerciseMinutes: return [.exerciseMinutes]
        case .standHours: return [.standHours]
        default: return []
        }
    }
}

import SwiftUI