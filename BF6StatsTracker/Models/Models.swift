//
//  Models.swift
//  BF6StatsTracker
//
//  Data models for Battlefield 6 statistics from GameTools.Network API
//

import Foundation
import SwiftUI

// MARK: - XP Structure
struct XPEntry: Codable {
    let total: Int
    let performance: Int
    let accolades: Int
}

// MARK: - In-Round (Last Match) Statistics

struct InRoundStats: Codable {
    let revives: Int
    let resupplies: Int
    let spotAssists: Int
    let thrownThrowables: Int
    let playerTakeDowns: Int

    enum CodingKeys: String, CodingKey {
        case revives
        case resupplies
        case spotAssists
        case thrownThrowables
        case playerTakeDowns
    }

    init(revives: Int, resupplies: Int, spotAssists: Int, thrownThrowables: Int, playerTakeDowns: Int) {
        self.revives = revives
        self.resupplies = resupplies
        self.spotAssists = spotAssists
        self.thrownThrowables = thrownThrowables
        self.playerTakeDowns = playerTakeDowns
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        revives = try container.decodeIfPresent(Int.self, forKey: .revives) ?? 0
        resupplies = try container.decodeIfPresent(Int.self, forKey: .resupplies) ?? 0
        spotAssists = try container.decodeIfPresent(Int.self, forKey: .spotAssists) ?? 0
        thrownThrowables = try container.decodeIfPresent(Int.self, forKey: .thrownThrowables) ?? 0
        playerTakeDowns = try container.decodeIfPresent(Int.self, forKey: .playerTakeDowns) ?? 0
    }
}

struct InRoundKills: Codable {
    let total: Int
    let grenade: Int
    let headshots: Int
    let melee: Int
    let multiKills: Int
    let assaultRifles: Int
    let dmrs: Int
    let lmgs: Int
    let smgs: Int
    let sniperRifles: Int
    let shotguns: Int

    enum CodingKeys: String, CodingKey {
        case total
        case grenade = "Grenade"
        case headshots
        case melee = "Melee"
        case multiKills
        case assaultRifles = "Assault Rifles"
        case dmrs = "DMR"
        case lmgs = "LMG"
        case smgs = "SMG-PDW"
        case sniperRifles = "Rifles"
        case shotguns = "Shotgun"
    }

    init(total: Int, grenade: Int, headshots: Int, melee: Int, multiKills: Int, assaultRifles: Int, dmrs: Int, lmgs: Int, smgs: Int, sniperRifles: Int, shotguns: Int) {
        self.total = total
        self.grenade = grenade
        self.headshots = headshots
        self.melee = melee
        self.multiKills = multiKills
        self.assaultRifles = assaultRifles
        self.dmrs = dmrs
        self.lmgs = lmgs
        self.smgs = smgs
        self.sniperRifles = sniperRifles
        self.shotguns = shotguns
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
        grenade = try container.decodeIfPresent(Int.self, forKey: .grenade) ?? 0
        headshots = try container.decodeIfPresent(Int.self, forKey: .headshots) ?? 0
        melee = try container.decodeIfPresent(Int.self, forKey: .melee) ?? 0
        multiKills = try container.decodeIfPresent(Int.self, forKey: .multiKills) ?? 0
        assaultRifles = try container.decodeIfPresent(Int.self, forKey: .assaultRifles) ?? 0
        dmrs = try container.decodeIfPresent(Int.self, forKey: .dmrs) ?? 0
        lmgs = try container.decodeIfPresent(Int.self, forKey: .lmgs) ?? 0
        smgs = try container.decodeIfPresent(Int.self, forKey: .smgs) ?? 0
        sniperRifles = try container.decodeIfPresent(Int.self, forKey: .sniperRifles) ?? 0
        shotguns = try container.decodeIfPresent(Int.self, forKey: .shotguns) ?? 0
    }
}

struct InRoundDamage: Codable {
    let vehicle: Int

    enum CodingKeys: String, CodingKey {
        case vehicle
    }

    init(vehicle: Int) {
        self.vehicle = vehicle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vehicle = try container.decodeIfPresent(Int.self, forKey: .vehicle) ?? 0
    }
}

struct InRoundAssists: Codable {
    let total: Int

    enum CodingKeys: String, CodingKey {
        case total
    }

    init(total: Int) {
        self.total = total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
    }
}

struct InRoundObjective: Codable {
    let armed: Int
    let captured: Int
    let neutralized: Int

    enum CodingKeys: String, CodingKey {
        case armed
        case captured
        case neutralized
    }

    init(armed: Int, captured: Int, neutralized: Int) {
        self.armed = armed
        self.captured = captured
        self.neutralized = neutralized
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        armed = try container.decodeIfPresent(Int.self, forKey: .armed) ?? 0
        captured = try container.decodeIfPresent(Int.self, forKey: .captured) ?? 0
        neutralized = try container.decodeIfPresent(Int.self, forKey: .neutralized) ?? 0
    }
}

struct LastMatchStats: Codable {
    let baseStats: InRoundStats?
    let kills: InRoundKills?
    let damage: InRoundDamage?
    let assists: InRoundAssists?
    let objective: InRoundObjective?

    init(baseStats: InRoundStats?, kills: InRoundKills?, damage: InRoundDamage?, assists: InRoundAssists?, objective: InRoundObjective?) {
        self.baseStats = baseStats
        self.kills = kills
        self.damage = damage
        self.assists = assists
        self.objective = objective
    }

    var hasData: Bool {
        return kills?.total ?? 0 > 0 ||
               baseStats?.revives ?? 0 > 0 ||
               baseStats?.resupplies ?? 0 > 0
    }
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
        userId = try container.decodeIfPresent(Int.self, forKey: .userId) ?? 0
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
        hasher.combine(vehicleName)
    }
    
    static func == (lhs: VehicleStats, rhs: VehicleStats) -> Bool {
        lhs.vehicleName == rhs.vehicleName
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

        case uses
        case spawns

        case damage
        case assistsDamage
        case dpm

        case vehiclesDestroyedWith

        case secondsPlayed
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(gadgetName)
    }
    
    static func == (lhs: GadgetStats, rhs: GadgetStats) -> Bool {
        lhs.gadgetName == rhs.gadgetName
    }
}

// MARK: - Platform Enum
enum Platform: String, CaseIterable, Identifiable {
    case pc = "pc"
    case steam = "steam"
    case ps3 = "ps3"
    case ps4 = "ps4"
    case ps5 = "ps5"
    case playstation = "playstation"
    case xbox = "xbox"
    case xboxOne = "xboxone"
    case xboxSeries = "xboxseries"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pc: return "PC (Origin/EA)"
        case .steam: return "Steam"
        case .ps3: return "PlayStation 3"
        case .ps4: return "PlayStation 4"
        case .ps5: return "PlayStation 5"
        case .playstation: return "PlayStation"
        case .xbox: return "Xbox"
        case .xboxOne: return "Xbox One"
        case .xboxSeries: return "Xbox Series X|S"
        }
    }

    var icon: String {
        switch self {
        case .pc: return "desktopcomputer"
        case .steam: return "cloud.fill"
        case .ps3, .ps4, .ps5, .playstation: return "playstation.logo"
        case .xbox, .xboxOne, .xboxSeries: return "xbox.logo"
        }
    }

    /// Initialize from API platform string
    init?(apiString: String?) {
        guard let str = apiString?.lowercased() else { return nil }

        // Map common platform strings
        switch str {
        case "pc", "origin": self = .pc
        case "steam": self = .steam
        case "ps3", "playstation3": self = .ps3
        case "ps4", "playstation4": self = .ps4
        case "ps5", "playstation5": self = .ps5
        case "playstation", "psn": self = .playstation
        case "xbox": self = .xbox
        case "xboxone", "xbox one": self = .xboxOne
        case "xboxseries", "xbox series", "xboxseriesx", "xboxseriess": self = .xboxSeries
        default:
            // Try to init with raw value
            self.init(rawValue: str)
        }
    }
}

// MARK: - BF6 Class Type Enum
enum BF6Class: String, CaseIterable, Identifiable {
    case assault = "Assault"
    case engineer = "Engineer"
    case support = "Support"
    case recon = "Recon"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .assault:
            return "Frontline infantry specialist with breach-and-clear gadgets"
        case .engineer:
            return "Vehicle and destruction expert with repair capabilities"
        case .support:
            return "Combat medic with healing, resupply, and revive abilities"
        case .recon:
            return "Intelligence and infiltration expert with marksmanship focus"
        }
    }
    
    var signatureGadget: String {
        switch self {
        case .assault: return "Adrenaline Injector"
        case .engineer: return "Repair Tool"
        case .support: return "Supply Crate"
        case .recon: return "Motion Sensor"
        }
    }
    
    var signatureWeaponType: String {
        switch self {
        case .assault: return "Assault Rifles"
        case .engineer: return "SMGs"
        case .support: return "LMGs"
        case .recon: return "Sniper Rifles"
        }
    }
    
    var color: Color {
        switch self {
        case .assault: return Theme.bf6Red
        case .engineer: return Theme.bf6Orange
        case .support: return Theme.bf6Green
        case .recon: return Theme.bf6Blue
        }
    }
    
    var iconName: String {
        switch self {
        case .assault: return "figure.run"
        case .engineer: return "wrench.and.screwdriver.fill"
        case .support: return "cross.case.fill"
        case .recon: return "scope"
        }
    }
}

// MARK: - Weapon Category Enum
enum WeaponCategory: String, CaseIterable, Identifiable {
    case assaultRifles = "Assault Rifles"
    case carbines = "Carbines"
    case smgs = "SMGs"
    case lmgs = "LMGs"
    case dmrs = "DMRs"
    case sniperRifles = "Sniper Rifles"
    case shotguns = "Shotguns"
    case pistols = "Pistols"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .assaultRifles: return "scope"
        case .carbines: return "rectangle.fill"
        case .smgs: return "bolt.fill"
        case .lmgs: return "rectangle.stack.fill"
        case .dmrs: return "target"
        case .sniperRifles: return "scope"
        case .shotguns: return "circle.grid.2x2.fill"
        case .pistols: return "hand.point.right.fill"
        }
    }
}

// MARK: - Vehicle Category Enum
enum VehicleCategory: String, CaseIterable, Identifiable {
    case mainBattleTank = "Main Battle Tank"
    case lightArmor = "Light Armor"
    case antiAircraft = "Anti-Aircraft"
    case attackHelicopter = "Attack Helicopter"
    case transportHelicopter = "Transport Helicopter"
    case jet = "Jet"
    case transportVehicle = "Transport Vehicle"
    case watercraft = "Watercraft"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .mainBattleTank: return "shield.fill"
        case .lightArmor: return "car.fill"
        case .antiAircraft: return "target"
        case .attackHelicopter: return "airplane"
        case .transportHelicopter: return "xmark"
        case .jet: return "airplane"
        case .transportVehicle: return "bus.fill"
        case .watercraft: return "ferry.fill"
        }
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
    }

    init(mapId: String, mapName: String, image: String, wins: Int, losses: Int, matches: Int, winPercentString: String, secondsPlayed: Int) {
        self.mapId = mapId
        self.mapName = mapName
        self.image = image
        self.wins = wins
        self.losses = losses
        self.matches = matches
        self.winPercentString = winPercentString
        self.secondsPlayed = secondsPlayed
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

// MARK: - Tile Position
struct TilePosition: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
}

// MARK: - App Settings
struct AppSettings: Codable {
    var playerName: String
    var platform: Platform
    var autoRefresh: Bool
    var refreshInterval: TimeInterval
    var tilePositions: [String: TilePosition]
    var showNotifications: Bool
    var compactMode: Bool
    var showEnhancedOverview: Bool
    var selectedColorScheme: AppColorScheme

    // EA Identity fields - populated from EAIdentityKit
    var nucleusId: String?        // pidId - Master account identifier
    var personaId: String?        // Per-game/platform identifier
    var eaId: String?             // Public username (EA ID)
    var isEAAuthenticated: Bool   // Whether user has logged in via EA

    init() {
        self.playerName = ""
        self.platform = .pc
        self.autoRefresh = true
        self.refreshInterval = 300 // 5 minutes
        self.tilePositions = [:]
        self.showNotifications = true
        self.compactMode = false
        self.showEnhancedOverview = true
        self.selectedColorScheme = .orange
        self.nucleusId = nil
        self.personaId = nil
        self.eaId = nil
        self.isEAAuthenticated = false
    }

    /// Update settings with EA identity information
    mutating func updateWithEAIdentity(nucleusId: String, personaId: String, eaId: String) {
        self.nucleusId = nucleusId
        self.personaId = personaId
        self.eaId = eaId
        self.playerName = eaId  // Use EA ID as the player name
        self.isEAAuthenticated = true
    }

    /// Clear EA identity information on logout
    mutating func clearEAIdentity() {
        self.nucleusId = nil
        self.personaId = nil
        self.eaId = nil
        self.isEAAuthenticated = false
    }
}

// MARK: - Error Types
enum BF6TrackerError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case playerNotFound
    case rateLimited
    case serverError(Int)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .playerNotFound:
            return "Player not found. Please check the username and platform."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error (code: \(code)). Please try again later."
        case .unknown:
            return "An unknown error occurred"
        }
    }
}


