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
import Charts

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

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        let snapshots = historyManager.getAllSnapshots()

        // Get last snapshot from before today (previous day)
        let beforeTodaySnapshots = snapshots.filter { snapshot in
            snapshot.timestamp < today
        }.sorted { $0.timestamp > $1.timestamp }

        if let lastBeforeToday = beforeTodaySnapshots.first {
            // Compare current to last snapshot from previous day
            return current.matchesPlayed - lastBeforeToday.matchesPlayed
        } else {
            // No previous day snapshot - get the first snapshot ever saved
            if let firstSnapshot = snapshots.last {
                return current.matchesPlayed - firstSnapshot.matchesPlayed
            }
            // Only one snapshot exists
            return current.matchesPlayed
        }
    }

    private var deltaWinRate: Int {
        guard let current = currentSnapshot else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        let snapshots = historyManager.getAllSnapshots()

        // Get last snapshot from before today (previous day)
        let beforeTodaySnapshots = snapshots.filter { snapshot in
            snapshot.timestamp < today
        }.sorted { $0.timestamp > $1.timestamp }

        let todayWins: Int
        let todayLosses: Int

        if let lastBeforeToday = beforeTodaySnapshots.first {
            // Calculate today's wins and losses
            todayWins = current.wins - lastBeforeToday.wins
            todayLosses = current.losses - lastBeforeToday.losses
        } else {
            // No previous day snapshot - get the first snapshot ever saved
            if let firstSnapshot = snapshots.last {
                todayWins = current.wins - firstSnapshot.wins
                todayLosses = current.losses - firstSnapshot.losses
            } else {
                // Only one snapshot exists
                todayWins = current.wins
                todayLosses = current.losses
            }
        }

        let totalGames = todayWins + todayLosses
        return totalGames > 0 ? Int(round((Double(todayWins) / Double(totalGames)) * 100.0)) : 0
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get all snapshots
        let allSnapshots = historyManager.getAllSnapshots()
        guard !allSnapshots.isEmpty else {
            logInfo("last7Days: No snapshots available", category: .api)
            return []
        }

        // Build daily performance from snapshots for up to the last 7 days
        var result: [DailyPerformance] = []

        for dayOffset in (0..<7).reversed() {
            guard let targetDay = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }

            let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay)!

            // Get all snapshots for this specific day
            let daySnapshots = allSnapshots.filter { snapshot in
                snapshot.timestamp >= targetDay && snapshot.timestamp < nextDay
            }.sorted { $0.timestamp < $1.timestamp }

            // Debug logging for today
            if Calendar.current.isDateInToday(targetDay) {
                logInfo("Today: Found \(daySnapshots.count) snapshots", category: .api)
                for (idx, snap) in daySnapshots.enumerated() {
                    logInfo("Snapshot \(idx): Time=\(snap.timestamp), Kills=\(snap.kills), Assists=\(snap.assists)", category: .api)
                }
            }

            guard let firstSnapshot = daySnapshots.first else {
                continue // Skip days with no snapshots
            }

            let lastSnapshot = daySnapshots.last!

            // Calculate daily deltas from snapshots
            // Special handling: if there's only 1 snapshot, use yesterday's last snapshot as baseline
            var kills: Int
            var deaths: Int
            var assists: Int
            var headshots: Int
            var revives: Int
            var matches: Int
            var wins: Int
            var score: Int

            if daySnapshots.count == 1 {
                // Single snapshot - use a placeholder that will trigger special handling below
                // We'll use the snapshot's own K/D and stats rather than calculating deltas
                kills = 0
                deaths = 0
                assists = 0
                headshots = 0
                revives = 0
                matches = 0
                wins = 0
                score = 0
            } else {
                // Multiple snapshots - normal delta calculation
                kills = lastSnapshot.kills - firstSnapshot.kills
                deaths = lastSnapshot.deaths - firstSnapshot.deaths
                assists = lastSnapshot.assists - firstSnapshot.assists
                headshots = lastSnapshot.headshots - firstSnapshot.headshots
                revives = lastSnapshot.revives - firstSnapshot.revives
                matches = lastSnapshot.matchesPlayed - firstSnapshot.matchesPlayed
                wins = lastSnapshot.wins - firstSnapshot.wins
                score = lastSnapshot.totalScore - firstSnapshot.totalScore
            }

            // Calculate K/D and KDA by averaging all snapshots for the day
            // This shows the average performance across all refreshes, not just the delta
            let dailyKD: Double
            let dailyKDA: Double

            // Average K/D and KDA from all snapshots for this day
            let totalKD = daySnapshots.map { $0.kdRatio }.reduce(0.0, +)
            dailyKD = totalKD / Double(daySnapshots.count)

            let totalKDA = daySnapshots.map { snapshot -> Double in
                let killAssists = snapshot.kills + snapshot.assists
                return snapshot.deaths > 0 ? Double(killAssists) / Double(snapshot.deaths) : Double(killAssists)
            }.reduce(0.0, +)
            dailyKDA = totalKDA / Double(daySnapshots.count)

            let dailyWinRate = matches > 0 ? (Double(wins) / Double(matches)) * 100.0 : 0.0

            // Create DailyPerformanceData for this day
            let perfData = DailyPerformanceData(
                deltaKills: kills,
                deltaDeaths: deaths,
                deltaHeadshots: headshots,
                deltaAssists: assists,
                deltaRevives: revives,
                deltaMatchesPlayed: matches,
                deltaScore: score,
                dailyKD: dailyKD,
                dailyKDA: dailyKDA,
                dailyAccuracy: lastSnapshot.accuracy,
                dailyHeadshotPercent: lastSnapshot.headshotPercentage,
                dailyKPM: lastSnapshot.killsPerMinute,
                dailyWinRate: dailyWinRate
            )

            // Create a transient DailyPerformance object
            // Note: This won't be persisted to the database, just used for display
            let performance = DailyPerformance(
                date: targetDay,
                playerName: firstSnapshot.playerName,
                platform: firstSnapshot.platform,
                startSnapshot: firstSnapshot
            )
            performance.endSnapshot = lastSnapshot
            performance.deltaKills = perfData.deltaKills
            performance.deltaDeaths = perfData.deltaDeaths
            performance.deltaHeadshots = perfData.deltaHeadshots
            performance.deltaAssists = perfData.deltaAssists
            performance.deltaRevives = perfData.deltaRevives
            performance.deltaMatchesPlayed = perfData.deltaMatchesPlayed
            performance.deltaScore = perfData.deltaScore
            performance.dailyKD = perfData.dailyKD
            performance.dailyAccuracy = perfData.dailyAccuracy
            performance.dailyHeadshotPercent = perfData.dailyHeadshotPercent
            performance.dailyKPM = perfData.dailyKPM
            performance.dailyWinRate = perfData.dailyWinRate

            // CRITICAL: For computedDailyKDA to return the correct averaged KDA,
            // we need to carefully set delta values that produce dailyKDA when computed
            // We already calculated the correct averaged KDA above (dailyKDA variable)
            // Now we need deltaKills, deltaDeaths, deltaAssists such that:
            // (deltaKills + deltaAssists) / deltaDeaths = dailyKDA

            // Use the averaged deaths as the denominator
            let avgDeaths = daySnapshots.map { $0.deaths }.reduce(0, +) / daySnapshots.count

            // Back-calculate kills+assists needed to produce the correct KDA
            let neededKillsAssists = Int(dailyKDA * Double(avgDeaths))

            // Split proportionally based on actual K/D ratio
            // If K/D is X, then for every (X+1) kill+assists, X are kills and 1 is assist
            let kdRatio = dailyKD
            let totalParts = kdRatio + 1.0
            let killsPart = kdRatio / totalParts

            let avgKills = Int(Double(neededKillsAssists) * killsPart)
            let avgAssists = neededKillsAssists - avgKills

            performance.deltaKills = avgKills
            performance.deltaDeaths = avgDeaths
            performance.deltaAssists = avgAssists

            // Debug logging for all days
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            let dateStr = dateFormatter.string(from: targetDay)
            logInfo("Day \(dateStr): \(daySnapshots.count) snapshots, Avg K/D: \(String(format: "%.2f", dailyKD)), Avg KDA: \(String(format: "%.2f", dailyKDA))", category: .api)
            logInfo("  Snapshot K/Ds: \(daySnapshots.map { String(format: "%.2f", $0.kdRatio) }.joined(separator: ", "))", category: .api)

            result.append(performance)
        }

        logInfo("last7Days: Generated \(result.count) daily records from snapshots", category: .api)
        logInfo("K/D values: \(result.map { String(format: "%.2f", $0.dailyKD) }.joined(separator: ", "))", category: .api)

        return result
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
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
            VStack(alignment: .leading, spacing: 20) {
                if currentSnapshot != nil {
                    // Header
                    header

                    // Main comparison cards
                    mainStatsGrid
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Maps Played
                    mapsPlayedSection
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Combat performance breakdown
                    combatBreakdown
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 7-day trend (full width) - show if we have at least 2 days of data
                    if last7Days.count >= 2 {
                        kdKdaTrendView
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    // No data state
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                Text("📊 Most Recent Performance")
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
                title: "Effectiveness",
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
                rightYesterdaySummary: yesterdayWinRate,
                rightSuffix: "%"
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

    // MARK: - K/D & KDA Trend View

    private var kdKdaTrendView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with both metrics
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("📈 K/D & KDA Trend")
                        .font(.headline)
                        .fontWeight(.bold)

                    Spacer()

                    HStack(spacing: 12) {
                        // K/D value
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.orange)
                                .frame(width: 8, height: 8)
                            Text(String(format: "%.2f", last7Days.last?.dailyKD ?? 0))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }

                        Text("|")
                            .foregroundStyle(.secondary)

                        // KDA value
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.cyan)
                                .frame(width: 8, height: 8)
                            Text(String(format: "%.2f", last7Days.last?.computedDailyKDA ?? 0))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.cyan)
                        }
                    }
                }

                // Description
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Shaded areas show relative performance magnitude. KDA includes assists (K+A)/D.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Dual-line chart
            Chart {
                // K/D series
                ForEach(Array(last7Days.enumerated()), id: \.offset) { index, performance in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Value", performance.dailyKD),
                        series: .value("Metric", "K/D")
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                    .symbol {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                    }

                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Value", performance.dailyKD),
                        series: .value("Metric", "K/D")
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.2), .orange.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                // KDA series
                ForEach(Array(last7Days.enumerated()), id: \.offset) { index, performance in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Value", performance.computedDailyKDA),
                        series: .value("Metric", "KDA")
                    )
                    .foregroundStyle(.cyan)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                    .symbol {
                        Circle()
                            .fill(.cyan)
                            .frame(width: 6, height: 6)
                    }

                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Value", performance.computedDailyKDA),
                        series: .value("Metric", "KDA")
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan.opacity(0.2), .cyan.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 120)

            // Day labels
            HStack {
                ForEach(last7Days.indices, id: \.self) { index in
                    Text(dayLabel(for: last7Days[index].date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Legend
            HStack(spacing: 16) {
                // K/D legend
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(.orange)
                        .frame(width: 20, height: 3)
                        .cornerRadius(1.5)
                    Text("K/D")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // KDA legend
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(.cyan)
                        .frame(width: 20, height: 3)
                        .cornerRadius(1.5)
                    Text("KDA")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Best days for both metrics
            HStack(spacing: 16) {
                // Best K/D day
                HStack(spacing: 4) {
                    Text("Best K/D:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let best = last7Days.max(by: { $0.dailyKD < $1.dailyKD }) {
                        Text(best.formattedDate)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                // Best KDA day
                HStack(spacing: 4) {
                    Text("Best KDA:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let best = last7Days.max(by: { $0.computedDailyKDA < $1.computedDailyKDA }) {
                        Text(best.formattedDate)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.cyan)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [.orange.opacity(0.3), .cyan.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
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
