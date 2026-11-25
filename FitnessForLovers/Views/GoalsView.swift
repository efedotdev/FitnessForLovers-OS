import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var goalsViewModel: GoalsViewModel
    @State private var showCreateGoal = false
    @State private var selectedGoal: GoalResponse?

    var body: some View {
        NavigationStack {
            List {
                if !goalsViewModel.activeGoals.isEmpty {
                    Section("Active goals") {
                        ForEach(goalsViewModel.activeGoals) { goal in
                            Button {
                                selectedGoal = goal
                            } label: {
                                GoalCard(goal: goal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !goalsViewModel.completedGoals.isEmpty {
                    Section("Completed goals") {
                        ForEach(goalsViewModel.completedGoals) { goal in
                            Button {
                                selectedGoal = goal
                            } label: {
                                GoalCard(goal: goal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if goalsViewModel.goals.isEmpty && !goalsViewModel.isLoading {
                    ContentUnavailableView {
                        Label("No shared goals yet", systemImage: "figure.walk")
                    } description: {
                        Text(goalsViewModel.canCreateGoal
                             ? "Create a step goal and track your combined progress."
                             : "Connect with a partner before creating a shared goal.")
                    } actions: {
                        if goalsViewModel.canCreateGoal {
                            Button("Create step goal") { showCreateGoal = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .overlay {
                if goalsViewModel.isLoading && goalsViewModel.goals.isEmpty {
                    ProgressView("Loading goals…")
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                if goalsViewModel.canCreateGoal {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCreateGoal = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Create step goal")
                    }
                }
            }
            .refreshable {
                await goalsViewModel.loadGoals()
            }
            .sheet(isPresented: $showCreateGoal) {
                CreateGoalSheet()
            }
            .sheet(item: $selectedGoal) { goal in
                GoalDetailView(goal: goal)
            }
            .alert("Error", isPresented: Binding(
                get: { goalsViewModel.errorMessage != nil },
                set: { if !$0 { goalsViewModel.errorMessage = nil } }
            )) {
                Button("OK") { goalsViewModel.errorMessage = nil }
            } message: {
                Text(goalsViewModel.errorMessage ?? "")
            }
            .task {
                await goalsViewModel.loadGoals()
            }
        }
    }
}

private struct GoalCard: View {
    let goal: GoalResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(goal.title, systemImage: "figure.walk")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(Int(min(goal.progressPercentage, 100)))%")
                    .font(.headline)
                    .foregroundStyle(goal.completed ? .green : .blue)
            }

            ProgressView(value: min(goal.progressPercentage / 100, 1))
                .tint(goal.completed ? .green : .blue)

            HStack {
                Text("\(Int(goal.currentValue)) / \(Int(goal.targetValue)) steps")
                Spacer()
                Text(goal.completed ? "Completed" : "\(Int(goal.remainingValue)) left")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

private struct CreateGoalSheet: View {
    @EnvironmentObject private var goalsViewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = "Shared steps"
    @State private var targetValue = 10000.0
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var isSaving = false

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && targetValue > 0
            && endDate >= startDate
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Shared step goal") {
                    TextField("Goal name", text: $title)
                    HStack {
                        Text("Target steps")
                        Spacer()
                        TextField("Steps", value: $targetValue, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                }

                Section("Date range") {
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("New goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        isSaving = true
        goalsViewModel.title = title
        goalsViewModel.targetValue = targetValue
        goalsViewModel.startDate = startDate
        goalsViewModel.endDate = endDate
        Task {
            if await goalsViewModel.createGoal() {
                dismiss()
            }
            isSaving = false
        }
    }
}

private struct GoalDetailView: View {
    @EnvironmentObject private var goalsViewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var goal: GoalResponse
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    init(goal: GoalResponse) {
        _goal = State(initialValue: goal)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Combined progress") {
                    ProgressView(value: min(goal.progressPercentage / 100, 1))
                        .tint(goal.completed ? .green : .blue)
                    HStack {
                        metric("Steps", value: Int(goal.currentValue).formatted())
                        Spacer()
                        metric("Target", value: Int(goal.targetValue).formatted())
                        Spacer()
                        metric("Remaining", value: Int(goal.remainingValue).formatted())
                    }
                    Text("Progress is calculated from both partners’ step data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Goal details") {
                    LabeledContent("Name", value: goal.title)
                    LabeledContent("Start", value: goal.startDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("End", value: goal.endDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Status", value: goal.completed ? "Completed" : "Active")
                }

                Section {
                    Button("Delete goal", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Goal details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEditSheet = true }
                        .disabled(goal.completed)
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditGoalSheet(goal: goal)
            }
            .task {
                if let progress = await goalsViewModel.refreshGoalProgress(goal) {
                    goal = goal.applying(progress: progress)
                }
            }
            .alert("Delete goal?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        if await goalsViewModel.deleteGoal(goal) {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("This shared goal will be permanently deleted.")
            }
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

private struct EditGoalSheet: View {
    @EnvironmentObject private var goalsViewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss

    let goal: GoalResponse
    @State private var title: String
    @State private var targetValue: Double
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isSaving = false

    init(goal: GoalResponse) {
        self.goal = goal
        _title = State(initialValue: goal.title)
        _targetValue = State(initialValue: goal.targetValue)
        _startDate = State(initialValue: goal.startDate)
        _endDate = State(initialValue: goal.endDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Shared step goal") {
                    TextField("Goal name", text: $title)
                    HStack {
                        Text("Target steps")
                        Spacer()
                        TextField("Steps", value: $targetValue, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                }
                Section("Date range") {
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task {
                            if await goalsViewModel.updateGoal(
                                goal,
                                title: title,
                                targetValue: targetValue,
                                startDate: startDate,
                                endDate: endDate
                            ) {
                                dismiss()
                            }
                            isSaving = false
                        }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || targetValue <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
