//
//  SettingsView.swift
//  BF6StatsTracker
//
//  Settings and preferences for the application
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var accountStore = EAAccountStore.shared

    @State private var autoRefresh: Bool = true
    @State private var refreshInterval: Double = 300
    @State private var showNotifications: Bool = true
    @State private var compactMode: Bool = false
    @State private var showEnhancedOverview: Bool = true
    @State private var selectedColorScheme: AppColorScheme = .orange
    @State private var showClearHistoryConfirmation = false
    @State private var showAbout = false
    @State private var accountToDelete: StoredEAAccount?
    @State private var showDeleteAccountAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Theme.overlayColor)
            
            ScrollView {
                VStack(spacing: 24) {
                    // EA Account Section
                    SettingsSection(title: "EA Accounts", icon: "person.badge.key.fill") {
                        if accountStore.accounts.isEmpty {
                            // No accounts state
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(Theme.textSecondary)

                                    Text("No EA accounts stored")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)

                                    Spacer()
                                }

                                Text("EA accounts are automatically saved when you authenticate through the app.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        } else {
                            // Display all stored accounts
                            VStack(spacing: 12) {
                                ForEach(accountStore.accounts) { account in
                                    EAAccountCard(
                                        account: account,
                                        onDelete: {
                                            accountToDelete = account
                                            showDeleteAccountAlert = true
                                        }
                                    )
                                }

                                Divider()

                                // Summary
                                HStack {
                                    Text("\(accountStore.accounts.count) stored account\(accountStore.accounts.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)

                                    Spacer()

                                    if accountStore.accounts.count > 1 {
                                        Button(role: .destructive) {
                                            accountStore.clearAllAccounts()
                                        } label: {
                                            Text("Clear All")
                                                .font(.caption)
                                                .foregroundColor(Theme.bf6Red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    // Refresh Settings
                    SettingsSection(title: "Auto Refresh", icon: "arrow.clockwise") {
                        VStack(spacing: 16) {
                            Toggle("Enable Auto Refresh", isOn: $autoRefresh)
                                .foregroundColor(Theme.textPrimary)

                            if autoRefresh {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Refresh Interval")
                                            .font(.subheadline)
                                            .foregroundColor(Theme.textSecondary)

                                        Spacer()

                                        Text("\(Int(refreshInterval / 60)) minutes")
                                            .font(.subheadline)
                                            .foregroundColor(Theme.accent)
                                    }

                                    Slider(value: $refreshInterval, in: 60...1800, step: 60)
                                        .tint(Theme.accent)

                                    HStack {
                                        Text("1 min")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textSecondary)

                                        Spacer()

                                        Text("30 min")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Display Settings
                    SettingsSection(title: "Display", icon: "paintbrush.fill") {
                        VStack(spacing: 12) {
                            // Color Scheme Picker
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Color Scheme")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    ForEach(AppColorScheme.allCases) { scheme in
                                        ColorSchemeButton(
                                            scheme: scheme,
                                            isSelected: selectedColorScheme == scheme
                                        ) {
                                            selectedColorScheme = scheme
                                            Theme.setAccentScheme(scheme)
                                        }
                                    }
                                }

                                Text("Choose your preferred accent color for the app")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }

                            Divider()

                            Toggle("Compact Mode", isOn: $compactMode)
                                .foregroundColor(Theme.textPrimary)

                            Toggle("Show Notifications", isOn: $showNotifications)
                                .foregroundColor(Theme.textPrimary)

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Overview Style")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)

                                Picker("Overview Style", selection: $showEnhancedOverview) {
                                    Text("Enhanced").tag(true)
                                    Text("Classic").tag(false)
                                }
                                .pickerStyle(.segmented)

                                Text("Choose between the modern enhanced view or classic overview layout")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    
                    // Data Management
                    SettingsSection(title: "Data Management", icon: "internaldrive.fill") {
                        VStack(spacing: 12) {
                            // Cache Section
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Cache Status")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)

                                    Text(viewModel.formatCacheAge())
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }

                                Spacer()

                                Button("Clear Cache") {
                                    viewModel.clearCache()
                                }
                                .buttonStyle(.bordered)
                            }

                            Text("Cache expires after 5 minutes. Data is stored locally for faster loading.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)

                            Divider()

                            // Historical Data Section
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Historical Data")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)

                                    Text(getHistoricalDataSummary())
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }

                                Spacer()

                                Button("Clear History") {
                                    showClearHistoryConfirmation = true
                                }
                                .buttonStyle(.bordered)
                                .tint(Theme.bf6Red)
                            }

                            Text("Permanently deletes all saved snapshots, sessions, and map statistics. This cannot be undone.")
                                .font(.caption)
                                .foregroundColor(Theme.bf6Red.opacity(0.8))
                        }
                    }
                    
                    // About Section
                    SettingsSection(title: "About", icon: "info.circle.fill") {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("BF6 Stats Tracker")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Theme.textPrimary)

                                    Text("Version 1.0.0")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }

                                Spacer()

                                Button {
                                    showAbout = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle")
                                        Text("About")
                                    }
                                    .font(.caption)
                                    .foregroundColor(Theme.bf6Orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.bf6Orange.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }

                            Text("Designed & Built by CitizenCoder • Powered by GameTools.Network API")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Save Button
                    Button {
                        saveSettings()
                    } label: {
                        Text("Save Settings")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Theme.bf6Blue, Theme.bf6Purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 800)
        .background(Theme.backgroundPrimary)
        .onAppear {
            loadCurrentSettings()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .alert("Clear Historical Data?", isPresented: $showClearHistoryConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All Data", role: .destructive) {
                clearHistoricalData()
            }
        } message: {
            Text("This will permanently delete all saved snapshots, play sessions, and map statistics. This action cannot be undone.\n\nAre you sure you want to continue?")
        }
        .alert("Delete EA Account", isPresented: $showDeleteAccountAlert, presenting: accountToDelete) { account in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                accountStore.deleteAccount(account)
            }
        } message: { account in
            Text("Are you sure you want to delete the EA account for \(account.nickname ?? account.eaId)?\n\nThis will remove the account from your stored accounts list.")
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentSettings() {
        autoRefresh = viewModel.settings.autoRefresh
        refreshInterval = viewModel.settings.refreshInterval
        showNotifications = viewModel.settings.showNotifications
        compactMode = viewModel.settings.compactMode
        showEnhancedOverview = viewModel.settings.showEnhancedOverview
        selectedColorScheme = viewModel.settings.selectedColorScheme
        Theme.setAccentScheme(selectedColorScheme)
    }

    private func saveSettings() {
        viewModel.settings.autoRefresh = autoRefresh
        viewModel.settings.refreshInterval = refreshInterval
        viewModel.settings.showNotifications = showNotifications
        viewModel.settings.compactMode = compactMode
        viewModel.settings.showEnhancedOverview = showEnhancedOverview
        viewModel.settings.selectedColorScheme = selectedColorScheme
        Theme.setAccentScheme(selectedColorScheme)

        Task {
            await viewModel.saveSettings()
        }

        dismiss()
    }

    private func getHistoricalDataSummary() -> String {
        let snapshots = HistoryManager.shared.recentSnapshots.count
        let sessions = HistoryManager.shared.sessions.count

        if snapshots == 0 && sessions == 0 {
            return "No historical data saved yet"
        }

        var parts: [String] = []
        if snapshots > 0 {
            parts.append("\(snapshots) snapshot\(snapshots == 1 ? "" : "s")")
        }
        if sessions > 0 {
            parts.append("\(sessions) session\(sessions == 1 ? "" : "s")")
        }

        return parts.joined(separator: ", ")
    }

    private func clearHistoricalData() {
        // Clear all historical data from SwiftData
        let playerName = viewModel.settings.playerName
        let platform = viewModel.settings.platform

        // Clear snapshots and sessions
        if let context = HistoryManager.shared.modelContext {
            // Delete all snapshots
            let snapshotDescriptor = FetchDescriptor<StatsSnapshot>()
            if let allSnapshots = try? context.fetch(snapshotDescriptor) {
                allSnapshots.forEach { context.delete($0) }
            }

            // Delete all sessions
            let sessionDescriptor = FetchDescriptor<PlaySession>()
            if let allSessions = try? context.fetch(sessionDescriptor) {
                allSessions.forEach { context.delete($0) }
            }

            // Save deletions
            try? context.save()

            // Reload empty data
            HistoryManager.shared.loadRecentData()
        }

        // Clear map statistics
        MapTracker.shared.clearMapStats(playerName: playerName, platform: platform.rawValue)

        print("🗑️ Historical data cleared successfully")
    }

    private func formatDate(_ dateString: String) -> String {
        // ISO8601 date format: "2014-11-02T13:16:03Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        return dateString
    }
}


// MARK: - EA Identity Row

struct EAIdentityRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Theme.accent)

                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
            }

            content
                .padding()
                .background(Theme.cardBackground)
                .cornerRadius(12)
        }
    }
}

// MARK: - Color Scheme Button

struct ColorSchemeButton: View {
    let scheme: AppColorScheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(scheme.displayColor)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Theme.textPrimary : Color.clear, lineWidth: 3)
                                .padding(-4)
                        )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                            .background(
                                Circle()
                                    .fill(scheme.displayColor)
                                    .padding(6)
                            )
                    } else {
                        Image(systemName: scheme.iconName)
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                }

                Text(scheme.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EA Account Card

struct EAAccountCard: View {
    let account: StoredEAAccount
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Avatar
                PlayerAvatarView(
                    avatarUrl: account.avatarUrl,
                    size: 45
                )

                // Account Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(account.nickname ?? account.eaId)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.textPrimary)

                        if let platform = Platform(apiString: account.platform) {
                            PlatformIconView(platform: platform, size: 10)
                        }

                        if let status = account.status, status.lowercased() == "active" {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.bf6Green)
                                .font(.caption2)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("Last used:")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        Text(account.lastUsedFormatted)
                            .font(.caption2)
                            .foregroundColor(Theme.textPrimary)
                    }
                }

                Spacer()

                // Delete button
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                        .frame(width: 24, height: 24)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Delete this account")
            }

            Divider()

            // Identity details (collapsible)
            VStack(spacing: 6) {
                EAIdentityRow(label: "EA ID", value: account.eaId)
                EAIdentityRow(label: "Nucleus ID", value: account.nucleusId)
                EAIdentityRow(label: "Persona ID", value: account.personaId)

                if let platform = account.platform {
                    EAIdentityRow(label: "Platform", value: platform.capitalized)
                }

                if let subscription = account.subscriptionLevel, !subscription.isEmpty, subscription.lowercased() != "nenhum" {
                    EAIdentityRow(label: "Subscription", value: subscription)
                }

                if let createdAt = account.createdAt {
                    EAIdentityRow(label: "Created", value: formatAccountDate(createdAt))
                }
            }
        }
        .padding(12)
        .background(Theme.overlayColor.opacity(0.5))
        .cornerRadius(10)
    }

    private func formatAccountDate(_ dateString: String) -> String {
        // ISO8601 date format: "2014-11-02T13:16:03Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        return dateString
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(StatsViewModel())
}
