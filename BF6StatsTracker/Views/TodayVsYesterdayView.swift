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
    @Environment(\.accentColor) private var accentColor
    @EnvironmentObject var historyManager: HistoryManager
    @State private var hasAnimated = false
    @State private var showSingleSnapshotInfo = false
    @State private var isMapsExpanded = true
    @State private var isCombatBreakdownExpanded = true
    @State private var snapshots: [StatsSnapshot] = []
    @State private var selectedChartPosition: Double? = nil
    @AppStorage("showKDKDATooltips") private var showTooltips: Bool = true

    // Combat Breakdown graph colors (persisted via AppStorage)
    @AppStorage("combatGraphColor_headshots") private var headshotsColor: Color = .purple
    @AppStorage("combatGraphColor_accuracy") private var accuracyColor: Color = .orange
    @AppStorage("combatGraphColor_kpm") private var kpmColor: Color = .yellow
    @AppStorage("combatGraphColor_assists") private var assistsColor: Color = .cyan
    @AppStorage("combatGraphColor_winRate") private var winRateColor: Color = .green
    @AppStorage("combatGraphColor_score") private var scoreColor: Color = .blue

    // Get current and previous snapshots for comparison
    private var currentSnapshot: StatsSnapshot? {
        snapshots.first
    }

    private var previousSnapshot: StatsSnapshot? {
        guard snapshots.count >= 2 else { return nil }
        return snapshots[1]
    }

    private var thirdSnapshot: StatsSnapshot? {
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

    // Get yesterday's data by comparing last snapshot of yesterday to last snapshot of day before yesterday
    // Falls back to first snapshot of yesterday if no day-before-yesterday data exists
    private var yesterdayData: DailyPerformanceData? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: today) ?? today

        // Get snapshots from yesterday, sorted chronologically
        let yesterdaySnapshots = snapshots.filter { snapshot in
            calendar.isDate(snapshot.timestamp, inSameDayAs: yesterday)
        }.sorted { $0.timestamp < $1.timestamp }

        guard let lastYesterday = yesterdaySnapshots.last else { return nil }

        // Get last snapshot from day before yesterday
        let dayBeforeSnapshots = snapshots.filter { snapshot in
            calendar.isDate(snapshot.timestamp, inSameDayAs: dayBeforeYesterday)
        }.sorted { $0.timestamp < $1.timestamp }

        // Use day-before-yesterday's last snapshot as baseline, or fall back to yesterday's first snapshot
        let baseline = dayBeforeSnapshots.last ?? yesterdaySnapshots.first!

        let kills = lastYesterday.kills - baseline.kills
        let deaths = lastYesterday.deaths - baseline.deaths
        let matches = lastYesterday.matchesPlayed - baseline.matchesPlayed
        let kd = deaths > 0 ? Double(kills) / Double(deaths) : Double(kills)
        let headshots = lastYesterday.headshots - baseline.headshots
        let assists = lastYesterday.assists - baseline.assists
        let revives = lastYesterday.revives - baseline.revives
        let score = lastYesterday.totalScore - baseline.totalScore
        let killAssists = kills + assists
        let kda = deaths > 0 ? Double(killAssists) / Double(deaths) : Double(killAssists)
        let wins = lastYesterday.wins - baseline.wins

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
            dailyAccuracy: lastYesterday.accuracy,
            dailyHeadshotPercent: lastYesterday.headshotPercentage,
            dailyKPM: lastYesterday.killsPerMinute,
            dailyWinRate: matches > 0 ? (Double(wins) / Double(matches)) * 100.0 : 0.0
        )
    }

    // MARK: - Combat Breakdown Averages

    /// Today's average performance per match
    private var todayAveragePerformance: CombatAverages? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get today's snapshots
        let todaySnapshots = snapshots.filter { snapshot in
            calendar.isDate(snapshot.timestamp, inSameDayAs: Date())
        }.sorted { $0.timestamp < $1.timestamp }

        guard let lastToday = todaySnapshots.last else { return nil }

        // Get baseline (last snapshot before today, or first snapshot of today if no previous day)
        let beforeTodaySnapshots = snapshots.filter { $0.timestamp < today }
            .sorted { $0.timestamp > $1.timestamp }

        let baseline: StatsSnapshot
        if let lastBeforeToday = beforeTodaySnapshots.first {
            baseline = lastBeforeToday
        } else if let firstToday = todaySnapshots.first, todaySnapshots.count > 1 {
            baseline = firstToday
        } else {
            // Only one snapshot, use its rate-based stats directly
            return CombatAverages(
                headshotsPerMatch: 0,
                assistsPerMatch: 0,
                accuracy: lastToday.accuracy,
                killsPerMinute: lastToday.killsPerMinute,
                winRate: lastToday.matchesPlayed > 0 ? (Double(lastToday.wins) / Double(lastToday.matchesPlayed)) * 100.0 : 0,
                scorePerMatch: 0,
                matchesPlayed: 0
            )
        }

        let deltaMatches = lastToday.matchesPlayed - baseline.matchesPlayed
        guard deltaMatches > 0 else {
            // No matches played today yet, return rate-based stats
            return CombatAverages(
                headshotsPerMatch: 0,
                assistsPerMatch: 0,
                accuracy: lastToday.accuracy,
                killsPerMinute: lastToday.killsPerMinute,
                winRate: 0,
                scorePerMatch: 0,
                matchesPlayed: 0
            )
        }

        let deltaHeadshots = lastToday.headshots - baseline.headshots
        let deltaAssists = lastToday.assists - baseline.assists
        let deltaScore = lastToday.totalScore - baseline.totalScore
        let deltaWins = lastToday.wins - baseline.wins

        return CombatAverages(
            headshotsPerMatch: Double(deltaHeadshots) / Double(deltaMatches),
            assistsPerMatch: Double(deltaAssists) / Double(deltaMatches),
            accuracy: lastToday.accuracy,
            killsPerMinute: lastToday.killsPerMinute,
            winRate: (Double(deltaWins) / Double(deltaMatches)) * 100.0,
            scorePerMatch: Double(deltaScore) / Double(deltaMatches),
            matchesPlayed: deltaMatches
        )
    }

    /// Yesterday's average performance per match
    private var yesterdayAveragePerformance: CombatAverages? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: today) ?? today

        // Get yesterday's snapshots
        let yesterdaySnapshots = snapshots.filter { snapshot in
            calendar.isDate(snapshot.timestamp, inSameDayAs: yesterday)
        }.sorted { $0.timestamp < $1.timestamp }

        guard let lastYesterday = yesterdaySnapshots.last else { return nil }

        // Get baseline from day before yesterday
        let dayBeforeSnapshots = snapshots.filter { snapshot in
            calendar.isDate(snapshot.timestamp, inSameDayAs: dayBeforeYesterday)
        }.sorted { $0.timestamp < $1.timestamp }

        guard let lastDayBefore = dayBeforeSnapshots.last else { return nil }

        let deltaMatches = lastYesterday.matchesPlayed - lastDayBefore.matchesPlayed
        guard deltaMatches > 0 else { return nil }

        let deltaHeadshots = lastYesterday.headshots - lastDayBefore.headshots
        let deltaAssists = lastYesterday.assists - lastDayBefore.assists
        let deltaScore = lastYesterday.totalScore - lastDayBefore.totalScore
        let deltaWins = lastYesterday.wins - lastDayBefore.wins

        return CombatAverages(
            headshotsPerMatch: Double(deltaHeadshots) / Double(deltaMatches),
            assistsPerMatch: Double(deltaAssists) / Double(deltaMatches),
            accuracy: lastYesterday.accuracy,
            killsPerMinute: lastYesterday.killsPerMinute,
            winRate: (Double(deltaWins) / Double(deltaMatches)) * 100.0,
            scorePerMatch: Double(deltaScore) / Double(deltaMatches),
            matchesPlayed: deltaMatches
        )
    }

    /// Cumulative historical average (fallback when yesterday's data is unavailable)
    private var historicalAveragePerformance: CombatAverages? {
        guard let latest = snapshots.first, let oldest = snapshots.last else { return nil }

        // Need at least some match history
        let totalMatches = latest.matchesPlayed - oldest.matchesPlayed
        guard totalMatches > 0 else {
            // Use the latest snapshot's rate-based stats
            return CombatAverages(
                headshotsPerMatch: latest.matchesPlayed > 0 ? Double(latest.headshots) / Double(latest.matchesPlayed) : 0,
                assistsPerMatch: latest.matchesPlayed > 0 ? Double(latest.assists) / Double(latest.matchesPlayed) : 0,
                accuracy: latest.accuracy,
                killsPerMinute: latest.killsPerMinute,
                winRate: latest.matchesPlayed > 0 ? (Double(latest.wins) / Double(latest.matchesPlayed)) * 100.0 : 0,
                scorePerMatch: latest.matchesPlayed > 0 ? Double(latest.totalScore) / Double(latest.matchesPlayed) : 0,
                matchesPlayed: latest.matchesPlayed
            )
        }

        let deltaHeadshots = latest.headshots - oldest.headshots
        let deltaAssists = latest.assists - oldest.assists
        let deltaScore = latest.totalScore - oldest.totalScore
        let deltaWins = latest.wins - oldest.wins

        return CombatAverages(
            headshotsPerMatch: Double(deltaHeadshots) / Double(totalMatches),
            assistsPerMatch: Double(deltaAssists) / Double(totalMatches),
            accuracy: latest.accuracy,
            killsPerMinute: latest.killsPerMinute,
            winRate: (Double(deltaWins) / Double(totalMatches)) * 100.0,
            scorePerMatch: Double(deltaScore) / Double(totalMatches),
            matchesPlayed: totalMatches
        )
    }

    /// The comparison baseline - yesterday if available, otherwise historical average
    private var comparisonBaseline: CombatAverages? {
        yesterdayAveragePerformance ?? historicalAveragePerformance
    }

    /// Whether we're comparing against yesterday or historical average
    private var isComparingToYesterday: Bool {
        yesterdayAveragePerformance != nil
    }

    private var last7Days: [DailyPerformance] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard !snapshots.isEmpty else {
            logInfo("last7Days: No snapshots available", category: .api)
            return []
        }
        let allSnapshots = snapshots

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
//            if Calendar.current.isDateInToday(targetDay) {
//                logInfo("Today: Found \(daySnapshots.count) snapshots", category: .api)
//                for (idx, snap) in daySnapshots.enumerated() {
//                    logInfo("Snapshot \(idx): Time=\(snap.timestamp), Kills=\(snap.kills), Assists=\(snap.assists)", category: .api)
//                }
//            }

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
//            let dateFormatter = DateFormatter()
//            dateFormatter.dateFormat = "MMM d"
//            let dateStr = dateFormatter.string(from: targetDay)
//            logInfo("Day \(dateStr): \(daySnapshots.count) snapshots, Avg K/D: \(String(format: "%.2f", dailyKD)), Avg KDA: \(String(format: "%.2f", dailyKDA))", category: .api)
//            logInfo("  Snapshot K/Ds: \(daySnapshots.map { String(format: "%.2f", $0.kdRatio) }.joined(separator: ", "))", category: .api)

            result.append(performance)
        }

//        logInfo("last7Days: Generated \(result.count) daily records from snapshots", category: .api)
//        logInfo("K/D values: \(result.map { String(format: "%.2f", $0.dailyKD) }.joined(separator: ", "))", category: .api)

        return result
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    /// Sanitize a Double value, replacing NaN or Infinity with a default value
    private func sanitize(_ value: Double, default defaultValue: Double = 0.0) -> Double {
        value.isFinite ? value : defaultValue
    }

    /// Calculate a safe Y-axis domain for the K/D & KDA chart to prevent NaN in chart rendering
    private var kdKdaChartYDomain: ClosedRange<Double> {
        var allValues: [Double] = []

        // Collect all KD and KDA values from snapshots
        for item in snapshotsForChart {
            if item.sessionKD.isFinite { allValues.append(item.sessionKD) }
            if item.sessionKDA.isFinite { allValues.append(item.sessionKDA) }
        }

        // Collect from daily averages
        for performance in last7Days {
            if performance.dailyKD.isFinite { allValues.append(performance.dailyKD) }
            if performance.computedDailyKDA.isFinite { allValues.append(performance.computedDailyKDA) }
        }

        guard !allValues.isEmpty else { return 0...2 }

        let minVal = allValues.min() ?? 0
        let maxVal = allValues.max() ?? 2
        let range = maxVal - minVal

        if range < 0.1 {
            // All values are essentially the same - create artificial range
            let center = (minVal + maxVal) / 2
            return max(0, center - 0.5)...(center + 0.5)
        }

        return max(0, minVal * 0.9)...(maxVal * 1.1)
    }

    /// Get snapshot deltas from the last 7 days with their x-position for the chart
    /// Shows discrete K/D and KDA for each gaming session (delta from previous snapshot)
    private var snapshotsForChart: [(sessionKD: Double, sessionKDA: Double, xPosition: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let allSnapshots = snapshots.sorted { $0.timestamp < $1.timestamp }

        guard !allSnapshots.isEmpty else { return [] }

        // Build a mapping of day -> chart index by mirroring the last7Days logic
        var dayToChartIndex: [Date: Int] = [:]
        var chartIndex = 0

        for dayOffset in (0..<7).reversed() {
            guard let targetDay = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }

            let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay)!

            let daySnapshots = allSnapshots.filter { snapshot in
                snapshot.timestamp >= targetDay && snapshot.timestamp < nextDay
            }

            if !daySnapshots.isEmpty {
                dayToChartIndex[targetDay] = chartIndex
                chartIndex += 1
            }
        }

        // Calculate discrete K/D and KDA for each snapshot
        var result: [(sessionKD: Double, sessionKDA: Double, xPosition: Double)] = []

        for dayOffset in (0..<7).reversed() {
            guard let targetDay = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }

            let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay)!

            let daySnapshots = allSnapshots.filter { snapshot in
                snapshot.timestamp >= targetDay && snapshot.timestamp < nextDay
            }.sorted { $0.timestamp < $1.timestamp }

            guard !daySnapshots.isEmpty,
                  let dayChartIndex = dayToChartIndex[targetDay] else {
                continue
            }

            let snapshotCount = daySnapshots.count

            for (index, snapshot) in daySnapshots.enumerated() {
                let inDayOffset = snapshotCount > 1 ? Double(index) / Double(snapshotCount - 1) : 0.5
                let xPos = Double(dayChartIndex) + (inDayOffset * 0.8) - 0.4

                // Get previous snapshot to calculate deltas
                let previousSnapshot: StatsSnapshot?
                if index > 0 {
                    previousSnapshot = daySnapshots[index - 1]
                } else {
                    previousSnapshot = allSnapshots.last { $0.timestamp < targetDay }
                }

                let deltaKills: Int
                let deltaDeaths: Int
                let deltaAssists: Int

                if let prev = previousSnapshot {
                    deltaKills = snapshot.kills - prev.kills
                    deltaDeaths = snapshot.deaths - prev.deaths
                    deltaAssists = snapshot.assists - prev.assists
                } else {
                    deltaKills = snapshot.kills
                    deltaDeaths = snapshot.deaths
                    deltaAssists = snapshot.assists
                }

                // Calculate discrete session K/D and KDA
                let sessionKD = deltaDeaths > 0 ? Double(deltaKills) / Double(deltaDeaths) : Double(deltaKills)
                let sessionKDA = deltaDeaths > 0 ? Double(deltaKills + deltaAssists) / Double(deltaDeaths) : Double(deltaKills + deltaAssists)

                result.append((sessionKD: sessionKD, sessionKDA: sessionKDA, xPosition: xPos))
            }
        }

        return result
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
        VStack(alignment: .leading, spacing: 20) {
            if currentSnapshot != nil {
                // Most Recent Performance - unified container
                mostRecentPerformanceCard
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 7-day trend (full width) - show if we have at least 2 days of data
                // Kept separate as it's a historical view, not "most recent"
                if last7Days.count >= 2 {
                    kdKdaTrendView
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // No data state
                emptyState
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { snapshots = historyManager.getAllSnapshots() }
        .onChange(of: historyManager.snapshotVersion) { _, _ in
            snapshots = historyManager.getAllSnapshots()
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

    // MARK: - Most Recent Performance Card (Unified Container)

    private var mostRecentPerformanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            header

            // Main comparison cards
            mainStatsGrid

            // Collapsible sub-sections
            VStack(alignment: .leading, spacing: 12) {
                // Maps Played - Collapsible
                mapsPlayedDisclosure

                // Combat Breakdown - Collapsible
                combatBreakdownDisclosure
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Maps Played Disclosure

    private var mapsPlayedDisclosure: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Disclosure header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMapsExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isMapsExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Image(systemName: "map.fill")
                        .font(.subheadline)
                        .foregroundStyle(accentColor)

                    Text("Maps Played")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)

                    // Badge showing count
                    if let count = mapsPlayedCount, count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor)
                            .cornerRadius(8)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable content
            if isMapsExpanded {
                MapsPlayedContent()
                    .environmentObject(historyManager)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(accentColor.opacity(0.1), lineWidth: 1)
        )
    }

    private var mapsPlayedCount: Int? {
        let snapshots = historyManager.getRecentSnapshots(limit: 2)
        guard let latest = snapshots.first,
              snapshots.count >= 2 else {
            return nil
        }
        let previous = snapshots[1]
        return latest.mapsPlayedSince(previous).count
    }

    // MARK: - Combat Breakdown Disclosure

    private var combatBreakdownDisclosure: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Disclosure header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCombatBreakdownExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isCombatBreakdownExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Image(systemName: "chart.bar.fill")
                        .font(.subheadline)
                        .foregroundStyle(accentColor)

                    Text("Combat Breakdown")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    // Show comparison context
                    HStack(spacing: 4) {
                        Image(systemName: isComparingToYesterday ? "calendar" : "chart.bar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(isComparingToYesterday ? "vs Yesterday" : "vs Historical Avg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable content
            if isCombatBreakdownExpanded {
                combatBreakdownContent
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(accentColor.opacity(0.1), lineWidth: 1)
        )
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
                        .foregroundStyle(accentColor)

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
                        .fill(accentColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
                )
            }
        }
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
                format: "%.1f",
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
                    
                    // Tooltip toggle
                    Button(action: {
                        showTooltips.toggle()
                    }) {
                        Image(systemName: showTooltips ? "info.circle.fill" : "info.circle")
                            .font(.caption)
                            .foregroundColor(showTooltips ? accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle hover tooltips")

                    HStack(spacing: 12) {
                        // K/D value
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Theme.warning)
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
                                .fill(Theme.info)
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
                    Text("Stacked bars show session K/D (orange) and KDA (cyan) for each snapshot. Lines show daily averages.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Dual-line chart
            Chart {
                // Snapshot bars - K/D (draw first, will be overlaid by KDA)
                ForEach(Array(snapshotsForChart.enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("Position", item.xPosition),
                        y: .value("K/D", item.sessionKD)
                    )
                    .foregroundStyle(.orange.opacity(0.4))
                    .cornerRadius(2)
                }

                // Snapshot bars - KDA (stacked on top of K/D)
                ForEach(Array(snapshotsForChart.enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("Position", item.xPosition),
                        yStart: .value("K/D", item.sessionKD),
                        yEnd: .value("KDA", item.sessionKDA)
                    )
                    .foregroundStyle(.cyan.opacity(0.4))
                    .cornerRadius(2)
                }

                // K/D trend line (daily averages)
                ForEach(Array(last7Days.enumerated()), id: \.offset) { index, performance in
                    LineMark(
                        x: .value("Day", Double(index)),
                        y: .value("Value", performance.dailyKD),
                        series: .value("Metric", "K/D")
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                    .symbol {
                        Circle()
                            .fill(Theme.warning)
                            .stroke(.white, lineWidth: 1.5)
                            .frame(width: 8, height: 8)
                    }
                }

                // KDA trend line (daily averages)
                ForEach(Array(last7Days.enumerated()), id: \.offset) { index, performance in
                    LineMark(
                        x: .value("Day", Double(index)),
                        y: .value("Value", performance.computedDailyKDA),
                        series: .value("Metric", "KDA")
                    )
                    .foregroundStyle(.cyan)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                    .symbol {
                        Circle()
                            .fill(Theme.info)
                            .stroke(.white, lineWidth: 1.5)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(String(format: "%.1f", doubleValue))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: kdKdaChartYDomain)
            .chartLegend(.hidden)
            .frame(height: 120)
            .chartXSelection(value: $selectedChartPosition)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if showTooltips,
                       let position = selectedChartPosition,
                       let snapshot = snapshotsForChart.first(where: { abs($0.xPosition - position) < 0.15 }),
                       let barX = proxy.position(forX: snapshot.xPosition) {
                        
                        let tooltipX = barX + geometry[proxy.plotFrame!].origin.x
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 6, height: 6)
                                Text("K/D:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f", snapshot.sessionKD))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.cyan)
                                    .frame(width: 6, height: 6)
                                Text("KDA:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f", snapshot.sessionKDA))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .position(x: tooltipX, y: -20)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeInOut(duration: 0.15), value: selectedChartPosition)
                    }
                }
            }

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
                        .fill(Theme.warning)
                        .frame(width: 20, height: 3)
                        .cornerRadius(1.5)
                    Text("K/D")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // KDA legend
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Theme.info)
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

    @State private var showCombatBreakdownInfo = false

    private var combatBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with info button
            HStack {
                Text("Combat Breakdown")
                    .font(.headline)
                    .fontWeight(.bold)

                Button {
                    showCombatBreakdownInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Learn about this section")
                .popover(isPresented: $showCombatBreakdownInfo, arrowEdge: .bottom) {
                    combatBreakdownInfoPopover
                }

                Spacer()

                // Show comparison context
                HStack(spacing: 4) {
                    Image(systemName: isComparingToYesterday ? "calendar" : "chart.bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(isComparingToYesterday ? "vs Yesterday" : "vs Historical Avg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let todayAvg = todayAveragePerformance, let baselineAvg = comparisonBaseline {
                VStack(spacing: 12) {
                    // Headshots per match
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.headshotsPerMatch,
                        yesterdayValue: baselineAvg.headshotsPerMatch,
                        label: "Headshots / Match",
                        accentColor: $headshotsColor,
                        delay: 0.0,
                        shouldAnimate: !hasAnimated
                    )

                    // Accuracy
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.accuracy,
                        yesterdayValue: baselineAvg.accuracy,
                        label: "Accuracy",
                        accentColor: $accuracyColor,
                        delay: 0.1,
                        shouldAnimate: !hasAnimated
                    )

                    // KPM
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.killsPerMinute,
                        yesterdayValue: baselineAvg.killsPerMinute,
                        label: "Kills Per Minute",
                        accentColor: $kpmColor,
                        delay: 0.2,
                        shouldAnimate: !hasAnimated
                    )

                    // Assists per match
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.assistsPerMatch,
                        yesterdayValue: baselineAvg.assistsPerMatch,
                        label: "Assists / Match",
                        accentColor: $assistsColor,
                        delay: 0.3,
                        shouldAnimate: !hasAnimated
                    )

                    // Win Rate
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.winRate,
                        yesterdayValue: baselineAvg.winRate,
                        label: "Win Rate",
                        accentColor: $winRateColor,
                        delay: 0.4,
                        shouldAnimate: !hasAnimated
                    )

                    // Score per match
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.scorePerMatch / 1000,
                        yesterdayValue: baselineAvg.scorePerMatch / 1000,
                        label: "Score / Match (K)",
                        accentColor: $scoreColor,
                        delay: 0.5,
                        shouldAnimate: !hasAnimated
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .onAppear {
                    if !hasAnimated {
                        // Mark as animated after a delay to ensure all bars have started
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                            hasAnimated = true
                        }
                    }
                }
            } else {
                // No data available
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No snapshot data for today.  Play some matches to see your combat breakdown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
            }
        }
    }

    // MARK: - Combat Breakdown Content (for disclosure group)

    private var combatBreakdownContent: some View {
        Group {
            if let todayAvg = todayAveragePerformance, let baselineAvg = comparisonBaseline {
                VStack(spacing: 10) {
                    // Info button row
                    HStack {
                        Spacer()
                        Button {
                            showCombatBreakdownInfo = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                Text("What's this?")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showCombatBreakdownInfo, arrowEdge: .bottom) {
                            combatBreakdownInfoPopover
                        }
                    }

                    // Headshots per match
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.headshotsPerMatch,
                        yesterdayValue: baselineAvg.headshotsPerMatch,
                        label: "Headshots / Match",
                        accentColor: $headshotsColor,
                        delay: 0.0,
                        shouldAnimate: !hasAnimated
                    )

                    // Accuracy
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.accuracy,
                        yesterdayValue: baselineAvg.accuracy,
                        label: "Accuracy",
                        accentColor: $accuracyColor,
                        delay: 0.1,
                        shouldAnimate: !hasAnimated
                    )

                    // KPM
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.killsPerMinute,
                        yesterdayValue: baselineAvg.killsPerMinute,
                        label: "Kills Per Minute",
                        accentColor: $kpmColor,
                        delay: 0.2,
                        shouldAnimate: !hasAnimated
                    )

                    // Assists per match
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.assistsPerMatch,
                        yesterdayValue: baselineAvg.assistsPerMatch,
                        label: "Assists / Match",
                        accentColor: $assistsColor,
                        delay: 0.3,
                        shouldAnimate: !hasAnimated
                    )

                    // Win Rate
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.winRate,
                        yesterdayValue: baselineAvg.winRate,
                        label: "Win Rate",
                        accentColor: $winRateColor,
                        delay: 0.4,
                        shouldAnimate: !hasAnimated
                    )

                    // Score per match
                    AnimatedComparisonProgressBar(
                        todayValue: todayAvg.scorePerMatch / 1000,
                        yesterdayValue: baselineAvg.scorePerMatch / 1000,
                        label: "Score / Match (K)",
                        accentColor: $scoreColor,
                        delay: 0.5,
                        shouldAnimate: !hasAnimated
                    )
                }
                .onAppear {
                    if !hasAnimated {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                            hasAnimated = true
                        }
                    }
                }
            } else {
                // No data available
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No snapshot data available. Play some matches to see your combat breakdown.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
    }

    private var combatBreakdownInfoPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(accentColor)
                Text("Combat Breakdown")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Divider()

            Text("This section shows your **average performance per match** for today compared to a baseline.")
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("**vs Yesterday**: Compares today's averages to yesterday's averages")
                        .font(.caption)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundStyle(.orange)
                }

                Label {
                    Text("**vs Historical**: When yesterday's data isn't available, compares to your overall historical average")
                        .font(.caption)
                } icon: {
                    Image(systemName: "chart.bar")
                        .foregroundStyle(.purple)
                }
            }

            Divider()

            Text("Why averages?")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Comparing averages per match gives a fair comparison regardless of how many matches you've played. Playing 3 matches today vs 10 yesterday? The averages normalize for that difference.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button {
                    showCombatBreakdownInfo = false
                } label: {
                    Text("Got it")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(accentColor)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 320)
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
    @Binding var accentColor: Color
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
                HStack(spacing: 6) {
                    ColorPickerDot(color: $accentColor, dotSize: 10)
                    Text(label)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }

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

/// Average combat performance metrics per match
/// Used for normalized comparisons in Combat Breakdown
struct CombatAverages {
    let headshotsPerMatch: Double
    let assistsPerMatch: Double
    let accuracy: Double
    let killsPerMinute: Double
    let winRate: Double
    let scorePerMatch: Double
    let matchesPlayed: Int
}

#Preview {
    TodayVsYesterdayView()
        .environmentObject(HistoryManager.shared)
        .frame(width: 1200, height: 800)
}
