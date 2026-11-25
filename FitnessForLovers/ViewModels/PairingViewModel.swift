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
    @Published var sentInvitations: [PairingResponse] = []
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
            async let allResponse = apiService.getPairings()
            async let pendingResponse = apiService.getPendingPairings()
            async let sentResponse = apiService.getSentPairings()

            let (all, pending, sent) = try await (allResponse, pendingResponse, sentResponse)
            self.pairings = all.pairings
            self.pendingInvitations = pending.pairings.filter { !$0.isInviter }
            self.sentInvitations = sent.pairings
            self.activePairings = all.pairings.filter { $0.isActive }
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
            sentInvitations.append(response.pairing)
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
            _ = try await apiService.deletePairing(id: pairing.id)
            pairings.removeAll { $0.id == pairing.id }
            pendingInvitations.removeAll { $0.id == pairing.id }
            sentInvitations.removeAll { $0.id == pairing.id }
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
        } else {
            pairings.append(updated)
        }

        pendingInvitations = pairings.filter { $0.status == .pending && !$0.isInviter }
        sentInvitations = pairings.filter { $0.status == .pending && $0.isInviter }
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