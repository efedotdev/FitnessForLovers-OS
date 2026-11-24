//
//  ProfileView.swift
//  FitnessForLovers
//
//  Created by Efe Eren Bilgili on 23.11.2026.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var healthKitService: HealthKitService

    @State private var showEditProfile = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Profile Header
                Section {
                    HStack(spacing: 16) {
                        // Avatar
                        ZStack(alignment: .bottomTrailing) {
                            if let profileImage = profileImage {
                                profileImage
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if let avatarUrl = authManager.currentUser?.avatarUrl,
                                      let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    defaultAvatar
                                }
                            } else {
                                defaultAvatar
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay {
                            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                                Circle()
                                    .fill(.blue.gradient)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .shadow(radius: 2)
                            }
                            .offset(x: 4, y: 4)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(authManager.currentUser?.displayName ?? "User")
                                .font(.title2.bold())

                            Text(authManager.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if let createdAt = authManager.currentUser?.createdAt {
                                Text("Member since \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // HealthKit Status
                Section {
                    let isAuthorized = healthKitService.isAuthorized
                    let iconName = isAuthorized ? "heart.fill" : "heart.slash"
                    let iconColor = isAuthorized ? Color.green : Color.gray
                    let statusText = isAuthorized ? "Connected" : "Not Connected"

                    HStack(spacing: 12) {
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundStyle(iconColor.gradient)
                            .frame(width: 44, height: 44)
                            .background(iconColor.opacity(0.15), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health")
                                .font(.headline)
                            Text(statusText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !healthKitService.isAuthorized {
                            Button("Connect") {
                                Task {
                                    _ = await healthKitService.requestAuthorization()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        } else if let lastSync = healthKitService.lastSyncDate {
                            Text("Last sync: \(lastSync.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Health Data")
                }

                // Preferences
                Section {
                    NavigationLink {
                        SharingPreferencesView()
                    } label: {
                        SettingsRow(
                            icon: "person.2.fill",
                            iconColor: .blue,
                            title: "Sharing Preferences",
                            subtitle: profileViewModel.selectedSharingScope.displayName
                        )
                    }

                    NavigationLink {
                        NotificationPreferencesView()
                    } label: {
                        SettingsRow(
                            icon: "bell.fill",
                            iconColor: .orange,
                            title: "Notifications",
                            subtitle: notificationStatus
                        )
                    }

                    NavigationLink {
                        GeneralPreferencesView()
                    } label: {
                        SettingsRow(
                            icon: "gear",
                            iconColor: .gray,
                            title: "General",
                            subtitle: "Language, Timezone"
                        )
                    }
                } header: {
                    Text("Preferences")
                }

                // Account
                Section {
                    NavigationLink {
                        EditProfileView()
                    } label: {
                        SettingsRow(
                            icon: "person.fill",
                            iconColor: .blue,
                            title: "Edit Profile",
                            subtitle: "Name, Avatar"
                        )
                    }

                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        SettingsRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            iconColor: .red,
                            title: "Sign Out",
                            subtitle: "",
                            showChevron: false
                        )
                    }
                } header: {
                    Text("Account")
                }

                // App Info
                Section {
                    InfoRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    InfoRow(label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    Link(destination: URL(string: "https://fitnessforlovers.com/privacy")!) {
                        SettingsRow(
                            icon: "lock.shield",
                            iconColor: .blue,
                            title: "Privacy Policy",
                            subtitle: ""
                        )
                    }
                    Link(destination: URL(string: "https://fitnessforlovers.com/terms")!) {
                        SettingsRow(
                            icon: "doc.text",
                            iconColor: .blue,
                            title: "Terms of Service",
                            subtitle: ""
                        )
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        profileImage = Image(uiImage: uiImage)
                        // TODO: Upload to server
                    }
                }
            }
        }
    }

    private var defaultAvatar: some View {
        Circle()
            .fill(.blue.gradient)
            .overlay {
                Text(authManager.currentUser?.displayName.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
    }

    private var notificationStatus: String {
        let notifications = [
            profileViewModel.notifyOnNewData ? "New Data" : nil,
            profileViewModel.notifyOnPartnerActive ? "Partner Active" : nil,
            profileViewModel.weeklyDigest ? "Weekly Digest" : nil
        ].compactMap { $0 }

        return notifications.isEmpty ? "All Off" : notifications.joined(separator: ", ")
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor.gradient)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct InfoRow: View {
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

// MARK: - Sharing Preferences

struct SharingPreferencesView: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @State private var showCustomTypes = false

    var body: some View {
        Form {
            Section {
                Picker("Sharing Scope", selection: $profileViewModel.selectedSharingScope) {
                    ForEach(SharingScope.allCases) { scope in
                        Text(scope.displayName).tag(scope)
                    }
                }
                .pickerStyle(.navigationLink)

                if profileViewModel.selectedSharingScope == .custom {
                    NavigationLink {
                        CustomDataTypesSelector(selectedTypes: $profileViewModel.customTypes)
                    } label: {
                        HStack {
                            Text("Select Data Types")
                            Spacer()
                            Text("\(profileViewModel.customTypes.count) selected")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Data Sharing")
            } footer: {
                Text(profileViewModel.selectedSharingScope.description)
            }

            Section {
                Button("Save Changes") {
                    Task {
                        await profileViewModel.savePreferences()
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Sharing Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Notification Preferences

struct NotificationPreferencesView: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel

    var body: some View {
        Form {
            Section {
                Toggle("New Health Data", isOn: $profileViewModel.notifyOnNewData)
                Toggle("Partner Activity", isOn: $profileViewModel.notifyOnPartnerActive)
                Toggle("Weekly Digest", isOn: $profileViewModel.weeklyDigest)
            } header: {
                Text("Notifications")
            } footer: {
                Text("Choose which notifications you'd like to receive")
            }

            Section {
                Button("Save Changes") {
                    Task {
                        await profileViewModel.savePreferences()
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - General Preferences

struct GeneralPreferencesView: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel

    var body: some View {
        Form {
            Section("Language") {
                Picker("Language", selection: $profileViewModel.selectedLanguage) {
                    ForEach(profileViewModel.availableLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section("Timezone") {
                Picker("Timezone", selection: $profileViewModel.selectedTimezone) {
                    ForEach(profileViewModel.availableTimezones, id: \.self) { tz in
                        Text(tz).tag(tz)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                Button("Save Changes") {
                    Task {
                        await profileViewModel.savePreferences()
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                }

                Section {
                    Button("Save Changes") {
                        Task {
                            isLoading = true
                            try? await authManager.updateProfile(name: name.isEmpty ? nil : name, avatarUrl: nil)
                            dismiss()
                            isLoading = false
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                name = authManager.currentUser?.name ?? ""
            }
        }
    }
}