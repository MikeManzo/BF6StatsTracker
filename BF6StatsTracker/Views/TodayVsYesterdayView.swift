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

    private var today: DailyPerformance? {
        historyManager.todayPerformance
    }

    private var yesterday: DailyPerformance? {
        historyManager.yesterdayPerformance
    }

    private var last7Days: [DailyPerformance] {
        Array(historyManager.recentDailyPerformances.prefix(7).reversed())
    }

    // Fallback values computed from snapshots when DailyPerformance is not available
    private var yesterdayFallback: DailyPerformanceData? {
        guard yesterday == nil else { return nil }

        // Get the last TWO snapshots before today to calculate the last session's deltas
        let todayStart = Calendar.current.startOfDay(for: Date())
        let snapshots = historyManager.getAllSnapshots()

        // Get all snapshots from before today
        let previousSnapshots = snapshots.filter { $0.timestamp < todayStart }

        // Need at least 2 snapshots to calculate deltas for the last session
        guard previousSnapshots.count >= 2 else {
            // If only 1 snapshot, use it as baseline with 0 deltas
            if let lastSnapshot = previousSnapshots.first {
                return DailyPerformanceData(
                    deltaKills: 0,
                    deltaDeaths: 0,
                    deltaHeadshots: 0,
                    deltaAssists: 0,
                    deltaMatchesPlayed: 0,
                    deltaScore: 0,
                    dailyKD: lastSnapshot.deaths > 0 ? Double(lastSnapshot.kills) / Double(lastSnapshot.deaths) : Double(lastSnapshot.kills),
                    dailyAccuracy: lastSnapshot.accuracy,
                    dailyHeadshotPercent: lastSnapshot.headshotPercentage,
                    dailyKPM: lastSnapshot.killsPerMinute,
                    dailyWinRate: lastSnapshot.matchesPlayed > 0 ? (Double(lastSnapshot.wins) / Double(lastSnapshot.matchesPlayed)) * 100.0 : 0.0
                )
            }
            return nil
        }

        // Get the most recent snapshot and the one before it from the previous day
        let lastSnapshot = previousSnapshots[0]  // Most recent from before today
        let beforeLastSnapshot = previousSnapshots[1]  // One before that

        // Calculate deltas for the last session (difference between the last two snapshots)
        let deltaKills = lastSnapshot.kills - beforeLastSnapshot.kills
        let deltaDeaths = lastSnapshot.deaths - beforeLastSnapshot.deaths
        let deltaHeadshots = lastSnapshot.headshots - beforeLastSnapshot.headshots
        let deltaAssists = lastSnapshot.assists - beforeLastSnapshot.assists
        let deltaMatchesPlayed = lastSnapshot.matchesPlayed - beforeLastSnapshot.matchesPlayed
        let deltaScore = lastSnapshot.totalScore - beforeLastSnapshot.totalScore

        // Calculate daily K/D from the deltas
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

    // Helper to get comparison values (use DailyPerformance if available, otherwise fallback)
    private var comparisonKills: Int { yesterday?.deltaKills ?? yesterdayFallback?.deltaKills ?? 0 }
    private var comparisonDeaths: Int { yesterday?.deltaDeaths ?? yesterdayFallback?.deltaDeaths ?? 0 }
    private var comparisonKD: Double { yesterday?.dailyKD ?? yesterdayFallback?.dailyKD ?? 0.0 }
    private var comparisonMatches: Int { yesterday?.deltaMatchesPlayed ?? yesterdayFallback?.deltaMatchesPlayed ?? 0 }
    private var comparisonHeadshots: Int { yesterday?.deltaHeadshots ?? yesterdayFallback?.deltaHeadshots ?? 1 }
    private var comparisonAccuracy: Double { yesterday?.dailyAccuracy ?? yesterdayFallback?.dailyAccuracy ?? 1.0 }
    private var comparisonKPM: Double { yesterday?.dailyKPM ?? yesterdayFallback?.dailyKPM ?? 1.0 }
    private var comparisonAssists: Int { yesterday?.deltaAssists ?? yesterdayFallback?.deltaAssists ?? 1 }
    private var comparisonWinRate: Double { yesterday?.dailyWinRate ?? yesterdayFallback?.dailyWinRate ?? 1.0 }
    private var comparisonScore: Int { yesterday?.deltaScore ?? yesterdayFallback?.deltaScore ?? 1 }

    private func calculateStreakDays() -> Int {
        guard let today = today, let yesterday = yesterday else { return 0 }
        var days = 0
        if today.dailyKD > yesterday.dailyKD { days = 1 }

        let performances = historyManager.recentDailyPerformances
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
                if let today = today {
                    // Header
                    header

                    // Main comparison cards
                    mainStatsGrid(today: today)

                    // Combat performance breakdown
                    combatBreakdown(today: today)

                    // Performance badges
                    PerformanceBadgesView(today: today, yesterday: yesterday)

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
                Text("📊 Today's Performance")
                    .font(.title2)
                    .fontWeight(.bold)

                if let today = today {
                    Text(today.sessionDurationString)
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

    private func mainStatsGrid(today: DailyPerformance) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            PerformanceComparisonCard(
                title: "Kills",
                todayValue: today.deltaKills,
                yesterdayValue: comparisonKills,
                icon: "target",
                accentColor: .green
            )

            PerformanceComparisonCard(
                title: "Deaths",
                todayValue: today.deltaDeaths,
                yesterdayValue: comparisonDeaths,
                icon: "xmark.circle",
                accentColor: .red
            )

            PerformanceComparisonCardDouble(
                title: "K/D",
                todayValue: today.dailyKD,
                yesterdayValue: comparisonKD,
                icon: "chart.line.uptrend.xyaxis",
                accentColor: .orange,
                format: "%.2f"
            )

            PerformanceComparisonCard(
                title: "Matches",
                todayValue: today.deltaMatchesPlayed,
                yesterdayValue: comparisonMatches,
                icon: "gamecontroller.fill",
                accentColor: .blue
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Combat Breakdown

    private func combatBreakdown(today: DailyPerformance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combat Breakdown")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // Headshots
                AnimatedComparisonProgressBar(
                    todayValue: Double(today.deltaHeadshots),
                    yesterdayValue: Double(comparisonHeadshots),
                    label: "🎯 Headshots (\(String(format: "%.1f%%", today.dailyHeadshotPercent)))",
                    accentColor: .purple,
                    delay: 0.0,
                    shouldAnimate: !hasAnimated
                )

                // Accuracy
                AnimatedComparisonProgressBar(
                    todayValue: today.dailyAccuracy,
                    yesterdayValue: comparisonAccuracy,
                    label: "🎪 Accuracy",
                    accentColor: .orange,
                    delay: 0.1,
                    shouldAnimate: !hasAnimated
                )

                // KPM
                AnimatedComparisonProgressBar(
                    todayValue: today.dailyKPM,
                    yesterdayValue: comparisonKPM,
                    label: "⚡ Kills Per Minute",
                    accentColor: .yellow,
                    delay: 0.2,
                    shouldAnimate: !hasAnimated
                )

                // Assists
                AnimatedComparisonProgressBar(
                    todayValue: Double(today.deltaAssists),
                    yesterdayValue: Double(comparisonAssists),
                    label: "🤝 Assists",
                    accentColor: .cyan,
                    delay: 0.3,
                    shouldAnimate: !hasAnimated
                )

                // Win Rate
                AnimatedComparisonProgressBar(
                    todayValue: today.dailyWinRate,
                    yesterdayValue: comparisonWinRate,
                    label: "🏆 Win Rate",
                    accentColor: .green,
                    delay: 0.4,
                    shouldAnimate: !hasAnimated
                )

                // Score
                AnimatedComparisonProgressBar(
                    todayValue: Double(today.deltaScore) / 1000,
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
                    Text("Today:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", todayValue))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Image(systemName: isImprovement ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(isImprovement ? .green : .red)

                    Text("Last Played:")
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
