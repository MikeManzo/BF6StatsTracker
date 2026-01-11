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
//  MapStatsView.swift
//  BF6StatsTracker
//
//  Enhanced map performance statistics with comparisons and insights
//

import SwiftUI
import Charts

struct MapStatsView: View {
    @EnvironmentObject var viewModel: StatsViewModel

    @State private var sortBy: MapSortOption = .matches
    @State private var searchText = ""
    @State private var showingComparison = false
    @State private var viewMode: ViewMode = .grid

    var filteredMaps: [MapPerformance] {
        guard let stats = viewModel.playerStats,
              let maps = stats.maps else { return [] }

        let filtered = searchText.isEmpty
            ? maps
            : maps.filter { $0.mapName.localizedCaseInsensitiveContains(searchText) }

        switch sortBy {
        case .matches:
            return filtered.sorted { $0.matchesPlayed > $1.matchesPlayed }
        case .winRate:
            return filtered.sorted { $0.winRate > $1.winRate }
        case .timePlayed:
            return filtered.sorted { $0.secondsPlayed > $1.secondsPlayed }
        case .name:
            return filtered.sorted { $0.mapName < $1.mapName }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with stats summary
            headerWithSummary

            if filteredMaps.isEmpty {
                emptyState
            } else {
                // Map comparison chart
                if showingComparison && filteredMaps.count > 1 {
                    mapComparisonChart
                }

                // Map list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredMaps) { map in
                            if viewMode == .grid {
                                MapPerformanceCard(map: map)
                            } else {
                                CompactMapRow(map: map)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Theme.backgroundPrimary)
    }

    // MARK: - Header

    private var headerWithSummary: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.blue)
                    .font(.title2)

                Text("Map Performance")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // View mode toggle
                HStack(spacing: 4) {
                    Button(action: { viewMode = .grid }) {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(viewMode == .grid ? .blue : .secondary)
                    }
                    Button(action: { viewMode = .list }) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(viewMode == .list ? .blue : .secondary)
                    }
                }
                .buttonStyle(.plain)

                // Sort menu
                Menu {
                    ForEach(MapSortOption.allCases) { option in
                        Button(action: { sortBy = option }) {
                            Label(option.rawValue, systemImage: sortBy == option ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
            }

            // Quick stats summary
            if !filteredMaps.isEmpty {
                HStack(spacing: 16) {
                    QuickMapStat(
                        title: "Best Win Rate",
                        value: String(format: "%.0f%%", filteredMaps.max(by: { $0.winRate < $1.winRate })?.winRate ?? 0),
                        subtitle: filteredMaps.max(by: { $0.winRate < $1.winRate })?.mapName ?? "",
                        color: .green
                    )

                    QuickMapStat(
                        title: "Most Played",
                        value: "\(filteredMaps.max(by: { $0.matchesPlayed < $1.matchesPlayed })?.matchesPlayed ?? 0) matches",
                        subtitle: filteredMaps.max(by: { $0.matchesPlayed < $1.matchesPlayed })?.mapName ?? "",
                        color: .orange
                    )

                    QuickMapStat(
                        title: "Most Time",
                        value: filteredMaps.max(by: { $0.secondsPlayed < $1.secondsPlayed })?.timePlayed ?? "0m",
                        subtitle: filteredMaps.max(by: { $0.secondsPlayed < $1.secondsPlayed })?.mapName ?? "",
                        color: .purple
                    )

                    // Comparison toggle
                    Button(action: { withAnimation { showingComparison.toggle() } }) {
                        VStack(spacing: 4) {
                            Image(systemName: showingComparison ? "chart.bar.fill" : "chart.bar")
                                .font(.title3)
                                .foregroundColor(.cyan)

                            Text("Compare")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.cyan.opacity(showingComparison ? 0.2 : 0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search maps...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Theme.overlayColor)
            .cornerRadius(10)
        }
        .padding()
        .background(Theme.overlayColor)
    }

    // MARK: - Map Comparison Chart

    private var mapComparisonChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Win Rate Comparison")
                .font(.headline)
                .padding(.horizontal)

            Chart(filteredMaps.prefix(8)) { map in
                BarMark(
                    x: .value("Map", map.mapName),
                    y: .value("Win %", map.winRate)
                )
                .foregroundStyle(by: .value("Performance", winPerformanceLevel(map.winRate)))
                .annotation(position: .top) {
                    Text(String(format: "%.0f%%", map.winRate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
        }
        .padding(.vertical)
        .background(Theme.overlayColor)
        .cornerRadius(16)
        .padding(.horizontal)
        .transition(.scale.combined(with: .opacity))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Map Data Available")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Play some matches to see your map performance")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func winPerformanceLevel(_ winRate: Double) -> String {
        if winRate >= 60 { return "Excellent" }
        if winRate >= 50 { return "Good" }
        if winRate >= 40 { return "Average" }
        return "Below Average"
    }
}

// MARK: - Enhanced Map Performance Card

struct MapPerformanceCard: View {
    let map: MapPerformance

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with map image and name
            HStack(spacing: 12) {
                // Map thumbnail
                AsyncImage(url: URL(string: map.image)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 50)
                            .cornerRadius(8)
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.backgroundSecondary)
                            .frame(width: 80, height: 50)
                            .overlay(
                                Image(systemName: "map")
                                    .foregroundColor(.secondary)
                            )
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.backgroundSecondary)
                            .frame(width: 80, height: 50)
                            .overlay(ProgressView())
                    @unknown default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.backgroundSecondary)
                            .frame(width: 80, height: 50)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(map.mapName)
                        .font(.headline)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        Label("\(map.matchesPlayed) matches", systemImage: "flag.checkered")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if map.matchesPlayed > 0 {
                            WinRateBadge(winRate: map.winRate)
                        }
                    }
                }

                Spacer()

                // Win Rate Circle
                ZStack {
                    Circle()
                        .stroke(winColor(map.winRate).opacity(0.3), lineWidth: 4)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: min(map.winRate / 100.0, 1.0))
                        .stroke(winColor(map.winRate), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text(String(format: "%.0f%%", map.winRate))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(winColor(map.winRate))

                        Text("Win")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()
                .background(Theme.borderColor)

            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                DetailedStatItem(
                    label: "Wins",
                    value: "\(map.wins)",
                    icon: "trophy.fill",
                    color: .green,
                    comparison: nil
                )
                DetailedStatItem(
                    label: "Losses",
                    value: "\(map.losses)",
                    icon: "xmark.circle",
                    color: .red,
                    comparison: nil
                )
                DetailedStatItem(
                    label: "Time Played",
                    value: map.timePlayed,
                    icon: "clock.fill",
                    color: .purple,
                    comparison: nil
                )
            }

            // Win/Loss visualization
            VStack(spacing: 8) {
                HStack {
                    Text("W/L Record")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(map.wins)W - \(map.losses)L")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(map.wins) / CGFloat(max(map.matchesPlayed, 1)))

                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geometry.size.width * CGFloat(map.losses) / CGFloat(max(map.matchesPlayed, 1)))
                    }
                }
                .frame(height: 8)
                .cornerRadius(4)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(winColor(map.winRate).opacity(0.3), lineWidth: 2)
        )
    }

    private func winColor(_ winRate: Double) -> Color {
        if winRate >= 60 { return .green }
        if winRate >= 50 { return .cyan }
        if winRate >= 40 { return .yellow }
        return .red
    }
}

// MARK: - Compact Map Row

struct CompactMapRow: View {
    let map: MapPerformance

    var body: some View {
        HStack(spacing: 12) {
            // Map thumbnail
            AsyncImage(url: URL(string: map.image)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 40)
                        .cornerRadius(6)
                case .failure, .empty:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.backgroundSecondary)
                        .frame(width: 60, height: 40)
                        .overlay(
                            Image(systemName: "map")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        )
                @unknown default:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.backgroundSecondary)
                        .frame(width: 60, height: 40)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(map.mapName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Label("\(map.wins)W", systemImage: "trophy.fill")
                    Label("\(map.losses)L", systemImage: "xmark.circle")
                    Label(map.timePlayed, systemImage: "clock.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Win rate indicator
            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", map.winRate))
                    .font(.headline)
                    .foregroundColor(winColor(map.winRate))

                Text("Win Rate")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    private func winColor(_ winRate: Double) -> Color {
        if winRate >= 60 { return .green }
        if winRate >= 50 { return .cyan }
        if winRate >= 40 { return .yellow }
        return .red
    }
}

// MARK: - Supporting Views

struct QuickMapStat: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DetailedStatItem: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    let comparison: String?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let comparison = comparison {
                    Image(systemName: comparison == "above" ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .foregroundColor(comparison == "above" ? .green : .red)
                }
            }
        }
    }
}

struct WinRateBadge: View {
    let winRate: Double

    var body: some View {
        Text(performanceText)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(performanceColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(performanceColor.opacity(0.2))
            .cornerRadius(4)
    }

    private var performanceText: String {
        if winRate >= 60 { return "Dominant" }
        if winRate >= 50 { return "Winning" }
        if winRate >= 40 { return "Competitive" }
        return "Improving"
    }

    private var performanceColor: Color {
        if winRate >= 60 { return .green }
        if winRate >= 50 { return .cyan }
        if winRate >= 40 { return .yellow }
        return .red
    }
}

// MARK: - Sort Options & View Mode

enum MapSortOption: String, CaseIterable, Identifiable {
    case matches = "Matches"
    case winRate = "Win Rate"
    case timePlayed = "Time Played"
    case name = "Name"

    var id: String { rawValue }
}

enum ViewMode {
    case grid, list
}

// MARK: - Preview

#Preview {
    MapStatsView()
        .environmentObject(StatsViewModel())
}
