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
                LoadingStateView()
            } else if viewModel.hasPlayerData {
                mainContentView
            } else {
                WelcomeStateView(
                    showingSearch: $showingSearch,
                    showingEALogin: $showingEALogin,
                    showingAccountSelection: $showingAccountSelection
                )
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
            HeaderSection(
                showingSearch: $showingSearch,
                showingSettings: $showingSettings,
                showingAccountSelection: $showingAccountSelection,
                showingXPBreakdown: $showingXPBreakdown,
                showingRankDetail: $showingRankDetail,
                usesLiquidGlass: usesLiquidGlass
            )
            
            TabBarView(usesLiquidGlass: usesLiquidGlass)
            
            if let subTabs = viewModel.selectedMainTab.subTabs {
                SubMenuView(
                    subTabs: subTabs,
                    usesLiquidGlass: usesLiquidGlass
                )
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
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(StatsViewModel())
        .frame(width: 1200, height: 800)
}
