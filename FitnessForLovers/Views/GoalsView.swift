//
//  GoalsView.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var goalsViewModel: GoalsViewModel
    @EnvironmentObject var pairingViewModel: PairingViewModel

    @State private var showCreateGoal = false
    @State private var selectedGoal: GoalResponse?
    @State private var showGoalDetail = false

    var body: some View {
        NavigationStack {
            List {
                // Active Goals
                if !goalsViewModel.activeGoals.isEmpty {
                    Section {
                        ForEach(goalsViewModel.activeGoals) { goal in
                            GoalCard(goal: goal)
                                .onTapGesture {
                                    selectedGoal = goal
                                    showGoalDetail = true
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task {
                                            await goalsViewModel.deleteGoal(goal)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text("Active Goals")
                            Spacer()
                            if goalsViewModel.canCreateGoal {
                                Button(action: { showCreateGoal = true }) {
                                    Image(systemName: "plus")
                                }
                            }
                        }
                    }
                }

                // Completed Goals
                if !goalsViewModel.completedGoals.isEmpty {
                    Section {
                        ForEach(goalsViewModel.completedGoals) { goal in
                            GoalCard(goal: goal, style: .completed)
                                .onTapGesture {
                                    selectedGoal = goal
                                    showGoalDetail = true
                                }
                        }
                    } header: {
                        Text("Completed Goals (\(goalsViewModel.completedGoals.count))")
                    }
                }

                // Empty State
                if goalsViewModel.activeGoals.isEmpty && goalsViewModel.completedGoals.isEmpty {
                    ContentUnavailableView {
                        Label("No Goals Yet", systemImage: "target")
                    } description: {
                        if goalsViewModel.canCreateGoal {
                            Text("Create your first shared fitness goal with your partner")
                        } else {
                            Text("Connect with a partner to start creating shared goals")
                        }
                    } actions: {
                        if goalsViewModel.canCreateGoal {
                            Button("Create Goal") { showCreateGoal = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 40)
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                if goalsViewModel.canCreateGoal {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showCreateGoal = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateGoal) {
                CreateGoalSheet()
            }
            .sheet(item: $selectedGoal) { goal in
                GoalDetailView(goal: goal)
            }
            .refreshable {
                await goalsViewModel.loadGoals()
            }
            .overlay {
                if goalsViewModel.isLoading && goalsViewModel.goals.isEmpty {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .alert("Error", isPresented: .constant(goalsViewModel.errorMessage != nil)) {
                Button("OK") { goalsViewModel.errorMessage = nil }
            } message: {
                Text(goalsViewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: GoalResponse
    var style: Style = .active

    enum Style {
        case active, completed
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: goal.type.systemImageName)
                    .font(.title2)
                    .foregroundStyle(goalColor.gradient)
                    .frame(width: 44, height: 44)
                    .background(goalColor.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.type.displayName)
                        .font(.headline)
                    if let customType = goal.customType {
                        Text(customType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(goal.progressPercentage))%")
                        .font(.title3.bold())
                        .foregroundColor(goalColor)
                    Text(style == .completed ? "Completed" : "\(goal.daysRemaining) days left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress Bar
            ProgressView(value: min(goal.progressPercentage / 100, 1.0))
                .tint(goalColor)
                .scaleEffect(y: 3)

            // Stats
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(goal.currentValue))")
                        .font(.subheadline.bold())
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Target")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(goal.targetValue))")
                        .font(.subheadline.bold())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Period")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(goal.period.displayName)
                        .font(.subheadline.bold())
                }
            }

                    }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style == .completed ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var goalColor: Color {
        if style == .completed { return .green }
        if goal.progressPercentage >= 100 { return .green }
        if goal.progressPercentage >= 75 { return .blue }
        if goal.progressPercentage >= 50 { return .orange }
        return .red
    }
}

struct PartnerProgressBar: View {
    let partnerProgress: PartnerGoalProgress?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Partner Progress")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            if let progress = partnerProgress {
                HStack(spacing: 8) {
                    // User
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(progress.currentValue))")
                            .font(.caption.bold())
                    }

                    // Progress comparison
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 8)

                            // Partner bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: geometry.size.width * min(progress.progress / 100, 1), height: 8)

                            // User bar (overlay)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green.gradient)
                                .frame(width: geometry.size.width * min(1.0, 1.0), height: 8)
                        }
                    }
                    .frame(height: 8)

                    // Partner
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(progress.name ?? "Partner")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(progress.currentValue))")
                            .font(.caption.bold())
                    }
                }
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Create Goal Sheet

struct CreateGoalSheet: View {
    @EnvironmentObject var goalsViewModel: GoalsViewModel
    @EnvironmentObject var pairingViewModel: PairingViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedType: GoalType = .steps
    @State private var customTypeName = ""
    @State private var targetValue: Double = 10000
    @State private var selectedPeriod: GoalPeriod = .daily
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(GoalType.allCases) { type in
                            Label(type.displayName, systemImage: type.systemImageName).tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    if selectedType == .custom {
                        TextField("Custom Goal Name", text: $customTypeName)
                    }
                }

                Section("Target") {
                    HStack {
                        Text("Target Value")
                        Spacer()
                        TextField("Value", value: $targetValue, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text(selectedType.defaultUnit.displayName)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Period") {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(GoalPeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                if let pairing = goalsViewModel.selectedPairing ?? pairingViewModel.currentPairing {
                    Section {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                            Text("Shared with \(pairing.partnerName)")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: createGoal) {
                        if isLoading {
                            ProgressView().frame(width: 20, height: 20)
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(isLoading || (selectedType == .custom && customTypeName.isEmpty))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func createGoal() {
        isLoading = true
        goalsViewModel.selectedGoalType = selectedType
        goalsViewModel.customGoalType = customTypeName
        goalsViewModel.targetValue = targetValue
        goalsViewModel.selectedPeriod = selectedPeriod
        goalsViewModel.startDate = startDate
        goalsViewModel.endDate = endDate

        Task {
            let success = await goalsViewModel.createGoal()
            if success {
                dismiss()
            }
            isLoading = false
        }
    }
}

// MARK: - Goal Detail View

struct GoalDetailView: View {
    @EnvironmentObject var goalsViewModel: GoalsViewModel
    @Environment(\.dismiss) var dismiss

    let goal: GoalResponse
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var updatedCurrentValue: Double

    init(goal: GoalResponse) {
        self.goal = goal
        _updatedCurrentValue = State(initialValue: goal.currentValue)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    GoalCard(goal: goal)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section("Progress") {
                    if goal.status == .active {
                        HStack {
                            Text("Current Value")
                            Spacer()
                            TextField("Value", value: $updatedCurrentValue, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }

                        Button("Update Progress") {
                            Task {
                                await goalsViewModel.updateGoal(goal, currentValue: updatedCurrentValue)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }

                    ProgressView(value: min(goal.progressPercentage / 100, 1.0))
                        .tint(progressColor)
                        .scaleEffect(y: 4)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Current").font(.caption).foregroundColor(.secondary)
                            Text("\(Int(goal.currentValue))").font(.headline)
                        }
                        Spacer()
                        VStack {
                            Text("Target").font(.caption).foregroundColor(.secondary)
                            Text("\(Int(goal.targetValue))").font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Progress").font(.caption).foregroundColor(.secondary)
                            Text("\(Int(goal.progressPercentage))%").font(.headline).foregroundColor(progressColor)
                        }
                    }
                }

                Section("Details") {
                    InfoRow(label: "Type", value: goal.type.displayName)
                    if let customType = goal.customType {
                        InfoRow(label: "Custom Name", value: customType)
                    }
                    InfoRow(label: "Period", value: goal.period.displayName)
                    InfoRow(label: "Status", value: goal.status.displayName, valueColor: statusColor)
                    InfoRow(label: "Created By", value: goal.createdBy?.name ?? "You")
                    InfoRow(label: "Created", value: goal.createdAt.formatted(date: .abbreviated, time: .omitted))
                }

                if goal.status == .active {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Goal", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                if goal.status == .active {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") { showEditSheet = true }
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditGoalSheet(goal: goal)
            }
            .alert("Delete Goal", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await goalsViewModel.deleteGoal(goal)
                        dismiss()
                    }
                }
            } message: {
                Text("This will permanently delete this goal.")
            }
        }
    }

    private var progressColor: Color {
        if goal.progressPercentage >= 100 { return .green }
        if goal.progressPercentage >= 75 { return .blue }
        if goal.progressPercentage >= 50 { return .orange }
        return .red
    }

    private var statusColor: Color {
        switch goal.status {
        case .active: return .green
        case .completed: return .blue
        case .archived: return .gray
        case .expired: return .red
        }
    }
}

struct EditGoalSheet: View {
    @EnvironmentObject var goalsViewModel: GoalsViewModel
    @Environment(\.dismiss) var dismiss

    let goal: GoalResponse
    @State private var targetValue: Double
    @State private var endDate: Date
    @State private var isLoading = false

    init(goal: GoalResponse) {
        self.goal = goal
        _targetValue = State(initialValue: goal.targetValue)
        _endDate = State(initialValue: goal.endDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Target") {
                    HStack {
                        Text("Target Value")
                        Spacer()
                        TextField("Value", value: $targetValue, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text(goal.type.defaultUnit.displayName)
                            .foregroundColor(.secondary)
                    }
                }

                Section("End Date") {
                    DatePicker("End Date", selection: $endDate, in: goal.startDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveChanges) {
                        if isLoading {
                            ProgressView().frame(width: 20, height: 20)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private func saveChanges() {
        isLoading = true
        Task {
            let request = UpdateGoalRequest(targetValue: targetValue, currentValue: nil, status: nil, endDate: endDate)
            let success = await goalsViewModel.updateGoal(goal, currentValue: nil, status: nil)
            if success {
                dismiss()
            }
            isLoading = false
        }
    }
}