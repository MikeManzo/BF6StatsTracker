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
//  PlayerStats.swift
//  BF6StatsTracker
//
//  Core player statistics models from GameTools.Network API
//

import Foundation

// MARK: - XP Structure
struct XPEntry: Codable {
    let total: Int
    let performance: Int
    let accolades: Int
}

// MARK: - Player Stats Response
struct PlayerStats: Codable, Identifiable {
    // Basic Info
    let id: String
    let userId: Int
    let userName: String
    let avatar: String
    let platform: String
    let platformId: Int
    let hasResults: Bool

    // Combat Stats
    let kills: Int
    let deaths: Int
    let kdRatio: Double
    let infantryKillDeath: Double
    let killsPerMinute: Double
    let killsPerMatch: Double

    // Headshot Stats (note: API has TWO fields!)
    let headShots: Int           // The COUNT of headshots
    let headshotsPercent: String // The PERCENTAGE as string like "13.31%"

    // Accuracy
    let accuracyPercent: String  // String like "15.87%"
    let shotsHit: Int
    let shotsFired: Int

    // Assists
    let killAssists: Int

    // Team Support
    let revives: Int
    let resupplies: Int
    let repairs: Int
    let heals: Int
    let squadmateRevive: Int
    let saviorKills: Int

    // Match Stats
    let wins: Int
    let losses: Int
    let wlPercent: String        // String like "43.9%"
    let matchesPlayed: Int

    // Time Stats
    let secondsPlayed: Int
    let timePlayedString: String       // Human readable like "3 days, 23:55:46"

    // Damage Stats
    let damage: Int
    let damagePerMatch: Double
    let damagePerMinute: Double

    // Other Stats
    let humanPercent: String     // String like "47.0%"
    let enemiesSpotted: Int
    let vehiclesDestroyed: Int
    let gadgetsDestoyed: Int
    let playerTakeDowns: Int
    let thrownThrowables: Int

    // XP and Progression
    let xpData: [XPEntry]?
    let bestClass: String

    // Nested Collections
    let classes: [ClassStats]?
    let weapons: [WeaponStats]?
    let vehicles: [VehicleStats]?
    let gadgets: [GadgetStats]?
    let maps: [MapPerformance]?

    // Last Match Stats
    let lastMatch: LastMatchStats?

    // Computed properties for backward compatibility
    var masteryLevel: Int {
        let xp = xpData?.first?.total ?? 0
        return min(xp / 25_000, 100)
    }

    // Convert percentage strings to doubles for display
    var accuracy: Double {
        parsePercentage(accuracyPercent)
    }

    var headshotPercentage: Double {
        parsePercentage(headshotsPercent)
    }

    var wlRatio: Double {
        parsePercentage(wlPercent)
    }

    var humanPercentage: Double {
        parsePercentage(humanPercent)
    }

    private func parsePercentage(_ percent: String) -> Double {
        let cleaned = percent.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0.0
    }

    // Aliases for backward compatibility
    var assists: Int { killAssists }
    var headshots: Int { headShots }
    var timePlayed: Int { secondsPlayed }

    // Computed properties not in API
    var scorePerMinute: Double {
        // Calculate based on XP performance score
        guard secondsPlayed > 0 else { return 0.0 }
        let totalXP = Double(xpData?.first?.total ?? 0)
        return (totalXP / Double(secondsPlayed)) * 60.0
    }

    var totalScore: Int {
        xpData?.first?.total ?? 0
    }

    var longestHeadshot: Double {
        // This field doesn't exist in the API - would need separate endpoint
        0.0
    }
    
    /// Calculate KDA ratio: (Kills + Assists) / Deaths
    var kdaRatio: Double {
        let killsAndAssists = kills + assists
        return deaths > 0 ? Double(killsAndAssists) / Double(deaths) : Double(killsAndAssists)
    }
    
    // MARK: - Community Performance Tiers
    
    var kdPerformanceTier: PerformanceTier {
        CommunityBenchmarks.kdPercentile(kd: kdRatio)
    }
    
    var killsPerformanceTier: PerformanceTier {
        CommunityBenchmarks.kpmPercentile(kpm: killsPerMinute)
    }
    
    var assistsPerformanceTier: PerformanceTier {
        let assistsPerMatch = matchesPlayed > 0 ? Double(assists) / Double(matchesPlayed) : 0.0
        return CommunityBenchmarks.assistsPercentile(assistsPerMatch: assistsPerMatch)
    }
    
    var winRatePerformanceTier: PerformanceTier {
        CommunityBenchmarks.winRatePercentile(winRate: wlRatio)
    }

    enum CodingKeys: String, CodingKey {
        // Basic Info
        case id
        case userId
        case userName
        case avatar
        case platform
        case platformId
        case hasResults

        // Combat Stats
        case kills
        case deaths
        case kdRatio = "killDeath"
        case infantryKillDeath
        case killsPerMinute
        case killsPerMatch

        // Headshot Stats
        case headShots
        case headshotsPercent = "headshots"

        // Accuracy
        case accuracyPercent = "accuracy"
        case shotsHit
        case shotsFired

        // Assists
        case killAssists

        // Team Support
        case revives
        case resupplies
        case repairs
        case heals
        case squadmateRevive
        case saviorKills

        // Match Stats
        case wins
        case losses = "loses"
        case wlPercent = "winPercent"
        case matchesPlayed

        // Time Stats
        case secondsPlayed
        case timePlayedString = "timePlayed"

        // Damage Stats
        case damage
        case damagePerMatch
        case damagePerMinute

        // Other Stats
        case humanPercent = "humanPrecentage"
        case enemiesSpotted
        case vehiclesDestroyed
        case gadgetsDestoyed
        case playerTakeDowns
        case thrownThrowables

        // XP and Progression
        case xpData = "XP"
        case bestClass

        // Nested Collections
        case classes
        case weapons
        case vehicles
        case gadgets
        case maps
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle ID - can be Int or String
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }

        // Decode all fields with defaults for optional values
        // Handle userId which can come as either Int or String from API
        if let userIdInt = try? container.decode(Int.self, forKey: .userId) {
            userId = userIdInt
        } else if let userIdString = try? container.decode(String.self, forKey: .userId),
                  let userIdInt = Int(userIdString) {
            userId = userIdInt
        } else {
            userId = 0
        }
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? "Unknown"
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar) ?? ""
        platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? "pc"
        platformId = try container.decodeIfPresent(Int.self, forKey: .platformId) ?? 0
        hasResults = try container.decodeIfPresent(Bool.self, forKey: .hasResults) ?? false

        // Combat Stats
        kills = try container.decodeIfPresent(Int.self, forKey: .kills) ?? 0
        deaths = try container.decodeIfPresent(Int.self, forKey: .deaths) ?? 0
        kdRatio = try container.decodeIfPresent(Double.self, forKey: .kdRatio) ?? 0.0
        infantryKillDeath = try container.decodeIfPresent(Double.self, forKey: .infantryKillDeath) ?? 0.0
        killsPerMinute = try container.decodeIfPresent(Double.self, forKey: .killsPerMinute) ?? 0.0
        killsPerMatch = try container.decodeIfPresent(Double.self, forKey: .killsPerMatch) ?? 0.0

        // Headshot Stats
        headShots = try container.decodeIfPresent(Int.self, forKey: .headShots) ?? 0
        headshotsPercent = try container.decodeIfPresent(String.self, forKey: .headshotsPercent) ?? "0.0%"

        // Accuracy
        accuracyPercent = try container.decodeIfPresent(String.self, forKey: .accuracyPercent) ?? "0.0%"
        shotsHit = try container.decodeIfPresent(Int.self, forKey: .shotsHit) ?? 0
        shotsFired = try container.decodeIfPresent(Int.self, forKey: .shotsFired) ?? 0

        // Assists
        killAssists = try container.decodeIfPresent(Int.self, forKey: .killAssists) ?? 0

        // Team Support
        revives = try container.decodeIfPresent(Int.self, forKey: .revives) ?? 0
        resupplies = try container.decodeIfPresent(Int.self, forKey: .resupplies) ?? 0
        repairs = try container.decodeIfPresent(Int.self, forKey: .repairs) ?? 0
        heals = try container.decodeIfPresent(Int.self, forKey: .heals) ?? 0
        squadmateRevive = try container.decodeIfPresent(Int.self, forKey: .squadmateRevive) ?? 0
        saviorKills = try container.decodeIfPresent(Int.self, forKey: .saviorKills) ?? 0

        // Match Stats
        wins = try container.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        losses = try container.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        wlPercent = try container.decodeIfPresent(String.self, forKey: .wlPercent) ?? "0.0%"
        matchesPlayed = try container.decodeIfPresent(Int.self, forKey: .matchesPlayed) ?? 0

        // Time Stats
        secondsPlayed = try container.decodeIfPresent(Int.self, forKey: .secondsPlayed) ?? 0
        timePlayedString = try container.decodeIfPresent(String.self, forKey: .timePlayedString) ?? "0 seconds"

        // Damage Stats
        damage = try container.decodeIfPresent(Int.self, forKey: .damage) ?? 0
        damagePerMatch = try container.decodeIfPresent(Double.self, forKey: .damagePerMatch) ?? 0.0
        damagePerMinute = try container.decodeIfPresent(Double.self, forKey: .damagePerMinute) ?? 0.0

        // Other Stats
        humanPercent = try container.decodeIfPresent(String.self, forKey: .humanPercent) ?? "0.0%"
        enemiesSpotted = try container.decodeIfPresent(Int.self, forKey: .enemiesSpotted) ?? 0
        vehiclesDestroyed = try container.decodeIfPresent(Int.self, forKey: .vehiclesDestroyed) ?? 0
        gadgetsDestoyed = try container.decodeIfPresent(Int.self, forKey: .gadgetsDestoyed) ?? 0
        playerTakeDowns = try container.decodeIfPresent(Int.self, forKey: .playerTakeDowns) ?? 0
        thrownThrowables = try container.decodeIfPresent(Int.self, forKey: .thrownThrowables) ?? 0

        // XP and Progression
        xpData = try container.decodeIfPresent([XPEntry].self, forKey: .xpData)

        // Handle bestClass which might be a String or a Number in the API
        if let bestClassString = try? container.decodeIfPresent(String.self, forKey: .bestClass) {
            bestClass = bestClassString
        } else if let bestClassInt = try? container.decodeIfPresent(Int.self, forKey: .bestClass) {
            bestClass = String(bestClassInt)
        } else {
            bestClass = ""
        }

        // Nested Collections
        classes = try container.decodeIfPresent([ClassStats].self, forKey: .classes)
        weapons = try container.decodeIfPresent([WeaponStats].self, forKey: .weapons)
        vehicles = try container.decodeIfPresent([VehicleStats].self, forKey: .vehicles)
        gadgets = try container.decodeIfPresent([GadgetStats].self, forKey: .gadgets)
        maps = try container.decodeIfPresent([MapPerformance].self, forKey: .maps)

        // Decode Last Match Stats from nested inRound structures
        lastMatch = try? Self.decodeLastMatchStats(from: decoder)
    }

    // Helper method to decode nested inRound data from various parts of the API response
    private static func decodeLastMatchStats(from decoder: Decoder) throws -> LastMatchStats? {
        let container = try decoder.container(keyedBy: GenericCodingKeys.self)

        // Try to decode base inRound stats
        var baseStats: InRoundStats?
        if let inRoundKey = GenericCodingKeys(stringValue: "inRound") {
            baseStats = try? container.decode(InRoundStats.self, forKey: inRoundKey)
        }

        // Try to decode dividedKills.inRound
        var kills: InRoundKills?
        if let dividedKillsKey = GenericCodingKeys(stringValue: "dividedKills"),
           let dividedKillsContainer = try? container.nestedContainer(keyedBy: GenericCodingKeys.self, forKey: dividedKillsKey),
           let inRoundKey = GenericCodingKeys(stringValue: "inRound") {
            kills = try? dividedKillsContainer.decode(InRoundKills.self, forKey: inRoundKey)
        }

        // Try to decode devidedDamage.inRound (NOTE: API has typo "devided" not "divided")
        var damage: InRoundDamage?
        if let devidedDamageKey = GenericCodingKeys(stringValue: "devidedDamage"),
           let devidedDamageContainer = try? container.nestedContainer(keyedBy: GenericCodingKeys.self, forKey: devidedDamageKey),
           let inRoundKey = GenericCodingKeys(stringValue: "inRound") {
            damage = try? devidedDamageContainer.decode(InRoundDamage.self, forKey: inRoundKey)
        }

        // Try to decode devidedAssists.inRound (NOTE: API has typo "devided" not "divided")
        var assists: InRoundAssists?
        if let devidedAssistsKey = GenericCodingKeys(stringValue: "devidedAssists"),
           let devidedAssistsContainer = try? container.nestedContainer(keyedBy: GenericCodingKeys.self, forKey: devidedAssistsKey),
           let inRoundKey = GenericCodingKeys(stringValue: "inRound") {
            assists = try? devidedAssistsContainer.decode(InRoundAssists.self, forKey: inRoundKey)
        }

        // Try to decode objective.inRound
        var objective: InRoundObjective?
        if let objectiveKey = GenericCodingKeys(stringValue: "objective"),
           let objectiveContainer = try? container.nestedContainer(keyedBy: GenericCodingKeys.self, forKey: objectiveKey),
           let inRoundKey = GenericCodingKeys(stringValue: "inRound") {
            objective = try? objectiveContainer.decode(InRoundObjective.self, forKey: inRoundKey)
        }

        return LastMatchStats(
            baseStats: baseStats,
            kills: kills,
            damage: damage,
            assists: assists,
            objective: objective
        )
    }
}

// MARK: - Generic Coding Keys for dynamic key access

struct GenericCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// MARK: - Cached Data Wrapper
struct CachedPlayerStats: Codable {
    let stats: PlayerStats
    let cachedAt: Date
    let expiresAt: Date

    var isExpired: Bool {
        Date() > expiresAt
    }
}
