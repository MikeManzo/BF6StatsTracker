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
//  DetailedStats.swift
//  BF6StatsTracker
//
//  Detailed statistics models: classes, weapons, vehicles, gadgets, and maps
//

import Foundation

// MARK: - Class Stats
struct ClassStats: Codable, Identifiable, Hashable {
    let id: String
    let className: String
    let timePlayed: Int
    let kills: Int
    let deaths: Int
    let kdRatio: Double
    let score: Int
    let scorePerMinute: Double
    let image: String?

    enum CodingKeys: String, CodingKey {
        case className
        case timePlayed = "secondsPlayed"
        case kills
        case deaths
        case kdRatio = "killDeath"
        case score
        case scorePerMinute
        case image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        className = try container.decodeIfPresent(String.self, forKey: .className) ?? "Unknown"
        timePlayed = try container.decodeIfPresent(Int.self, forKey: .timePlayed) ?? 0
        kills = try container.decodeIfPresent(Int.self, forKey: .kills) ?? 0
        deaths = try container.decodeIfPresent(Int.self, forKey: .deaths) ?? 0
        kdRatio = try container.decodeIfPresent(Double.self, forKey: .kdRatio) ?? 0.0
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        scorePerMinute = try container.decodeIfPresent(Double.self, forKey: .scorePerMinute) ?? 0.0
        image = try container.decodeIfPresent(String.self, forKey: .image)

        // Generate unique ID combining className with timePlayed to avoid duplicates
        id = "\(className)_\(timePlayed)_\(kills)"
    }

    init(className: String, timePlayed: Int, kills: Int, deaths: Int, kdRatio: Double, score: Int, scorePerMinute: Double, image: String?) {
        self.className = className
        self.timePlayed = timePlayed
        self.kills = kills
        self.deaths = deaths
        self.kdRatio = kdRatio
        self.score = score
        self.scorePerMinute = scorePerMinute
        self.image = image

        // Generate unique ID
        self.id = "\(className)_\(timePlayed)_\(kills)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ClassStats, rhs: ClassStats) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Weapon Stats
struct WeaponStats: Codable, Identifiable, Hashable {
    var id: String { weaponId }

    // Basic Info
    let weaponId: String
    let weaponName: String
    let type: String
    let image: String
    let altImage: String?

    // Kill Stats
    let kills: Int
    let bodyKills: Int
    let headshotKills: Int
    let hipfireKills: Int
    let scopedKills: Int
    let multiKills: Int

    // Damage Stats
    let damage: Int
    let assistsDamage: Int
    let damagePerMinute: Double

    // Accuracy (stored as percentage strings!)
    let accuracyPercent: String    // e.g., "14.44%"
    let headshotsPercent: String   // e.g., "8.43%"

    // Shooting Stats
    let shotsHit: Int
    let shotsFired: Int
    let hitVKills: Double

    // Time Stats
    let timeEquipped: Int
    let spawns: Int
    let killsPerMinute: Double

    // Computed properties for backward compatibility
    var accuracy: Double {
        parsePercentage(accuracyPercent)
    }

    var headshotPercentage: Double {
        parsePercentage(headshotsPercent)
    }

    // Alias for backward compatibility
    var headshots: Int { headshotKills }
    var timePlayed: Int { timeEquipped }

    private func parsePercentage(_ percent: String) -> Double {
        let cleaned = percent.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0.0
    }
    
    enum CodingKeys: String, CodingKey {
        case weaponId = "id"
        case weaponName
        case type
        case image
        case altImage

        case kills
        case bodyKills
        case headshotKills
        case hipfireKills
        case scopedKills
        case multiKills

        case damage
        case assistsDamage
        case damagePerMinute

        case accuracyPercent = "accuracy"
        case headshotsPercent = "headshots"

        case shotsHit
        case shotsFired
        case hitVKills

        case timeEquipped
        case spawns
        case killsPerMinute
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(weaponName)
    }
    
    static func == (lhs: WeaponStats, rhs: WeaponStats) -> Bool {
        lhs.weaponName == rhs.weaponName
    }
}

// MARK: - Vehicle Stats
struct VehicleStats: Codable, Identifiable, Hashable {
    var id: String { vehicleId }

    // Basic Info
    let vehicleId: String
    let vehicleName: String
    let type: String
    let image: String
    let altImage: String?

    // Combat Stats
    let kills: Int
    let multiKills: Int
    let assists: Int
    let killsPerMinute: Double
    let roadKills: Int

    // Damage Stats
    let damage: Int
    let damageTo: Int

    // Vehicle Stats
    let destroyed: Int
    let vehiclesDestroyedWith: Int
    let distanceTraveled: Int

    // Assist Stats
    let driverAssists: Int
    let passengerAssists: Int

    // Time Stats
    let timeIn: Int
    let spawns: Int

    // Computed properties for backward compatibility
    var timePlayed: Int { timeIn }
    var deaths: Int { 0 } // API doesn't provide vehicle deaths
    var kdRatio: Double {
        // Note: API doesn't provide deaths for vehicles, so this is just kills
        Double(kills)
    }

    enum CodingKeys: String, CodingKey {
        case vehicleId = "id"
        case vehicleName
        case type
        case image
        case altImage

        case kills
        case multiKills
        case assists
        case killsPerMinute
        case roadKills

        case damage
        case damageTo

        case destroyed
        case vehiclesDestroyedWith
        case distanceTraveled

        case driverAssists
        case passengerAssists

        case timeIn
        case spawns
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(vehicleId)
    }

    static func == (lhs: VehicleStats, rhs: VehicleStats) -> Bool {
        lhs.vehicleId == rhs.vehicleId
    }
}

// MARK: - Gadget Stats
struct GadgetStats: Codable, Identifiable, Hashable {
    var id: String { gadgetId }

    // Basic Info
    let gadgetId: String
    let gadgetName: String
    let type: String
    let image: String

    // Combat Stats
    let kills: Int
    let multiKills: Int
    let assists: Int
    let kpm: Double

    // Spotting Stats
    let spotAssists: Int
    let spots: Int

    // Usage Stats
    let uses: Int
    let spawns: Int

    // Damage Stats
    let damage: Int
    let assistsDamage: Int
    let dpm: Double

    // Vehicle Stats
    let vehiclesDestroyedWith: Int

    // Time Stats
    let secondsPlayed: Int

    // Computed properties for backward compatibility
    var timePlayed: Int { secondsPlayed }
    var damageDealt: Int { damage }
    var vehiclesDestroyed: Int { vehiclesDestroyedWith }
    var killsPerMinute: Double { kpm }
    var damagePerMinute: Double { dpm }

    enum CodingKeys: String, CodingKey {
        case gadgetId = "id"
        case gadgetName
        case type
        case image

        case kills
        case multiKills
        case assists
        case kpm

        case spotAssists
        case spots

        case uses
        case spawns

        case damage
        case assistsDamage
        case dpm

        case vehiclesDestroyedWith

        case secondsPlayed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gadgetId = try container.decodeIfPresent(String.self, forKey: .gadgetId) ?? UUID().uuidString
        gadgetName = try container.decodeIfPresent(String.self, forKey: .gadgetName) ?? "Unknown"
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        image = try container.decodeIfPresent(String.self, forKey: .image) ?? ""

        kills = try container.decodeIfPresent(Int.self, forKey: .kills) ?? 0
        multiKills = try container.decodeIfPresent(Int.self, forKey: .multiKills) ?? 0
        assists = try container.decodeIfPresent(Int.self, forKey: .assists) ?? 0
        kpm = try container.decodeIfPresent(Double.self, forKey: .kpm) ?? 0.0

        spotAssists = try container.decodeIfPresent(Int.self, forKey: .spotAssists) ?? 0
        spots = try container.decodeIfPresent(Int.self, forKey: .spots) ?? 0

        uses = try container.decodeIfPresent(Int.self, forKey: .uses) ?? 0
        spawns = try container.decodeIfPresent(Int.self, forKey: .spawns) ?? 0

        damage = try container.decodeIfPresent(Int.self, forKey: .damage) ?? 0
        assistsDamage = try container.decodeIfPresent(Int.self, forKey: .assistsDamage) ?? 0
        dpm = try container.decodeIfPresent(Double.self, forKey: .dpm) ?? 0.0

        vehiclesDestroyedWith = try container.decodeIfPresent(Int.self, forKey: .vehiclesDestroyedWith) ?? 0

        secondsPlayed = try container.decodeIfPresent(Int.self, forKey: .secondsPlayed) ?? 0
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(gadgetId)
    }

    static func == (lhs: GadgetStats, rhs: GadgetStats) -> Bool {
        lhs.gadgetId == rhs.gadgetId
    }
}

// MARK: - Map Performance Stats
struct MapPerformance: Codable, Identifiable {
    var id: String { mapId }

    let mapId: String
    let mapName: String
    let image: String
    let wins: Int
    let losses: Int
    let matches: Int
    let winPercentString: String
    let secondsPlayed: Int
    let score: Int

    // Computed properties
    var winRate: Double {
        parsePercentage(winPercentString)
    }

    var matchesPlayed: Int { matches }

    var timePlayed: String {
        let hours = secondsPlayed / 3600
        let minutes = (secondsPlayed % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func parsePercentage(_ percent: String) -> Double {
        let cleaned = percent.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0.0
    }

    enum CodingKeys: String, CodingKey {
        case mapId = "id"
        case mapName
        case image
        case wins
        case losses
        case matches
        case winPercentString = "winPercent"
        case secondsPlayed
        case score
    }

    init(mapId: String, mapName: String, image: String, wins: Int, losses: Int, matches: Int, winPercentString: String, secondsPlayed: Int, score: Int) {
        self.mapId = mapId
        self.mapName = mapName
        self.image = image
        self.wins = wins
        self.losses = losses
        self.matches = matches
        self.winPercentString = winPercentString
        self.secondsPlayed = secondsPlayed
        self.score = score
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mapId = try container.decodeIfPresent(String.self, forKey: .mapId) ?? UUID().uuidString
        mapName = try container.decode(String.self, forKey: .mapName)
        image = try container.decodeIfPresent(String.self, forKey: .image) ?? ""
        wins = try container.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        losses = try container.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        matches = try container.decodeIfPresent(Int.self, forKey: .matches) ?? 0
        winPercentString = try container.decodeIfPresent(String.self, forKey: .winPercentString) ?? "0%"
        secondsPlayed = try container.decodeIfPresent(Int.self, forKey: .secondsPlayed) ?? 0
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
    }
}
