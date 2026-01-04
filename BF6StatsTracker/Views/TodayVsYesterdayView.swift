//
//  TodayVsYesterdayView.swift
//  BF6StatsTracker
//
//  Created by Claude on 2025-12-29.
//

import SwiftUI

struct TodayVsYesterdayView: View {
    @EnvironmentObject var historyManager: HistoryManager
    @State private var hasAnimated = false

    private var last7Days: [DailyPerformance] {
        Array(historyManager.recentDailyPerformances.prefix(7).reversed())
    }

    // Get the last snapshot and second-to-last snapshot for "Last Played" comparison
    private var lastPlayedData: DailyPerformanceData? {
        let snapshots = historyManager.getAllSnapshots()

        // Need at least 2 snapshots to calculate deltas for the last session
        guard snapshots.count >= 2 else {
            // If only 1 snapshot, use it as baseline with 0 deltas
            if let lastSnapshot = snapshots.first {
                return DailyPerformanceData(
                    deltaKills: lastSnapshot.kills,
                    deltaDeaths: lastSnapshot.deaths,
                    deltaHeadshots: lastSnapshot.headshots,
                    deltaAssists: lastSnapshot.assists,
                    deltaMatchesPlayed: lastSnapshot.matchesPlayed,
                    deltaScore: lastSnapshot.totalScore,
                    dailyKD: lastSnapshot.deaths > 0 ? Double(lastSnapshot.kills) / Double(lastSnapshot.deaths) : Double(lastSnapshot.kills),
                    dailyAccuracy: lastSnapshot.accuracy,
                    dailyHeadshotPercent: lastSnapshot.headshotPercentage,
                    dailyKPM: lastSnapshot.killsPerMinute,
                    dailyWinRate: lastSnapshot.matchesPlayed > 0 ? (Double(lastSnapshot.wins) / Double(lastSnapshot.matchesPlayed)) * 100.0 : 0.0
                )
            }
            return nil
        }

        // Get the most recent snapshot
        let lastSnapshot = snapshots[0]

        // Find the most recent snapshot where values actually changed
        var comparisonSnapshot: StatsSnapshot? = nil
        for i in 1..<snapshots.count {
            let previousSnapshot = snapshots[i]
            // Check if any stat values changed from this snapshot to the last one
            if lastSnapshot.kills != previousSnapshot.kills ||
               lastSnapshot.deaths != previousSnapshot.deaths ||
               lastSnapshot.matchesPlayed != previousSnapshot.matchesPlayed {
                comparisonSnapshot = previousSnapshot
                break
            }
        }

        // If no comparison snapshot found (all snapshots are identical), use the second-to-last
        guard let beforeLastSnapshot = comparisonSnapshot ?? snapshots.dropFirst().first else {
            return nil
        }

        // Calculate deltas for the last session (difference between last snapshot and last changed snapshot)
        let deltaKills = lastSnapshot.kills - beforeLastSnapshot.kills
        let deltaDeaths = lastSnapshot.deaths - beforeLastSnapshot.deaths
        let deltaHeadshots = lastSnapshot.headshots - beforeLastSnapshot.headshots
        let deltaAssists = lastSnapshot.assists - beforeLastSnapshot.assists
        let deltaMatchesPlayed = lastSnapshot.matchesPlayed - beforeLastSnapshot.matchesPlayed
        let deltaScore = lastSnapshot.totalScore - beforeLastSnapshot.totalScore

        // Calculate K/D from the deltas
        let dailyKD = deltaDeaths > 0 ? Double(deltaKills) / Double(deltaDeaths) : Double(deltaKills)

        return DailyPerformanceData(
            deltaKills: deltaKills,
            deltaDeaths: deltaDeaths,
            deltaHeadshots: deltaHeadshots,
            deltaAssists: deltaAssists,
            deltaMatchesPlayed: deltaMatchesPlayed,
            deltaScore: deltaScore,
            dailyKD: dailyKD,
            dailyAccuracy: lastSnapshot.accuracy,
            dailyHeadshotPercent: lastSnapshot.headshotPercentage,
            dailyKPM: lastSnapshot.killsPerMinute,
            dailyWinRate: lastSnapshot.matchesPlayed > 0 ? (Double(lastSnapshot.wins) / Double(lastSnapshot.matchesPlayed)) * 100.0 : 0.0
        )
    }

    // Get the second-to-last snapshot data for comparison
    private var previousPlayedData: DailyPerformanceData? {
        let snapshots = historyManager.getAllSnapshots()

        // Need at least 2 snapshots
        guard snapshots.count >= 2 else {
            return nil
        }

        // Find the first snapshot where values changed (this becomes our "current" for previous session)
        let lastSnapshot = snapshots[0]
        var firstChangedIndex: Int? = nil
        for i in 1..<snapshots.count {
            let previousSnapshot = snapshots[i]
            if lastSnapshot.kills != previousSnapshot.kills ||
               lastSnapshot.deaths != previousSnapshot.deaths ||
               lastSnapshot.matchesPlayed != previousSnapshot.matchesPlayed {
                firstChangedIndex = i
                break
            }
        }

        // If no change found or not enough snapshots after the change, return nil
        guard let changedIndex = firstChangedIndex, changedIndex + 1 < snapshots.count else {
            // Return zero deltas if we only have 2 snapshots or no previous session
            if snapshots.count >= 2 {
                let beforeLastSnapshot = snapshots[1]
                return DailyPerformanceData(
                    deltaKills: 0,
                    deltaDeaths: 0,
                    deltaHeadshots: 0,
                    deltaAssists: 0,
                    deltaMatchesPlayed: 0,
                    deltaScore: 0,
                    dailyKD: beforeLastSnapshot.deaths > 0 ? Double(beforeLastSnapshot.kills) / Double(beforeLastSnapshot.deaths) : Double(beforeLastSnapshot.kills),
                    dailyAccuracy: beforeLastSnapshot.accuracy,
                    dailyHeadshotPercent: beforeLastSnapshot.headshotPercentage,
                    dailyKPM: beforeLastSnapshot.killsPerMinute,
                    dailyWinRate: beforeLastSnapshot.matchesPlayed > 0 ? (Double(beforeLastSnapshot.wins) / Double(beforeLastSnapshot.matchesPlayed)) * 100.0 : 0.0
                )
            }
            return nil
        }

        // The snapshot at changedIndex is where the last session started
        // Now find the previous session by looking for the next change
        let sessionStartSnapshot = snapshots[changedIndex]
        var previousSessionEndIndex: Int? = nil
        for i in (changedIndex + 1)..<snapshots.count {
            let previousSnapshot = snapshots[i]
            if sessionStartSnapshot.kills != previousSnapshot.kills ||
               sessionStartSnapshot.deaths != previousSnapshot.deaths ||
               sessionStartSnapshot.matchesPlayed != previousSnapshot.matchesPlayed {
                previousSessionEndIndex = changedIndex  // The session ended at changedIndex
                break
            }
        }

        // If we found a previous session, calculate deltas
        if let prevEndIndex = previousSessionEndIndex, prevEndIndex + 1 < snapshots.count {
            let prevSessionEnd = snapshots[prevEndIndex]

            // Find where that previous session started
            var prevSessionStart = snapshots[prevEndIndex + 1]
            for i in (prevEndIndex + 1)..<snapshots.count {
                let olderSnapshot = snapshots[i]
                if prevSessionEnd.kills != olderSnapshot.kills ||
                   prevSessionEnd.deaths != olderSnapshot.deaths ||
                   prevSessionEnd.matchesPlayed != olderSnapshot.matchesPlayed {
                    prevSessionStart = olderSnapshot
                    break
                }
            }

            let deltaKills = prevSessionEnd.kills - prevSessionStart.kills
            let deltaDeaths = prevSessionEnd.deaths - prevSessionStart.deaths
            let deltaHeadshots = prevSessionEnd.headshots - prevSessionStart.headshots
            let deltaAssists = prevSessionEnd.assists - prevSessionStart.assists
            let deltaMatchesPlayed = prevSessionEnd.matchesPlayed - prevSessionStart.matchesPlayed
            let deltaScore = prevSessionEnd.totalScore - prevSessionStart.totalScore
            let dailyKD = deltaDeaths > 0 ? Double(deltaKills) / Double(deltaDeaths) : Double(deltaKills)

            return DailyPerformanceData(
                deltaKills: deltaKills,
                deltaDeaths: deltaDeaths,
                deltaHeadshots: deltaHeadshots,
                deltaAssists: deltaAssists,
                deltaMatchesPlayed: deltaMatchesPlayed,
                deltaScore: deltaScore,
                dailyKD: dailyKD,
                dailyAccuracy: prevSessionEnd.accuracy,
                dailyHeadshotPercent: prevSessionEnd.headshotPercentage,
                dailyKPM: prevSessionEnd.killsPerMinute,
                dailyWinRate: prevSessionEnd.matchesPlayed > 0 ? (Double(prevSessionEnd.wins) / Double(prevSessionEnd.matchesPlayed)) * 100.0 : 0.0
            )
        }

        // Fallback: use the snapshot at changedIndex with zero deltas
        let fallbackSnapshot = snapshots[changedIndex]
        return DailyPerformanceData(
            deltaKills: 0,
            deltaDeaths: 0,
            deltaHeadshots: 0,
            deltaAssists: 0,
            deltaMatchesPlayed: 0,
            deltaScore: 0,
            dailyKD: fallbackSnapshot.deaths > 0 ? Double(fallbackSnapshot.kills) / Double(fallbackSnapshot.deaths) : Double(fallbackSnapshot.kills),
            dailyAccuracy: fallbackSnapshot.accuracy,
            dailyHeadshotPercent: fallbackSnapshot.headshotPercentage,
            dailyKPM: fallbackSnapshot.killsPerMinute,
            dailyWinRate: fallbackSnapshot.matchesPlayed > 0 ? (Double(fallbackSnapshot.wins) / Double(fallbackSnapshot.matchesPlayed)) * 100.0 : 0.0
        )
    }

    // Helper to get comparison values
    private var comparisonKills: Int { previousPlayedData?.deltaKills ?? 0 }
    private var comparisonDeaths: Int { previousPlayedData?.deltaDeaths ?? 0 }
    private var comparisonKD: Double { previousPlayedData?.dailyKD ?? 0.0 }
    private var comparisonMatches: Int { previousPlayedData?.deltaMatchesPlayed ?? 0 }
    private var comparisonHeadshots: Int { previousPlayedData?.deltaHeadshots ?? 1 }
    private var comparisonAccuracy: Double { previousPlayedData?.dailyAccuracy ?? 1.0 }
    private var comparisonKPM: Double { previousPlayedData?.dailyKPM ?? 1.0 }
    private var comparisonAssists: Int { previousPlayedData?.deltaAssists ?? 1 }
    private var comparisonWinRate: Double { previousPlayedData?.dailyWinRate ?? 1.0 }
    private var comparisonScore: Int { previousPlayedData?.deltaScore ?? 1 }

    private func calculateStreakDays() -> Int {
        let performances = historyManager.recentDailyPerformances
        guard performances.count >= 2 else { return 0 }

        var days = 0
        for i in 0..<min(performances.count - 1, 6) {
            if performances[i].dailyKD > performances[i + 1].dailyKD {
                days += 1
            } else {
                break
            }
        }
        return days
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let lastPlayed = lastPlayedData {
                    // Header
                    header

                    // Main comparison cards
                    mainStatsGrid(lastPlayed: lastPlayed)

                    // Combat performance breakdown
                    combatBreakdown(lastPlayed: lastPlayed)

                    // 7-day trend (full width)
                    if !last7Days.isEmpty {
                        SevenDayTrendView(
                            dailyPerformances: last7Days,
                            metric: .kd
                        )
                    }
                } else {
                    // No data state
                    emptyState
                }
            }
            .padding()
        }
        .onDisappear {
            // Reset animation state when view disappears so it animates again on next view
            hasAnimated = false
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("📊 Last Played")
                    .font(.title2)
                    .fontWeight(.bold)

                if let snapshots = historyManager.getAllSnapshots().prefix(1).first {
                    Text(snapshots.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            let streakDays = calculateStreakDays()
            if streakDays > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(streakDays) day\(streakDays == 1 ? "" : "s")")
                            .font(.headline)
                            .fontWeight(.bold)

                        Text("Improvement Streak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Main Stats Grid

    private func mainStatsGrid(lastPlayed: DailyPerformanceData) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            PerformanceComparisonCard(
                title: "Kills",
                todayValue: lastPlayed.deltaKills,
                yesterdayValue: comparisonKills,
                icon: "target",
                accentColor: .green
            )

            PerformanceComparisonCard(
                title: "Deaths",
                todayValue: lastPlayed.deltaDeaths,
                yesterdayValue: comparisonDeaths,
                icon: "xmark.circle",
                accentColor: .red
            )

            PerformanceComparisonCardDouble(
                title: "K/D",
                todayValue: lastPlayed.dailyKD,
                yesterdayValue: comparisonKD,
                icon: "chart.line.uptrend.xyaxis",
                accentColor: .orange,
                format: "%.2f"
            )

            PerformanceComparisonCard(
                title: "Matches",
                todayValue: lastPlayed.deltaMatchesPlayed,
                yesterdayValue: comparisonMatches,
                icon: "gamecontroller.fill",
                accentColor: .blue
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Combat Breakdown

    private func combatBreakdown(lastPlayed: DailyPerformanceData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combat Breakdown")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // Headshots
                AnimatedComparisonProgressBar(
                    todayValue: Double(lastPlayed.deltaHeadshots),
                    yesterdayValue: Double(comparisonHeadshots),
                    label: "🎯 Headshots (\(String(format: "%.1f%%", lastPlayed.dailyHeadshotPercent)))",
                    accentColor: .purple,
                    delay: 0.0,
                    shouldAnimate: !hasAnimated
                )

                // Accuracy
                AnimatedComparisonProgressBar(
                    todayValue: lastPlayed.dailyAccuracy,
                    yesterdayValue: comparisonAccuracy,
                    label: "🎪 Accuracy",
                    accentColor: .orange,
                    delay: 0.1,
                    shouldAnimate: !hasAnimated
                )

                // KPM
                AnimatedComparisonProgressBar(
                    todayValue: lastPlayed.dailyKPM,
                    yesterdayValue: comparisonKPM,
                    label: "⚡ Kills Per Minute",
                    accentColor: .yellow,
                    delay: 0.2,
                    shouldAnimate: !hasAnimated
                )

                // Assists
                AnimatedComparisonProgressBar(
                    todayValue: Double(lastPlayed.deltaAssists),
                    yesterdayValue: Double(comparisonAssists),
                    label: "🤝 Assists",
                    accentColor: .cyan,
                    delay: 0.3,
                    shouldAnimate: !hasAnimated
                )

                // Win Rate
                AnimatedComparisonProgressBar(
                    todayValue: lastPlayed.dailyWinRate,
                    yesterdayValue: comparisonWinRate,
                    label: "🏆 Win Rate",
                    accentColor: .green,
                    delay: 0.4,
                    shouldAnimate: !hasAnimated
                )

                // Score
                AnimatedComparisonProgressBar(
                    todayValue: Double(lastPlayed.deltaScore) / 1000,
                    yesterdayValue: Double(comparisonScore) / 1000,
                    label: "🎖️ Score (thousands)",
                    accentColor: .blue,
                    delay: 0.5,
                    shouldAnimate: !hasAnimated
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .padding(.horizontal)
            .onAppear {
                if !hasAnimated {
                    // Mark as animated after a delay to ensure all bars have started
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                        hasAnimated = true
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "chart.bar.xaxis",
            title: "No Performance Data Yet",
            message: "Play some matches to start tracking your daily performance!"
        )
    }
}

// MARK: - Animated Comparison Progress Bar Wrapper

struct AnimatedComparisonProgressBar: View {
    let todayValue: Double
    let yesterdayValue: Double
    let label: String
    let accentColor: Color
    let delay: Double
    let shouldAnimate: Bool

    @State private var displayProgress: Double = 0

    private var progress: Double {
        guard yesterdayValue > 0 else { return 0 }
        return min(todayValue / yesterdayValue, 1.5) / 1.5 // Cap at 150%
    }

    private var percentChange: Double {
        guard yesterdayValue > 0 else { return 0 }
        return ((todayValue - yesterdayValue) / yesterdayValue) * 100
    }

    private var isImprovement: Bool {
        todayValue > yesterdayValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label and values
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Text("Last:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", todayValue))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Image(systemName: isImprovement ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(isImprovement ? .green : .red)

                    Text("Previous:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", yesterdayValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            ProgressBarView(
                value: shouldAnimate ? displayProgress : progress,
                color: accentColor,
                height: 6,
                showShimmer: false
            )
            .onAppear {
                if shouldAnimate {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                            displayProgress = progress
                        }
                    }
                } else {
                    displayProgress = progress
                }
            }

            // Percentage change
            HStack {
                Text(String(format: "%.0f%% %@", abs(percentChange), isImprovement ? "improvement" : "decrease"))
                    .font(.caption2)
                    .foregroundStyle(isImprovement ? .green : .red)

                Spacer()
            }
        }
    }
}

// MARK: - Supporting Types

/// Lightweight data structure for holding daily performance values
/// Used as fallback when DailyPerformance records are not available
struct DailyPerformanceData {
    let deltaKills: Int
    let deltaDeaths: Int
    let deltaHeadshots: Int
    let deltaAssists: Int
    let deltaMatchesPlayed: Int
    let deltaScore: Int
    let dailyKD: Double
    let dailyAccuracy: Double
    let dailyHeadshotPercent: Double
    let dailyKPM: Double
    let dailyWinRate: Double
}

#Preview {
    TodayVsYesterdayView()
        .environmentObject(HistoryManager.shared)
        .frame(width: 1200, height: 800)
}
