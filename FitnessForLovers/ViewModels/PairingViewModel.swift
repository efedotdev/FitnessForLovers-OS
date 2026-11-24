//
//  PairingViewModel.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import Foundation
import Combine

@MainActor
class PairingViewModel: ObservableObject {
    static let shared = PairingViewModel()

    @Published var pairings: [PairingResponse] = []
    @Published var pendingInvitations: [PairingResponse] = []
    @Published var activePairings: [PairingResponse] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showInviteSheet: Bool = false
    @Published var inviteEmail: String = ""
    @Published var selectedSharingScope: SharingScope = .activityOnly
    @Published var customTypes: Set<HealthDataType> = []

    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.publisher(for: .pairingChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.loadPairings() }
            }
            .store(in: &cancellables)
    }

    func loadPairings() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.getPairings()
            self.pairings = response.pairings
            self.pendingInvitations = response.pairings.filter { $0.status == .pending }
            self.activePairings = response.pairings.filter { $0.isActive }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func sendInvitation() async -> Bool {
        guard !inviteEmail.isEmpty,
              inviteEmail.contains("@") else {
            errorMessage = "Please enter a valid email address"
            return false
        }

        isLoading = true
        errorMessage = nil

        let request = CreatePairingRequest(
            inviteeEmail: inviteEmail,
            sharingScope: selectedSharingScope,
            customTypes: selectedSharingScope == .custom ? Array(customTypes) : nil
        )

        do {
            let response = try await apiService.createPairing(request)
            pairings.append(response.pairing)
            pendingInvitations.append(response.pairing)
            showInviteSheet = false
            inviteEmail = ""
            selectedSharingScope = .activityOnly
            customTypes.removeAll()
            NotificationCenter.default.post(name: .pairingChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func acceptInvitation(_ pairing: PairingResponse) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.respondToPairing(id: pairing.id, action: .accept)
            updatePairingInLists(response.pairing)
            NotificationCenter.default.post(name: .pairingChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func rejectInvitation(_ pairing: PairingResponse) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.respondToPairing(id: pairing.id, action: .reject)
            updatePairingInLists(response.pairing)
            NotificationCenter.default.post(name: .pairingChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateSharingScope(for pairing: PairingResponse, scope: SharingScope, customTypes: [HealthDataType]? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil

        let request = UpdatePairingRequest(
            sharingScope: scope,
            customTypes: customTypes
        )

        do {
            let response = try await apiService.updatePairing(id: pairing.id, pairingRequest: request)
            updatePairingInLists(response.pairing)
            NotificationCenter.default.post(name: .pairingChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func removePairing(_ pairing: PairingResponse) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await apiService.deletePairing(id: pairing.id)
            pairings.removeAll { $0.id == pairing.id }
            pendingInvitations.removeAll { $0.id == pairing.id }
            activePairings.removeAll { $0.id == pairing.id }
            NotificationCenter.default.post(name: .pairingChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func updatePairingInLists(_ updated: PairingResponse) {
        if let index = pairings.firstIndex(where: { $0.id == updated.id }) {
            pairings[index] = updated
        }
        if let index = pendingInvitations.firstIndex(where: { $0.id == updated.id }) {
            pendingInvitations[index] = updated
        }
        if let index = activePairings.firstIndex(where: { $0.id == updated.id }) {
            activePairings[index] = updated
        }

        // Re-categorize
        pendingInvitations = pairings.filter { $0.status == .pending }
        activePairings = pairings.filter { $0.isActive }
    }

    // MARK: - Computed Properties

    var hasActivePairing: Bool {
        return !activePairings.isEmpty
    }

    var currentPairing: PairingResponse? {
        return activePairings.first
    }
}