//
//  PairingView.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import SwiftUI

struct PairingView: View {
    @EnvironmentObject var pairingViewModel: PairingViewModel
    @EnvironmentObject var authManager: AuthManager

    @State private var showInviteSheet = false
    @State private var selectedPairing: PairingResponse?
    @State private var showPairingDetail = false

    var body: some View {
        NavigationStack {
            List {
                // Active Pairing Section
                if pairingViewModel.hasActivePairing {
                    Section {
                        if let pairing = pairingViewModel.currentPairing {
                            ActivePairingCard(pairing: pairing)
                                .onTapGesture {
                                    selectedPairing = pairing
                                    showPairingDetail = true
                                }
                        }
                    } header: {
                        Text("Your Partner")
                    }
                }

                // Pending Invitations
                if !pairingViewModel.pendingInvitations.isEmpty {
                    Section {
                        ForEach(pairingViewModel.pendingInvitations) { invitation in
                            PendingInvitationCard(invitation: invitation)
                        }
                    } header: {
                        HStack {
                            Text("Pending Invitations")
                            Spacer()
                            Text("\(pairingViewModel.pendingInvitations.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2), in: Capsule())
                        }
                    }
                }

                // Invite Section
                Section {
                    Button(action: { showInviteSheet = true }) {
                        HStack {
                            Image(systemName: "person.badge.plus.fill")
                                .font(.title3)
                                .foregroundStyle(.blue.gradient)
                                .frame(width: 40, height: 40)
                                .background(.blue.opacity(0.15), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Invite a Partner")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Share your fitness journey with someone special")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Connect")
                }

                // Past Pairings
                let pastPairings = pairingViewModel.pairings.filter { !$0.isActive && $0.status != .pending }
                if !pastPairings.isEmpty {
                    Section {
                        ForEach(pastPairings) { pairing in
                            PastPairingCard(pairing: pairing)
                        }
                    } header: {
                        Text("Previous Connections")
                    }
                }

                // Empty State
                if !pairingViewModel.hasActivePairing && pairingViewModel.pendingInvitations.isEmpty && pairingViewModel.pairings.isEmpty {
                    ContentUnavailableView(
                        "No Partner Yet",
                        systemImage: "person.2.slash",
                        description: Text("Invite someone to start sharing your fitness journey together")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 40)
                }
            }
            .navigationTitle("Partner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showInviteSheet = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showInviteSheet) {
                InvitePartnerSheet()
            }
            .sheet(item: $selectedPairing) { pairing in
                PairingDetailView(pairing: pairing)
            }
            .refreshable {
                await pairingViewModel.loadPairings()
            }
            .overlay {
                if pairingViewModel.isLoading && pairingViewModel.pairings.isEmpty {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .alert("Error", isPresented: .constant(pairingViewModel.errorMessage != nil)) {
                Button("OK") { pairingViewModel.errorMessage = nil }
            } message: {
                Text(pairingViewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Subviews

struct ActivePairingCard: View {
    let pairing: PairingResponse

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Partner Avatar
                AsyncImage(url: URL(string: pairing.partner.avatarUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.blue.gradient)
                        .overlay {
                            Text(partnerInitials)
                                .font(.title.bold())
                                .foregroundColor(.white)
                        }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())

                // Partner Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(pairing.partnerName)
                        .font(.title3.bold())
                    Text(pairing.partner.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status Badge
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("Connected")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.green)
                }
            }

            // Sharing Scope
            HStack {
                Image(systemName: sharingScopeIcon)
                    .font(.caption)
                Text(pairing.sharingScope.displayName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("Since \(pairing.acceptedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var partnerInitials: String {
        let components = pairing.partnerName.components(separatedBy: " ")
        return components.compactMap { $0.first }.prefix(2).map(String.init).joined().uppercased()
    }

    private var sharingScopeIcon: String {
        switch pairing.sharingScope {
        case .all: return "square.grid.3x3.fill"
        case .activityOnly: return "figure.walk.circle.fill"
        case .heartOnly: return "heart.circle.fill"
        case .sleepOnly: return "bed.double.circle.fill"
        case .workoutOnly: return "dumbbell.circle.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}

struct PendingInvitationCard: View {
    @EnvironmentObject var pairingViewModel: PairingViewModel
    let invitation: PairingResponse

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Circle()
                    .fill(.orange.gradient)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "envelope.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.isInviter ? "Invitation Sent" : "New Invitation")
                        .font(.headline)
                    Text(invitation.partner.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Expires")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(invitation.expiresAt, style: .relative)
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                }
            }

            if !invitation.isInviter {
                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        Task {
                            await pairingViewModel.rejectInvitation(invitation)
                        }
                    } label: {
                        Text("Decline")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        Task {
                            await pairingViewModel.acceptInvitation(invitation)
                        }
                    } label: {
                        Text("Accept")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                Text("Waiting for response...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
}

struct PastPairingCard: View {
    @EnvironmentObject var pairingViewModel: PairingViewModel
    let pairing: PairingResponse

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: pairing.partner.avatarUrl ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.gray.gradient)
                    .overlay {
                        Text(partnerInitials)
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(pairing.partnerName)
                    .font(.subheadline.weight(.medium))
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }

            Spacer()

            Text(pairing.acceptedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var partnerInitials: String {
        let components = pairing.partnerName.components(separatedBy: " ")
        return components.compactMap { $0.first }.prefix(2).map(String.init).joined().uppercased()
    }

    private var statusText: String {
        switch pairing.status {
        case .rejected: return "Declined"
        case .blocked: return "Blocked"
        case .expired: return "Expired"
        default: return pairing.status.rawValue.capitalized
        }
    }

    private var statusColor: Color {
        switch pairing.status {
        case .rejected: return .red
        case .blocked: return .orange
        case .expired: return .gray
        default: return .secondary
        }
    }
}

// MARK: - Invite Partner Sheet

struct InvitePartnerSheet: View {
    @EnvironmentObject var pairingViewModel: PairingViewModel
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var selectedScope: SharingScope = .activityOnly
    @State private var customTypes: Set<HealthDataType> = []
    @State private var showCustomTypes = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Partner's Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                } header: {
                    Text("Partner's Email")
                } footer: {
                    Text("We'll send them an invitation to connect")
                }

                Section {
                    Picker("Sharing Scope", selection: $selectedScope) {
                        ForEach(SharingScope.allCases) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    if selectedScope == .custom {
                        NavigationLink {
                            CustomDataTypesSelector(selectedTypes: $customTypes)
                        } label: {
                            HStack {
                                Text("Select Data Types")
                                Spacer()
                                Text("\(customTypes.count) selected")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Data Sharing")
                } footer: {
                    Text(selectedScope.description)
                }
            }
            .navigationTitle("Invite Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: sendInvitation) {
                        if isLoading {
                            ProgressView()
                                .frame(width: 20, height: 20)
                        } else {
                            Text("Send")
                        }
                    }
                    .disabled(email.isEmpty || !email.contains("@") || isLoading)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sendInvitation() {
        pairingViewModel.inviteEmail = email
        pairingViewModel.selectedSharingScope = selectedScope
        pairingViewModel.customTypes = customTypes
        pairingViewModel.showInviteSheet = true
        dismiss()
    }
}

struct CustomDataTypesSelector: View {
    @Binding var selectedTypes: Set<HealthDataType>
    @Environment(\.dismiss) var dismiss

    let categories: [(String, [HealthDataType])] = [
        ("Activity", [.steps, .activeEnergy, .exerciseMinutes, .standHours, .distanceWalkingRunning, .flightsClimbed]),
        ("Heart", [.heartRate, .restingHeartRate, .heartRateVariability, .vo2Max]),
        ("Sleep", [.sleepAnalysis]),
        ("Workouts", [.workout]),
        ("Body", [.bodyMass, .bodyFatPercentage]),
        ("Vitals", [.bloodPressureSystolic, .bloodPressureDiastolic, .bloodGlucose, .oxygenSaturation, .respiratoryRate, .bodyTemperature]),
        ("Reproductive", [.menstrualFlow])
    ]

    var body: some View {
        List {
            ForEach(categories, id: \.0) { category, types in
                Section(category) {
                    ForEach(types) { type in
                        Toggle(type.displayName, isOn: Binding(
                            get: { selectedTypes.contains(type) },
                            set: { isOn in
                                if isOn { selectedTypes.insert(type) }
                                else { selectedTypes.remove(type) }
                            }
                        ))
                    }
                }
            }
        }
        .navigationTitle("Select Data Types")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Pairing Detail View

struct PairingDetailView: View {
    @EnvironmentObject var pairingViewModel: PairingViewModel
    @Environment(\.dismiss) var dismiss

    let pairing: PairingResponse
    @State private var showEditSharing = false
    @State private var showRemoveConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        AsyncImage(url: URL(string: pairing.partner.avatarUrl ?? "")) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(.blue.gradient)
                                .overlay {
                                    Text(partnerInitials)
                                        .font(.title.bold())
                                        .foregroundColor(.white)
                                }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(pairing.partnerName)
                                .font(.title2.bold())
                            Text(pairing.partner.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Sharing Settings") {
                    HStack {
                        Image(systemName: sharingScopeIcon)
                            .font(.title3)
                            .foregroundStyle(.blue.gradient)
                            .frame(width: 40, height: 40)
                            .background(.blue.opacity(0.15), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sharing Scope")
                                .font(.headline)
                            Text(pairing.sharingScope.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showEditSharing = true }

                    if pairing.sharingScope == .custom {
                        ForEach(pairing.customTypes, id: \.self) { type in
                            HStack {
                                Image(systemName: type.systemImageName)
                                    .foregroundColor(colorForType(type))
                                Text(type.displayName)
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                    }
                }

                Section("Connection Info") {
                    PairingInfoRow(label: "Status", value: pairing.status.rawValue.capitalized, valueColor: statusColor)
                    PairingInfoRow(label: "Connected Since", value: pairing.acceptedAt?.formatted(date: .complete, time: .omitted) ?? "—")
                    PairingInfoRow(label: "Invited", value: pairing.invitedAt.formatted(date: .complete, time: .omitted))
                }

                Section {
                    Button(role: .destructive) {
                        showRemoveConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Remove Partner", systemImage: "person.badge.minus")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Partner Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditSharing) {
                EditSharingScopeSheet(pairing: pairing)
            }
            .alert("Remove Partner", isPresented: $showRemoveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    Task {
                        await pairingViewModel.removePairing(pairing)
                        dismiss()
                    }
                }
            } message: {
                Text("This will disconnect you from \(pairing.partnerName). You'll no longer see each other's health data.")
            }
        }
    }

    private var partnerInitials: String {
        let components = pairing.partnerName.components(separatedBy: " ")
        return components.compactMap { $0.first }.prefix(2).map(String.init).joined().uppercased()
    }

    private var sharingScopeIcon: String {
        switch pairing.sharingScope {
        case .all: return "square.grid.3x3.fill"
        case .activityOnly: return "figure.walk.circle.fill"
        case .heartOnly: return "heart.circle.fill"
        case .sleepOnly: return "bed.double.circle.fill"
        case .workoutOnly: return "dumbbell.circle.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    private func colorForType(_ type: HealthDataType) -> Color {
        switch type.color {
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "purple": return .purple
        case "mint": return .mint
        case "teal": return .teal
        case "indigo": return .indigo
        case "pink": return .pink
        case "brown": return .brown
        case "gray": return .gray
        case "cyan": return .cyan
        default: return .primary
        }
    }

    private var statusColor: Color {
        switch pairing.status {
        case .accepted: return .green
        case .pending: return .orange
        case .rejected: return .red
        case .blocked: return .orange
        case .expired: return .gray
        }
    }
}

struct PairingInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(valueColor)
        }
    }
}

struct EditSharingScopeSheet: View {
    @EnvironmentObject var pairingViewModel: PairingViewModel
    @Environment(\.dismiss) var dismiss

    let pairing: PairingResponse
    @State private var selectedScope: SharingScope
    @State private var customTypes: Set<HealthDataType>
    @State private var isLoading = false

    init(pairing: PairingResponse) {
        self.pairing = pairing
        _selectedScope = State(initialValue: pairing.sharingScope)
        _customTypes = State(initialValue: Set(pairing.customTypes))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Sharing Scope", selection: $selectedScope) {
                        ForEach(SharingScope.allCases) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    if selectedScope == .custom {
                        NavigationLink {
                            CustomDataTypesSelector(selectedTypes: $customTypes)
                        } label: {
                            HStack {
                                Text("Select Data Types")
                                Spacer()
                                Text("\(customTypes.count) selected")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Data Sharing")
                } footer: {
                    Text(selectedScope.description)
                }
            }
            .navigationTitle("Edit Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveChanges) {
                        if isLoading {
                            ProgressView()
                                .frame(width: 20, height: 20)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func saveChanges() {
        isLoading = true
        Task {
            let success = await pairingViewModel.updateSharingScope(
                for: pairing,
                scope: selectedScope,
                customTypes: selectedScope == .custom ? Array(customTypes) : nil
            )
            if success {
                dismiss()
            }
            isLoading = false
        }
    }
}