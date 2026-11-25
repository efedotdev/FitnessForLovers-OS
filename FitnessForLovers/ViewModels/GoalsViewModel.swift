import Foundation
import Combine

@MainActor
class GoalsViewModel: ObservableObject {
    @Published var goals: [GoalResponse] = []
    @Published var activeGoals: [GoalResponse] = []
    @Published var completedGoals: [GoalResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCreateGoalSheet = false
    @Published var title = "Shared steps"
    @Published var targetValue = 10000.0
    @Published var startDate = Date()
    @Published var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @Published var progressByGoal: [String: GoalProgress] = [:]

    private let apiService = APIService.shared
    private let pairingViewModel = PairingViewModel.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
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
            goals = []
            activeGoals = []
            completedGoals = []
            progressByGoal = [:]
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apiService.getGoals(pairingId: pairingId)
            goals = response.goals
            categorizeGoals()

            for goal in activeGoals {
                _ = await refreshGoalProgress(goal)
            }
        } catch {
            errorMessage = "Hedefler yüklenemedi. Lütfen tekrar deneyin."
        }
    }

    func createGoal() async -> Bool {
        guard let pairing = pairingViewModel.currentPairing else {
            errorMessage = "Ortak hedef oluşturmak için önce bir partnerle eşleşin."
            return false
        }
        guard targetValue > 0 else {
            errorMessage = "Hedef adım sayısı sıfırdan büyük olmalıdır."
            return false
        }
        guard endDate >= startDate else {
            errorMessage = "Bitiş tarihi başlangıç tarihinden önce olamaz."
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let request = CreateGoalRequest(
            pairingId: pairing.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            targetValue: targetValue,
            startDate: startDate,
            endDate: endDate
        )

        do {
            let goal = try await apiService.createGoal(request)
            goals.append(goal)
            categorizeGoals()
            showCreateGoalSheet = false
            resetForm()
            NotificationCenter.default.post(name: .goalsChanged, object: nil)
            return true
        } catch {
            errorMessage = "Hedef oluşturulamadı. Bilgilerinizi kontrol edip tekrar deneyin."
            return false
        }
    }

    func updateGoal(
        _ goal: GoalResponse,
        title: String?,
        targetValue: Double?,
        startDate: Date?,
        endDate: Date?
    ) async -> Bool {
        let request = UpdateGoalRequest(
            title: title,
            targetValue: targetValue,
            startDate: startDate,
            endDate: endDate
        )

        do {
            let updated = try await apiService.updateGoal(id: goal.id, goalRequest: request)
            updateGoalInLists(updated)
            NotificationCenter.default.post(name: .goalsChanged, object: nil)
            return true
        } catch {
            errorMessage = "Hedef güncellenemedi. Lütfen tekrar deneyin."
            return false
        }
    }

    func deleteGoal(_ goal: GoalResponse) async -> Bool {
        do {
            try await apiService.deleteGoal(id: goal.id)
            goals.removeAll { $0.id == goal.id }
            progressByGoal.removeValue(forKey: goal.id)
            categorizeGoals()
            NotificationCenter.default.post(name: .goalsChanged, object: nil)
            return true
        } catch {
            errorMessage = "Hedef silinemedi. Lütfen tekrar deneyin."
            return false
        }
    }

    func refreshGoalProgress(_ goal: GoalResponse) async -> GoalProgress? {
        do {
            let response = try await apiService.getGoalProgress(id: goal.id)
            progressByGoal[goal.id] = response.progress
            updateGoalInLists(goal.applying(progress: response.progress))
            return response.progress
        } catch {
            errorMessage = "Hedef ilerlemesi alınamadı. Lütfen tekrar deneyin."
            return nil
        }
    }

    private func updateGoalInLists(_ updated: GoalResponse) {
        if let index = goals.firstIndex(where: { $0.id == updated.id }) {
            goals[index] = updated
        } else {
            goals.append(updated)
        }
        categorizeGoals()
    }

    private func categorizeGoals() {
        activeGoals = goals.filter { !$0.completed }
        completedGoals = goals.filter(\.completed)
    }

    private func resetForm() {
        title = "Shared steps"
        targetValue = 10000
        startDate = Date()
        endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    }

    var canCreateGoal: Bool {
        pairingViewModel.hasActivePairing
    }
}
