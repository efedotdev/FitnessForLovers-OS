import Foundation
import Combine
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var dashboard: DashboardResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var refreshGeneration = 0

    init() {
        NotificationCenter.default.publisher(for: .pairingChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .goalsChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        refreshTimer?.invalidate()
    }

    @discardableResult
    func refresh() async -> DashboardResponse? {
        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        errorMessage = nil
        defer {
            if generation == refreshGeneration {
                isLoading = false
            }
        }

        do {
            let refreshedDashboard = try await apiService.getDashboard()
            guard generation == refreshGeneration else { return nil }
            dashboard = refreshedDashboard
            lastUpdated = Date()
            return refreshedDashboard
        } catch {
            guard generation == refreshGeneration else { return nil }
            errorMessage = "Dashboard yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin."
            return nil
        }
    }

    func startAutoRefresh(interval: TimeInterval = 300) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    var summary: DashboardSummary? {
        dashboard?.summary
    }

    var partnerSummary: DashboardPartnerSummary? {
        dashboard?.partner
    }

    var activeGoals: [GoalResponse] {
        dashboard?.goals.filter { !$0.completed } ?? []
    }

    var hasPartner: Bool {
        partnerSummary != nil
    }

    var syncStatusText: String {
        guard let sync = dashboard?.sync else { return "No sync recorded" }
        if let date = sync.lastSyncedAt {
            return "Last synced \(date.formatted(date: .abbreviated, time: .shortened))"
        }
        return sync.status == "SUCCESS" ? "Sync complete" : "No sync recorded"
    }

    var primaryMetrics: [MetricCard] {
        guard let summary else { return [] }
        let partner = partnerSummary?.summary

        return [
            MetricCard(
                title: "Steps",
                value: summary.steps.formatted(),
                unit: "steps",
                icon: "figure.walk",
                color: .blue,
                progress: compare(Double(summary.steps), with: partner?.steps.map(Double.init)),
                partnerValue: partner?.steps.map { $0.formatted() }
            ),
            MetricCard(
                title: "Active energy",
                value: "\(Int(summary.activeEnergy))",
                unit: "kcal",
                icon: "flame.fill",
                color: .orange,
                progress: compare(summary.activeEnergy, with: partner?.activeEnergy),
                partnerValue: partner?.activeEnergy.map { "\(Int($0)) kcal" }
            ),
            MetricCard(
                title: "Distance",
                value: String(format: "%.1f", summary.distance / 1000),
                unit: "km",
                icon: "figure.run",
                color: .green,
                progress: compare(summary.distance, with: partner?.distance),
                partnerValue: partner?.distance.map { String(format: "%.1f km", $0 / 1000) }
            )
        ]
    }

    private func compare(_ own: Double, with partner: Double?) -> Double? {
        guard let partner, partner > 0 else { return nil }
        return min(own / partner * 100, 200)
    }
}

struct MetricCard: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let progress: Double?
    let partnerValue: String?
}
