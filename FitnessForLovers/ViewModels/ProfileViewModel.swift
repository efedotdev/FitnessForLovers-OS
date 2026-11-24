//
//  ProfileViewModel.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var preferences: UserPreferencesResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showSharingScopeSheet: Bool = false
    @Published var selectedSharingScope: SharingScope = .activityOnly
    @Published var customTypes: Set<HealthDataType> = []
    @Published var notifyOnNewData: Bool = true
    @Published var notifyOnPartnerActive: Bool = true
    @Published var weeklyDigest: Bool = true
    @Published var selectedTimezone: String = TimeZone.current.identifier
    @Published var selectedLanguage: String = "en"

    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadPreferences()
    }

    func loadPreferences() {
        Task {
            await fetchPreferences()
        }
    }

    func fetchPreferences() async {
        isLoading = true
        errorMessage = nil

        do {
            let prefs = try await apiService.getPreferences()
            self.preferences = prefs
            self.updateLocalState(from: prefs)
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func savePreferences() async -> Bool {
        isLoading = true
        errorMessage = nil

        let request = UpdatePreferencesRequest(
            sharingScope: selectedSharingScope,
            customDataTypes: selectedSharingScope == .custom ? Array(customTypes) : nil,
            notifyOnNewData: notifyOnNewData,
            notifyOnPartnerActive: notifyOnPartnerActive,
            weeklyDigest: weeklyDigest,
            timezone: selectedTimezone,
            language: selectedLanguage
        )

        do {
            let prefs = try await apiService.updatePreferences(request)
            self.preferences = prefs
            self.updateLocalState(from: prefs)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    private func updateLocalState(from prefs: UserPreferencesResponse) {
        self.selectedSharingScope = prefs.sharingScope
        self.customTypes = Set(prefs.customDataTypes)
        self.notifyOnNewData = prefs.notifyOnNewData
        self.notifyOnPartnerActive = prefs.notifyOnPartnerActive
        self.weeklyDigest = prefs.weeklyDigest
        self.selectedTimezone = prefs.timezone
        self.selectedLanguage = prefs.language
    }

    // MARK: - Computed Properties

    var availableTimezones: [String] {
        return TimeZone.knownTimeZoneIdentifiers.sorted()
    }

    var availableLanguages: [(code: String, name: String)] {
        return [
            ("en", "English"),
            ("tr", "Türkçe"),
            ("es", "Español"),
            ("fr", "Français"),
            ("de", "Deutsch"),
            ("it", "Italiano"),
            ("pt", "Português"),
            ("ja", "日本語"),
            ("ko", "한국어"),
            ("zh", "中文")
        ]
    }
}