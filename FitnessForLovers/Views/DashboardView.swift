//
//  DashboardView.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import SwiftUI
import HealthKit

struct DashboardView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var pairingViewModel: PairingViewModel

    @State private var showSyncIndicator = false
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                    // Date Header
                    dateHeader

                    // Primary Metrics
                    Section {
                        primaryMetricsSection
                    } header: {
                        SectionHeader(title: "Today", actionTitle: "Sync") {
                            await syncHealthData()
                        }
                    }

                    // Partner Comparison
                    if dashboardViewModel.hasPartner {
                        Section {
                            partnerComparisonSection
                        } header: {
                            SectionHeader(title: "Partner Comparison")
                        }
                    }

                    // Heart Rate
                    if !dashboardViewModel.heartRateMetrics.isEmpty {
                        Section {
                            heartRateSection
                        } header: {
                            SectionHeader(title: "Heart")
                        }
                    }

                    // Body Metrics
                    if !dashboardViewModel.bodyMetrics.isEmpty {
                        Section {
                            bodyMetricsSection
                        } header: {
                            SectionHeader(title: "Body")
                        }
                    }

                    // Secondary Metrics
                    Section {
                        secondaryMetricsSection
                    } header: {
                        SectionHeader(title: "More Metrics")
                    }

                    // Active Goals
                    if !dashboardViewModel.activeGoals.isEmpty {
                        Section {
                            activeGoalsSection
                        } header: {
                            SectionHeader(title: "Active Goals", actionTitle: "View All") {
                                // Navigate to goals
                            }
                        }
                    }

                    // Recent Activity
                    if !dashboardViewModel.recentActivity.isEmpty {
                        Section {
                            recentActivitySection
                        } header: {
                            SectionHeader(title: "Recent Activity")
                        }
                    }

                    // Insights
                    if !dashboardViewModel.insights.isEmpty {
                        Section {
                            insightsSection
                        } header: {
                            SectionHeader(title: "Insights")
                        }
                    }

                    // Empty State
                    if dashboardViewModel.userSummary == nil && !dashboardViewModel.isLoading {
                        emptyStateView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    syncButton
                }
            }
            .refreshable {
                await dashboardViewModel.refresh()
            }
            .overlay {
                if dashboardViewModel.isLoading && dashboardViewModel.dashboard == nil {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .alert("Error", isPresented: .constant(dashboardViewModel.errorMessage != nil)) {
                Button("OK") { dashboardViewModel.errorMessage = nil }
            } message: {
                Text(dashboardViewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Subviews

    private var dateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.title2.bold())
                Text(selectedDate.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()

            Menu {
                Button("Today") { selectedDate = Date() }
                Button("Yesterday") { selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date() }
                Button("This Week") { selectedDate = Date() }
            } label: {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(.regularMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var primaryMetricsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(dashboardViewModel.primaryMetrics) { metric in
                MetricCardView(metric: metric)
            }
        }
    }

    private var partnerComparisonSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("You vs \(dashboardViewModel.partnerSummary?.name ?? "Partner")")
                    .font(.headline)
                Spacer()
            }

            ForEach(dashboardViewModel.primaryMetrics) { metric in
                PartnerComparisonRow(metric: metric)
            }
        }
    }

    private var heartRateSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(dashboardViewModel.heartRateMetrics) { metric in
                    SmallMetricCard(metric: metric)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var bodyMetricsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(dashboardViewModel.bodyMetrics) { metric in
                    SmallMetricCard(metric: metric)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var secondaryMetricsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(dashboardViewModel.secondaryMetrics) { metric in
                MetricCardView(metric: metric, style: .compact)
            }
        }
    }

    private var activeGoalsSection: some View {
        VStack(spacing: 12) {
            ForEach(dashboardViewModel.activeGoals.prefix(3)) { goal in
                GoalProgressRow(goal: goal)
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(spacing: 8) {
            ForEach(dashboardViewModel.recentActivity.prefix(5)) { activity in
                RecentActivityRow(activity: activity)
            }
        }
    }

    private var insightsSection: some View {
        VStack(spacing: 8) {
            ForEach(dashboardViewModel.insights.prefix(3)) { insight in
                InsightCard(insight: insight)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Health Data Yet")
                .font(.title2.bold())

            Text("Grant HealthKit access and sync your data to see your dashboard")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                Task {
                    await syncHealthData()
                }
            }) {
                Label("Sync Health Data", systemImage: "arrow.clockwise.heart")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(.blue.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.vertical, 60)
    }

    private var syncButton: some View {
        Button(action: {
            Task {
                await syncHealthData()
            }
        }) {
            if healthKitService.isSyncing {
                ProgressView()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "arrow.clockwise.heart")
                    .font(.title3)
            }
        }
        .disabled(healthKitService.isSyncing)
    }

    private func syncHealthData() async {
        await healthKitService.syncTodayData()
        await dashboardViewModel.refresh()
        NotificationCenter.default.post(name: .healthDataSynced, object: nil)
    }
}

// MARK: - Component Views

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() async -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle) {
                    Task { await action() }
                }
                .font(.subheadline.weight(.medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

struct MetricCardView: View {
    let metric: MetricCard
    var style: Style = .regular

    enum Style {
        case regular, compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: metric.icon)
                    .font(style == .regular ? .title2 : .title3)
                    .foregroundStyle(metric.color.gradient)
                    .frame(width: 32, height: 32)
                    .background(metric.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                Spacer()

                if let progress = metric.progress {
                    PartnerProgressBadge(progress: progress)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.value)
                    .font(style == .regular ? .system(size: 36, weight: .bold, design: .rounded) : .system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())

                HStack(spacing: 4) {
                    Text(metric.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(metric.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(style == .regular ? 20 : 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct SmallMetricCard: View {
    let metric: MetricCard

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: metric.icon)
                .font(.title2)
                .foregroundStyle(metric.color.gradient)
                .frame(width: 44, height: 44)
                .background(metric.color.opacity(0.15), in: Circle())

            Text(metric.value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(metric.title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(metric.unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .frame(minWidth: 100)
    }
}

struct PartnerProgressBadge: View {
    let progress: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption2)
            Text("\(Int(progress))%")
                .font(.caption2.bold())
        }
        .foregroundColor(progressColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(progressColor.opacity(0.15), in: Capsule())
    }

    private var progressColor: Color {
        if progress >= 100 { return .green }
        if progress >= 80 { return .blue }
        if progress >= 60 { return .orange }
        return .red
    }
}

struct PartnerComparisonRow: View {
    let metric: MetricCard

    var body: some View {
        HStack(spacing: 12) {
            // User metric
            VStack(alignment: .leading, spacing: 4) {
                Text("You")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(metric.value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(metric.unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Progress bar
            if let progress = metric.progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(progressColor(progress).gradient)
                            .frame(width: geometry.size.width * min(progress / 200, 1), height: 12)
                    }
                }
                .frame(height: 12)

                Text("\(Int(progress))%")
                    .font(.caption.bold())
                    .foregroundColor(progressColor(progress))
                    .frame(width: 50, alignment: .trailing)
            }

            // Partner metric placeholder
            VStack(alignment: .trailing, spacing: 4) {
                Text("Partner")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("—")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Text(metric.unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 100 { return .green }
        if progress >= 80 { return .blue }
        if progress >= 60 { return .orange }
        return .red
    }
}

struct GoalProgressRow: View {
    let goal: DashboardGoal

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.type)
                        .font(.subheadline.weight(.medium))
                    Text("\(goal.period) · \(goal.status)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(Int(goal.progress))%")
                    .font(.headline.weight(.bold))
                    .foregroundColor(progressColor)
            }

            ProgressView(value: goal.progress / 100)
                .tint(progressColor)
                .scaleEffect(y: 2)

            HStack {
                Text("\(Int(goal.currentValue)) / \(Int(goal.targetValue))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(goal.daysRemaining) days left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var progressColor: Color {
        if goal.progress >= 100 { return .green }
        if goal.progress >= 75 { return .blue }
        if goal.progress >= 50 { return .orange }
        return .red
    }
}

struct RecentActivityRow: View {
    let activity: RecentActivityItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType(activity.type))
                .font(.title3)
                .foregroundStyle(.blue.gradient)
                .frame(width: 40, height: 40)
                .background(.blue.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.type)
                    .font(.subheadline.weight(.medium))
                if let source = activity.sourceName {
                    Text(source)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(activity.value.formatted()) \(activity.unit)")
                    .font(.subheadline.weight(.semibold))
                Text(activity.startDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case let t where t.contains("step"): return "figure.walk"
        case let t where t.contains("calorie") || t.contains("energy"): return "flame.fill"
        case let t where t.contains("heart"): return "heart.fill"
        case let t where t.contains("distance"): return "figure.run"
        case let t where t.contains("workout"): return "dumbbell.fill"
        case let t where t.contains("sleep"): return "bed.double.fill"
        default: return "chart.bar.fill"
        }
    }
}

struct InsightCard: View {
    let insight: Insight

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForPriority(insight.priority))
                .font(.title3)
                .foregroundColor(colorForPriority(insight.priority))
                .frame(width: 36, height: 36)
                .background(colorForPriority(insight.priority).opacity(0.15), in: Circle())

            Text(insight.message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func iconForPriority(_ priority: InsightPriority) -> String {
        switch priority {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func colorForPriority(_ priority: InsightPriority) -> Color {
        switch priority {
        case .success: return .green
        case .warning: return .orange
        case .info: return .blue
        }
    }
}