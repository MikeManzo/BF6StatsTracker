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
    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var showingEALogin = false

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
            
            if viewModel.hasPlayerData {
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
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Tab Bar
            tabBarView
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    switch viewModel.selectedTab {
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
                    case .gadgets:
                        GadgetStatsView()
                    case .vehicles:
                        VehicleStatsView()
                    case .loadout:
                        LoadoutAnalyzerView()
                    case .servers:
                        ServerBrowserView()
                    }
                }
                .padding()
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
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)

                        Image(systemName: "person.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black) // Intentionally black on orange gradient
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stats.userName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textPrimary)

                            PlatformIconView(platform: viewModel.settings.platform, size: 16)

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
                                }

                                HStack(spacing: 4) {
                                    Image(systemName: "trophy.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("\(formatXP(xp.accolades))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
                
                // Search button
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(Theme.textPrimary)
                }
                .buttonStyle(.plain)

                // Settings button
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(Theme.textPrimary)
                }
                .buttonStyle(.plain)
                
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
            ForEach(StatTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(viewModel.selectedTab == tab ? Theme.textPrimary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        viewModel.selectedTab == tab ?
                        Theme.bf6Blue.opacity(0.3) :
                        Color.clear
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.overlayColor)
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

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(StatsViewModel())
        .frame(width: 1200, height: 800)
}
