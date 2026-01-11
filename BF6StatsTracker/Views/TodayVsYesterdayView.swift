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
//  TodayVsYesterdayView.swift
//  BF6StatsTracker
//
//  Refactored to use snapshot-based comparison
//

import SwiftUI

struct TodayVsYesterdayView: View {
    @EnvironmentObject var historyManager: HistoryManager
    @State private var hasAnimated = false
    @State private var showSingleSnapshotInfo = false

    // Get current and previous snapshots for comparison
    private var currentSnapshot: StatsSnapshot? {
        let snapshots = historyManager.getAllSnapshots()
        return snapshots.first
    }

    private var previousSnapshot: StatsSnapshot? {
        let snapshots = historyManager.getAllSnapshots()
        guard snapshots.count >= 2 else { return nil }
        return snapshots[1]
    }

    private var thirdSnapshot: StatsSnapshot? {
        let snapshots = historyManager.getAllSnapshots()
        guard snapshots.count >= 3 else { return nil }
        return snapshots[2]
    }

    // Calculate deltas between current and previous snapshot
    // If only one snapshot exists (Rule 2), show current values instead of deltas
    private var deltaKills: Int {
        guard let current = currentSnapshot else { return 0 }
        guard let previous = previousSnapshot else { return current.kills }
        return current.kills - previous.kills
    }

    private var deltaDeaths: Int {
        guard let current = currentSnapshot else { return 0 }
        guard let previous = previousSnapshot else { return current.deaths }
        return current.deaths - previous.deaths
    }

    private var deltaKD: Double {
        guard let current = currentSnapshot else { return 0.0 }
        guard let previous = previousSnapshot else { return current.kdRatio }
        let kills = current.kills - previous.kills
        let deaths = current.deaths - previous.deaths
        return deaths > 0 ? Double(kills) / Double(deaths) : Double(kills)
    }

    private var deltaKDA: Double {
        guard let current = currentSnapshot else { return 0.0 }
        guard let previous = previousSnapshot else {
            // If only one snapshot, calculate KDA from absolute values
            let killAssists = current.kills + current.assists
            return current.deaths > 0 ? Double(killAssists) / Double(current.deaths) : Double(killAssists)
        }
        let kills = current.kills - previous.kills
        let assists = current.assists - previous.assists
        let deaths = current.deaths - previous.deaths
        let killAssists = kills + assists
        return deaths > 0 ? Double(killAssists) / Double(deaths) : Double(killAssists)
    }

    private var deltaMatches: Int {
        guard let current = currentSnapshot else { return 0 }
        guard let previous = previousSnapshot else { return current.matchesPlayed }
        return current.matchesPlayed - previous.matchesPlayed
    }

    private var deltaWinRate: Int {
        guard let current = currentSnapshot else { return 0 }
        guard let previous = previousSnapshot else {
            // If only one snapshot, calculate win rate from absolute values
            let matches = current.matchesPlayed
            return matches > 0 ? Int(round((Double(current.wins) / Double(matches)) * 100.0)) : 0
        }
        let wins = current.wins - previous.wins
        let matches = current.matchesPlayed - previous.matchesPlayed
        return matches > 0 ? Int(round((Double(wins) / Double(matches)) * 100.0)) : 0
    }

    private var deltaHeadshots: Int {
        guard let current = currentSnapshot else { return 0 }
        guard let previous = previousSnapshot else { return current.headshots }
        return current.headshots - previous.headshots
    }

    private var deltaAssists: Int {
        guard let current = currentSnapshot else { return 0 }
        guard let previous = previousSnapshot else { return current.assists }
        return current.assists - previous.assists
    }

    private var deltaRevives: Int {
        guard let current = currentSnapshot else { return 0 }
        guard let previous = previousSnapshot else { return current.revives }
        return current.revives - previous.revives
    }

    private var deltaScore: Int {
        guard let current = currentSnapshot else { return 0 }
        guard let previous = previousSnapshot else { return current.totalScore }
        return current.totalScore - previous.totalScore
    }

    // Previous session's delta values for comparison (used as "yesterdayValue" when no yesterday data exists)
    // This calculates the delta between the 2nd and 3rd most recent snapshots
    private var previousDeltaKills: Int {
        guard let second = previousSnapshot, let third = thirdSnapshot else { return 0 }
        return second.kills - third.kills
    }

    private var previousDeltaDeaths: Int {
        guard let second = previousSnapshot, let third = thirdSnapshot else { return 0 }
        return second.deaths - third.deaths
    }

    private var previousDeltaKD: Double {
        guard let second = previousSnapshot, let third = thirdSnapshot else { return 0.0 }
        let kills = second.kills - third.kills
        let deaths = second.deaths - third.deaths
        return deaths > 0 ? Double(kills) / Double(deaths) : Double(kills)
    }

    private var previousDeltaKDA: Double {
        guard let second = previousSnapshot, let third = thirdSnapshot else { return 0.0 }
        let kills = second.kills - third.kills
        let assists = second.assists - third.assists
        let deaths = second.deaths - third.deaths
        let killAssists = kills + assists
        return deaths > 0 ? Double(killAssists) / Double(deaths) : Double(killAssists)
    }

    private var previousDeltaMatches: Int {
        guard let second = previousSnapshot, let third = thirdSnapshot else { return 0 }
        return second.matchesPlayed - third.matchesPlayed
    }

    private var previousDeltaWinRate: Int {
        guard let second = previousSnapshot, let third = thirdSnapshot else { return 0 }
        let wins = second.wins - third.wins
        let matches = second.matchesPlayed - third.matchesPlayed
        return matches > 0 ? Int(round((Double(wins) / Double(matches)) * 100.0)) : 0
    }

    private var previousDeltaAssists: Int {
        guard let second = previousSnapshot, let third = thirdSnapshot else { return 0 }
        return second.assists - third.assists
    }

    private var previousDeltaRevives: Int {
        guard let second = previousSnapshot, let third = thirdSnapshot else { return 0 }
        return second.revives - third.revives
    }

    // Get today's total matches - compare last snapshot of today to last snapshot before today
    private var todayMatches: Int {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        let snapshots = historyManager.getAllSnapshots()
        let todaySnapshots = snapshots.filter { snapshot in
            calendar.isDate(snapshot.timestamp, inSameDayAs: now)
        }

        guard todaySnapshots.count > 0 else { return 0 }

        // Get last snapshot of today
        let sorted = todaySnapshots.sorted { $0.timestamp < $1.timestamp }
        guard let lastToday = sorted.last else { return 0 }

        // Get last snapshot from before today
        let beforeTodaySnapshots = snapshots.filter { snapshot in
            snapshot.timestamp < today
        }.sorted { $0.timestamp > $1.timestamp }

        if let lastBeforeToday = beforeTodaySnapshots.first {
            let matches = lastToday.matchesPlayed - lastBeforeToday.matchesPlayed
            logInfo("Total matches today: \(matches) (today: \(lastToday.matchesPlayed), yesterday: \(lastBeforeToday.matchesPlayed))", category: .api)
            return matches
        } else {
            // No baseline from before today - first snapshot represents 1 match, then add deltas
            var totalMatches = 1  // First snapshot = 1 match
            for i in 0..<sorted.count - 1 {
                let delta = sorted[i + 1].matchesPlayed - sorted[i].matchesPlayed
                totalMatches += delta
            }
            logInfo("Total matches today: \(totalMatches) (no baseline, from \(sorted.count) snapshots)", category: .api)
            return totalMatches
        }
    }

    // Get yesterday's total kills (return 0 if no data)
    private var yesterdayKills: Int {
        yesterdayData?.deltaKills ?? 0
    }

    // Get yesterday's total deaths (return 0 if no data)
    private var yesterdayDeaths: Int {
        yesterdayData?.deltaDeaths ?? 0
    }

    // Get yesterday's K/D (return 0 if no data)
    private var yesterdayKD: Double {
        yesterdayData?.dailyKD ?? 0.0
    }

    // Get yesterday's KDA (return 0 if no data)
    private var yesterdayKDA: Double {
        yesterdayData?.dailyKDA ?? 0.0
    }

    // Get yesterday's total matches (return 0 if no data)
    private var yesterdayMatches: Int {
        yesterdayData?.deltaMatchesPlayed ?? 0
    }

    // Get yesterday's win rate (return 0 if no data)
    private var yesterdayWinRate: Int {
        Int(round(yesterdayData?.dailyWinRate ?? 0.0))
    }

    // Get yesterday's total assists (return 0 if no data)
    private var yesterdayAssists: Int {
        yesterdayData?.deltaAssists ?? 0
    }

    // Get yesterday's total revives (return 0 if no data)
    private var yesterdayRevives: Int {
        yesterdayData?.deltaRevives ?? 0
    }

    // Get yesterday's data by summing all snapshots from the previous day
    private var yesterdayData: DailyPerformanceData? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let snapshots = historyManager.getAllSnapshots()
        let yesterdaySnapshots = snapshots.filter { snapshot in
            calendar.isDate(snapshot.timestamp, inSameDayAs: yesterday)
        }

        guard !yesterdaySnapshots.isEmpty else { return nil }

        // Sort by timestamp to get first and last
        let sorted = yesterdaySnapshots.sorted { $0.timestamp < $1.timestamp }
        guard let first = sorted.first, let last = sorted.last else { return nil }

        let kills = last.kills - first.kills
        let deaths = last.deaths - first.deaths
        let matches = last.matchesPlayed - first.matchesPlayed + 1
        let kd = deaths > 0 ? Double(kills) / Double(deaths) : Double(kills)
        let headshots = last.headshots - first.headshots
        let assists = last.assists - first.assists
        let revives = last.revives - first.revives
        let score = last.totalScore - first.totalScore
        let killAssists = kills + assists
        let kda = deaths > 0 ? Double(killAssists) / Double(deaths) : Double(killAssists)

        return DailyPerformanceData(
            deltaKills: kills,
            deltaDeaths: deaths,
            deltaHeadshots: headshots,
            deltaAssists: assists,
            deltaRevives: revives,
            deltaMatchesPlayed: matches,
            deltaScore: score,
            dailyKD: kd,
            dailyKDA: kda,
            dailyAccuracy: last.accuracy,
            dailyHeadshotPercent: last.headshotPercentage,
            dailyKPM: last.killsPerMinute,
            dailyWinRate: matches > 0 ? (Double(last.wins - first.wins) / Double(matches)) * 100.0 : 0.0
        )
    }

    private var last7Days: [DailyPerformance] {
        let performances = Array(historyManager.recentDailyPerformances.prefix(7).reversed())
        logInfo("last7Days: \(performances.count) daily performance records", category: .api)
        logInfo("recentDailyPerformances total: \(historyManager.recentDailyPerformances.count)", category: .api)
        return performances
    }

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
                if currentSnapshot != nil {
                    // Header
                    header

                    // Main comparison cards
                    mainStatsGrid

                    // Maps Played
                    mapsPlayedSection

                    // Combat performance breakdown
                    combatBreakdown

                    // 7-day trend (full width) - show if we have at least 2 days of data
                    if last7Days.count >= 2 {
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
        .alert("Single Snapshot", isPresented: $showSingleSnapshotInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You currently have only one snapshot. Comparison data will be available after you play a match and stats change.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("📊 Last Played")
                    .font(.title2)
                    .fontWeight(.bold)

                if let snapshot = currentSnapshot {
                    HStack(spacing: 4) {
                        Text(snapshot.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if previousSnapshot == nil {
                            Button {
                                showSingleSnapshotInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Single snapshot - more data after next match")
                        }
                    }
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

    private var mainStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            PerformanceDualComparisonCard(
                title: "Offense",
                leftLabel: "Kills",
                leftTodayValue: deltaKills,
                leftYesterdayValue: previousDeltaKills,
                rightLabel: "Assists",
                rightTodayValue: deltaAssists,
                rightYesterdayValue: previousDeltaAssists,
                icon: "target",
                accentColor: .green,
                leftYesterdaySummary: yesterdayKills,
                rightYesterdaySummary: yesterdayAssists
            )

            PerformanceDualComparisonCard(
                title: "Combat Cycle",
                leftLabel: "Deaths",
                leftTodayValue: deltaDeaths,
                leftYesterdayValue: previousDeltaDeaths,
                rightLabel: "Revives",
                rightTodayValue: deltaRevives,
                rightYesterdayValue: previousDeltaRevives,
                icon: "heart.circle",
                accentColor: .red,
                leftYesterdaySummary: yesterdayDeaths,
                rightYesterdaySummary: yesterdayRevives,
                leftLowerIsBetter: true,
                rightLowerIsBetter: false
            )

            PerformanceDualComparisonCardDouble(
                title: "Ratios",
                leftLabel: "K/D",
                leftTodayValue: deltaKD,
                leftYesterdayValue: previousDeltaKD,
                rightLabel: "KDA",
                rightTodayValue: deltaKDA,
                rightYesterdayValue: previousDeltaKDA,
                icon: "chart.line.uptrend.xyaxis",
                accentColor: .orange,
                format: "%.2f",
                leftYesterdaySummary: yesterdayKD,
                rightYesterdaySummary: yesterdayKDA
            )

            PerformanceDualComparisonCard(
                title: "Performance",
                leftLabel: "Matches",
                leftTodayValue: deltaMatches,
                leftYesterdayValue: previousDeltaMatches,
                rightLabel: "Win Rate",
                rightTodayValue: deltaWinRate,
                rightYesterdayValue: previousDeltaWinRate,
                icon: "trophy.fill",
                accentColor: .blue,
                leftYesterdaySummary: yesterdayMatches,
                rightYesterdaySummary: yesterdayWinRate
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Maps Played Section

    private var mapsPlayedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Maps Played", icon: "map.fill")
                .padding(.horizontal)

            if let mapsPlayed = getMapsPlayed() {
                if mapsPlayed.isEmpty {
                    Text("No map activity detected")
                        .foregroundColor(Theme.textSecondary)
                        .font(.subheadline)
                        .padding()
                } else if mapsPlayed.count == 1 {
                    // Single map - prominent display
                    singleMapView(mapsPlayed[0])
                        .padding(.horizontal)
                } else {
                    // Multiple maps - compact list
                    multipleMapsList(mapsPlayed)
                        .padding()
                }
            } else {
                Text("No snapshot history available")
                    .foregroundColor(Theme.textSecondary)
                    .font(.subheadline)
                    .padding()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .padding(.horizontal)
    }

    private func getMapsPlayed() -> [MapActivity]? {
        let snapshots = historyManager.getRecentSnapshots(limit: 2)
        guard let latest = snapshots.first,
              snapshots.count >= 2 else {
            return nil
        }

        let previous = snapshots[1]
        return latest.mapsPlayedSince(previous)
    }

    private func singleMapView(_ mapActivity: MapActivity) -> some View {
        HStack(spacing: 16) {
            // Map icon
            Image(systemName: "map.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.bf6Orange)

            VStack(alignment: .leading, spacing: 6) {
                Text(mapActivity.mapName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                HStack(spacing: 16) {
                    Label("\(mapActivity.matchesPlayed) match\(mapActivity.matchesPlayed == 1 ? "" : "es")", systemImage: "flag.checkered")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Label(mapActivity.timePlayedFormatted, systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Label(mapActivity.recordFormatted, systemImage: mapActivity.hasWins ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(mapActivity.hasWins ? .green : .red)
                }
            }

            Spacer()
        }
        .padding()
        .background(Theme.bf6Orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.bf6Orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func multipleMapsList(_ maps: [MapActivity]) -> some View {
        VStack(spacing: 8) {
            ForEach(maps.prefix(5)) { mapActivity in
                HStack(spacing: 12) {
                    // Map bullet
                    Circle()
                        .fill(Theme.bf6Orange)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mapActivity.mapName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)

                        HStack(spacing: 8) {
                            Text("\(mapActivity.matchesPlayed) match\(mapActivity.matchesPlayed == 1 ? "" : "es")")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)

                            Text("•")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)

                            Text(mapActivity.timePlayedShort)
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)

                            Text("•")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)

                            Text(mapActivity.recordFormatted)
                                .font(.caption2)
                                .foregroundColor(mapActivity.hasWins ? .green : .red)
                        }
                    }

                    Spacer()

                    // Win/Loss badge
                    HStack(spacing: 4) {
                        Image(systemName: mapActivity.hasWins ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(mapActivity.hasWins ? .green : .red)

                        Text(mapActivity.recordFormatted)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(mapActivity.hasWins ? .green : .red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((mapActivity.hasWins ? Color.green : Color.red).opacity(0.1))
                    .cornerRadius(6)
                }
                .padding(.vertical, 4)
            }

            if maps.count > 5 {
                Text("+ \(maps.count - 5) more map\(maps.count - 5 == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Combat Breakdown

    private var combatBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combat Breakdown")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // Headshots
                AnimatedComparisonProgressBar(
                    todayValue: Double(deltaHeadshots),
                    yesterdayValue: Double(yesterdayData?.deltaHeadshots ?? 1),
                    label: "🎯 Headshots",
                    accentColor: .purple,
                    delay: 0.0,
                    shouldAnimate: !hasAnimated
                )

                // Accuracy
                AnimatedComparisonProgressBar(
                    todayValue: currentSnapshot?.accuracy ?? 0,
                    yesterdayValue: yesterdayData?.dailyAccuracy ?? 1.0,
                    label: "🎪 Accuracy",
                    accentColor: .orange,
                    delay: 0.1,
                    shouldAnimate: !hasAnimated
                )

                // KPM
                AnimatedComparisonProgressBar(
                    todayValue: currentSnapshot?.killsPerMinute ?? 0,
                    yesterdayValue: yesterdayData?.dailyKPM ?? 1.0,
                    label: "⚡ Kills Per Minute",
                    accentColor: .yellow,
                    delay: 0.2,
                    shouldAnimate: !hasAnimated
                )

                // Assists
                AnimatedComparisonProgressBar(
                    todayValue: Double(deltaAssists),
                    yesterdayValue: Double(yesterdayData?.deltaAssists ?? 1),
                    label: "🤝 Assists",
                    accentColor: .cyan,
                    delay: 0.3,
                    shouldAnimate: !hasAnimated
                )

                // Win Rate
                AnimatedComparisonProgressBar(
                    todayValue: currentSnapshot?.matchesPlayed ?? 0 > 0 ? (Double(currentSnapshot?.wins ?? 0) / Double(currentSnapshot?.matchesPlayed ?? 1)) * 100.0 : 0.0,
                    yesterdayValue: yesterdayData?.dailyWinRate ?? 1.0,
                    label: "🏆 Win Rate",
                    accentColor: .green,
                    delay: 0.4,
                    shouldAnimate: !hasAnimated
                )

                // Score
                AnimatedComparisonProgressBar(
                    todayValue: Double(deltaScore) / 1000,
                    yesterdayValue: Double(yesterdayData?.deltaScore ?? 1000) / 1000,
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
                    Text("Current:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", todayValue))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Image(systemName: isImprovement ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(isImprovement ? .green : .red)

                    Text("Yesterday:")
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
    let deltaRevives: Int
    let deltaMatchesPlayed: Int
    let deltaScore: Int
    let dailyKD: Double
    let dailyKDA: Double
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
