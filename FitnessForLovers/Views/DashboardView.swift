import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var dashboardViewModel: DashboardViewModel
    @EnvironmentObject private var healthKitService: HealthKitService

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let summary = dashboardViewModel.summary {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(summary.date)
                                .font(.title2.bold())
                            Text(dashboardViewModel.syncStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(dashboardViewModel.primaryMetrics) { metric in
                                MetricCardView(metric: metric)
                            }
                        }

                        if let partner = dashboardViewModel.partnerSummary {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Partner · \(partner.name ?? "Connected")", systemImage: "person.2.fill")
                                    .font(.headline)
                                Text("Sharing: \(partner.sharingScope.replacingOccurrences(of: "_", with: " ").lowercased())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                partnerMetric("Steps", value: partner.summary.steps.map { $0.formatted() })
                                partnerMetric("Active energy", value: partner.summary.activeEnergy.map { "\(Int($0)) kcal" })
                                partnerMetric("Distance", value: partner.summary.distance.map { String(format: "%.1f km", $0 / 1000) })
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        } else {
                            ContentUnavailableView(
                                "No partner yet",
                                systemImage: "person.2.slash",
                                description: Text("Connect with a partner to see shared fitness metrics.")
                            )
                            .padding(.vertical, 8)
                        }

                        if !dashboardViewModel.activeGoals.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Shared step goals")
                                    .font(.headline)
                                ForEach(dashboardViewModel.activeGoals) { goal in
                                    GoalProgressRow(goal: goal)
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "No active goals",
                                systemImage: "figure.walk",
                                description: Text("Create a shared step goal from the Goals tab.")
                            )
                            .padding(.vertical, 8)
                        }
                    } else if !dashboardViewModel.isLoading {
                        ContentUnavailableView(
                            "Dashboard unavailable",
                            systemImage: "chart.bar",
                            description: Text("Pull to refresh or try again later.")
                        )
                    }
                }
                .padding(16)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await syncHealthData() }
                    } label: {
                        if healthKitService.isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise.heart")
                        }
                    }
                    .accessibilityLabel("Sync Health data")
                    .disabled(healthKitService.isSyncing)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await dashboardViewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh dashboard")
                }
            }
            .refreshable {
                await dashboardViewModel.refresh()
            }
            .overlay {
                if dashboardViewModel.isLoading && dashboardViewModel.dashboard == nil {
                    ProgressView("Loading dashboard…")
                }
            }
            .alert("Dashboard error", isPresented: Binding(
                get: { dashboardViewModel.errorMessage != nil },
                set: { if !$0 { dashboardViewModel.errorMessage = nil } }
            )) {
                Button("OK") { dashboardViewModel.errorMessage = nil }
            } message: {
                Text(dashboardViewModel.errorMessage ?? "")
            }
            .alert("Health data sync", isPresented: Binding(
                get: { healthKitService.syncError != nil },
                set: { if !$0 { healthKitService.syncError = nil } }
            )) {
                Button("OK") { healthKitService.syncError = nil }
            } message: {
                Text(healthKitService.syncError ?? "")
            }
            .task {
                await dashboardViewModel.refresh()
            }
        }
    }

    private func syncHealthData() async {
        if !healthKitService.hasRequestedAuthorization {
            guard await healthKitService.requestAuthorization() else { return }
        }
        await healthKitService.syncTodayData()
        await dashboardViewModel.refresh()
        NotificationCenter.default.post(name: .healthDataSynced, object: nil)
    }

    private func partnerMetric(_ title: String, value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value ?? "Not shared")
                .foregroundStyle(value == nil ? .secondary : .primary)
        }
        .font(.subheadline)
    }
}

private struct MetricCardView: View {
    let metric: MetricCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: metric.icon)
                .font(.title2)
                .foregroundStyle(metric.color)
            Text(metric.value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text("\(metric.title) · \(metric.unit)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let progress = metric.progress, let partnerValue = metric.partnerValue {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                    Text("\(Int(progress))% of partner")
                    Spacer(minLength: 0)
                    Text(partnerValue)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 125, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct GoalProgressRow: View {
    let goal: GoalResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(min(goal.progressPercentage, 100)))%")
                    .font(.subheadline.bold())
            }
            ProgressView(value: min(goal.progressPercentage / 100, 1))
                .tint(.green)
            HStack {
                Text("\(Int(goal.currentValue)) / \(Int(goal.targetValue)) steps combined")
                Spacer()
                Text("\(Int(goal.remainingValue)) left")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
