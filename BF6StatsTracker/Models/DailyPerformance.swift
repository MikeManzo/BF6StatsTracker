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
//  DailyPerformance.swift
//  BF6StatsTracker
//
//  SwiftData model for tracking daily performance statistics
//

import Foundation
import SwiftData

// MARK: - Daily Performance

@Model
final class DailyPerformance {
    @Attribute(.unique) var id: UUID
    var date: Date // Calendar day (normalized to start of day)
    var playerName: String
    var platform: String

    // Start and end snapshots for the day
    @Relationship(deleteRule: .nullify) var startSnapshot: StatsSnapshot?
    @Relationship(deleteRule: .nullify) var endSnapshot: StatsSnapshot?

    // Delta stats (calculated from snapshots)
    var deltaKills: Int
    var deltaDeaths: Int
    var deltaHeadshots: Int
    var deltaAssists: Int
    var deltaRevives: Int
    var deltaResupplies: Int
    var deltaWins: Int
    var deltaLosses: Int
    var deltaMatchesPlayed: Int
    var deltaScore: Int
    var deltaTimePlayed: Int // In seconds

    // Computed performance metrics
    var dailyKD: Double
    var dailyAccuracy: Double
    var dailyHeadshotPercent: Double
    var dailyKPM: Double
    var dailyWinRate: Double

    // Session metadata
    var sessionStartTime: Date?
    var sessionEndTime: Date?
    var isActive: Bool // Whether this is today's active session

    init(date: Date, playerName: String, platform: String, startSnapshot: StatsSnapshot) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.playerName = playerName
        self.platform = platform
        self.startSnapshot = startSnapshot
        self.endSnapshot = nil

        // Initialize deltas to 0
        self.deltaKills = 0
        self.deltaDeaths = 0
        self.deltaHeadshots = 0
        self.deltaAssists = 0
        self.deltaRevives = 0
        self.deltaResupplies = 0
        self.deltaWins = 0
        self.deltaLosses = 0
        self.deltaMatchesPlayed = 0
        self.deltaScore = 0
        self.deltaTimePlayed = 0

        // Initialize computed metrics
        self.dailyKD = 0.0
        self.dailyAccuracy = 0.0
        self.dailyHeadshotPercent = 0.0
        self.dailyKPM = 0.0
        self.dailyWinRate = 0.0

        // Session metadata
        self.sessionStartTime = Date()
        self.sessionEndTime = nil
        self.isActive = true
    }

    /// Update the daily performance with new snapshot data
    func update(with newSnapshot: StatsSnapshot) {
        self.endSnapshot = newSnapshot
        self.sessionEndTime = Date()

        guard let start = startSnapshot else { return }

        // Calculate deltas
        deltaKills = newSnapshot.kills - start.kills
        deltaDeaths = newSnapshot.deaths - start.deaths
        deltaHeadshots = newSnapshot.headshots - start.headshots
        deltaAssists = newSnapshot.assists - start.assists
        deltaRevives = newSnapshot.revives - start.revives
        deltaResupplies = newSnapshot.resupplies - start.resupplies
        deltaWins = newSnapshot.wins - start.wins
        deltaLosses = newSnapshot.losses - start.losses
        deltaScore = newSnapshot.totalScore - start.totalScore
        deltaTimePlayed = newSnapshot.timePlayed - start.timePlayed

        // Calculate matches played from time delta (more reliable than API matchesPlayed)
        // Average BF6 match duration is ~18 minutes (1080 seconds)
        // Use time played delta to estimate matches
        deltaMatchesPlayed = estimateMatchesFromTimePlayed(
            startTime: start.timePlayed,
            endTime: newSnapshot.timePlayed
        )

        // Calculate daily K/D
        dailyKD = deltaDeaths > 0 ? Double(deltaKills) / Double(deltaDeaths) : Double(deltaKills)

        // Calculate daily accuracy
        if deltaKills > 0 {
            let startShotsFired = estimateShotsFired(for: start)
            let endShotsFired = estimateShotsFired(for: newSnapshot)
            let shotsFired = endShotsFired - startShotsFired

            if shotsFired > 0 {
                let startShotsHit = estimateShotsHit(for: start)
                let endShotsHit = estimateShotsHit(for: newSnapshot)
                let shotsHit = endShotsHit - startShotsHit
                dailyAccuracy = (Double(shotsHit) / Double(shotsFired)) * 100.0
            }
        }

        // Calculate daily headshot percentage
        dailyHeadshotPercent = deltaKills > 0 ? (Double(deltaHeadshots) / Double(deltaKills)) * 100.0 : 0.0

        // Calculate daily KPM
        if deltaTimePlayed > 0 {
            dailyKPM = (Double(deltaKills) / Double(deltaTimePlayed)) * 60.0
        }

        // Calculate daily win rate
        dailyWinRate = deltaMatchesPlayed > 0 ? (Double(deltaWins) / Double(deltaMatchesPlayed)) * 100.0 : 0.0
    }

    /// End the daily session
    func endSession() {
        self.isActive = false
        self.sessionEndTime = Date()
    }

    /// Calculate session duration
    var sessionDuration: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        let end = sessionEndTime ?? Date()
        return end.timeIntervalSince(start)
    }

    /// Format session duration as string
    var sessionDurationString: String {
        let duration = sessionDuration
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Estimate matches played from time delta
    /// More reliable than using API's matchesPlayed which can be incorrect
    private func estimateMatchesFromTimePlayed(startTime: Int, endTime: Int) -> Int {
        let deltaSeconds = endTime - startTime

        // Guard against negative or zero deltas
        guard deltaSeconds > 0 else { return 0 }

        // Average match duration constants (in seconds)
        let averageMatchDuration = 1080 // 18 minutes
        let minMatchDuration = 600      // 10 minutes (minimum to count as a match)

        // If delta is less than minimum match duration, count as 0 matches
        if deltaSeconds < minMatchDuration {
            return 0
        }

        // Calculate matches played by dividing time delta by average match duration
        // Round to nearest whole number for better accuracy
        let estimatedMatches = Double(deltaSeconds) / Double(averageMatchDuration)
        return max(1, Int(round(estimatedMatches)))
    }

    /// Estimate shots fired (helper for accuracy calculation)
    private func estimateShotsFired(for snapshot: StatsSnapshot) -> Int {
        // Approximate shots fired based on accuracy and kills
        // This is an estimation since snapshots don't store shots fired
        guard snapshot.accuracy > 0 else { return 0 }
        let shotsHit = estimateShotsHit(for: snapshot)
        return Int(Double(shotsHit) / (snapshot.accuracy / 100.0))
    }

    /// Estimate shots hit (helper for accuracy calculation)
    private func estimateShotsHit(for snapshot: StatsSnapshot) -> Int {
        // Rough estimate: assume ~4 shots per kill
        return snapshot.kills * 4
    }

    /// Check if this performance is from today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Check if this performance is from yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }

    /// Format date for display
    var formattedDate: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    /// Computed KDA (Kills + Assists / Deaths) calculated from existing properties
    /// This doesn't modify SwiftData storage - calculated on-the-fly
    var computedDailyKDA: Double {
        let killAssists = deltaKills + deltaAssists
        return deltaDeaths > 0 ? Double(killAssists) / Double(deltaDeaths) : Double(killAssists)
    }
}
