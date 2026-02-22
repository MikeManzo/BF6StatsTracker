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
@preconcurrency import SwiftData
import SwiftUI

@MainActor
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    var modelContext: ModelContext?  // Made public for access from SettingsView
    nonisolated(unsafe) var modelContainer: ModelContainer?  // Store container for creating background contexts
    private var currentSession: PlaySession?

    @Published var snapshots: [StatsSnapshot] = []
    @Published var sessions: [PlaySession] = []
    @Published var recentSnapshots: [StatsSnapshot] = []
    /// Incremented each time a new snapshot is persisted. Views observe this to refresh cached snapshot data.
    @Published var snapshotVersion: Int = 0
    @Published var todayPerformance: DailyPerformance?
    @Published var yesterdayPerformance: DailyPerformance?
    @Published var recentDailyPerformances: [DailyPerformance] = []

    private var currentDailyPerformance: DailyPerformance?
    
    // Cached trend values to avoid recalculating on every stats refresh
    private var cachedTrends: (kills: TrendDirection, assists: TrendDirection, kd: TrendDirection, wl: TrendDirection)?
    private var trendCacheVersion: Int = -1  // Track which snapshot version trends were calculated for

    private init() {}

    /// Initialize with SwiftData model context
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.modelContainer = modelContext.container
    }



    // MARK: - Snapshots

    /// Save a stats snapshot only when a match has been completed
    /// A match is considered completed when BOTH conditions are met:
    /// 1. matchesPlayed has increased by at least 1
    /// 2. timePlayed has increased (any amount)
    /// Async version that uses background context to avoid blocking main thread
    nonisolated func saveSnapshotAsync(from stats: PlayerStats, sessionId: UUID? = nil, eaId: String? = nil, progressionMode: String? = nil, playSoundNotification: Bool = true, settings: AppSettings? = nil) async {
        guard let container = await MainActor.run(body: { modelContainer }) else { return }
        
        // Create background context - this is thread-safe
        let backgroundContext = ModelContext(container)
        
        // All operations happen on background thread - NO main thread blocking
        let newSnapshot = StatsSnapshot(from: stats, sessionId: sessionId, eaId: eaId, progressionMode: progressionMode)
        
        // Fetch only the most recent snapshot (limit 1 for performance)
        var descriptor = FetchDescriptor<StatsSnapshot>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let recentSnapshots = try? backgroundContext.fetch(descriptor),
              let mostRecent = recentSnapshots.first else {
            // First snapshot - insert and save
            backgroundContext.insert(newSnapshot)
            try? backgroundContext.save()
            
            await MainActor.run {
                self.snapshotVersion += 1
            }
            return
        }
        
        // Calculate deltas to detect match completion
        let matchDelta = newSnapshot.matchesPlayed - mostRecent.matchesPlayed
        let timeDelta = newSnapshot.timePlayed - mostRecent.timePlayed
        let matchCompleted = matchDelta >= 1 && timeDelta > 0
        
        guard matchCompleted else { return }
        
        // Insert and save on background thread
        backgroundContext.insert(newSnapshot)
        try? backgroundContext.save()
        
        // Update UI on main thread
        await MainActor.run {
            // Play sound notification
            if playSoundNotification, let settings = settings {
                SoundNotificationService.shared.playMatchCompletionSound(settings: settings)
            }
            
            // Increment version once
            self.snapshotVersion += 1
            logInfo("Background snapshot save completed", category: .general)
        }
        
        // Trigger iCloud backup if enabled
        if let settings = settings {
            Task { @MainActor in
                let backupService = iCloudBackupService.shared
                if settings.iCloudBackupEnabled {
                    let frequency = BackupFrequency(rawValue: settings.backupFrequency) ?? .afterEachMatch
                    await backupService.autoBackupIfNeeded(frequency: frequency, settings: settings)
                }
            }
        }
        
        // Pre-calculate trends in background so they're cached when UI needs them
        Task.detached(priority: .userInitiated) {
            let trends = await self.calculateTrendsAsync(days: 7)
            let currentVersion = await MainActor.run { self.snapshotVersion }
            await MainActor.run {
                self.cachedTrends = trends
                self.trendCacheVersion = currentVersion
                logInfo("Pre-cached trends after async snapshot save", category: .general)
            }
        }
    }
    
    func saveSnapshot(from stats: PlayerStats, sessionId: UUID? = nil, eaId: String? = nil, progressionMode: String? = nil, playSoundNotification: Bool = true, settings: AppSettings? = nil) {
        guard let context = modelContext else { return }

        // OPTIMIZATION: Perform early return check without fetching if possible
        let newSnapshot = StatsSnapshot(from: stats, sessionId: sessionId, eaId: eaId, progressionMode: progressionMode)

        // Get the most recent snapshot for comparison using the main actor's context
        // This avoids priority inversion by not calling nonisolated getRecentSnapshots from MainActor
        var descriptor = FetchDescriptor<StatsSnapshot>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 1
        let recentSnapshots = (try? context.fetch(descriptor)) ?? []
        
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

        }

        // ULTRA-CRITICAL FIX: Defer EVERYTHING to avoid ANY main thread blocking
        // Including the insert, save, and notification - all deferred to background
        let playerName = stats.userName
        let platform = stats.platform
        let shouldPlaySound = playSoundNotification
        let soundSettings = settings
        
        Task.detached(priority: .userInitiated) {
            await MainActor.run {
                // First: Quick insert (minimal blocking)
                context.insert(newSnapshot)
                
                if let session = self.currentSession {
                    session.snapshots.append(newSnapshot)
                }
                
                // Save immediately after insert (disk I/O but necessary)
                try? context.save()
                
                // Play notification sound right after save
                if shouldPlaySound, let soundSettings = soundSettings {
                    SoundNotificationService.shared.playMatchCompletionSound(settings: soundSettings)
                }
            }
            
            // Now defer the truly expensive operations with a delay
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            await MainActor.run {
                // Expensive daily performance update
                self.updateDailyPerformance(with: newSnapshot, playerName: playerName, platform: platform)
                
                // Reload data
                self.loadRecentData()
                self.loadDailyPerformances(playerName: playerName)
                self.snapshotVersion += 1
                
                logInfo("Deferred snapshot processing completed", category: .general)
            }
            
            // Pre-calculate trends in background so they're cached when UI needs them
            // This prevents the 14ms database fetch from blocking the UI later
            Task.detached(priority: .userInitiated) {
                let trends = await self.calculateTrendsAsync(days: 7)
                let currentVersion = await MainActor.run { self.snapshotVersion }
                await MainActor.run {
                    self.cachedTrends = trends
                    self.trendCacheVersion = currentVersion
                    logInfo("Pre-cached trends after snapshot save", category: .general)
                }
            }
            
            // Trigger iCloud backup if enabled
            if let soundSettings = soundSettings {
                Task { @MainActor in
                    let backupService = iCloudBackupService.shared
                    if soundSettings.iCloudBackupEnabled {
                        let frequency = BackupFrequency(rawValue: soundSettings.backupFrequency) ?? .afterEachMatch
                        await backupService.autoBackupIfNeeded(frequency: frequency, settings: soundSettings)
                    }
                }
            }
        }
    }

    /// Create a synthetic snapshot for debugging (randomly increments stats)
    func createSyntheticSnapshot() {
        guard let context = modelContext else { return }

        // Get the most recent snapshot as a base using the main actor's context
        var descriptor = FetchDescriptor<StatsSnapshot>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 1
        let recentSnapshots = (try? context.fetch(descriptor)) ?? []
        
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
    nonisolated func getSnapshots(from startDate: Date, to endDate: Date) async -> [StatsSnapshot] {
        guard let container = modelContainer else { return [] }
        
        return await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            
            let predicate = #Predicate<StatsSnapshot> { snapshot in
                snapshot.timestamp >= startDate && snapshot.timestamp <= endDate
            }

            let descriptor = FetchDescriptor<StatsSnapshot>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )

            return (try? context.fetch(descriptor)) ?? []
        }.value
    }

    /// Get last N snapshots
    /// Async version to avoid priority inversion when called from high-priority threads
    nonisolated func getRecentSnapshots(limit: Int = 20) async -> [StatsSnapshot] {
        guard let container = modelContainer else { return [] }
        
        return await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false  // Disable autosave for read-only operations
            
            var descriptor = FetchDescriptor<StatsSnapshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = limit

            return (try? context.fetch(descriptor)) ?? []
        }.value
    }

    /// Get all snapshots (no limit)
    /// Async version to avoid priority inversion when called from high-priority threads
    nonisolated func getAllSnapshots() async -> [StatsSnapshot] {
        guard let container = modelContainer else { return [] }
        
        return await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false  // Disable autosave for read-only operations
            
            let descriptor = FetchDescriptor<StatsSnapshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )

            return (try? context.fetch(descriptor)) ?? []
        }.value
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
    nonisolated func getAllSessions() -> [PlaySession] {
        guard let container = modelContainer else { return [] }
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PlaySession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Get recent sessions
    nonisolated func getRecentSessions(limit: Int = 10) -> [PlaySession] {
        guard let container = modelContainer else { return [] }
        
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<PlaySession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Analytics

    /// Calculate K/D trend over time
    func getKDTrend(days: Int = 7) async -> [(Date, Double)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = await getSnapshots(from: startDate, to: Date())

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
    func getKPMTrend(days: Int = 7) async -> [(Date, Double)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = await getSnapshots(from: startDate, to: Date())

        return snapshots.map { ($0.timestamp, $0.killsPerMinute) }
    }

    /// Calculate kills trend - returns daily kill deltas
    func getKillsTrend(days: Int = 7) async -> [(Date, Int)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = await getSnapshots(from: startDate, to: Date())

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
    func getAssistsTrend(days: Int = 7) async -> [(Date, Int)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = await getSnapshots(from: startDate, to: Date())

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

    /// Calculate win rate trend - returns all-time cumulative win rate from snapshots over time
    func getWLTrend(days: Int = 7) -> [(Date, Double)] {
        guard let context = modelContext else { return [] }
        
        // Get snapshots sorted chronologically (oldest first) using context directly
        var descriptor = FetchDescriptor<StatsSnapshot>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 100
        let snapshots = ((try? context.fetch(descriptor)) ?? [])
            .sorted { $0.timestamp < $1.timestamp }

        guard !snapshots.isEmpty else { return [] }

        // Calculate all-time win rate at each snapshot
        // Win rate = (wins / matchesPlayed) * 100
        let winRateTrend = snapshots.compactMap { snapshot -> (Date, Double)? in
            guard snapshot.matchesPlayed > 0 else { return nil }
            let winRate = (Double(snapshot.wins) / Double(snapshot.matchesPlayed)) * 100.0
            return (snapshot.timestamp, winRate)
        }

        return winRateTrend
    }

    /// Get performance summary for period
    func getPerformanceSummary(days: Int = 7) async -> PerformanceSummary? {
        let snapshots = await getKDTrend(days: days)
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

    /// Calculate trend for delta-based stats (kills, assists, deaths)
    /// These are daily deltas, so positive values = increasing, negative = decreasing
    /// For cumulative stats, if deltas are consistently positive, that's improving
    private func calculateDeltaTrend(values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }

        // Calculate average delta
        let avgDelta = values.reduce(0, +) / Double(values.count)

        // If average delta is positive and significant, we're improving
        // Even if deltas are decreasing, as long as they're positive we're still gaining
        if avgDelta > 0.5 {
            return .improving
        } else if avgDelta < -0.5 {
            return .declining
        } else {
            return .stable
        }
    }

    /// Calculate trend for kills (using Int values)
    func calculateKillsTrend(days: Int = 7) async -> TrendDirection {
        let killsData = await getKillsTrend(days: days)
        guard !killsData.isEmpty else { return .stable }

        let values = killsData.map { Double($0.1) }
        // Use delta trend: positive deltas = improving (gaining kills)
        return calculateDeltaTrend(values: values)
    }

    /// Calculate trend for assists (using Int values)
    func calculateAssistsTrend(days: Int = 7) async -> TrendDirection {
        let assistsData = await getAssistsTrend(days: days)
        guard !assistsData.isEmpty else { return .stable }

        let values = assistsData.map { Double($0.1) }
        // Use delta trend: positive deltas = improving (gaining assists)
        return calculateDeltaTrend(values: values)
    }

    /// Calculate trend for K/D ratio (absolute - is overall K/D increasing over time?)
    func calculateKDTrend(days: Int = 7) async -> TrendDirection {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = await getSnapshots(from: startDate, to: Date())

        guard snapshots.count >= 2 else { return .stable }

        // Snapshots are in reverse order (newest first)
        let newestKD = snapshots.first!.kdRatio  // Current cumulative K/D
        let oldestKD = snapshots.last!.kdRatio   // K/D from `days` ago

        let difference = newestKD - oldestKD

        // Use absolute threshold since all-time K/D changes slowly
        if difference > 0.01 {
            return .improving
        } else if difference < -0.01 {
            return .declining
        } else {
            return .stable
        }
    }

    /// Calculate trend for W/L ratio (win rate)
    /// Uses more sensitive threshold since all-time win rate changes slowly
    func calculateWLTrend(days: Int = 7) -> TrendDirection {
        let wlData = getWLTrend(days: days)
        guard wlData.count >= 2 else { return .stable }

        let values = wlData.map { $0.1 }

        // For win rate, compare oldest value to most recent value
        // (all-time win rate should show consistent direction)
        let oldestValue = values.first!
        let newestValue = values.last!

        let difference = newestValue - oldestValue

        // Use absolute difference threshold of 0.1% for win rate
        // (since it's already a percentage and changes slowly)
        if difference > 0.1 {
            return .improving
        } else if difference < -0.1 {
            return .declining
        } else {
            return .stable
        }
    }

    // MARK: - Async Trend Calculations (Background Thread)
    
    /// Get cached trends if available, otherwise calculate and cache them
    func getCachedTrendsOrCalculate(days: Int = 7) async -> (kills: TrendDirection, assists: TrendDirection, kd: TrendDirection, wl: TrendDirection) {
        // Check if cache is valid (matches current snapshot version)
        if let cached = cachedTrends, trendCacheVersion == snapshotVersion {
            return cached
        }
        
        // Cache is invalid or missing, calculate trends
        let trends = await calculateTrendsAsync(days: days)
        
        // Update cache
        await MainActor.run {
            self.cachedTrends = trends
            self.trendCacheVersion = self.snapshotVersion
        }
        
        return trends
    }
    
    /// Calculate all trends asynchronously on a background thread
    /// Optimized to use a single database fetch for all trend calculations
    nonisolated func calculateTrendsAsync(days: Int = 7) async -> (kills: TrendDirection, assists: TrendDirection, kd: TrendDirection, wl: TrendDirection) {
        guard let container = modelContainer else {
            return (.stable, .stable, .stable, .stable)
        }
        
        return await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false  // Disable autosave for read-only operations
            
            // Fetch recent snapshots (100 max) for all trend calculations in one query
            let predicate = #Predicate<StatsSnapshot> { _ in true }
            var descriptor = FetchDescriptor<StatsSnapshot>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = 100
            
            guard let allSnapshots = try? context.fetch(descriptor), !allSnapshots.isEmpty else {
                return (.stable, .stable, .stable, .stable)
            }
        
        // Filter to last N days for kills, assists, and K/D trends
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentSnapshots = allSnapshots.filter { $0.timestamp >= startDate }
        
        // Calculate kills trend
        let killsTrend: TrendDirection
        if recentSnapshots.count >= 2 {
            var deltas: [Double] = []
            for i in 0..<recentSnapshots.count - 1 {
                let newer = recentSnapshots[i]
                let older = recentSnapshots[i + 1]
                let killDelta = newer.kills - older.kills
                deltas.append(Double(max(0, killDelta)))
            }
            killsTrend = Self.calculateDeltaTrendStatic(values: deltas)
        } else {
            killsTrend = .stable
        }
        
        // Calculate assists trend
        let assistsTrend: TrendDirection
        if recentSnapshots.count >= 2 {
            var deltas: [Double] = []
            for i in 0..<recentSnapshots.count - 1 {
                let newer = recentSnapshots[i]
                let older = recentSnapshots[i + 1]
                let assistDelta = newer.assists - older.assists
                deltas.append(Double(max(0, assistDelta)))
            }
            assistsTrend = Self.calculateDeltaTrendStatic(values: deltas)
        } else {
            assistsTrend = .stable
        }
        
        // Calculate K/D trend
        let kdTrend: TrendDirection
        if recentSnapshots.count >= 2 {
            let newestKD = recentSnapshots.first!.kdRatio
            let oldestKD = recentSnapshots.last!.kdRatio
            let difference = newestKD - oldestKD
            
            if difference > 0.01 {
                kdTrend = .improving
            } else if difference < -0.01 {
                kdTrend = .declining
            } else {
                kdTrend = .stable
            }
        } else {
            kdTrend = .stable
        }
        
        // Calculate W/L trend using all snapshots
        let wlTrend: TrendDirection
        if allSnapshots.count >= 2 {
            let sorted = allSnapshots.sorted { $0.timestamp < $1.timestamp }
            let winRates = sorted.compactMap { snapshot -> Double? in
                guard snapshot.matchesPlayed > 0 else { return nil }
                return (Double(snapshot.wins) / Double(snapshot.matchesPlayed)) * 100.0
            }
            
            if winRates.count >= 2 {
                let difference = winRates.last! - winRates.first!
                if difference > 0.1 {
                    wlTrend = .improving
                } else if difference < -0.1 {
                    wlTrend = .declining
                } else {
                    wlTrend = .stable
                }
            } else {
                wlTrend = .stable
            }
        } else {
            wlTrend = .stable
        }
        
        return (killsTrend, assistsTrend, kdTrend, wlTrend)
        }.value
    }
    
    /// Static version of calculateDeltaTrend for use in nonisolated contexts
    private nonisolated static func calculateDeltaTrendStatic(values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }
        
        let avgDelta = values.reduce(0, +) / Double(values.count)
        
        if avgDelta > 0.5 {
            return .improving
        } else if avgDelta < -0.5 {
            return .declining
        } else {
            return .stable
        }
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
    nonisolated func getDailyKDTrend(days: Int = 7) async -> [(Date, Double)] {
        guard let container = modelContainer else { return [] }

        return await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false

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
                // Ensure the result is finite (not NaN or Infinity)
                return dailyKD.isFinite ? (date, dailyKD) : (date, 0.0)
            }.sorted { $0.0 < $1.0 }
        }.value
    }

    /// Calculate daily kills trend from snapshots
    nonisolated func getDailyKillsTrend(days: Int = 7) async -> [(Date, Int)] {
        guard let container = modelContainer else { return [] }

        return await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false

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
        }.value
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
    /// Async version to avoid priority inversion when called from high-priority threads
    nonisolated func getSnapshotsInRange(days: Int) async -> [StatsSnapshot] {
        guard let container = modelContainer else { return [] }

        // Use Task.detached with userInitiated priority to avoid SwiftData's default utility QoS
        return await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false  // Disable autosave for read-only operations

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
        }.value
    }

    /// Calculate rolling average K/D for snapshots
    nonisolated func getRollingKDAverage(days: Int, windowSize: Int) async -> [(Date, Double)] {
        let snapshots = await getSnapshotsInRange(days: days)
        guard snapshots.count >= windowSize else { return [] }

        var result: [(Date, Double)] = []

        for i in (windowSize - 1)..<snapshots.count {
            let window = Array(snapshots[(i - windowSize + 1)...i])
            // Filter out non-finite kdRatio values before averaging
            let finiteKDs = window.map { $0.kdRatio }.filter { $0.isFinite }
            let avgKD = finiteKDs.isEmpty ? 0.0 : finiteKDs.reduce(0.0, +) / Double(finiteKDs.count)
            result.append((window.last!.timestamp, avgKD.isFinite ? avgKD : 0.0))
        }

        return result
    }

    /// Detect gaming sessions (groups of snapshots within sessionGapMinutes of each other)
    nonisolated func detectSessions(days: Int, sessionGapMinutes: Int = 120) async -> [[StatsSnapshot]] {
        let snapshots = await getSnapshotsInRange(days: days)
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
    nonisolated func getBestAndWorstSnapshots(days: Int) async -> (best: StatsSnapshot?, worst: StatsSnapshot?) {
        let snapshots = await getSnapshotsInRange(days: days)
        guard !snapshots.isEmpty else { return (nil, nil) }

        let best = snapshots.max(by: { $0.kdRatio < $1.kdRatio })
        let worst = snapshots.min(by: { $0.kdRatio < $1.kdRatio })
        return (best, worst)
    }

    /// Calculate weekend vs weekday statistics
    nonisolated func getWeekendVsWeekdayStats(days: Int) async -> (weekendAvgKD: Double, weekdayAvgKD: Double) {
        let snapshots = await getSnapshotsInRange(days: days)
        let calendar = Calendar.current

        var weekendKDs: [Double] = []
        var weekdayKDs: [Double] = []

        for snapshot in snapshots {
            // Only include finite kdRatio values
            guard snapshot.kdRatio.isFinite else { continue }

            let weekday = calendar.component(.weekday, from: snapshot.timestamp)
            if weekday == 1 || weekday == 7 { // Sunday = 1, Saturday = 7
                weekendKDs.append(snapshot.kdRatio)
            } else {
                weekdayKDs.append(snapshot.kdRatio)
            }
        }

        let weekendAvg = weekendKDs.isEmpty ? 0.0 : weekendKDs.reduce(0.0, +) / Double(weekendKDs.count)
        let weekdayAvg = weekdayKDs.isEmpty ? 0.0 : weekdayKDs.reduce(0.0, +) / Double(weekdayKDs.count)

        return (weekendAvg.isFinite ? weekendAvg : 0.0, weekdayAvg.isFinite ? weekdayAvg : 0.0)
    }

    /// Get hourly performance data with multiple metrics
    func getHourlyStats(snapshots: [StatsSnapshot]) -> [HourlyPerformanceData] {
        let calendar = Calendar.current
        var hourlyData: [Int: (kdSum: Double, validKdCount: Int, snapshots: [StatsSnapshot])] = [:]

        // Group snapshots by hour, filtering NaN values
        for snapshot in snapshots {
            let hour = calendar.component(.hour, from: snapshot.timestamp)
            let current = hourlyData[hour] ?? (0, 0, [])
            // Only add to kdSum if the value is finite (not NaN or Infinity)
            let kdValue = snapshot.kdRatio
            if kdValue.isFinite {
                hourlyData[hour] = (current.kdSum + kdValue, current.validKdCount + 1, current.snapshots + [snapshot])
            } else {
                hourlyData[hour] = (current.kdSum, current.validKdCount, current.snapshots + [snapshot])
            }
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

                // Calculate average K/D, guarding against division by zero and NaN
                let avgKD: Double
                if data.validKdCount > 0 {
                    avgKD = data.kdSum / Double(data.validKdCount)
                } else {
                    avgKD = 0.0
                }

                return HourlyPerformanceData(
                    hour: hour,
                    avgKD: avgKD.isFinite ? avgKD : 0.0,
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
    
    // MARK: - Advanced Analytics
    
    /// Get performance metrics grouped by hour of day (0-23)
    func getPerformanceByHourOfDay(days: Int = 30) -> [Int: PerformanceMetrics] {
        guard let context = modelContext else { return [:] }
        
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<StatsSnapshot>(
            predicate: #Predicate<StatsSnapshot> { snapshot in
                snapshot.timestamp >= startDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        guard let snapshots = try? context.fetch(descriptor) else { return [:] }
        
        var metricsByHour: [Int: [PerformanceMetrics]] = [:]
        
        for i in 0..<snapshots.count - 1 {
            let current = snapshots[i]
            let next = snapshots[i + 1]
            
            let hour = Calendar.current.component(.hour, from: next.timestamp)
            let metrics = calculateSessionMetrics(from: current, to: next)
            
            metricsByHour[hour, default: []].append(metrics)
        }
        
        // Average metrics for each hour
        var result: [Int: PerformanceMetrics] = [:]
        for (hour, metricsList) in metricsByHour {
            result[hour] = averageMetrics(metricsList)
        }
        
        return result
    }
    
    /// Get performance metrics grouped by day of week (1=Sunday, 7=Saturday)
    func getPerformanceByDayOfWeek(days: Int = 30) -> [Int: PerformanceMetrics] {
        guard let context = modelContext else { return [:] }
        
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<StatsSnapshot>(
            predicate: #Predicate<StatsSnapshot> { snapshot in
                snapshot.timestamp >= startDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        guard let snapshots = try? context.fetch(descriptor) else { return [:] }
        
        var metricsByDay: [Int: [PerformanceMetrics]] = [:]
        
        for i in 0..<snapshots.count - 1 {
            let current = snapshots[i]
            let next = snapshots[i + 1]
            
            let dayOfWeek = Calendar.current.component(.weekday, from: next.timestamp)
            let metrics = calculateSessionMetrics(from: current, to: next)
            
            metricsByDay[dayOfWeek, default: []].append(metrics)
        }
        
        // Average metrics for each day
        var result: [Int: PerformanceMetrics] = [:]
        for (day, metricsList) in metricsByDay {
            result[day] = averageMetrics(metricsList)
        }
        
        return result
    }
    
    /// Calculate playstyle fingerprint metrics
    func getPlaystyleFingerprint(days: Int = 30) -> PlaystyleFingerprint {
        guard let context = modelContext else {
            return PlaystyleFingerprint(aggression: 0, accuracy: 0, teamSupport: 0, survival: 0, objective: 0)
        }
        
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<StatsSnapshot>(
            predicate: #Predicate<StatsSnapshot> { snapshot in
                snapshot.timestamp >= startDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        guard let snapshots = try? context.fetch(descriptor), snapshots.count >= 2 else {
            return PlaystyleFingerprint(aggression: 0, accuracy: 0, teamSupport: 0, survival: 0, objective: 0)
        }
        
        let first = snapshots.first!
        let last = snapshots.last!
        
        let timePlayed = Double(last.timePlayed - first.timePlayed) / 60.0 // minutes
        let killsGained = last.kills - first.kills
        let deathsGained = last.deaths - first.deaths
        let matchesGained = last.matchesPlayed - first.matchesPlayed
        
        // Aggression: Kills per minute (normalized to 0-1 scale, 2 KPM = 1.0)
        let kpm = timePlayed > 0 ? Double(killsGained) / timePlayed : 0
        let aggression = min(kpm / 2.0, 1.0)
        
        // Accuracy: Headshot percentage (normalized to 0-1 scale, 30% = 1.0)
        let accuracy = min(last.headshotPercentage / 30.0, 1.0)
        
        // Team Support: (Revives + Resupplies) per match (normalized, 10 per match = 1.0)
        let supportActions = last.revives - first.revives + last.resupplies - first.resupplies
        let supportPerMatch = matchesGained > 0 ? Double(supportActions) / Double(matchesGained) : 0
        let teamSupport = min(supportPerMatch / 10.0, 1.0)
        
        // Survival: Inverse of deaths per match (normalized, 10 deaths/match = 0, 5 = 0.5, 0 = 1.0)
        let deathsPerMatch = matchesGained > 0 ? Double(deathsGained) / Double(matchesGained) : 10
        let survival = max(0, 1.0 - (deathsPerMatch / 20.0))
        
        // Objective: Win rate (already 0-1 scale)
        let winsGained = last.wins - first.wins
        let objective = matchesGained > 0 ? Double(winsGained) / Double(matchesGained) : 0
        
        return PlaystyleFingerprint(
            aggression: aggression,
            accuracy: accuracy,
            teamSupport: teamSupport,
            survival: survival,
            objective: objective
        )
    }
    
    /// Get form indicator based on recent performance vs overall average
    /// - Parameter days: Number of days to analyze for recent performance (defaults to 30)
    func getFormIndicator(days: Int = 30) -> FormIndicator {
        guard let context = modelContext else {
            return FormIndicator(status: .neutral, recentKD: 0, overallKD: 0, recentWinRate: 0, overallWinRate: 0, sessionsAnalyzed: 0)
        }
        
        // Get all snapshots
        let allDescriptor = FetchDescriptor<StatsSnapshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        guard let allSnapshots = try? context.fetch(allDescriptor), allSnapshots.count >= 10 else {
            return FormIndicator(status: .neutral, recentKD: 0, overallKD: 0, recentWinRate: 0, overallWinRate: 0, sessionsAnalyzed: 0)
        }
        
        // Calculate overall performance
        let overallFirst = allSnapshots.first!
        let overallLast = allSnapshots.last!
        let overallKillsGained = overallLast.kills - overallFirst.kills
        let overallDeathsGained = overallLast.deaths - overallFirst.deaths
        let overallKD = overallDeathsGained > 0 ? Double(overallKillsGained) / Double(overallDeathsGained) : 0
        
        let overallMatchesGained = overallLast.matchesPlayed - overallFirst.matchesPlayed
        let overallWinsGained = overallLast.wins - overallFirst.wins
        let overallWinRate = overallMatchesGained > 0 ? Double(overallWinsGained) / Double(overallMatchesGained) * 100 : 0
        
        // Calculate recent performance based on the specified number of days
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentSnapshots = allSnapshots.filter { $0.timestamp >= cutoffDate }
        
        guard recentSnapshots.count >= 2 else {
            return FormIndicator(status: .neutral, recentKD: overallKD, overallKD: overallKD, recentWinRate: overallWinRate, overallWinRate: overallWinRate, sessionsAnalyzed: 0)
        }
        
        let recentCount = recentSnapshots.count - 1
        
        let recentFirst = recentSnapshots.first!
        let recentLast = recentSnapshots.last!
        let recentKillsGained = recentLast.kills - recentFirst.kills
        let recentDeathsGained = recentLast.deaths - recentFirst.deaths
        let recentKD = recentDeathsGained > 0 ? Double(recentKillsGained) / Double(recentDeathsGained) : 0
        
        let recentMatchesGained = recentLast.matchesPlayed - recentFirst.matchesPlayed
        let recentWinsGained = recentLast.wins - recentFirst.wins
        let recentWinRate = recentMatchesGained > 0 ? Double(recentWinsGained) / Double(recentMatchesGained) * 100 : 0
        
        // Determine form status
        let kdDiff = recentKD - overallKD
        let winRateDiff = recentWinRate - overallWinRate
        
        let status: FormStatus
        if kdDiff > 0.15 && winRateDiff > 5 {
            status = .hot
        } else if kdDiff > 0.05 || winRateDiff > 2 {
            status = .good
        } else if kdDiff < -0.15 && winRateDiff < -5 {
            status = .cold
        } else if kdDiff < -0.05 || winRateDiff < -2 {
            status = .declining
        } else {
            status = .neutral
        }
        
        return FormIndicator(
            status: status,
            recentKD: recentKD,
            overallKD: overallKD,
            recentWinRate: recentWinRate,
            overallWinRate: overallWinRate,
            sessionsAnalyzed: recentCount
        )
    }
    
    /// Generate recommendations based on current form and patterns
    /// - Parameter days: Number of days to analyze (defaults to 30)
    func getRecommendations(days: Int = 30) -> [String] {
        let form = getFormIndicator(days: days)
        let hourMetrics = getPerformanceByHourOfDay(days: days)
        let dayMetrics = getPerformanceByDayOfWeek(days: days)
        
        var recommendations: [String] = []
        
        // Form-based recommendations
        switch form.status {
        case .hot:
            recommendations.append("🔥 You're on fire! Keep playing while your form is hot.")
        case .good:
            recommendations.append("✅ Solid performance. You're playing above your average.")
        case .declining:
            recommendations.append("⚠️ Performance dipping. Consider switching tactics or taking a break.")
        case .cold:
            recommendations.append("❄️ Rough patch. Take a break and come back refreshed.")
        case .neutral:
            recommendations.append("➡️ Steady performance. Maintain your current approach.")
        }
        
        // Time-based recommendations
        let currentHour = Calendar.current.component(.hour, from: Date())
        if let currentHourMetrics = hourMetrics[currentHour] {
            let avgKD = hourMetrics.values.map { $0.kdRatio }.reduce(0, +) / Double(hourMetrics.count)
            if currentHourMetrics.kdRatio > avgKD * 1.2 {
                recommendations.append("⏰ This is typically one of your best performing hours!")
            } else if currentHourMetrics.kdRatio < avgKD * 0.8 {
                recommendations.append("⏰ Performance tends to be lower at this hour. Stay focused!")
            }
        }
        
        // Best time recommendations
        if let bestHour = hourMetrics.max(by: { $0.value.kdRatio < $1.value.kdRatio }) {
            let hourString = bestHour.key == 0 ? "12 AM" : bestHour.key < 12 ? "\(bestHour.key) AM" : bestHour.key == 12 ? "12 PM" : "\(bestHour.key - 12) PM"
            recommendations.append("🎯 Your peak performance is typically around \(hourString)")
        }
        
        return recommendations
    }
    
    // MARK: - Helper Methods
    
    private func calculateSessionMetrics(from: StatsSnapshot, to: StatsSnapshot) -> PerformanceMetrics {
        let killsGained = to.kills - from.kills
        let deathsGained = to.deaths - from.deaths
        let matchesGained = to.matchesPlayed - from.matchesPlayed
        let winsGained = to.wins - from.wins
        
        let kdRatio = deathsGained > 0 ? Double(killsGained) / Double(deathsGained) : Double(killsGained)
        let winRate = matchesGained > 0 ? Double(winsGained) / Double(matchesGained) * 100 : 0
        
        return PerformanceMetrics(
            kdRatio: kdRatio,
            winRate: winRate,
            killsPerMatch: matchesGained > 0 ? Double(killsGained) / Double(matchesGained) : 0,
            accuracy: to.accuracy,
            sessionCount: 1
        )
    }
    
    private func averageMetrics(_ metricsList: [PerformanceMetrics]) -> PerformanceMetrics {
        guard !metricsList.isEmpty else {
            return PerformanceMetrics(kdRatio: 0, winRate: 0, killsPerMatch: 0, accuracy: 0, sessionCount: 0)
        }
        
        let avgKD = metricsList.map { $0.kdRatio }.reduce(0, +) / Double(metricsList.count)
        let avgWinRate = metricsList.map { $0.winRate }.reduce(0, +) / Double(metricsList.count)
        let avgKPM = metricsList.map { $0.killsPerMatch }.reduce(0, +) / Double(metricsList.count)
        let avgAccuracy = metricsList.map { $0.accuracy }.reduce(0, +) / Double(metricsList.count)
        
        return PerformanceMetrics(
            kdRatio: avgKD,
            winRate: avgWinRate,
            killsPerMatch: avgKPM,
            accuracy: avgAccuracy,
            sessionCount: metricsList.count
        )
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

struct PerformanceMetrics {
    let kdRatio: Double
    let winRate: Double
    let killsPerMatch: Double
    let accuracy: Double
    let sessionCount: Int
}

struct PlaystyleFingerprint {
    let aggression: Double      // 0-1 scale based on KPM
    let accuracy: Double         // 0-1 scale based on headshot %
    let teamSupport: Double      // 0-1 scale based on revives/resupplies
    let survival: Double         // 0-1 scale based on deaths per match
    let objective: Double        // 0-1 scale based on win rate
    
    var values: [Double] {
        [aggression, accuracy, teamSupport, survival, objective]
    }
    
    var labels: [String] {
        ["Aggression", "Accuracy", "Team Support", "Survival", "Objective"]
    }
}

enum FormStatus {
    case hot        // Significantly above average
    case good       // Above average
    case neutral    // Around average
    case declining  // Below average
    case cold       // Significantly below average
    
    var color: Color {
        switch self {
        case .hot: return .orange
        case .good: return Theme.bf6Green
        case .neutral: return Theme.textSecondary
        case .declining: return .yellow
        case .cold: return Theme.bf6Red
        }
    }
    
    var icon: String {
        switch self {
        case .hot: return "flame.fill"
        case .good: return "arrow.up.circle.fill"
        case .neutral: return "arrow.left.arrow.right.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        case .cold: return "snowflake"
        }
    }
    
    var title: String {
        switch self {
        case .hot: return "On Fire"
        case .good: return "In Form"
        case .neutral: return "Steady"
        case .declining: return "Declining"
        case .cold: return "Cold Streak"
        }
    }
}

struct FormIndicator {
    let status: FormStatus
    let recentKD: Double
    let overallKD: Double
    let recentWinRate: Double
    let overallWinRate: Double
    let sessionsAnalyzed: Int
}
