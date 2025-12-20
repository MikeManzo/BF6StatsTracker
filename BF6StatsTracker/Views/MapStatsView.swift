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
        // Note: GameTools.Network API doesn't provide map stats for BF6
        // Generate sample data based on overall stats
        guard let stats = viewModel.playerStats else { return [] }

        let maps = stats.maps ?? MapPerformance.generateSampleData(from: stats)

        let filtered = searchText.isEmpty
            ? maps
            : maps.filter { $0.mapName.localizedCaseInsensitiveContains(searchText) }

        switch sortBy {
        case .matches:
            return filtered.sorted { $0.matchesPlayed > $1.matchesPlayed }
        case .kd:
            return filtered.sorted { $0.kdRatio > $1.kdRatio }
        case .winRate:
            return filtered.sorted { $0.winRate > $1.winRate }
        case .kills:
            return filtered.sorted { $0.kills > $1.kills }
        case .name:
            return filtered.sorted { $0.mapName < $1.mapName }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with stats summary
            headerWithSummary

            // Info banner about generated data
            if !filteredMaps.isEmpty {
                infoBanner
            }

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

    // MARK: - Info Banner

    private var infoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated Map Statistics")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text("BF6 API doesn't provide map-specific data. Stats shown are estimated based on your overall performance.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                        title: "Best K/D",
                        value: String(format: "%.2f", filteredMaps.max(by: { $0.kdRatio < $1.kdRatio })?.kdRatio ?? 0),
                        subtitle: filteredMaps.max(by: { $0.kdRatio < $1.kdRatio })?.mapName ?? "",
                        color: .green
                    )

                    QuickMapStat(
                        title: "Best Win Rate",
                        value: String(format: "%.0f%%", filteredMaps.max(by: { $0.winRate < $1.winRate })?.winRate ?? 0),
                        subtitle: filteredMaps.max(by: { $0.winRate < $1.winRate })?.mapName ?? "",
                        color: .purple
                    )

                    QuickMapStat(
                        title: "Most Played",
                        value: "\(filteredMaps.max(by: { $0.matchesPlayed < $1.matchesPlayed })?.matchesPlayed ?? 0)",
                        subtitle: filteredMaps.max(by: { $0.matchesPlayed < $1.matchesPlayed })?.mapName ?? "",
                        color: .orange
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
            Text("K/D Comparison")
                .font(.headline)
                .padding(.horizontal)

            Chart(filteredMaps.prefix(8)) { map in
                BarMark(
                    x: .value("Map", map.mapName),
                    y: .value("K/D", map.kdRatio)
                )
                .foregroundStyle(by: .value("Performance", performanceLevel(map.kdRatio)))
                .annotation(position: .top) {
                    Text(String(format: "%.1f", map.kdRatio))
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

    private func performanceLevel(_ kd: Double) -> String {
        if kd >= 2.0 { return "Excellent" }
        if kd >= 1.5 { return "Good" }
        if kd >= 1.0 { return "Average" }
        return "Below Average"
    }
}

// MARK: - Enhanced Map Performance Card

struct MapPerformanceCard: View {
    let map: MapPerformance

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with map name and match count
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(map.mapName)
                        .font(.headline)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        Label("\(map.matchesPlayed) matches", systemImage: "flag.checkered")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if map.matchesPlayed > 0 {
                            PerformanceBadge(kd: map.kdRatio)
                        }
                    }
                }

                Spacer()

                // K/D Circle
                ZStack {
                    Circle()
                        .stroke(kdColor(map.kdRatio).opacity(0.3), lineWidth: 4)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: min(map.kdRatio / 4.0, 1.0))
                        .stroke(kdColor(map.kdRatio), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text(String(format: "%.2f", map.kdRatio))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(kdColor(map.kdRatio))

                        Text("K/D")
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
                    label: "Kills",
                    value: "\(map.kills)",
                    icon: "target",
                    color: .red,
                    comparison: nil
                )
                DetailedStatItem(
                    label: "Deaths",
                    value: "\(map.deaths)",
                    icon: "xmark.circle",
                    color: Theme.textSecondary,
                    comparison: nil
                )
                DetailedStatItem(
                    label: "Win Rate",
                    value: String(format: "%.1f%%", map.winRate),
                    icon: "trophy",
                    color: .green,
                    comparison: map.winRate >= 50 ? "above" : "below"
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
                .stroke(kdColor(map.kdRatio).opacity(0.3), lineWidth: 2)
        )
    }

    private func kdColor(_ kd: Double) -> Color {
        if kd >= 2.0 { return .green }
        if kd >= 1.5 { return .cyan }
        if kd >= 1.0 { return .yellow }
        return .red
    }
}

// MARK: - Compact Map Row

struct CompactMapRow: View {
    let map: MapPerformance

    var body: some View {
        HStack(spacing: 12) {
            // K/D Badge
            VStack(spacing: 2) {
                Text(String(format: "%.2f", map.kdRatio))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(kdColor(map.kdRatio))

                Text("K/D")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            .padding(.vertical, 8)
            .background(kdColor(map.kdRatio).opacity(0.1))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(map.mapName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Label("\(map.kills)K", systemImage: "target")
                    Label("\(map.deaths)D", systemImage: "xmark.circle")
                    Label("\(map.matchesPlayed)M", systemImage: "flag.checkered")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Win rate indicator
            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", map.winRate))
                    .font(.headline)
                    .foregroundColor(.green)

                Text("Win Rate")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    private func kdColor(_ kd: Double) -> Color {
        if kd >= 2.0 { return .green }
        if kd >= 1.5 { return .cyan }
        if kd >= 1.0 { return .yellow }
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

struct PerformanceBadge: View {
    let kd: Double

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
        if kd >= 2.0 { return "Elite" }
        if kd >= 1.5 { return "Great" }
        if kd >= 1.0 { return "Good" }
        return "Practice"
    }

    private var performanceColor: Color {
        if kd >= 2.0 { return .green }
        if kd >= 1.5 { return .cyan }
        if kd >= 1.0 { return .yellow }
        return .red
    }
}

// MARK: - Sort Options & View Mode

enum MapSortOption: String, CaseIterable, Identifiable {
    case matches = "Matches"
    case kd = "K/D Ratio"
    case winRate = "Win Rate"
    case kills = "Kills"
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
