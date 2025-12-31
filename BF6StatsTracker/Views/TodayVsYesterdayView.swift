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
                yesterdayValue: yesterday?.deltaKills ?? 0,
                icon: "target",
                accentColor: .green
            )

            PerformanceComparisonCard(
                title: "Deaths",
                todayValue: today.deltaDeaths,
                yesterdayValue: yesterday?.deltaDeaths ?? 0,
                icon: "xmark.circle",
                accentColor: .red
            )

            PerformanceComparisonCardDouble(
                title: "K/D",
                todayValue: today.dailyKD,
                yesterdayValue: yesterday?.dailyKD ?? 0,
                icon: "chart.line.uptrend.xyaxis",
                accentColor: .orange,
                format: "%.2f"
            )

            PerformanceComparisonCard(
                title: "Matches",
                todayValue: today.deltaMatchesPlayed,
                yesterdayValue: yesterday?.deltaMatchesPlayed ?? 0,
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
                    yesterdayValue: Double(yesterday?.deltaHeadshots ?? 1),
                    label: "🎯 Headshots (\(String(format: "%.1f%%", today.dailyHeadshotPercent)))",
                    accentColor: .purple,
                    delay: 0.0,
                    shouldAnimate: !hasAnimated
                )

                // Accuracy
                AnimatedComparisonProgressBar(
                    todayValue: today.dailyAccuracy,
                    yesterdayValue: yesterday?.dailyAccuracy ?? 1,
                    label: "🎪 Accuracy",
                    accentColor: .orange,
                    delay: 0.1,
                    shouldAnimate: !hasAnimated
                )

                // KPM
                AnimatedComparisonProgressBar(
                    todayValue: today.dailyKPM,
                    yesterdayValue: yesterday?.dailyKPM ?? 1,
                    label: "⚡ Kills Per Minute",
                    accentColor: .yellow,
                    delay: 0.2,
                    shouldAnimate: !hasAnimated
                )

                // Assists
                AnimatedComparisonProgressBar(
                    todayValue: Double(today.deltaAssists),
                    yesterdayValue: Double(yesterday?.deltaAssists ?? 1),
                    label: "🤝 Assists",
                    accentColor: .cyan,
                    delay: 0.3,
                    shouldAnimate: !hasAnimated
                )

                // Win Rate
                AnimatedComparisonProgressBar(
                    todayValue: today.dailyWinRate,
                    yesterdayValue: yesterday?.dailyWinRate ?? 1,
                    label: "🏆 Win Rate",
                    accentColor: .green,
                    delay: 0.4,
                    shouldAnimate: !hasAnimated
                )

                // Score
                AnimatedComparisonProgressBar(
                    todayValue: Double(today.deltaScore) / 1000,
                    yesterdayValue: Double(yesterday?.deltaScore ?? 1) / 1000,
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
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Performance Data Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Play some matches to start tracking your daily performance!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(60)
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

#Preview {
    TodayVsYesterdayView()
        .environmentObject(HistoryManager.shared)
        .frame(width: 1200, height: 800)
}
