//
//  GoalsViewModel.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import Foundation
import Combine

@MainActor
class GoalsViewModel: ObservableObject {
    @Published var goals: [GoalResponse] = []
    @Published var activeGoals: [GoalResponse] = []
    @Published var completedGoals: [GoalResponse] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showCreateGoalSheet: Bool = false
    @Published var selectedPairing: PairingResponse?
    @Published var selectedGoalType: GoalType = .steps
    @Published var customGoalType: String = ""
    @Published var targetValue: Double = 10000
    @Published var selectedPeriod: GoalPeriod = .daily
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    private let apiService = APIService.shared
    private let pairingViewModel = PairingViewModel.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.publisher(for: .pairingChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.loadGoals() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .healthDataSynced)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.loadGoals() }
            }
            .store(in: &cancellables)
    }

    func loadGoals() async {
        guard pairingViewModel.hasActivePairing,
              let pairingId = pairingViewModel.currentPairing?.id else {
            self.goals = []
            self.activeGoals = []
            self.completedGoals = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.getGoals(query: QueryGoalsRequest(page: nil, limit: nil, pairingId: pairingId, status: nil, type: nil, period: nil))
            self.goals = response.goals
            self.activeGoals = response.goals.filter { $0.status == GoalStatus.active }
            self.completedGoals = response.goals.filter { $0.status == GoalStatus.completed }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createGoal() async -> Bool {
        guard let pairing = selectedPairing ?? pairingViewModel.currentPairing else {
            errorMessage = "No active pairing found"
            return false
        }

        isLoading = true
        errorMessage = nil

        let request = CreateGoalRequest(
            pairingId: pairing.id,
            type: selectedGoalType,
            customType: selectedGoalType == .custom && !customGoalType.isEmpty ? customGoalType : nil,
            targetValue: targetValue,
            period: selectedPeriod,
            startDate: startDate,
            endDate: endDate
        )

        do {
            let goal = try await apiService.createGoal(request)
            goals.append(goal)
            if goal.status == .active {
                activeGoals.append(goal)
            }
            showCreateGoalSheet = false
            resetForm()
            NotificationCenter.default.post(name: .goalsChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateGoal(_ goal: GoalResponse, currentValue: Double? = nil, status: GoalStatus? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil

        let request = UpdateGoalRequest(
            targetValue: nil,
            currentValue: currentValue,
            status: status,
            endDate: nil
        )

        do {
            let updated = try await apiService.updateGoal(id: goal.id, goalRequest: request)
            updateGoalInLists(updated)
            NotificationCenter.default.post(name: .goalsChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteGoal(_ goal: GoalResponse) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await apiService.deleteGoal(id: goal.id)
            goals.removeAll { $0.id == goal.id }
            activeGoals.removeAll { $0.id == goal.id }
            completedGoals.removeAll { $0.id == goal.id }
            NotificationCenter.default.post(name: .goalsChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshGoalProgress(_ goal: GoalResponse) async {
        do {
            let response = try await apiService.getGoalProgress(id: goal.id)
            updateGoalInLists(response.goal)
            if let partnerProgress = response.partnerProgress {
                // Could store partner progress separately for UI
            }
        } catch {
            print("Failed to refresh goal progress: \(error)")
        }
    }

    private func updateGoalInLists(_ updated: GoalResponse) {
        if let index = goals.firstIndex(where: { $0.id == updated.id }) {
            goals[index] = updated
        }
        if let index = activeGoals.firstIndex(where: { $0.id == updated.id }) {
            activeGoals[index] = updated
        }
        if let index = completedGoals.firstIndex(where: { $0.id == updated.id }) {
            completedGoals[index] = updated
        }

        // Re-categorize
        activeGoals = goals.filter { $0.status == .active }
        completedGoals = goals.filter { $0.status == .completed }
    }

    private func resetForm() {
        selectedGoalType = .steps
        customGoalType = ""
        targetValue = 10000
        selectedPeriod = .daily
        startDate = Date()
        endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    }

    // MARK: - Computed Properties

    var canCreateGoal: Bool {
        return pairingViewModel.hasActivePairing
    }

    var availableGoalTypes: [GoalType] {
        return GoalType.allCases
    }
}