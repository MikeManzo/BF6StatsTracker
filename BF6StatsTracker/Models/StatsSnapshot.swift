//
//  StatsSnapshot.swift
//  BF6StatsTracker
//
//  SwiftData models for tracking stats over time
//

import Foundation
import SwiftData

// MARK: - Stats Snapshot

@Model
final class StatsSnapshot {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var playerName: String
    var platform: String

    // Core Stats
    var kills: Int
    var deaths: Int
    var kdRatio: Double
    var wins: Int
    var losses: Int
    var matchesPlayed: Int
    var totalScore: Int
    var scorePerMinute: Double
    var killsPerMinute: Double
    var accuracy: Double
    var headshotPercentage: Double
    var timePlayed: Int

    // Combat Stats
    var headshots: Int
    var assists: Int
    var revives: Int
    var resupplies: Int

    // Session metadata
    var sessionId: UUID?

    init(from stats: PlayerStats, sessionId: UUID? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.playerName = stats.userName
        self.platform = stats.platform

        self.kills = stats.kills
        self.deaths = stats.deaths
        self.kdRatio = stats.kdRatio
        self.wins = stats.wins
        self.losses = stats.losses
        self.matchesPlayed = stats.matchesPlayed
        self.totalScore = stats.totalScore
        self.scorePerMinute = stats.scorePerMinute
        self.killsPerMinute = stats.killsPerMinute
        self.accuracy = stats.accuracy
        self.headshotPercentage = stats.headshotPercentage
        self.timePlayed = stats.timePlayed

        self.headshots = stats.headshots
        self.assists = stats.assists
        self.revives = stats.revives
        self.resupplies = stats.resupplies

        self.sessionId = sessionId
    }
}

// MARK: - Play Session

@Model
final class PlaySession {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?
    var playerName: String
    var platform: String

    // Session Stats (calculated from snapshots)
    var killsGained: Int
    var deathsGained: Int
    var matchesPlayed: Int
    var timePlayedMinutes: Int
    var avgKD: Double
    var bestMatch: String? // Description of best match

    @Relationship(deleteRule: .cascade) var snapshots: [StatsSnapshot]

    init(playerName: String, platform: String) {
        self.id = UUID()
        self.startTime = Date()
        self.playerName = playerName
        self.platform = platform
        self.killsGained = 0
        self.deathsGained = 0
        self.matchesPlayed = 0
        self.timePlayedMinutes = 0
        self.avgKD = 0.0
        self.snapshots = []
    }

    func endSession(with finalSnapshot: StatsSnapshot) {
        self.endTime = Date()

        // Calculate session stats
        if let firstSnapshot = snapshots.first {
            killsGained = finalSnapshot.kills - firstSnapshot.kills
            deathsGained = finalSnapshot.deaths - firstSnapshot.deaths
            matchesPlayed = finalSnapshot.matchesPlayed - firstSnapshot.matchesPlayed
            timePlayedMinutes = (finalSnapshot.timePlayed - firstSnapshot.timePlayed) / 60

            if deathsGained > 0 {
                avgKD = Double(killsGained) / Double(deathsGained)
            }
        }
    }

    var duration: TimeInterval {
        if let end = endTime {
            return end.timeIntervalSince(startTime)
        }
        return Date().timeIntervalSince(startTime)
    }
}

// MARK: - Map Stats (Parsed from API)

@Model
final class MapStats {
    @Attribute(.unique) var id: UUID
    var mapName: String
    var playerName: String
    var platform: String
    var timestamp: Date

    // Performance on this map
    var kills: Int
    var deaths: Int
    var kdRatio: Double
    var wins: Int
    var losses: Int
    var matchesPlayed: Int
    var winRate: Double

    init(mapName: String, playerName: String, platform: String, kills: Int, deaths: Int, wins: Int, losses: Int, matchesPlayed: Int) {
        self.id = UUID()
        self.mapName = mapName
        self.playerName = playerName
        self.platform = platform
        self.timestamp = Date()
        self.kills = kills
        self.deaths = deaths
        self.kdRatio = deaths > 0 ? Double(kills) / Double(deaths) : Double(kills)
        self.wins = wins
        self.losses = losses
        self.matchesPlayed = matchesPlayed
        self.winRate = matchesPlayed > 0 ? Double(wins) / Double(matchesPlayed) * 100 : 0
    }
}
