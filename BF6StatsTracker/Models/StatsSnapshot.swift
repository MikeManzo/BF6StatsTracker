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
    var eaId: String? // EA Account ID

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

    init(from stats: PlayerStats, sessionId: UUID? = nil, eaId: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.playerName = stats.userName
        self.platform = stats.platform
        self.eaId = eaId

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

    /// Direct initializer for creating synthetic snapshots
    init(
        playerName: String,
        platform: String,
        eaId: String?,
        kills: Int,
        deaths: Int,
        wins: Int,
        losses: Int,
        matchesPlayed: Int,
        totalScore: Int,
        timePlayed: Int,
        headshots: Int,
        assists: Int,
        revives: Int,
        resupplies: Int,
        sessionId: UUID? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.playerName = playerName
        self.platform = platform
        self.eaId = eaId

        self.kills = kills
        self.deaths = deaths
        self.kdRatio = deaths > 0 ? Double(kills) / Double(deaths) : Double(kills)
        self.wins = wins
        self.losses = losses
        self.matchesPlayed = matchesPlayed
        self.totalScore = totalScore
        self.timePlayed = timePlayed
        self.headshots = headshots
        self.assists = assists
        self.revives = revives
        self.resupplies = resupplies

        // Calculate derived stats
        if timePlayed > 0 {
            self.killsPerMinute = Double(kills) / (Double(timePlayed) / 60.0)
            self.scorePerMinute = Double(totalScore) / (Double(timePlayed) / 60.0)
        } else {
            self.killsPerMinute = 0
            self.scorePerMinute = 0
        }

        if kills > 0 {
            self.headshotPercentage = (Double(headshots) / Double(kills)) * 100.0
        } else {
            self.headshotPercentage = 0
        }

        // Accuracy would need shots fired/hits data which we don't have in snapshots
        self.accuracy = 0

        self.sessionId = sessionId
    }

    /// Calculate approximate storage size in bytes
    var approximateStorageSize: Int {
        var size = 0

        // UUID (128 bits = 16 bytes)
        size += 16

        // Date (8 bytes - TimeInterval is Double)
        size += 8

        // Strings (approximate based on UTF-8 encoding)
        size += playerName.utf8.count
        size += platform.utf8.count
        if let eaId = eaId {
            size += eaId.utf8.count
        }

        // Int fields (8 bytes each on 64-bit systems)
        let intFieldCount = 11 // kills, deaths, wins, losses, matchesPlayed, totalScore, timePlayed, headshots, assists, revives, resupplies
        size += intFieldCount * 8

        // Double fields (8 bytes each)
        let doubleFieldCount = 5 // kdRatio, scorePerMinute, killsPerMinute, accuracy, headshotPercentage
        size += doubleFieldCount * 8

        // Optional UUID for sessionId
        if sessionId != nil {
            size += 16
        }

        // Add some overhead for SwiftData metadata (approximate)
        size += 64

        return size
    }

    /// Format storage size as human-readable string
    var formattedStorageSize: String {
        let bytes = Double(approximateStorageSize)
        if bytes < 1024 {
            return String(format: "%.0f B", bytes)
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.2f MB", bytes / (1024 * 1024))
        }
    }

    /// Check if this snapshot has identical stats to another snapshot
    /// - Parameter other: The snapshot to compare with
    /// - Returns: True if all stat values are identical (ignores timestamp, id, and sessionId)
    func isIdentical(to other: StatsSnapshot) -> Bool {
        return self.playerName == other.playerName &&
               self.platform == other.platform &&
               self.eaId == other.eaId &&
               self.kills == other.kills &&
               self.deaths == other.deaths &&
               self.kdRatio == other.kdRatio &&
               self.wins == other.wins &&
               self.losses == other.losses &&
               self.matchesPlayed == other.matchesPlayed &&
               self.totalScore == other.totalScore &&
               self.scorePerMinute == other.scorePerMinute &&
               self.killsPerMinute == other.killsPerMinute &&
               self.accuracy == other.accuracy &&
               self.headshotPercentage == other.headshotPercentage &&
               self.timePlayed == other.timePlayed &&
               self.headshots == other.headshots &&
               self.assists == other.assists &&
               self.revives == other.revives &&
               self.resupplies == other.resupplies
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
