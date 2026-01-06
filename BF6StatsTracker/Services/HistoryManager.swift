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
            print("🗑️ Clearing \(allPerformances.count) DailyPerformance objects to fix stale references")
            for performance in allPerformances {
                context.delete(performance)
            }
            try context.save()
            print("✅ Cleared corrupt DailyPerformance data")

            // Mark as cleaned only if successful
            UserDefaults.standard.set(true, forKey: hasCleanedKey)
        } catch {
            // If we can't even fetch DailyPerformance objects, the corruption is severe
            // Delete the entire DailyPerformance table by deleting all data
            print("⚠️ Severe corruption detected, performing emergency cleanup: \(error)")

            // Try to delete using executeDelete (bypasses object loading)
            do {
                try context.delete(model: DailyPerformance.self)
                try context.save()
                print("✅ Emergency cleanup successful")
                UserDefaults.standard.set(true, forKey: hasCleanedKey)
            } catch {
                print("⚠️ Emergency cleanup failed: \(error)")
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

    /// Save a stats snapshot only if it differs from the most recent snapshot
    func saveSnapshot(from stats: PlayerStats, sessionId: UUID? = nil, eaId: String? = nil) {
        guard let context = modelContext else { return }

        let newSnapshot = StatsSnapshot(from: stats, sessionId: sessionId, eaId: eaId)

        // Get the most recent snapshot for comparison
        let recentSnapshots = getRecentSnapshots(limit: 1)
        if let mostRecent = recentSnapshots.first {
            // Check if the new snapshot is identical to the most recent one
            if newSnapshot.isIdentical(to: mostRecent) {
                print("⏭️ Skipping snapshot save - identical to previous snapshot")
                return
            }
        }

        // Snapshot differs from previous, save it
        context.insert(newSnapshot)
        print("💾 Saving new snapshot - stats have changed")

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
            print("⚠️ No snapshots available to base synthetic snapshot on")
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

        print("🧪 Creating 10 synthetic snapshots for yesterday...")

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

        print("🧪 Created 10 snapshots for yesterday")

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
        print("🧪 Created 1 snapshot for today: +\(killsIncrease) kills, +\(deathsIncrease) deaths, +\(matchesIncrease) matches")

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

        return snapshots.map { ($0.timestamp, $0.kdRatio) }
    }

    /// Calculate kills per minute trend
    func getKPMTrend(days: Int = 7) -> [(Date, Double)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = getSnapshots(from: startDate, to: Date())

        return snapshots.map { ($0.timestamp, $0.killsPerMinute) }
    }

    /// Calculate kills trend
    func getKillsTrend(days: Int = 7) -> [(Date, Int)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = getSnapshots(from: startDate, to: Date())

        return snapshots.map { ($0.timestamp, $0.kills) }
    }

    /// Calculate W/L ratio trend
    func getWLTrend(days: Int = 7) -> [(Date, Double)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = getSnapshots(from: startDate, to: Date())

        return snapshots.map { snapshot -> (Date, Double) in
            let wlRatio = snapshot.losses > 0 ? Double(snapshot.wins) / Double(snapshot.losses) : Double(snapshot.wins)
            return (snapshot.timestamp, wlRatio)
        }
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

        let firstHalf = values.prefix(values.count / 2)
        let secondHalf = values.suffix(values.count / 2)

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        let difference = secondAvg - firstAvg
        let percentChange = (difference / firstAvg) * 100

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
                let newPerformance = DailyPerformance(
                    date: today,
                    playerName: playerName,
                    platform: platform,
                    startSnapshot: snapshot
                )
                context.insert(newPerformance)
                currentDailyPerformance = newPerformance

                // End any previous active daily performance
                endPreviousDailyPerformances(playerName: playerName, platform: platform)
            }

            try? context.save()
        } catch {
            print("⚠️ Error updating DailyPerformance: \(error)")
            UserDefaults.standard.set(false, forKey: "HasCleanedCorruptDailyPerformance_v1")
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
            print("⚠️ Error ending previous DailyPerformance objects: \(error)")
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
            print("⚠️ Error loading DailyPerformance objects: \(error)")
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
            print("⚠️ Error fetching recent DailyPerformance objects: \(error)")
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
            print("⚠️ Error fetching DailyPerformance for date: \(error)")
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

    /// Rebuild DailyPerformance records from existing snapshots
    /// Call this to regenerate daily performance data from snapshot history
    func rebuildDailyPerformances(playerName: String) {
        guard let context = modelContext else { return }

        print("🔧 Rebuilding DailyPerformance records from snapshots...")

        // Get all snapshots for this player
        let descriptor = FetchDescriptor<StatsSnapshot>(
            predicate: #Predicate<StatsSnapshot> { snapshot in
                snapshot.playerName == playerName
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        guard let snapshots = try? context.fetch(descriptor) else {
            print("⚠️ Failed to fetch snapshots")
            return
        }

        print("🔧 Found \(snapshots.count) snapshots to process")

        // Group snapshots by day
        let calendar = Calendar.current
        var snapshotsByDay: [Date: [StatsSnapshot]] = [:]

        for snapshot in snapshots {
            let day = calendar.startOfDay(for: snapshot.timestamp)
            snapshotsByDay[day, default: []].append(snapshot)
        }

        print("🔧 Grouped into \(snapshotsByDay.count) days")

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
                print("📝 Updated DailyPerformance for \(day)")
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
                print("✅ Created DailyPerformance for \(day)")
            }
        }

        // Save changes
        try? context.save()

        // Reload daily performances
        loadDailyPerformances(playerName: playerName)

        print("🔧 Rebuild complete! Now have \(recentDailyPerformances.count) daily performance records")
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
