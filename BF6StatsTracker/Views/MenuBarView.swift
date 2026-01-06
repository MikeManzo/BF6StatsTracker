//
//  MenuBarView.swift
//  BF6StatsTracker
//
//  Menu bar extra view for quick stats access
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    
    var body: some View {
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
    
    // MARK: - Player Header

    private func playerHeader(stats: PlayerStats) -> some View {
        HStack(spacing: 12) {
            // Player Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.bf6Orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(stats.userName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    PlatformIconView(size: 12)
                }

                // XP Info
                if let xpArray = stats.xpData, let xp = xpArray.first {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text("\(formatXP(xp.total)) XP")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.textPrimary)
                    }
                } else {
                    Text("\(viewModel.formattedPlayTime) played")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()

            // Last Updated
            VStack(alignment: .trailing, spacing: 2) {
                Circle()
                    .fill(viewModel.isLoading ? Color.yellow : Theme.bf6Green)
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
                    color: stats.kdRatio >= 1 ? Theme.bf6Green : Theme.bf6Orange,
                    tooltip: "Kill/Death ratio - higher is better"
                )

                MenuBarStatItem(
                    icon: "trophy.fill",
                    label: "Wins",
                    value: stats.wins.formatted(),
                    color: .yellow,
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
                            color: Theme.bf6Orange,
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
                    .foregroundColor(classStats.kdRatio >= 1 ? Theme.bf6Green : Theme.bf6Orange)
            }
            .padding(10)
            .background(Theme.overlayColor)
            .cornerRadius(10)
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
                .background(Theme.bf6Blue.opacity(0.2))
                .cornerRadius(8)
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
                .background(Theme.overlayColor)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help("Open the main application window with detailed stats")

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
                .background(Theme.bf6Blue)
                .cornerRadius(8)
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
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.title.contains("BF6") || $0.isKeyWindow == false }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Create new window if needed
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
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

// MARK: - Menu Bar Stat Item

struct MenuBarStatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var tooltip: String = ""

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
        .background(Theme.overlayColor)
        .cornerRadius(8)
        .help(tooltip.isEmpty ? label : tooltip)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environmentObject(StatsViewModel())
        .frame(width: 300)
}
