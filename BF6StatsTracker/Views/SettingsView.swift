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
    
    @State private var playerName: String = ""
    @State private var selectedPlatform: Platform = .pc
    @State private var autoRefresh: Bool = true
    @State private var refreshInterval: Double = 300
    @State private var showNotifications: Bool = true
    @State private var compactMode: Bool = false
    @State private var showEnhancedOverview: Bool = true
    @State private var selectedColorScheme: AppColorScheme = .orange
    @State private var showEALogin = false
    @State private var showClearHistoryConfirmation = false
    
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
                    SettingsSection(title: "EA Account", icon: "person.badge.key.fill") {
                        if viewModel.isEAAuthenticated {
                            // Logged in state
                            VStack(spacing: 12) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Theme.accent, Theme.bf6Red],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 40, height: 40)

                                        Image(systemName: "person.badge.key.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(viewModel.settings.eaId ?? "EA User")
                                                .font(.headline)
                                                .foregroundColor(Theme.textPrimary)

                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundColor(Theme.bf6Green)
                                                .font(.caption)
                                        }

                                        Text("EA Account Connected")
                                            .font(.caption)
                                            .foregroundColor(Theme.bf6Green)
                                    }

                                    Spacer()
                                }

                                Divider()

                                // Identity details
                                VStack(spacing: 8) {
                                    EAIdentityRow(label: "EA ID", value: viewModel.settings.eaId ?? "N/A")
                                    EAIdentityRow(label: "Nucleus ID", value: viewModel.settings.nucleusId ?? "N/A")
                                    EAIdentityRow(label: "Persona ID", value: viewModel.settings.personaId ?? "N/A")
                                }

                                Divider()

                                // Disconnect button
                                Button(role: .destructive) {
                                    viewModel.logout()
                                } label: {
                                    HStack {
                                        Image(systemName: "person.badge.minus")
                                        Text("Disconnect EA Account")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(Theme.bf6Red)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            // Not logged in state
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.circle")
                                        .foregroundColor(Theme.accent)

                                    Text("No EA Account Connected")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)

                                    Spacer()
                                }

                                Button {
                                    showEALogin = true
                                } label: {
                                    HStack {
                                        Image(systemName: "person.badge.key.fill")
                                        Text("Sign in with EA")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: [Theme.accent, Theme.bf6Red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)

                                Text("Connect your EA account to automatically detect your player name and get verified stats.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }

                    // Player Settings
                    SettingsSection(title: "Player", icon: "person.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            // Player Name
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Player Name")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)

                                TextField("Enter player name", text: $playerName)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(10)
                                    .background(Theme.overlayColor)
                                    .cornerRadius(8)
                            }

                            // Platform
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Platform")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)

                                Picker("Platform", selection: $selectedPlatform) {
                                    ForEach(Platform.allCases) { platform in
                                        HStack {
                                            PlatformIconView(platform: platform, size: 14)
                                            Text(platform.displayName)
                                        }
                                        .tag(platform)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                                Text("Version")
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("1.0.0")
                                    .foregroundColor(Theme.textPrimary)
                            }

                            HStack {
                                Text("API Provider")
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Link("GameTools.Network", destination: URL(string: "https://api.gametools.network")!)
                                    .foregroundColor(Theme.bf6Blue)
                            }

                            HStack {
                                Text("Game Data")
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("Battlefield 6")
                                    .foregroundColor(Theme.textPrimary)
                            }

                            Divider()

                            Text("This app uses the free GameTools.Network API to fetch player statistics. Images and assets are sourced from official EA/DICE CDNs.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
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
        .sheet(isPresented: $showEALogin) {
            EALoginView()
                .environmentObject(viewModel)
        }
        .alert("Clear Historical Data?", isPresented: $showClearHistoryConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All Data", role: .destructive) {
                clearHistoricalData()
            }
        } message: {
            Text("This will permanently delete all saved snapshots, play sessions, and map statistics. This action cannot be undone.\n\nAre you sure you want to continue?")
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentSettings() {
        playerName = viewModel.settings.playerName
        selectedPlatform = viewModel.settings.platform
        autoRefresh = viewModel.settings.autoRefresh
        refreshInterval = viewModel.settings.refreshInterval
        showNotifications = viewModel.settings.showNotifications
        compactMode = viewModel.settings.compactMode
        showEnhancedOverview = viewModel.settings.showEnhancedOverview
        selectedColorScheme = viewModel.settings.selectedColorScheme
        Theme.setAccentScheme(selectedColorScheme)
    }

    private func saveSettings() {
        viewModel.settings.playerName = playerName
        viewModel.settings.platform = selectedPlatform
        viewModel.settings.autoRefresh = autoRefresh
        viewModel.settings.refreshInterval = refreshInterval
        viewModel.settings.showNotifications = showNotifications
        viewModel.settings.compactMode = compactMode
        viewModel.settings.showEnhancedOverview = showEnhancedOverview
        viewModel.settings.selectedColorScheme = selectedColorScheme
        Theme.setAccentScheme(selectedColorScheme)

        Task {
            await viewModel.saveSettings()

            // Refresh if player changed
            if playerName != viewModel.playerStats?.userName {
                await viewModel.searchPlayer(name: playerName, platform: selectedPlatform)
            }
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

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(StatsViewModel())
}
