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
//  MenuBarView.swift
//  BF6StatsTracker
//
//  Menu bar extra view for quick stats access
//

import SwiftUI

struct MenuBarView: View {
    @Environment(\.accentColor) private var accentColor
    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var viewModel: StatsViewModel

    private var usesGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }

    var body: some View {
        GlassContainerWrapper(usesGlass: usesGlass) {
        VStack(spacing: 0) {
            if viewModel.hasPlayerData, let stats = viewModel.playerStats {
                // Player Header
                playerHeader(stats: stats)

                Divider()
                    .padding(.vertical, 8)

                // Quick Stats
                quickStatsSection(stats: stats)

                Divider()
                    .padding(.vertical, 8)

                // Top Class
                if let topClass = viewModel.topClass {
                    topClassSection(classStats: topClass)

                    Divider()
                        .padding(.vertical, 8)
                }

                // Actions
                actionsSection
            } else {
                noDataView
            }
        }
        .padding()
        .frame(width: 300)
        }
    }
    
    // MARK: - Player Header

    private func playerHeader(stats: PlayerStats) -> some View {
        HStack(spacing: 12) {
            // Player Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(stats.userName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    PlatformIconView(size: 12)
                }

                // XP and Rank Info
                if let xpArray = stats.xpData, let xp = xpArray.first {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.warning)
                        Text("\(formatXP(xp.total)) XP")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.textPrimary)
                        
                        // Rank badge
                        if let profileData = viewModel.profileData, let rank = profileData.rank {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                            
                            Image(systemName: "shield.fill")
                                .font(.caption2)
                                .foregroundColor(accentColor)
                            Text("Rank \(rank)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text("\(viewModel.formattedPlayTime) played")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Last Updated
            VStack(alignment: .trailing, spacing: 2) {
                Circle()
                    .fill(viewModel.isLoading ? Theme.warning : Theme.success)
                    .frame(width: 8, height: 8)

                Text(viewModel.formatTimeAgo(viewModel.lastUpdated))
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            .help(viewModel.isLoading ? "Updating stats..." : "Last updated: \(viewModel.lastUpdated?.formatted(date: .abbreviated, time: .shortened) ?? "Never")")
        }
    }
    
    // MARK: - Quick Stats Section

    private func quickStatsSection(stats: PlayerStats) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("Quick Stats")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textSecondary)

                Spacer()
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                MenuBarStatItem(
                    icon: "target",
                    label: "Kills",
                    value: stats.kills.formatted(),
                    color: Theme.bf6Red,
                    tooltip: "Total eliminations across all matches"
                )

                MenuBarStatItem(
                    icon: "xmark.circle",
                    label: "Deaths",
                    value: stats.deaths.formatted(),
                    color: Theme.textSecondary,
                    tooltip: "Total deaths across all matches"
                )

                MenuBarStatItem(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "K/D Ratio",
                    value: String(format: "%.2f", stats.kdRatio),
                    color: stats.kdRatio >= 1 ? Theme.bf6Green : accentColor,
                    tooltip: "Kill/Death ratio - higher is better"
                )

                MenuBarStatItem(
                    icon: "trophy.fill",
                    label: "Wins",
                    value: stats.wins.formatted(),
                    color: Theme.warning,
                    tooltip: "Total matches won"
                )

                MenuBarStatItem(
                    icon: "scope",
                    label: "Accuracy",
                    value: String(format: "%.1f%%", stats.accuracy),
                    color: Theme.bf6Blue,
                    tooltip: "Overall shooting accuracy"
                )

                MenuBarStatItem(
                    icon: "clock.fill",
                    label: "Time Played",
                    value: viewModel.formattedPlayTime,
                    color: Theme.bf6Purple,
                    tooltip: "Total time spent in matches"
                )
            }

            // XP Breakdown (if available)
            if let xpArray = stats.xpData, let xp = xpArray.first {
                VStack(spacing: 4) {
                    HStack {
                        Text("Experience Breakdown")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        MenuBarStatItem(
                            icon: "target",
                            label: "Performance",
                            value: formatXP(xp.performance),
                            color: Theme.bf6Blue,
                            tooltip: "XP earned from combat performance"
                        )

                        MenuBarStatItem(
                            icon: "trophy.fill",
                            label: "Accolades",
                            value: formatXP(xp.accolades),
                            color: accentColor,
                            tooltip: "XP earned from accolades and achievements"
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Top Class Section

    private func topClassSection(classStats: ClassStats) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Most Played Class")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textSecondary)

                Spacer()
            }

            HStack(spacing: 12) {
                ClassIconView(
                    className: BF6Class(rawValue: classStats.className) ?? .assault,
                    size: 36
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(classStats.className)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)

                    HStack(spacing: 8) {
                        Text("\(classStats.kills) kills")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        Text("•")
                            .foregroundColor(Theme.textSecondary)

                        Text("\(classStats.timePlayed / 3600)h played")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                Spacer()

                Text(String(format: "%.2f", classStats.kdRatio))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(classStats.kdRatio >= 1 ? Theme.bf6Green : accentColor)
            }
            .padding(10)
            .background(usesGlass ? Color.clear : Theme.overlayColor)
            .cornerRadius(10)
            .modifier(SubTabGlassModifier(
                isSelected: true,
                accentColor: accentColor.opacity(0.4),
                usesGlass: usesGlass
            ))
            .help("Your most played class with its K/D ratio")
        }
    }
    
    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 8) {
            // Refresh Button
            Button {
                Task {
                    await viewModel.forceRefreshStats()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(viewModel.isLoading ? "Refreshing..." : "Refresh Stats")
                }
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(usesGlass ? Color.clear : Theme.bf6Blue.opacity(0.2))
                .cornerRadius(8)
                .modifier(SubTabGlassModifier(
                    isSelected: true,
                    accentColor: Theme.bf6Blue.opacity(0.4),
                    usesGlass: usesGlass
                ))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .help("Fetch latest stats from EA servers")

            // Open Main Window Button
            Button {
                openMainWindow()
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open Full Stats")
                }
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(usesGlass ? Color.clear : Theme.overlayColor)
                .cornerRadius(8)
                .modifier(SubTabGlassModifier(
                    isSelected: true,
                    accentColor: accentColor.opacity(0.4),
                    usesGlass: usesGlass
                ))
            }
            .buttonStyle(.plain)
            .help("Open the main application window with detailed stats")

            Divider()

            // Menu Bar Mode Toggle
            MenuBarModeToggle(viewModel: viewModel)

            Divider()

            // Quit Button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                }
                .font(.subheadline)
                .foregroundColor(Theme.bf6Red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Quit BF6 Stats Tracker")
        }
    }
    
    // MARK: - No Data View

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)

            Text("No Player Data")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            Text("Search for a player to view stats")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                openMainWindow()
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Search Player")
                }
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(usesGlass ? Color.clear : Theme.bf6Blue)
                .cornerRadius(8)
                .modifier(SubTabGlassModifier(
                    isSelected: true,
                    accentColor: Theme.bf6Blue,
                    usesGlass: usesGlass
                ))
            }
            .buttonStyle(.plain)
            .help("Open the main window to search for a player")

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.subheadline)
                    .foregroundColor(Theme.bf6Red)
            }
            .buttonStyle(.plain)
            .help("Quit BF6 Stats Tracker")
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Helpers

    private func openMainWindow() {
        // Check if we're in menu bar only mode
        let menuBarOnlyMode = UserDefaults.standard.bool(forKey: "menuBarOnlyMode")

        if menuBarOnlyMode {
            // User wants to use the full app, so disable menu bar only mode
            UserDefaults.standard.set(false, forKey: "menuBarOnlyMode")

            // Update the setting in the view model
            Task { @MainActor in
                viewModel.settings.menuBarOnlyMode = false
                await viewModel.saveSettings()
            }

            // Show the dock icon permanently
            NSApp.setActivationPolicy(.regular)

            logInfo("Disabled menu bar only mode - user opened full app", category: .general)
        }

        // First, try to find and show any existing hidden window
        var foundExistingWindow = false
        for window in NSApp.windows {
            let className = String(describing: type(of: window))
            
            // Look for the main content window (not status bar or menu bar windows)
            if className.contains("NSWindow") && 
               !className.contains("StatusBar") && 
               !className.contains("MenuBarExtra") &&
               window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                foundExistingWindow = true
                logInfo("Showing existing hidden window", category: .general)
                break
            }
        }
        
        // If no existing window found, create a new one using openWindow
        if !foundExistingWindow {
            logInfo("No existing window found - opening new window", category: .general)
            openWindow(id: "main")
        }
        
        // Activate the app to bring it to front
        NSApp.activate(ignoringOtherApps: true)
    }

    private func formatXP(_ xp: Int) -> String {
        if xp >= 1_000_000 {
            return String(format: "%.1fM", Double(xp) / 1_000_000.0)
        } else if xp >= 1_000 {
            return String(format: "%.1fK", Double(xp) / 1_000.0)
        } else {
            return "\(xp)"
        }
    }
}

// MARK: - Menu Bar Mode Toggle

struct MenuBarModeToggle: View {
    @Environment(\.accentColor) private var accentColor
    @ObservedObject var viewModel: StatsViewModel
    @State private var isMenuBarOnly: Bool = false
    @State private var isHovering: Bool = false
    @State private var isInitialized: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: isMenuBarOnly ? "menubar.rectangle" : "macwindow.badge.plus")
                .font(.subheadline)
                .foregroundColor(isMenuBarOnly ? accentColor : Theme.bf6Blue)
                .frame(width: 20)

            // Label and description
            VStack(alignment: .leading, spacing: 2) {
                Text("Menu Bar Only")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text(isMenuBarOnly ? "Enabled" : "Disabled")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            // Toggle Switch
            Toggle("", isOn: $isMenuBarOnly)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: accentColor))
                .scaleEffect(0.8)
                .onChange(of: isMenuBarOnly) { oldValue, newValue in
                    // Only handle changes after initialization to prevent restart loop
                    if isInitialized {
                        handleToggleChange(newValue)
                    }
                }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Theme.overlayColor.opacity(0.8) : Theme.overlayColor.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isMenuBarOnly ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .help(isMenuBarOnly ? "Disable to show dock icon and use full app" : "Enable to hide dock icon and use menu bar only")
        .onAppear {
            // Load current state without triggering onChange
            isMenuBarOnly = UserDefaults.standard.bool(forKey: "menuBarOnlyMode")
            // Mark as initialized after a brief delay to allow the view to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInitialized = true
            }
        }
    }

    private func handleToggleChange(_ newValue: Bool) {
        // Save to UserDefaults
        UserDefaults.standard.set(newValue, forKey: "menuBarOnlyMode")

        // Update view model
        Task { @MainActor in
            viewModel.settings.menuBarOnlyMode = newValue
            await viewModel.saveSettings()
        }

        if newValue {
            // Enabling menu bar only mode - need to restart
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                restartApplication()
            }
        } else {
            // Disabling menu bar only mode - show dock icon immediately
            NSApp.setActivationPolicy(.regular)
            logInfo("Disabled menu bar only mode", category: .general)
        }
    }

    private func restartApplication() {
        guard let bundleURL = Bundle.main.bundleURL as URL? else {
            logError("Failed to get bundle URL for restart", category: .error)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { app, error in
            if let error = error {
                logError("Failed to relaunch app: \(error)", category: .error)
            } else {
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}

// MARK: - Menu Bar Stat Item

struct MenuBarStatItem: View {
    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled

    let icon: String
    let label: String
    let value: String
    let color: Color
    var tooltip: String = ""

    private var usesGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)

                Text(label)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(8)
        .background(usesGlass ? Color.clear : Theme.overlayColor)
        .cornerRadius(8)
        .modifier(SubTabGlassModifier(
            isSelected: true,
            accentColor: color.opacity(0.4),
            usesGlass: usesGlass
        ))
        .help(tooltip.isEmpty ? label : tooltip)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environmentObject(StatsViewModel())
        .frame(width: 300)
}
