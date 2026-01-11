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
//  ContentView.swift
//  BF6StatsTracker
//
//  Main content view for the Battlefield 6 Stats Tracker
//

import SwiftUI
import EAIdentityKit

struct ContentView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @StateObject private var accountStore = EAAccountStore.shared
    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var showingEALogin = false
    @State private var showingAccountSelection = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Theme.backgroundPrimary,
                    Theme.backgroundSecondary
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if viewModel.isInitializing {
                loadingView
            } else if viewModel.hasPlayerData {
                mainContentView
            } else {
                welcomeView
            }
        }
        .sheet(isPresented: $showingSearch) {
            PlayerSearchView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingEALogin) {
            EALoginView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingAccountSelection) {
            AccountSelectionView()
                .environmentObject(viewModel)
        }
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Tab Bar
            tabBarView
            
            // Sub-menu navigation (if applicable)
            if let subTabs = viewModel.selectedMainTab.subTabs {
                subMenuView(subTabs: subTabs)
            }

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        switch viewModel.activeTab {
                        case .overview:
                            OverviewStatsView()
                        case .history:
                            SessionHistoryView()
                        case .maps:
                            MapStatsView()
                        case .charts:
                            PerformanceChartsView()
                        case .classes:
                            DraggableTileContainer()
                        case .weapons:
                            WeaponStatsView()
                        case .weaponMastery:
                            WeaponMasteryView()
                        case .gadgets:
                            GadgetStatsView()
                        case .utility:
                            UtilityEffectivenessView()
                        case .vehicleStats:
                            VehicleStatsView()
                        case .vehicleSpec:
                            VehicleSpecialistView()
                        case .support:
                            TeamSupportView()
                        case .intel:
                            IntelligenceView()
                        case .loadout:
                            LoadoutAnalyzerView()
                        case .xpCalculator:
                            XPCalculatorView()
                        case .modeEfficiency:
                            ModeEfficiencyView()
                        case .servers:
                            ServerBrowserView()
                        case .logViewer:
                            LogViewerView()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                    .id(viewModel.activeTab)
                }
                .padding()
                .animation(.easeInOut(duration: 0.25), value: viewModel.activeTab)
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // Player Info
            if let stats = viewModel.playerStats {
                HStack(spacing: 12) {
                    // Player Icon
                    PlayerAvatarView(
                        avatarUrl: EAAccountStore.shared.mostRecentAccount?.avatarUrl,
                        size: 50
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stats.userName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textPrimary)

                            PlatformIconView(size: 16)

                            // EA Verified badge
                            if viewModel.isEAAuthenticated {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                    .help("EA Account Verified")
                            }
                        }

                        // XP Breakdown
                        if let xpArray = stats.xpData, let xp = xpArray.first {
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text("\(formatXP(xp.total)) XP")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Theme.textPrimary)
                                        .help("XP Total")
                                }

                                Text("•")
                                    .foregroundColor(.secondary)

                                HStack(spacing: 4) {
                                    Image(systemName: "target")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    Text("\(formatXP(xp.performance))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .help("XP Performance")
                                }

                                HStack(spacing: 4) {
                                    Image(systemName: "trophy.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("\(formatXP(xp.accolades))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .help("XP Accolades")
                                }
                            }
                        } else {
                            Text("\(viewModel.formattedPlayTime) played")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Quick Stats
            if let stats = viewModel.playerStats {
                HStack(spacing: 20) {
                    QuickStatView(title: "K/D", value: String(format: "%.2f", stats.kdRatio), color: .green, trend: viewModel.kdTrend)
                    QuickStatView(title: "Kills", value: stats.kills.formatted(), color: .red, trend: viewModel.killsTrend)
                    QuickStatView(title: "W/L", value: String(format: "%.1f%%", stats.wlRatio), color: .blue, trend: viewModel.wlTrend)
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                // Cache indicator
                if let _ = viewModel.cacheAge {
                    Text(viewModel.formatCacheAge())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                
                // Refresh button
                Button {
                    Task {
                        await viewModel.forceRefreshStats()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(Theme.textPrimary)
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                        .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh stats (⌘R)")
                .accessibilityLabel("Refresh statistics")

                // Search button
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(Theme.textPrimary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("f", modifiers: .command)
                .help("Search player (⌘F)")
                .accessibilityLabel("Search for player")

                // Settings button
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(Theme.textPrimary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",", modifiers: .command)
                .help("Settings (⌘,)")
                .accessibilityLabel("Open settings")

                // Account switcher button (if multiple accounts exist)
                if accountStore.accounts.count > 1 {
                    Button {
                        showingAccountSelection = true
                    } label: {
                        Image(systemName: "person.2.fill")
                            .font(.title3)
                            .foregroundColor(Theme.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .help("Switch Account")
                }

                // Logout button
                Button(role: .destructive) {
                    viewModel.logout()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Theme.overlayColor)
    }
    
    // MARK: - Tab Bar View

    private var tabBarView: some View {
        HStack(spacing: 0) {
            ForEach(Array(MainTab.allCases.enumerated()), id: \.element) { index, tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.selectedMainTab = tab
                        // Set default sub-tab if applicable
                        viewModel.selectedSubTab = tab.defaultSubTab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)

                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(viewModel.selectedMainTab == tab ? Theme.textPrimary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        viewModel.selectedMainTab == tab ?
                        Theme.bf6Blue.opacity(0.3) :
                        Color.clear
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .if(index < 9) { view in
                    view
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                        .help("\(tab.rawValue) (⌘\(index + 1))")
                }
                .if(index >= 9) { view in
                    view.help(tab.rawValue)
                }
                .accessibilityLabel("\(tab.rawValue) tab")
                .accessibilityAddTraits(viewModel.selectedMainTab == tab ? [.isSelected] : [])
            }
        }
        .background(Theme.overlayColor)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation tabs")
    }

    // MARK: - Sub-Menu View

    private func subMenuView(subTabs: [StatTab]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(subTabs, id: \.self) { subTab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedSubTab = subTab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: subTab.icon)
                                .font(.body)

                            Text(subTab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(viewModel.selectedSubTab == subTab ? Theme.textPrimary : .secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.selectedSubTab == subTab ?
                            Theme.bf6Orange.opacity(0.3) :
                            Color.clear
                        )
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(subTab.rawValue) sub-tab")
                    .accessibilityAddTraits(viewModel.selectedSubTab == subTab ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.overlayColor.opacity(0.5))
        .frame(height: 52)
    }
    
    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.bf6Orange))

            Text("Loading...")
                .font(.title3)
                .foregroundColor(Theme.textPrimary)
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 30) {
            // Logo/Icon
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 10) {
                Text("BF6 Stats Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                Text("Track your Battlefield 6 statistics in real-time")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "person.badge.key.fill", text: "EA Account integration")
                FeatureRow(icon: "person.3.fill", text: "All 4 classes with detailed stats")
                FeatureRow(icon: "scope", text: "45+ weapons tracking")
                FeatureRow(icon: "car.fill", text: "8 vehicle categories")
                FeatureRow(icon: "wrench.and.screwdriver.fill", text: "Gadget performance")
                FeatureRow(icon: "clock.arrow.circlepath", text: "Auto-refresh every 5 minutes")
            }
            .padding(30)
            .background(Theme.overlayColor)
            .cornerRadius(16)

            // Action buttons
            VStack(spacing: 16) {
                // Show account selection if accounts exist, otherwise EA Login
                if !accountStore.accounts.isEmpty {
                    // Account Selection Button (Primary)
                    Button {
                        showingAccountSelection = true
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("Choose Saved Account")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.selectedText)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .frame(minWidth: 280)
                        .background(
                            LinearGradient(
                                colors: [Theme.bf6Orange, Theme.bf6Red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Text("or")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // EA Login Button (Secondary)
                    Button {
                        showingEALogin = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                            Text("Sign in with different account")
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.selectedText)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .frame(minWidth: 280)
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
                } else {
                    // EA Login Button (Primary)
                    Button {
                        showingEALogin = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                            Text("Sign in with EA")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.selectedText)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .frame(minWidth: 280)
                        .background(
                            LinearGradient(
                                colors: [Theme.bf6Orange, Theme.bf6Red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Text("or")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Manual Search Button (Secondary)
                    Button {
                        showingSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search Player Manually")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.selectedText)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .frame(minWidth: 280)
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
            }

            // Info text
            VStack(spacing: 4) {
                Text("Powered by GameTools.Network API")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("EA Identity via EAIdentityKit")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(40)
    }

    // MARK: - Helper Functions

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

// MARK: - Quick Stat View

struct QuickStatView: View {
    let title: String
    let value: String
    let color: Color
    var trend: TrendDirection? = nil

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(color)

                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.caption)
                        .foregroundColor(trend.color)
                }
            }

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.bf6Orange)
                .frame(width: 30)

            Text(text)
                .font(.body)
                .foregroundColor(Theme.textPrimary)
        }
    }
}

// MARK: - Player Avatar View

struct PlayerAvatarView: View {
    let avatarUrl: String?
    let size: CGFloat

    @State private var avatarImage: NSImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            if let avatarImage = avatarImage {
                Image(nsImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.black)
            }
        }
        .task {
            await loadAvatar()
        }
    }

    private func loadAvatar() async {
        guard let avatarUrl = avatarUrl,
              let url = URL(string: avatarUrl),
              !isLoading else {
            return
        }

        isLoading = true

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                await MainActor.run {
                    self.avatarImage = image
                }
            }
        } catch {
            logError("Failed to load avatar: \(error.localizedDescription)", category: .error)
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(StatsViewModel())
        .frame(width: 1200, height: 800)
}
