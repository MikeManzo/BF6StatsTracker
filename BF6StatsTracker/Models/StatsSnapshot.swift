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
//  StatsSnapshot.swift
//  BF6StatsTracker
//
//  SwiftData models for tracking stats over time
//

import Foundation
import SwiftData

// MARK: - Stats Snapshot

@Model
final class StatsSnapshot: @unchecked Sendable {
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
    var progressionMode: String? // The progression mode for this snapshot (e.g., "official-progression")

    // Map statistics snapshot
    @Attribute(.externalStorage) var mapsJSON: Data?

    // Computed property to access maps
    var maps: [MapPerformance]? {
        get {
            guard let data = mapsJSON else { return nil }
            return try? JSONDecoder().decode([MapPerformance].self, from: data)
        }
        set {
            mapsJSON = try? JSONEncoder().encode(newValue)
        }
    }

    init(from stats: PlayerStats, sessionId: UUID? = nil, eaId: String? = nil, progressionMode: String? = nil) {
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
        self.progressionMode = progressionMode

        // Store map statistics
        self.maps = stats.maps
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
        sessionId: UUID? = nil,
        progressionMode: String? = nil
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
        self.progressionMode = progressionMode
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
final class PlaySession: @unchecked Sendable {
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
final class MapStats: @unchecked Sendable {
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

// MARK: - Map Activity Tracking

/// Represents activity on a single map between snapshots
struct MapActivity: Identifiable {
    let id = UUID()
    let mapName: String
    let mapId: String
    let matchesPlayed: Int
    let timePlayedSeconds: Int
    let wins: Int
    let losses: Int
    let score: Int

    /// Format time played as human-readable string
    var timePlayedFormatted: String {
        let minutes = timePlayedSeconds / 60
        let seconds = timePlayedSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// Format time played as short version (just minutes if applicable)
    var timePlayedShort: String {
        let minutes = timePlayedSeconds / 60
        if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(timePlayedSeconds)s"
        }
    }

    /// Get win/loss record as formatted string
    var recordFormatted: String {
        "\(wins)W-\(losses)L"
    }

    /// Check if this activity had any wins
    var hasWins: Bool {
        wins > 0
    }

    /// Check if this activity had any losses
    var hasLosses: Bool {
        losses > 0
    }

    /// Format score as human-readable string (e.g., 1.2K, 15K)
    var scoreFormatted: String {
        if score >= 1000 {
            let thousands = Double(score) / 1000.0
            return String(format: "%.1fK", thousands)
        } else {
            return "\(score)"
        }
    }
}

extension StatsSnapshot {
    /// Get all maps that were played between this snapshot and a previous one
    /// Returns detailed activity for each map, sorted by time played (descending)
    func mapsPlayedSince(_ previous: StatsSnapshot?) -> [MapActivity] {
        guard let currentMaps = self.maps,
              let previousMaps = previous?.maps else {
            return []
        }

        // Calculate total score delta from snapshots
        let totalScoreDelta = previous != nil ? self.totalScore - previous!.totalScore : self.totalScore

        // First pass: collect map activities and total time played
        var rawActivities: [(mapName: String, mapId: String, matchesPlayed: Int, timePlayedSeconds: Int, wins: Int, losses: Int)] = []
        var totalTimePlayed = 0

        for currentMap in currentMaps {
            if let prevMap = previousMaps.first(where: { $0.mapId == currentMap.mapId }) {
                let timeDelta = currentMap.secondsPlayed - prevMap.secondsPlayed
                let matchesDelta = currentMap.matches - prevMap.matches
                let winsDelta = currentMap.wins - prevMap.wins
                let lossesDelta = currentMap.losses - prevMap.losses

                // Only include maps that had activity
                if timeDelta > 0 || matchesDelta > 0 {
                    rawActivities.append((
                        mapName: currentMap.mapName,
                        mapId: currentMap.mapId,
                        matchesPlayed: matchesDelta,
                        timePlayedSeconds: timeDelta,
                        wins: winsDelta,
                        losses: lossesDelta
                    ))
                    totalTimePlayed += timeDelta
                }
            } else if currentMap.matches > 0 {
                // New map that wasn't in previous snapshot
                rawActivities.append((
                    mapName: currentMap.mapName,
                    mapId: currentMap.mapId,
                    matchesPlayed: currentMap.matches,
                    timePlayedSeconds: currentMap.secondsPlayed,
                    wins: currentMap.wins,
                    losses: currentMap.losses
                ))
                totalTimePlayed += currentMap.secondsPlayed
            }
        }

        // Second pass: distribute score proportionally by time played
        var activities: [MapActivity] = []
        for raw in rawActivities {
            let scoreForMap: Int
            if totalTimePlayed > 0 {
                // Distribute score proportionally by time played
                scoreForMap = Int(Double(totalScoreDelta) * (Double(raw.timePlayedSeconds) / Double(totalTimePlayed)))
            } else {
                // Fallback: distribute evenly
                scoreForMap = rawActivities.isEmpty ? 0 : totalScoreDelta / rawActivities.count
            }

            activities.append(
                MapActivity(
                    mapName: raw.mapName,
                    mapId: raw.mapId,
                    matchesPlayed: raw.matchesPlayed,
                    timePlayedSeconds: raw.timePlayedSeconds,
                    wins: raw.wins,
                    losses: raw.losses,
                    score: scoreForMap
                )
            )
        }

        // Sort by time played (descending) - most played first
        return activities.sorted { $0.timePlayedSeconds > $1.timePlayedSeconds }
    }
}
