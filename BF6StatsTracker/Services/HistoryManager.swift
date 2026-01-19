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
//  HistoryManager.swift
//  BF6StatsTracker
//
//  Manages stat snapshots and session tracking using SwiftData
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    var modelContext: ModelContext?  // Made public for access from SettingsView
    private var currentSession: PlaySession?

    @Published var snapshots: [StatsSnapshot] = []
    @Published var sessions: [PlaySession] = []
    @Published var recentSnapshots: [StatsSnapshot] = []
    @Published var todayPerformance: DailyPerformance?
    @Published var yesterdayPerformance: DailyPerformance?
    @Published var recentDailyPerformances: [DailyPerformance] = []

    private var currentDailyPerformance: DailyPerformance?

    private init() {}

    /// Initialize with SwiftData model context
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Clear any corrupt data on startup
        // This prevents crashes from stale object references
        clearCorruptData()
    }

    /// Clear any corrupt DailyPerformance objects that reference deleted snapshots
    private func clearCorruptData() {
        guard let context = modelContext else { return }

        // Check if we've already done this cleanup
        let hasCleanedKey = "HasCleanedCorruptDailyPerformance_v2"
        if UserDefaults.standard.bool(forKey: hasCleanedKey) {
            // Already cleaned up, skip
            return
        }

        // Delete ALL DailyPerformance objects to prevent stale reference crashes
        // Wrap in do-catch because even fetching corrupt data can crash
        do {
            let descriptor = FetchDescriptor<DailyPerformance>()
            let allPerformances = try context.fetch(descriptor)
            logInfo("Clearing \(allPerformances.count) DailyPerformance objects to fix stale references", category: .cleanup)
            for performance in allPerformances {
                context.delete(performance)
            }
            try context.save()
            logSuccess("Cleared corrupt DailyPerformance data", category: .success)

            // Mark as cleaned only if successful
            UserDefaults.standard.set(true, forKey: hasCleanedKey)
        } catch {
            // If we can't even fetch DailyPerformance objects, the corruption is severe
            // Delete the entire DailyPerformance table by deleting all data
            logWarning("Severe corruption detected, performing emergency cleanup: \(error)", category: .general)

            // Try to delete using executeDelete (bypasses object loading)
            do {
                try context.delete(model: DailyPerformance.self)
                try context.save()
                logSuccess("Emergency cleanup successful", category: .success)
                UserDefaults.standard.set(true, forKey: hasCleanedKey)
            } catch {
                logWarning("Emergency cleanup failed: \(error)", category: .general)
                // Mark as cleaned anyway to prevent infinite loops
                UserDefaults.standard.set(true, forKey: hasCleanedKey)
            }
        }

        // Clear the published properties
        todayPerformance = nil
        yesterdayPerformance = nil
        recentDailyPerformances = []
    }

    // MARK: - Snapshots

    /// Save a stats snapshot only when a match has been completed
    /// A match is considered completed when BOTH conditions are met:
    /// 1. matchesPlayed has increased by at least 1
    /// 2. timePlayed has increased (any amount)
    func saveSnapshot(from stats: PlayerStats, sessionId: UUID? = nil, eaId: String? = nil, progressionMode: String? = nil, playSoundNotification: Bool = true, settings: AppSettings? = nil) {
        guard let context = modelContext else { return }

        let newSnapshot = StatsSnapshot(from: stats, sessionId: sessionId, eaId: eaId, progressionMode: progressionMode)

        // Get the most recent snapshot for comparison
        let recentSnapshots = getRecentSnapshots(limit: 1)
        if let mostRecent = recentSnapshots.first {
            // Calculate deltas to detect match completion
            let matchDelta = newSnapshot.matchesPlayed - mostRecent.matchesPlayed
            let timeDelta = newSnapshot.timePlayed - mostRecent.timePlayed

            // Match completion criteria:
            // - At least 1 match completed (handles multiple matches between refreshes)
            // - Time has increased (confirms actual play time, regardless of duration)
            let matchCompleted = matchDelta >= 1 && timeDelta > 0

            if !matchCompleted {
                return
            }

            // Play sound notification if enabled
            if playSoundNotification, let settings = settings {
                SoundNotificationService.shared.playMatchCompletionSound(settings: settings)
            }
        }

        // Match completed or first snapshot, save it
        context.insert(newSnapshot)

        if let session = currentSession {
            session.snapshots.append(newSnapshot)
        }

        // Update or create daily performance
        updateDailyPerformance(with: newSnapshot, playerName: stats.userName, platform: stats.platform)

        try? context.save()
        loadRecentData()
        loadDailyPerformances(playerName: stats.userName)
    }

    /// Create a synthetic snapshot for debugging (randomly increments stats)
    func createSyntheticSnapshot() {
        guard let context = modelContext else { return }

        // Get the most recent snapshot as a base
        let recentSnapshots = getRecentSnapshots(limit: 1)
        guard let baseSnapshot = recentSnapshots.first else {
            return
        }

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        // Create 10 snapshots for yesterday
        var yesterdayBase = baseSnapshot.kills
        var yesterdayDeaths = baseSnapshot.deaths
        var yesterdayMatches = baseSnapshot.matchesPlayed
        var yesterdayHeadshots = baseSnapshot.headshots
        var yesterdayAssists = baseSnapshot.assists
        var yesterdayScore = baseSnapshot.totalScore
        var yesterdayRevives = baseSnapshot.revives
        var yesterdayResupplies = baseSnapshot.resupplies
        var yesterdayTimePlayed = baseSnapshot.timePlayed
        var yesterdayWins = baseSnapshot.wins
        var yesterdayLosses = baseSnapshot.losses

        for i in 0..<10 {
            let killsIncrease = Int.random(in: 1...20)
            let deathsIncrease = Int.random(in: 0...3)
            let matchesIncrease = Int.random(in: 0...10)
            let headshotsIncrease = Int.random(in: 0...5)
            let assistsIncrease = Int.random(in: 0...10)
            let scoreIncrease = Int.random(in: 1000...5000)
            let revivesIncrease = Int.random(in: 0...5)
            let resuppliesIncrease = Int.random(in: 0...8)
            let timeIncrease = Int.random(in: 600...3600)

            yesterdayBase += killsIncrease
            yesterdayDeaths += deathsIncrease
            yesterdayMatches += matchesIncrease
            yesterdayHeadshots += headshotsIncrease
            yesterdayAssists += assistsIncrease
            yesterdayScore += scoreIncrease
            yesterdayRevives += revivesIncrease
            yesterdayResupplies += resuppliesIncrease
            yesterdayTimePlayed += timeIncrease
            yesterdayWins += (matchesIncrease > 0 ? Int.random(in: 0...matchesIncrease) : 0)
            yesterdayLosses += (matchesIncrease > 0 ? Int.random(in: 0...matchesIncrease) : 0)

            let snapshot = StatsSnapshot(
                playerName: baseSnapshot.playerName,
                platform: baseSnapshot.platform,
                eaId: baseSnapshot.eaId,
                kills: yesterdayBase,
                deaths: yesterdayDeaths,
                wins: yesterdayWins,
                losses: yesterdayLosses,
                matchesPlayed: yesterdayMatches,
                totalScore: yesterdayScore,
                timePlayed: yesterdayTimePlayed,
                headshots: yesterdayHeadshots,
                assists: yesterdayAssists,
                revives: yesterdayRevives,
                resupplies: yesterdayResupplies,
                sessionId: nil
            )

            // Set timestamp to yesterday with progressive hours
            let hourOffset = TimeInterval(i * 2 * 3600) // Every 2 hours
            snapshot.timestamp = calendar.date(byAdding: .second, value: Int(hourOffset), to: calendar.startOfDay(for: yesterday)) ?? yesterday

            context.insert(snapshot)
            updateDailyPerformance(with: snapshot, playerName: snapshot.playerName, platform: snapshot.platform)
        }

        // Now create 1 snapshot for today
        let killsIncrease = Int.random(in: 1...20)
        let deathsIncrease = Int.random(in: 0...3)
        let matchesIncrease = Int.random(in: 0...10)
        let headshotsIncrease = Int.random(in: 0...5)
        let assistsIncrease = Int.random(in: 0...10)
        let scoreIncrease = Int.random(in: 1000...5000)
        let revivesIncrease = Int.random(in: 0...5)
        let resuppliesIncrease = Int.random(in: 0...8)

        let todaySnapshot = StatsSnapshot(
            playerName: baseSnapshot.playerName,
            platform: baseSnapshot.platform,
            eaId: baseSnapshot.eaId,
            kills: yesterdayBase + killsIncrease,
            deaths: yesterdayDeaths + deathsIncrease,
            wins: yesterdayWins + (matchesIncrease > 0 ? Int.random(in: 0...matchesIncrease) : 0),
            losses: yesterdayLosses + (matchesIncrease > 0 ? Int.random(in: 0...matchesIncrease) : 0),
            matchesPlayed: yesterdayMatches + matchesIncrease,
            totalScore: yesterdayScore + scoreIncrease,
            timePlayed: yesterdayTimePlayed + Int.random(in: 600...3600),
            headshots: yesterdayHeadshots + headshotsIncrease,
            assists: yesterdayAssists + assistsIncrease,
            revives: yesterdayRevives + revivesIncrease,
            resupplies: yesterdayResupplies + resuppliesIncrease,
            sessionId: nil
        )

        context.insert(todaySnapshot)

        updateDailyPerformance(with: todaySnapshot, playerName: todaySnapshot.playerName, platform: todaySnapshot.platform)

        try? context.save()
        loadRecentData()
        loadDailyPerformances(playerName: baseSnapshot.playerName)
    }

    /// Get snapshots for a date range
    func getSnapshots(from startDate: Date, to endDate: Date) -> [StatsSnapshot] {
        guard let context = modelContext else { return [] }

        let predicate = #Predicate<StatsSnapshot> { snapshot in
            snapshot.timestamp >= startDate && snapshot.timestamp <= endDate
        }

        let descriptor = FetchDescriptor<StatsSnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Get last N snapshots
    func getRecentSnapshots(limit: Int = 20) -> [StatsSnapshot] {
        guard let context = modelContext else { return [] }

        var descriptor = FetchDescriptor<StatsSnapshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Get all snapshots (no limit)
    func getAllSnapshots() -> [StatsSnapshot] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<StatsSnapshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Sessions

    /// Start a new play session
    func startSession(playerName: String, platform: String) {
        guard let context = modelContext else { return }

        // End current session if exists
        if currentSession != nil {
            // Session will be ended when next snapshot is saved
        }

        let session = PlaySession(playerName: playerName, platform: platform)
        context.insert(session)
        currentSession = session

        try? context.save()
    }

    /// End the current session
    func endSession(with finalStats: PlayerStats) {
        guard let context = modelContext, let session = currentSession else { return }

        let finalSnapshot = StatsSnapshot(from: finalStats, sessionId: session.id)
        session.endSession(with: finalSnapshot)
        context.insert(finalSnapshot)

        try? context.save()
        currentSession = nil
        loadRecentData()
    }

    /// Get all sessions
    func getAllSessions() -> [PlaySession] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<PlaySession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Get recent sessions
    func getRecentSessions(limit: Int = 10) -> [PlaySession] {
        guard let context = modelContext else { return [] }

        var descriptor = FetchDescriptor<PlaySession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Analytics

    /// Calculate K/D trend over time
    func getKDTrend(days: Int = 7) -> [(Date, Double)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = getSnapshots(from: startDate, to: Date())

        // Convert cumulative K/D to daily K/D ratios based on deltas
        guard snapshots.count >= 2 else {
            return snapshots.map { ($0.timestamp, $0.kdRatio) }
        }

        var dailyKDs: [(Date, Double)] = []
        // Snapshots are in reverse order (newest first at index 0)
        for i in 0..<snapshots.count - 1 {
            let newer = snapshots[i]      // Newer snapshot (earlier index)
            let older = snapshots[i + 1]  // Older snapshot (later index)
            let killDelta = newer.kills - older.kills
            let deathDelta = newer.deaths - older.deaths
            let dailyKD = deathDelta > 0 ? Double(killDelta) / Double(deathDelta) : Double(killDelta)
            dailyKDs.append((newer.timestamp, max(0, dailyKD))) // Use max to avoid negative K/D
        }

        return dailyKDs.reversed() // Return in chronological order (oldest first)
    }

    /// Calculate kills per minute trend
    func getKPMTrend(days: Int = 7) -> [(Date, Double)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = getSnapshots(from: startDate, to: Date())

        return snapshots.map { ($0.timestamp, $0.killsPerMinute) }
    }

    /// Calculate kills trend - returns daily kill deltas
    func getKillsTrend(days: Int = 7) -> [(Date, Int)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = getSnapshots(from: startDate, to: Date())

        // Convert cumulative kills to daily deltas
        guard snapshots.count >= 2 else {
            return snapshots.map { ($0.timestamp, $0.kills) }
        }

        var deltas: [(Date, Int)] = []
        // Snapshots are in reverse order (newest first at index 0)
        for i in 0..<snapshots.count - 1 {
            let newer = snapshots[i]      // Newer snapshot (earlier index)
            let older = snapshots[i + 1]  // Older snapshot (later index)
            let killDelta = newer.kills - older.kills
            deltas.append((newer.timestamp, max(0, killDelta))) // Use max to avoid negative deltas
        }

        return deltas.reversed() // Return in chronological order (oldest first)
    }

    /// Calculate assists trend - returns daily assist deltas
    func getAssistsTrend(days: Int = 7) -> [(Date, Int)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = getSnapshots(from: startDate, to: Date())

        // Convert cumulative assists to daily deltas
        guard snapshots.count >= 2 else {
            return snapshots.map { ($0.timestamp, $0.assists) }
        }

        var deltas: [(Date, Int)] = []
        // Snapshots are in reverse order (newest first at index 0)
        for i in 0..<snapshots.count - 1 {
            let newer = snapshots[i]      // Newer snapshot (earlier index)
            let older = snapshots[i + 1]  // Older snapshot (later index)
            let assistDelta = newer.assists - older.assists
            deltas.append((newer.timestamp, max(0, assistDelta))) // Use max to avoid negative deltas
        }

        return deltas.reversed() // Return in chronological order (oldest first)
    }

    /// Calculate W/L ratio trend - returns daily W/L ratios based on deltas
    func getWLTrend(days: Int = 7) -> [(Date, Double)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = getSnapshots(from: startDate, to: Date())

        // Convert cumulative W/L to daily W/L ratios based on deltas
        guard snapshots.count >= 2 else {
            return snapshots.map { snapshot -> (Date, Double) in
                let wlRatio = snapshot.losses > 0 ? Double(snapshot.wins) / Double(snapshot.losses) : Double(snapshot.wins)
                return (snapshot.timestamp, wlRatio)
            }
        }

        var dailyWLs: [(Date, Double)] = []
        // Snapshots are in reverse order (newest first at index 0)
        for i in 0..<snapshots.count - 1 {
            let newer = snapshots[i]      // Newer snapshot (earlier index)
            let older = snapshots[i + 1]  // Older snapshot (later index)
            let winDelta = newer.wins - older.wins
            let lossDelta = newer.losses - older.losses

            // Calculate daily W/L ratio
            let dailyWL: Double
            if lossDelta > 0 {
                dailyWL = Double(winDelta) / Double(lossDelta)
            } else if winDelta > 0 {
                dailyWL = Double(winDelta) // All wins, no losses
            } else {
                dailyWL = 0.0 // No games played
            }

            dailyWLs.append((newer.timestamp, max(0, dailyWL)))
        }

        return dailyWLs.reversed() // Return in chronological order (oldest first)
    }

    /// Get performance summary for period
    func getPerformanceSummary(days: Int = 7) -> PerformanceSummary? {
        let snapshots = getKDTrend(days: days)
        guard !snapshots.isEmpty else { return nil }

        let kdValues = snapshots.map { $0.1 }
        let avgKD = kdValues.reduce(0, +) / Double(kdValues.count)
        let maxKD = kdValues.max() ?? 0
        let minKD = kdValues.min() ?? 0

        return PerformanceSummary(
            averageKD: avgKD,
            maxKD: maxKD,
            minKD: minKD,
            trend: calculateTrend(values: kdValues),
            snapshotCount: snapshots.count
        )
    }

    private func calculateTrend(values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }

        // Values are now in chronological order (oldest first) after our delta calculations
        let firstHalf = values.prefix(values.count / 2)  // Older period
        let secondHalf = values.suffix(values.count / 2) // Recent period

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        // Guard against division by zero or very small averages
        guard firstAvg > 0.01 else {
            // If old average is near zero, just compare absolute values
            if secondAvg > firstAvg + 0.5 {
                return .improving
            } else if secondAvg < firstAvg - 0.5 {
                return .declining
            } else {
                return .stable
            }
        }

        let difference = secondAvg - firstAvg  // Recent - Old (positive = improving)
        let percentChange = (difference / firstAvg) * 100

        // Use 5% threshold for trend detection
        if percentChange > 5 {
            return .improving
        } else if percentChange < -5 {
            return .declining
        } else {
            return .stable
        }
    }

    /// Calculate trend for kills (using Int values)
    func calculateKillsTrend(days: Int = 7) -> TrendDirection {
        let killsData = getKillsTrend(days: days)
        guard !killsData.isEmpty else { return .stable }

        let values = killsData.map { Double($0.1) }
        return calculateTrend(values: values)
    }

    /// Calculate trend for assists (using Int values)
    func calculateAssistsTrend(days: Int = 7) -> TrendDirection {
        let assistsData = getAssistsTrend(days: days)
        guard !assistsData.isEmpty else { return .stable }

        let values = assistsData.map { Double($0.1) }
        return calculateTrend(values: values)
    }

    /// Calculate trend for K/D ratio
    func calculateKDTrend(days: Int = 7) -> TrendDirection {
        let kdData = getKDTrend(days: days)
        guard !kdData.isEmpty else { return .stable }

        let values = kdData.map { $0.1 }
        return calculateTrend(values: values)
    }

    /// Calculate trend for W/L ratio
    func calculateWLTrend(days: Int = 7) -> TrendDirection {
        let wlData = getWLTrend(days: days)
        guard !wlData.isEmpty else { return .stable }

        let values = wlData.map { $0.1 }
        return calculateTrend(values: values)
    }

    func loadRecentData() {  // Made public for refresh after clearing
        // Note: Views now use @Query to automatically get snapshots
        // Clear all cached data to prevent stale references
        // Views should use @Query instead
        recentSnapshots = []
        snapshots = []
        sessions = []
    }

    // MARK: - Daily Performance

    /// Update or create daily performance for the current day
    private func updateDailyPerformance(with snapshot: StatsSnapshot, playerName: String, platform: String) {
        guard let context = modelContext else { return }

        let today = Calendar.current.startOfDay(for: Date())

        // Try to find existing daily performance for today
        do {
            let predicate = #Predicate<DailyPerformance> { performance in
                performance.date == today && performance.playerName == playerName
            }

            let descriptor = FetchDescriptor<DailyPerformance>(predicate: predicate)
            let existingPerformances = try context.fetch(descriptor)

            if let existing = existingPerformances.first {
                // Update existing daily performance
                existing.update(with: snapshot)
                currentDailyPerformance = existing
            } else {
                // Create new daily performance for today
                // Use yesterday's last snapshot as the starting point
                let startSnapshot = getLastSnapshotFromYesterday(playerName: playerName) ?? snapshot

                let newPerformance = DailyPerformance(
                    date: today,
                    playerName: playerName,
                    platform: platform,
                    startSnapshot: startSnapshot
                )
                context.insert(newPerformance)
                currentDailyPerformance = newPerformance

                // End any previous active daily performance
                endPreviousDailyPerformances(playerName: playerName, platform: platform)
            }

            try? context.save()
        } catch {
            logWarning("Error updating DailyPerformance: \(error)", category: .general)
            UserDefaults.standard.set(false, forKey: "HasCleanedCorruptDailyPerformance_v1")
        }
    }

    /// Get the last snapshot from yesterday for a given player
    private func getLastSnapshotFromYesterday(playerName: String) -> StatsSnapshot? {
        guard let context = modelContext else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return nil
        }

        do {
            // Find yesterday's DailyPerformance
            let predicate = #Predicate<DailyPerformance> { performance in
                performance.date == yesterday && performance.playerName == playerName
            }

            let descriptor = FetchDescriptor<DailyPerformance>(predicate: predicate)
            let yesterdayPerformances = try context.fetch(descriptor)

            // Return yesterday's end snapshot (which is the last snapshot of the day)
            return yesterdayPerformances.first?.endSnapshot
        } catch {
            return nil
        }
    }

    /// End all previous active daily performances (from previous days)
    private func endPreviousDailyPerformances(playerName: String, platform: String) {
        guard let context = modelContext else { return }

        do {
            let today = Calendar.current.startOfDay(for: Date())

            let predicate = #Predicate<DailyPerformance> { performance in
                performance.date < today && performance.isActive && performance.playerName == playerName
            }

            let descriptor = FetchDescriptor<DailyPerformance>(predicate: predicate)
            let previousPerformances = try context.fetch(descriptor)

            for performance in previousPerformances {
                performance.endSession()
            }

            try? context.save()
        } catch {
            logWarning("Error ending previous DailyPerformance objects: \(error)", category: .general)
            UserDefaults.standard.set(false, forKey: "HasCleanedCorruptDailyPerformance_v1")
        }
    }

    /// Load daily performances
    /// - Parameter playerName: Optional player name to filter by. If nil, loads for any player.
    func loadDailyPerformances(playerName: String? = nil) {
        guard let context = modelContext else { return }

        // Wrap all DailyPerformance fetches in try-catch to handle corrupt data
        do {
            let today = Calendar.current.startOfDay(for: Date())

            // Load today's performance
            if let playerName = playerName {
                let todayPredicate = #Predicate<DailyPerformance> { performance in
                    performance.date == today && performance.playerName == playerName
                }
                let todayDescriptor = FetchDescriptor<DailyPerformance>(predicate: todayPredicate)
                todayPerformance = try context.fetch(todayDescriptor).first
            } else {
                let todayPredicate = #Predicate<DailyPerformance> { performance in
                    performance.date == today
                }
                let todayDescriptor = FetchDescriptor<DailyPerformance>(predicate: todayPredicate)
                todayPerformance = try context.fetch(todayDescriptor).first
            }

            // Load last performance (most recent non-today performance)
            if let playerName = playerName {
                let lastPlayedPredicate = #Predicate<DailyPerformance> { performance in
                    performance.date < today && performance.playerName == playerName
                }
                var lastPlayedDescriptor = FetchDescriptor<DailyPerformance>(
                    predicate: lastPlayedPredicate,
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                lastPlayedDescriptor.fetchLimit = 1
                yesterdayPerformance = try context.fetch(lastPlayedDescriptor).first
            } else {
                let lastPlayedPredicate = #Predicate<DailyPerformance> { performance in
                    performance.date < today
                }
                var lastPlayedDescriptor = FetchDescriptor<DailyPerformance>(
                    predicate: lastPlayedPredicate,
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                lastPlayedDescriptor.fetchLimit = 1
                yesterdayPerformance = try context.fetch(lastPlayedDescriptor).first
            }

            // Load recent daily performances (last 30 days)
            recentDailyPerformances = getRecentDailyPerformances(days: 30, playerName: playerName)
        } catch {
            // If we can't fetch (likely due to corrupt data), reset the cleanup flag
            logWarning("Error loading DailyPerformance objects: \(error)", category: .general)
            UserDefaults.standard.set(false, forKey: "HasCleanedCorruptDailyPerformance_v1")
            todayPerformance = nil
            yesterdayPerformance = nil
            recentDailyPerformances = []
        }
    }

    /// Get daily performances for the last N days
    /// - Parameters:
    ///   - days: Number of days to retrieve (default: 30)
    ///   - playerName: Optional player name to filter by. If nil, returns all players.
    func getRecentDailyPerformances(days: Int = 30, playerName: String? = nil) -> [DailyPerformance] {
        guard let context = modelContext else { return [] }

        do {
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let startOfDay = Calendar.current.startOfDay(for: startDate)

            let descriptor: FetchDescriptor<DailyPerformance>

            if let playerName = playerName {
                let predicate = #Predicate<DailyPerformance> { performance in
                    performance.date >= startOfDay && performance.playerName == playerName
                }
                descriptor = FetchDescriptor<DailyPerformance>(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                let predicate = #Predicate<DailyPerformance> { performance in
                    performance.date >= startOfDay
                }
                descriptor = FetchDescriptor<DailyPerformance>(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }

            return try context.fetch(descriptor)
        } catch {
            logWarning("Error fetching recent DailyPerformance objects: \(error)", category: .general)
            UserDefaults.standard.set(false, forKey: "HasCleanedCorruptDailyPerformance_v1")
            return []
        }
    }

    /// Get daily performance for a specific date
    func getDailyPerformance(for date: Date) -> DailyPerformance? {
        guard let context = modelContext else { return nil }

        do {
            let targetDate = Calendar.current.startOfDay(for: date)

            let predicate = #Predicate<DailyPerformance> { performance in
                performance.date == targetDate
            }

            let descriptor = FetchDescriptor<DailyPerformance>(predicate: predicate)
            return try context.fetch(descriptor).first
        } catch {
            logWarning("Error fetching DailyPerformance for date: \(error)", category: .general)
            UserDefaults.standard.set(false, forKey: "HasCleanedCorruptDailyPerformance_v1")
            return nil
        }
    }

    /// Calculate daily K/D trend from snapshots
    func getDailyKDTrend(days: Int = 7) -> [(Date, Double)] {
        guard let context = modelContext else { return [] }

        // For "All" (days >= 365), fetch all snapshots without date filter
        let descriptor: FetchDescriptor<StatsSnapshot>
        if days >= 365 {
            descriptor = FetchDescriptor<StatsSnapshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
        } else {
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let predicate = #Predicate<StatsSnapshot> { snapshot in
                snapshot.timestamp >= startDate
            }
            descriptor = FetchDescriptor<StatsSnapshot>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
        }

        guard let snapshots = try? context.fetch(descriptor) else { return [] }

        // Group snapshots by day and calculate daily K/D (delta between first and last snapshot of each day)
        let calendar = Calendar.current
        var dailyData: [Date: (startSnapshot: StatsSnapshot?, endSnapshot: StatsSnapshot?)] = [:]

        for snapshot in snapshots {
            let day = calendar.startOfDay(for: snapshot.timestamp)
            if dailyData[day] == nil {
                dailyData[day] = (snapshot, snapshot)
            } else {
                dailyData[day]?.endSnapshot = snapshot
            }
        }

        // Calculate daily K/D from deltas
        return dailyData.compactMap { (date, snapshots) -> (Date, Double)? in
            guard let start = snapshots.startSnapshot, let end = snapshots.endSnapshot else { return nil }
            let deltaKills = end.kills - start.kills
            let deltaDeaths = end.deaths - start.deaths
            let dailyKD = deltaDeaths > 0 ? Double(deltaKills) / Double(deltaDeaths) : Double(deltaKills)
            return (date, dailyKD)
        }.sorted { $0.0 < $1.0 }
    }

    /// Calculate daily kills trend from snapshots
    func getDailyKillsTrend(days: Int = 7) -> [(Date, Int)] {
        guard let context = modelContext else { return [] }

        // For "All" (days >= 365), fetch all snapshots without date filter
        let descriptor: FetchDescriptor<StatsSnapshot>
        if days >= 365 {
            descriptor = FetchDescriptor<StatsSnapshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
        } else {
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let predicate = #Predicate<StatsSnapshot> { snapshot in
                snapshot.timestamp >= startDate
            }
            descriptor = FetchDescriptor<StatsSnapshot>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
        }

        guard let snapshots = try? context.fetch(descriptor) else { return [] }

        // Group snapshots by day and calculate daily kills (delta between first and last snapshot of each day)
        let calendar = Calendar.current
        var dailyData: [Date: (startSnapshot: StatsSnapshot?, endSnapshot: StatsSnapshot?)] = [:]

        for snapshot in snapshots {
            let day = calendar.startOfDay(for: snapshot.timestamp)
            if dailyData[day] == nil {
                dailyData[day] = (snapshot, snapshot)
            } else {
                dailyData[day]?.endSnapshot = snapshot
            }
        }

        // Calculate daily kills from deltas
        return dailyData.compactMap { (date, snapshots) -> (Date, Int)? in
            guard let start = snapshots.startSnapshot, let end = snapshots.endSnapshot else { return nil }
            let deltaKills = end.kills - start.kills
            return (date, deltaKills)
        }.sorted { $0.0 < $1.0 }
    }

    /// Get best daily performance
    func getBestDailyPerformance(days: Int = 30) -> DailyPerformance? {
        let performances = getRecentDailyPerformances(days: days)
        return performances.max(by: { $0.dailyKD < $1.dailyKD })
    }

    /// Get worst daily performance
    func getWorstDailyPerformance(days: Int = 30) -> DailyPerformance? {
        let performances = getRecentDailyPerformances(days: days)
        return performances.min(by: { $0.dailyKD < $1.dailyKD })
    }

    /// Get average daily K/D
    func getAverageDailyKD(days: Int = 30) -> Double {
        let performances = getRecentDailyPerformances(days: days)
        guard !performances.isEmpty else { return 0.0 }

        let totalKD = performances.reduce(0.0) { $0 + $1.dailyKD }
        return totalKD / Double(performances.count)
    }

    /// Get standard deviation of daily K/D
    func getDailyKDStandardDeviation(days: Int = 30) -> Double {
        let performances = getRecentDailyPerformances(days: days)
        guard performances.count > 1 else { return 0.0 }

        let avg = getAverageDailyKD(days: days)
        let squaredDiffs = performances.map { pow($0.dailyKD - avg, 2) }
        let variance = squaredDiffs.reduce(0.0, +) / Double(performances.count)
        return sqrt(variance)
    }

    /// Get snapshots within a date range
    func getSnapshotsInRange(days: Int) -> [StatsSnapshot] {
        guard let context = modelContext else { return [] }

        let descriptor: FetchDescriptor<StatsSnapshot>
        if days >= 365 {
            descriptor = FetchDescriptor<StatsSnapshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
        } else {
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let predicate = #Predicate<StatsSnapshot> { snapshot in
                snapshot.timestamp >= startDate
            }
            descriptor = FetchDescriptor<StatsSnapshot>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
        }

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Calculate rolling average K/D for snapshots
    func getRollingKDAverage(days: Int, windowSize: Int) -> [(Date, Double)] {
        let snapshots = getSnapshotsInRange(days: days)
        guard snapshots.count >= windowSize else { return [] }

        var result: [(Date, Double)] = []

        for i in (windowSize - 1)..<snapshots.count {
            let window = Array(snapshots[(i - windowSize + 1)...i])
            let avgKD = window.reduce(0.0) { $0 + $1.kdRatio } / Double(windowSize)
            result.append((window.last!.timestamp, avgKD))
        }

        return result
    }

    /// Detect gaming sessions (groups of snapshots within sessionGapMinutes of each other)
    func detectSessions(days: Int, sessionGapMinutes: Int = 120) -> [[StatsSnapshot]] {
        let snapshots = getSnapshotsInRange(days: days)
        guard !snapshots.isEmpty else { return [] }

        var sessions: [[StatsSnapshot]] = []
        var currentSession: [StatsSnapshot] = [snapshots[0]]

        for i in 1..<snapshots.count {
            let timeDiff = snapshots[i].timestamp.timeIntervalSince(snapshots[i-1].timestamp)
            if timeDiff <= Double(sessionGapMinutes * 60) {
                currentSession.append(snapshots[i])
            } else {
                sessions.append(currentSession)
                currentSession = [snapshots[i]]
            }
        }

        if !currentSession.isEmpty {
            sessions.append(currentSession)
        }

        return sessions
    }

    /// Get best and worst snapshots by K/D
    func getBestAndWorstSnapshots(days: Int) -> (best: StatsSnapshot?, worst: StatsSnapshot?) {
        let snapshots = getSnapshotsInRange(days: days)
        guard !snapshots.isEmpty else { return (nil, nil) }

        let best = snapshots.max(by: { $0.kdRatio < $1.kdRatio })
        let worst = snapshots.min(by: { $0.kdRatio < $1.kdRatio })
        return (best, worst)
    }

    /// Calculate weekend vs weekday statistics
    func getWeekendVsWeekdayStats(days: Int) -> (weekendAvgKD: Double, weekdayAvgKD: Double) {
        let snapshots = getSnapshotsInRange(days: days)
        let calendar = Calendar.current

        var weekendKDs: [Double] = []
        var weekdayKDs: [Double] = []

        for snapshot in snapshots {
            let weekday = calendar.component(.weekday, from: snapshot.timestamp)
            if weekday == 1 || weekday == 7 { // Sunday = 1, Saturday = 7
                weekendKDs.append(snapshot.kdRatio)
            } else {
                weekdayKDs.append(snapshot.kdRatio)
            }
        }

        let weekendAvg = weekendKDs.isEmpty ? 0.0 : weekendKDs.reduce(0.0, +) / Double(weekendKDs.count)
        let weekdayAvg = weekdayKDs.isEmpty ? 0.0 : weekdayKDs.reduce(0.0, +) / Double(weekdayKDs.count)

        return (weekendAvg, weekdayAvg)
    }

    /// Get hourly performance data with multiple metrics
    func getHourlyStats(snapshots: [StatsSnapshot]) -> [HourlyPerformanceData] {
        let calendar = Calendar.current
        var hourlyData: [Int: (kdSum: Double, snapshots: [StatsSnapshot])] = [:]

        // Group snapshots by hour
        for snapshot in snapshots {
            let hour = calendar.component(.hour, from: snapshot.timestamp)
            let current = hourlyData[hour] ?? (0, [])
            hourlyData[hour] = (current.kdSum + snapshot.kdRatio, current.snapshots + [snapshot])
        }

        // Calculate delta kills for each hour
        return (0..<24).map { hour in
            if let data = hourlyData[hour], !data.snapshots.isEmpty {
                let sortedSnapshots = data.snapshots.sorted(by: { $0.timestamp < $1.timestamp })

                // Calculate delta kills (difference between first and last snapshot in the hour)
                let deltaKills: Int
                if sortedSnapshots.count > 1 {
                    deltaKills = sortedSnapshots.last!.kills - sortedSnapshots.first!.kills
                } else {
                    // For a single snapshot, we can't calculate delta, so use 0
                    deltaKills = 0
                }

                return HourlyPerformanceData(
                    hour: hour,
                    avgKD: data.kdSum / Double(data.snapshots.count),
                    totalKills: max(0, deltaKills), // Ensure non-negative
                    sessionCount: data.snapshots.count
                )
            } else {
                return HourlyPerformanceData(hour: hour, avgKD: 0, totalKills: 0, sessionCount: 0)
            }
        }
    }

    /// Rebuild DailyPerformance records from existing snapshots
    /// Call this to regenerate daily performance data from snapshot history
    func rebuildDailyPerformances(playerName: String) {
        guard let context = modelContext else { return }

        // Get all snapshots for this player
        let descriptor = FetchDescriptor<StatsSnapshot>(
            predicate: #Predicate<StatsSnapshot> { snapshot in
                snapshot.playerName == playerName
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        guard let snapshots = try? context.fetch(descriptor) else {
            return
        }

        // Group snapshots by day
        let calendar = Calendar.current
        var snapshotsByDay: [Date: [StatsSnapshot]] = [:]

        for snapshot in snapshots {
            let day = calendar.startOfDay(for: snapshot.timestamp)
            snapshotsByDay[day, default: []].append(snapshot)
        }

        // Create DailyPerformance for each day
        for (day, daySnapshots) in snapshotsByDay.sorted(by: { $0.key < $1.key }) {
            guard let first = daySnapshots.first,
                  let last = daySnapshots.last else { continue }

            // Check if DailyPerformance already exists for this day
            let existingPredicate = #Predicate<DailyPerformance> { performance in
                performance.date == day && performance.playerName == playerName
            }
            let existingDescriptor = FetchDescriptor<DailyPerformance>(predicate: existingPredicate)

            if let existing = try? context.fetch(existingDescriptor).first {
                // Update existing
                existing.update(with: last)
            } else {
                // Create new
                let performance = DailyPerformance(
                    date: day,
                    playerName: first.playerName,
                    platform: first.platform,
                    startSnapshot: first
                )
                performance.update(with: last)
                context.insert(performance)
            }
        }

        // Save changes
        try? context.save()

        // Reload daily performances
        loadDailyPerformances(playerName: playerName)
    }
}

// MARK: - Supporting Types

struct PerformanceSummary {
    let averageKD: Double
    let maxKD: Double
    let minKD: Double
    let trend: TrendDirection
    let snapshotCount: Int
}

enum TrendDirection {
    case improving
    case declining
    case stable

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .improving: return Theme.bf6Green
        case .declining: return Theme.bf6Red
        case .stable: return Theme.textSecondary
        }
    }
}
