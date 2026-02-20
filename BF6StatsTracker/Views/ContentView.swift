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

struct ContentView: View {
    @Environment(\.accentColor) private var accentColor
    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled
    @EnvironmentObject var viewModel: StatsViewModel

    /// True when running on macOS 26+ AND the user has the toggle on.
    private var usesLiquidGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }
    @StateObject private var accountStore = EAAccountStore.shared
    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var showingEALogin = false
    @State private var showingAccountSelection = false
    @State private var showingXPBreakdown = false
    @State private var showingRankDetail = false

    var body: some View {
        ZStack {
            // Background gradient — extends under chrome bars via backgroundExtensionEffect on macOS 26+
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
    
    /// The scrollable content area shared by both layout paths.
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                Group {
                    switch viewModel.activeTab {
                    case .overview:
                        OverviewStatsView()
                    case .history:
                        SessionHistoryView()
                    case .squad:
                        SquadComparisonView()
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
                    case .modeEfficiency:
                        ModeEfficiencyView()
                    case .servers:
                        ServerBrowserView()
                    case .logViewer:
                        LogViewerView()
                    case .aiCoach:
                        AICoachView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            }
            .padding()
            .animation(.easeInOut(duration: 0.25), value: viewModel.activeTab)
        }
    }

    /// The chrome (header + tabs + optional sub-menu) shared by both layout paths.
    private var chromeView: some View {
        VStack(spacing: 0) {
            headerView
            tabBarView
            if let subTabs = viewModel.selectedMainTab.subTabs {
                subMenuView(subTabs: subTabs)
            }
        }
        .conditionalBackground(apply: usesLiquidGlass)
    }

    @ViewBuilder
    private var mainContentView: some View {
        if #available(macOS 26, *), usesLiquidGlass {
            // Glass path: content scrolls under the glass chrome bars.
            // safeAreaBar places chromeView at the top and insets the scroll
            // content by its height, so content scrolls underneath the bars.
            // scrollEdgeEffectStyle adds the frosted pocket at the scroll edge.
            scrollContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollEdgeEffectStyle(.automatic, for: .top)
                .safeAreaBar(edge: .top, spacing: 0) {
                    chromeView
                }
        } else {
            // Legacy path: chrome stacked above content in a VStack
            VStack(spacing: 0) {
                chromeView
                scrollContent
            }
        }
    }
    
    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 20) {
            // LEADING SECTION: Player Identity
            playerIdentitySection

            Spacer()

            // CENTER SECTION: Quick Stats
            if let stats = viewModel.playerStats {
                quickStatsSection(stats: stats)
            }

            Spacer()

            // TRAILING SECTION: Actions Toolbar
            actionsToolbarSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(height: 76)
        .conditionalBackground(apply: !usesLiquidGlass)
        .overlay(alignment: .bottom) {
            if !usesLiquidGlass {
                Divider()
            }
        }
    }

    // MARK: - Player Identity Section

    private var playerIdentitySection: some View {
        HStack(spacing: 12) {
            if let stats = viewModel.playerStats {
                // Avatar with EA badge overlay
                ZStack(alignment: .bottomTrailing) {
                    PlayerAvatarView(
                        avatarUrl: EAAccountStore.shared.mostRecentAccount?.avatarUrl,
                        size: 44
                    )

                    if viewModel.isEAAuthenticated {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.success)
                            .background(
                                Circle()
                                    .fill(Theme.selectedText)
                                    .frame(width: 16, height: 16)
                            )
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Name and platform
                    HStack(spacing: 6) {
                        Text(stats.userName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        PlatformIconView(size: 14)
                    }

                    // Total XP - clickable to show XP breakdown, with rank badge to the right
                    if let xpArray = stats.xpData, let xp = xpArray.first {
                        HStack(spacing: 6) {
                            Button {
                                showingXPBreakdown.toggle()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(Theme.warning)

                                    Text("\(formatXP(xp.total)) XP")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Click to view XP breakdown")
                            .popover(isPresented: $showingXPBreakdown) {
                                xpBreakdownPopover
                            }
                            
                            // Rank badge to the right of XP button
                            if let profileData = viewModel.profileData, let rank = profileData.rank {
                                Button {
                                    showingRankDetail.toggle()
                                } label: {
                                    HStack(spacing: 4) {
                                        // Rank image from profile data if available
                                        if let rankImgUrl = profileData.rankImg,
                                           let url = URL(string: rankImgUrl) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                case .failure(_):
                                                    Image(systemName: "star.circle.fill")
                                                        .foregroundColor(Theme.warning)
                                                case .empty:
                                                    ProgressView()
                                                        .scaleEffect(0.5)
                                                @unknown default:
                                                    Image(systemName: "star.circle.fill")
                                                        .foregroundColor(Theme.warning)
                                                }
                                            }
                                            .frame(width: 16, height: 16)
                                        } else {
                                            // Fallback to icon if no image available
                                            Image(systemName: "star.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(Theme.warning)
                                        }
                                        
                                        Text("Rank \(rank)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.cardBackground.opacity(0.5))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                .help("Click to view rank details")
                                .popover(isPresented: $showingRankDetail) {
                                    rankDetailPopover
                                }
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Player information")
    }

    // MARK: - XP Breakdown Popover

    private var xpBreakdownPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let stats = viewModel.playerStats,
               let xpArray = stats.xpData,
               let xp = xpArray.first {

                Text("Experience Breakdown")
                    .font(.headline)
                    .foregroundColor(.primary)

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Theme.warning)
                    Text("\(formatXP(xp.total)) Total XP")
                        .font(.body)
                        .foregroundColor(Theme.textPrimary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .foregroundColor(Theme.info)
                    Text("\(formatXP(xp.performance)) Performance")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(Theme.warning)
                    Text("\(formatXP(xp.accolades)) Accolades")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Divider()
                
                // Badges count from profile data
                if let profileData = viewModel.profileData, let badges = profileData.badges {
                    HStack(spacing: 8) {
                        Image(systemName: "medal.fill")
                            .foregroundColor(Theme.success)
                        Text("\(badges) Badges")
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 220)
    }
    
    // MARK: - Rank Detail Popover
    
    private var rankDetailPopover: some View {
        VStack(spacing: 12) {
            if let profileData = viewModel.profileData, 
               let rank = profileData.rank,
               let largeRankImgUrl = profileData.playerCard?.rankImage?.large,
               let url = URL(string: largeRankImgUrl) {
                
                Text("Rank \(rank)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Divider()
                
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 150, height: 150)
                    case .failure(_):
                        VStack {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(Theme.warning)
                            Text("Unable to load rank image")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    case .empty:
                        ProgressView()
                            .frame(width: 150, height: 150)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 220, height: 250)
    }

    // MARK: - Quick Stats Section

    private func quickStatsSection(stats: PlayerStats) -> some View {
        HStack(spacing: 20) {
            CleanStatCard(
                value: String(format: "%.2f", stats.kdRatio),
                label: "KILLS / DEATH",
                color: .green,
                trend: viewModel.kdTrend
            ).help("All-Time Kills / Death Ratio")

            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1, height: 40)

            CleanStatCard(
                value: formatKills(stats.kills),
                label: "KILLS",
                color: .orange,
                trend: viewModel.killsTrend
            ).help("All-Time Kills")

            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1, height: 40)

            CleanStatCard(
                value: formatKills(stats.assists),
                label: "ASSISTS",
                color: .purple,
                trend: viewModel.assistsTrend
            ).help("All-Time Assists")

            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1, height: 40)

            CleanStatCard(
                value: String(format: "%.1f%%", stats.wlRatio),
                label: "WIN RATE",
                color: .blue,
                trend: viewModel.wlTrend
            ).help("All-Time Win Rate")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick statistics")
    }

    // MARK: - Actions Toolbar Section

    private var actionsToolbarSection: some View {
        HStack(spacing: 12) {
            // Primary action group - toolbar style
            HStack(spacing: 8) {
                ToolbarButton(
                    icon: "arrow.clockwise",
                    tooltip: "Refresh stats (⌘R)",
                    isLoading: viewModel.isLoading,
                    buttonColor: viewModel.refreshButtonColor,
                    shouldPulsate: viewModel.shouldPulsateRefreshButton
                ) {
                    Task {
                        await viewModel.forceRefreshStats()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(viewModel.isLoading)

                Divider()
                    .frame(height: 20)

                ToolbarButton(
                    icon: "magnifyingglass",
                    tooltip: "Search player (⌘F)"
                ) {
                    showingSearch = true
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()
                    .frame(height: 20)

                ToolbarButton(
                    icon: "gearshape",
                    tooltip: "Settings (⌘,)"
                ) {
                    showingSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            .padding(4)
            .background(usesLiquidGlass ? .clear : Color.secondary.opacity(0.08))
            .cornerRadius(7)
            .modifier(ToolbarGroupGlassModifier(usesGlass: usesLiquidGlass))

            // Secondary actions menu
            Menu {
                if accountStore.accounts.count > 1 {
                    Button {
                        showingAccountSelection = true
                    } label: {
                        Label("Switch Account", systemImage: "person.2.fill")
                    }

                    Divider()
                }

                Button(role: .destructive) {
                    viewModel.logout()
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .help("More options")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Action buttons")
    }
    
    // MARK: - Tab Bar View

    private var tabBarView: some View {
        GlassContainerWrapper(usesGlass: usesLiquidGlass) {
            HStack(spacing: 0) {
                ForEach(Array(viewModel.visibleMainTabs.enumerated()), id: \.element) { index, tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectedMainTab = tab
                            // Set default sub-tab if applicable
                            viewModel.selectedSubTab = tab.defaultSubTab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: tab.icon)
                                    .font(.title3)

                                // Experimental badge
                                if tab.isExperimental {
                                    Circle()
                                        .fill(Theme.bf6Purple)
                                        .frame(width: 6, height: 6)
                                        .offset(x: 2, y: -2)
                                }
                            }

                            Text(tab.rawValue)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(viewModel.selectedMainTab == tab ? Theme.textPrimary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            viewModel.selectedMainTab == tab && !usesLiquidGlass ?
                            (tab.isExperimental ? Theme.bf6Purple.opacity(0.3) : Theme.bf6Blue.opacity(0.3)) :
                            Color.clear
                        )
                        .modifier(TabGlassModifier(
                            isSelected: viewModel.selectedMainTab == tab,
                            isExperimental: tab.isExperimental,
                            usesGlass: usesLiquidGlass
                        ))
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
                    .contextMenu {
                        Button("Hide Tab") {
                            hideTab(tab)
                        }
                    }
                    .onDrag {
                        NSItemProvider(object: tab.rawValue as NSString)
                    }
                    .onDrop(of: [.text], delegate: TabDropDelegate(
                        tab: tab,
                        tabs: viewModel.visibleMainTabs,
                        onMove: { from, to in
                            moveTab(from: from, to: to)
                        }
                    ))
                }
            }
        }
        .conditionalBackground(apply: !usesLiquidGlass)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation tabs")
    }
    
    private func hideTab(_ tab: MainTab) {
        viewModel.settings.hiddenTabs.insert(tab.rawValue)
        Task {
            await viewModel.saveSettings()
        }
        
        // If the current tab is being hidden, switch to the first visible tab
        if viewModel.selectedMainTab == tab {
            if let firstVisible = viewModel.visibleMainTabs.first {
                withAnimation {
                    viewModel.selectedMainTab = firstVisible
                    viewModel.selectedSubTab = firstVisible.defaultSubTab
                }
            }
        }
    }
    
    private func moveTab(from source: MainTab, to destination: MainTab) {
        let allTabs = MainTab.allCases.map { $0.rawValue }
        
        // Initialize tabOrder if it's empty
        if viewModel.settings.tabOrder.isEmpty {
            viewModel.settings.tabOrder = allTabs
        }
        
        guard let sourceIndex = viewModel.settings.tabOrder.firstIndex(of: source.rawValue),
              let destIndex = viewModel.settings.tabOrder.firstIndex(of: destination.rawValue) else {
            return
        }
        
        withAnimation {
            viewModel.settings.tabOrder.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destIndex > sourceIndex ? destIndex + 1 : destIndex)
        }
        
        Task {
            await viewModel.saveSettings()
        }
    }

    // MARK: - Sub-Menu View

    private func subMenuView(subTabs: [StatTab]) -> some View {
        GlassContainerWrapper(usesGlass: usesLiquidGlass) {
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
                                viewModel.selectedSubTab == subTab && !usesLiquidGlass ?
                                accentColor.opacity(0.3) :
                                Color.clear
                            )
                            .modifier(SubTabGlassModifier(
                                isSelected: viewModel.selectedSubTab == subTab,
                                accentColor: accentColor,
                                usesGlass: usesLiquidGlass
                            ))
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
        }
        .conditionalBackground(apply: !usesLiquidGlass)
        .frame(height: 52)
    }
    
    // MARK: - Loading View

    @State private var rotationAngle: Double = 0
    @State private var isPulsing: Bool = false

    private var loadingView: some View {
        VStack(spacing: 32) {
            ZStack {
                // Background pulse circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(accentColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale(for: index))
                        .opacity(pulseOpacity(for: index))
                }

                // Center icon
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColor, Theme.bf6Red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(rotationAngle))
            }
            .frame(height: 200)

            VStack(spacing: 12) {
                Text("Loading Stats")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                Text("Preparing your battlefield data...")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private func pulseScale(for index: Int) -> CGFloat {
        let baseScale: CGFloat = 1.0 + (CGFloat(index) * 0.3)
        return isPulsing ? baseScale + 0.2 : baseScale
    }

    private func pulseOpacity(for index: Int) -> Double {
        let _ = Double(index) * 0.2  // Delay calculation for future animation use
        return isPulsing ? 0.0 : 0.6
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
                    .foregroundColor(Theme.textSecondary)
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
                                colors: [accentColor, Theme.bf6Red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Text("or")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

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
                                colors: [accentColor, Theme.bf6Red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Text("or")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

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
                    .foregroundColor(Theme.textSecondary)
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

    private func formatKills(_ kills: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: kills)) ?? "\(kills)"
    }
}

// MARK: - Clean Stat Card

struct CleanStatCard: View {
    let value: String
    let label: String
    let color: Color
    var trend: TrendDirection? = nil

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(color)

                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.caption2)
                        .foregroundColor(trend.color)
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .textCase(.uppercase)
        }
        .frame(minWidth: 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled
    let icon: String
    let tooltip: String
    var isLoading: Bool = false
    var buttonColor: Color? = nil
    var shouldPulsate: Bool = false
    let action: () -> Void

    /// True when running on macOS 26+ AND the user has the toggle on.
    private var usesLiquidGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulsating background circle — always show when needed to alert user of upcoming refresh
                if shouldPulsate {
                    PulsatingCircle(color: buttonColor ?? .primary)
                        .frame(width: 28, height: 28)
                }

                // Icon with color progression (green -> yellow -> red)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(buttonColor ?? .primary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
            }
        }
        .modifier(ToolbarGlassButtonStyle(usesGlass: usesLiquidGlass))
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
}

/// Applies .glass buttonStyle on macOS 26+; falls back to .plain on older OS.
struct ToolbarGlassButtonStyle: ViewModifier {
    let usesGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), usesGlass {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.plain)
        }
    }
}

struct ToolbarGroupGlassModifier: ViewModifier {
    let usesGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), usesGlass {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 7))
        } else {
            content
        }
    }
}

// MARK: - Pulsating Circle (Core Animation)

struct PulsatingCircle: NSViewRepresentable {
    let color: Color

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true

        let shapeLayer = CAShapeLayer()
        let size: CGFloat = 28
        let circlePath = NSBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size))
        shapeLayer.path = circlePath.cgPath
        shapeLayer.fillColor = NSColor(color).withAlphaComponent(0.4).cgColor
        shapeLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)

        // Core Animation - runs entirely on GPU
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.4
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        shapeLayer.add(pulseAnimation, forKey: "pulse")

        view.layer?.addSublayer(shapeLayer)

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed - animation is continuous
    }
}

// MARK: - NSBezierPath to CGPath Extension

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            default:
                break
            }
        }

        return path
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    @Environment(\.accentColor) private var accentColor

    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(accentColor)
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
                    .foregroundColor(Theme.textPrimary)
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

// MARK: - Conditional ultraThinMaterial background

// MARK: - Tab Drop Delegate

struct TabDropDelegate: DropDelegate {
    let tab: MainTab
    let tabs: [MainTab]
    let onMove: (MainTab, MainTab) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let sourceTab = info.itemProviders(for: [.text]).first else { return }
        
        sourceTab.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let tabName = String(data: data, encoding: .utf8),
                  let sourceMainTab = MainTab.allCases.first(where: { $0.rawValue == tabName }),
                  sourceMainTab != tab else {
                return
            }
            
            DispatchQueue.main.async {
                onMove(sourceMainTab, tab)
            }
        }
    }
}

extension View {
    /// Conditionally applies `.ultraThinMaterial` backdrop blur.
    func conditionalBackground(apply: Bool) -> AnyView {
        if apply {
            return AnyView(self.background(.ultraThinMaterial))
        }
        return AnyView(self)
    }
}

// MARK: - Liquid Glass ViewModifiers (availability-gated)

/// Applies glassEffect to a main-tab pill on macOS 26+; no-op on older OS.
struct TabGlassModifier: ViewModifier {
    let isSelected: Bool
    let isExperimental: Bool
    let usesGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), usesGlass {
            content
                .glassEffect(
                    .regular.tint(isSelected ? (isExperimental ? Theme.bf6Purple : Theme.bf6Blue) : Color.white.opacity(0.12)),
                    in: .rect(cornerRadius: 8)
                )
        } else {
            content
        }
    }
}

/// Applies glassEffect to a sub-tab pill on macOS 26+; no-op on older OS.
struct SubTabGlassModifier: ViewModifier {
    let isSelected: Bool
    let accentColor: Color
    let usesGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), usesGlass {
            content
                .glassEffect(
                    .regular.tint(isSelected ? accentColor : .clear),
                    in: .rect(cornerRadius: 8)
                )
        } else {
            content
        }
    }
}

/// Wraps content in a GlassEffectContainer on macOS 26+ when glass is enabled; passthrough otherwise.
struct GlassContainerWrapper<Content: View>: View {
    let usesGlass: Bool
    let content: Content

    init(usesGlass: Bool, @ViewBuilder content: () -> Content) {
        self.usesGlass = usesGlass
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(macOS 26, *), usesGlass {
            GlassEffectContainer(spacing: 12) {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(StatsViewModel())
        .frame(width: 1200, height: 800)
}
