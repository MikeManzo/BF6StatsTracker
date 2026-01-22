//
// This file is part of BF6StatsTracker.
//
// BF6StatsTracker is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 or later.
//
// Copyright (c) 2026 CitizenCoder
//

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

    // Use @Query to automatically handle object lifecycle
    @Query(sort: \StatsSnapshot.timestamp, order: .reverse)
    private var allSnapshots: [StatsSnapshot]

    @State private var autoRefresh: Bool = true
    @State private var refreshInterval: Double = 300
    @State private var showNotifications: Bool = true
    @State private var compactMode: Bool = false
    @State private var selectedColorScheme: AppColorScheme = .orange
    @State private var debugMode: Bool = false
    @State private var playSoundOnSnapshot: Bool = true
    @State private var menuBarOnlyMode: Bool = false
    @State private var appearanceMode: AppearanceMode = .auto
    @State private var showClearHistoryConfirmation = false
    @State private var accountToDelete: StoredEAAccount?
    @State private var showDeleteAccountAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Save Button
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                // macOS-style Save Button
                Button {
                    saveSettings()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                        Text("Save")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Save settings and close")

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Close without saving")
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

                    // Appearance Settings
                    SettingsSection(title: "Appearance", icon: "paintpalette.fill") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose your preferred appearance mode")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)

                            HStack(spacing: 12) {
                                ForEach(AppearanceMode.allCases) { mode in
                                    AppearanceModeButton(
                                        mode: mode,
                                        isSelected: appearanceMode == mode
                                    ) {
                                        appearanceMode = mode
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

                            HStack {
                                Toggle("Compact Mode", isOn: $compactMode)
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                                
                                Toggle("Show Notifications", isOn: $showNotifications)
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                                                        
                            Toggle("Play Sound on when new data is available", isOn: $playSoundOnSnapshot)
                                .foregroundColor(Theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                        }
                    }

                    // Menubar Settings
                    SettingsSection(title: "Menu Bar", icon: "menubar.rectangle") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Menu Bar Only Mode", isOn: $menuBarOnlyMode)
                                .foregroundColor(Theme.textPrimary)

                            Text("Hides the desktop icon and runs the app exclusively in the menu bar. You can still access the main window from the menu bar icon.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)

                            if menuBarOnlyMode {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(Theme.bf6Orange)
                                        .font(.caption)

                                    Text("App will restart to apply this change")
                                        .font(.caption)
                                        .foregroundColor(Theme.bf6Orange)
                                }
                                .padding(8)
                                .background(Theme.bf6Orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                    
                    SettingsSection(title: "Debug Options", icon: "ladybug.slash") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Debug Mode (Synthetic Snapshots)", isOn: $debugMode)
                                .foregroundColor(Theme.textPrimary)

                            Text("Used for testing snapshots")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 800)
        .background(Theme.backgroundPrimary)
        .onAppear {
            loadCurrentSettings()
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
        selectedColorScheme = viewModel.settings.selectedColorScheme
        debugMode = viewModel.settings.debugMode
        playSoundOnSnapshot = viewModel.settings.playSoundOnSnapshot
        menuBarOnlyMode = viewModel.settings.menuBarOnlyMode
        appearanceMode = viewModel.settings.appearanceMode
        Theme.setAccentScheme(selectedColorScheme)
    }

    private func saveSettings() {
        let previousMenuBarOnlyMode = viewModel.settings.menuBarOnlyMode

        viewModel.settings.autoRefresh = autoRefresh
        viewModel.settings.refreshInterval = refreshInterval
        viewModel.settings.showNotifications = showNotifications
        viewModel.settings.compactMode = compactMode
        viewModel.settings.selectedColorScheme = selectedColorScheme
        viewModel.settings.debugMode = debugMode
        viewModel.settings.playSoundOnSnapshot = playSoundOnSnapshot
        viewModel.settings.menuBarOnlyMode = menuBarOnlyMode
        viewModel.settings.appearanceMode = appearanceMode
        Theme.setAccentScheme(selectedColorScheme)

        Task {
            await viewModel.saveSettings()
            await MainActor.run {
                dismiss()

                // If menu bar only mode changed, restart the app to apply the change
                if previousMenuBarOnlyMode != menuBarOnlyMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        restartApplication()
                    }
                }
            }
        }
    }

    private func restartApplication() {
        guard let bundleURL = Bundle.main.bundleURL as URL? else {
            logError("Failed to get bundle URL for restart", category: .error)
            return
        }

        // Create a configuration for launching
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true

        // Launch the app
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { app, error in
            if let error = error {
                logError("Failed to relaunch app: \(error)", category: .error)
            } else {
                // Terminate this instance after successfully launching new one
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private func getHistoricalDataSummary() -> String {
        let snapshots = allSnapshots.count
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
            do {
                // Delete all daily performances first (they reference snapshots)
                let dailyPerfDescriptor = FetchDescriptor<DailyPerformance>()
                let allDailyPerf = try context.fetch(dailyPerfDescriptor)
                allDailyPerf.forEach { context.delete($0) }

                // Delete all sessions (they reference snapshots)
                let sessionDescriptor = FetchDescriptor<PlaySession>()
                let allSessions = try context.fetch(sessionDescriptor)
                allSessions.forEach { context.delete($0) }

                // Delete all snapshots
                let snapshotDescriptor = FetchDescriptor<StatsSnapshot>()
                let allSnapshots = try context.fetch(snapshotDescriptor)
                allSnapshots.forEach { context.delete($0) }
            } catch {
                logWarning("Error clearing historical data: \(error)", category: .general)
                // Reset the cleanup flag so it runs again on next launch
                UserDefaults.standard.set(false, forKey: "HasCleanedCorruptDailyPerformance_v1")
            }

            // Save deletions
            try? context.save()

            // Reload empty data
            HistoryManager.shared.loadRecentData()
        }

        // Clear map statistics
        MapTracker.shared.clearMapStats(playerName: playerName, platform: platform.rawValue)

        logInfo("Historical data cleared successfully", category: .cleanup)

        // Immediately refresh stats to create a new snapshot
        Task {
            await viewModel.forceRefreshStats()
            logInfo("Stats refreshed after clearing history", category: .retry)
        }
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

// MARK: - Appearance Mode Button

struct AppearanceModeButton: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Image representation
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.cardBackground)
                        .frame(width: 120, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Theme.accent : Theme.borderColor, lineWidth: isSelected ? 3 : 1)
                        )

                    // Mode-specific preview
                    modePreview
                }

                // Label
                Text(mode.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var modePreview: some View {
        switch mode {
        case .light:
            // Light mode preview
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white)
                    .frame(height: 50)
                    .overlay(
                        VStack {
                            HStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                Spacer()
                            }
                            .padding(6)
                            Spacer()
                        }
                    )

                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 30)
            }
            .cornerRadius(8)
            .frame(width: 100, height: 60)
            .overlay(
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
            )

        case .dark:
            // Dark mode preview
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color(white: 0.15))
                    .frame(height: 50)
                    .overlay(
                        VStack {
                            HStack {
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                Spacer()
                            }
                            .padding(6)
                            Spacer()
                        }
                    )

                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 30)
            }
            .cornerRadius(8)
            .frame(width: 100, height: 60)
            .overlay(
                Image(systemName: "moon.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            )

        case .auto:
            // Auto mode preview - split light/dark
            HStack(spacing: 0) {
                // Light half
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 50)

                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 30)
                }

                // Dark half
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .frame(height: 50)

                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 30)
                }
            }
            .cornerRadius(8)
            .frame(width: 100, height: 60)
            .overlay(
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundColor(.purple)
                    .font(.title3)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(StatsViewModel())
}
