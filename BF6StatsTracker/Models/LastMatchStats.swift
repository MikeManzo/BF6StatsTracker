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
//  LastMatchStats.swift
//  BF6StatsTracker
//
//  In-round and last match statistics models
//

import Foundation

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
