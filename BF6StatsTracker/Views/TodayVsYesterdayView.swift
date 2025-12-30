//
//  TodayVsYesterdayView.swift
//  BF6StatsTracker
//
//  Created by Claude on 2025-12-29.
//

import SwiftUI

struct TodayVsYesterdayView: View {
    @EnvironmentObject var historyManager: HistoryManager

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
                ComparisonProgressBarView(
                    todayValue: Double(today.deltaHeadshots),
                    yesterdayValue: Double(yesterday?.deltaHeadshots ?? 1),
                    label: "🎯 Headshots (\(String(format: "%.1f%%", today.dailyHeadshotPercent)))",
                    accentColor: .purple
                )

                // Accuracy
                ComparisonProgressBarView(
                    todayValue: today.dailyAccuracy,
                    yesterdayValue: yesterday?.dailyAccuracy ?? 1,
                    label: "🎪 Accuracy",
                    accentColor: .orange
                )

                // KPM
                ComparisonProgressBarView(
                    todayValue: today.dailyKPM,
                    yesterdayValue: yesterday?.dailyKPM ?? 1,
                    label: "⚡ Kills Per Minute",
                    accentColor: .yellow
                )

                // Assists
                ComparisonProgressBarView(
                    todayValue: Double(today.deltaAssists),
                    yesterdayValue: Double(yesterday?.deltaAssists ?? 1),
                    label: "🤝 Assists",
                    accentColor: .cyan
                )

                // Win Rate
                ComparisonProgressBarView(
                    todayValue: today.dailyWinRate,
                    yesterdayValue: yesterday?.dailyWinRate ?? 1,
                    label: "🏆 Win Rate",
                    accentColor: .green
                )

                // Score
                ComparisonProgressBarView(
                    todayValue: Double(today.deltaScore) / 1000,
                    yesterdayValue: Double(yesterday?.deltaScore ?? 1) / 1000,
                    label: "🎖️ Score (thousands)",
                    accentColor: .blue
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .padding(.horizontal)
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

#Preview {
    TodayVsYesterdayView()
        .environmentObject(HistoryManager.shared)
        .frame(width: 1200, height: 800)
}
