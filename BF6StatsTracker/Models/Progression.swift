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
//  Progression.swift
//  BF6StatsTracker
//
//  Progression system and XP multiplier models
//

import Foundation

// MARK: - Progression Types

struct ProgressionTypeResponse: Codable {
    let entries: [ProgressionMode]
}

struct ProgressionMode: Codable, Identifiable {
    var id: String { progressionMode }

    let progressionMode: String
    let progressibles: [Progressible]

    // Computed properties for easy access to XP multipliers
    var aiXpFactor: Double {
        progressibles.first(where: { $0.name == "AiXpFactor" })?.kind.mutatorFloat?.value ?? 0.0
    }

    var matchBonusXpFactor: Double {
        progressibles.first(where: { $0.name == "FromMatchBonusXpFactor" })?.kind.mutatorFloat?.value ?? 1.0
    }

    var winBonusXpFactor: Double {
        progressibles.first(where: { $0.name == "FromWinBonusXpFactor" })?.kind.mutatorFloat?.value ?? 1.0
    }

    var persistStats: Bool {
        // If PersistStats field exists, it means stats are NOT tracked (false)
        // If PersistStats field is absent, stats ARE tracked (true)
        let hasPersistStatsField = progressibles.contains(where: { $0.name == "PersistStats" })
        return !hasPersistStatsField
    }

    // Human-readable display name
    var displayName: String {
        switch progressionMode {
        case "official-progression": return "Official Match"
        case "portal-default": return "Portal Default"
        case "portal-unranked": return "Portal Unranked"
        case "portal-fallback": return "Portal Fallback"
        case "onboarding-santiago-progression": return "Tutorial"
        case "onboarding-f2p-progression": return "F2P Tutorial"
        case "official-gauntlet-progression": return "Gauntlet"
        case "casual-AI-Progression": return "Casual AI"
        case "official-strikepoint-temp": return "Strikepoint"
        case "portal-default-backfillai": return "Portal w/ AI Backfill"
        default: return progressionMode.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    // Short description of XP rules
    var xpDescription: String {
        let aiPenalty = Int((1.0 - aiXpFactor) * 100)
        if !persistStats {
            return "Stats not tracked"
        } else if aiXpFactor == 0.0 {
            return "No XP from AI"
        } else if aiXpFactor < 1.0 {
            return "\(aiPenalty)% AI XP penalty"
        } else {
            return "Full XP"
        }
    }

    // Badge color based on progression quality
    var badgeColor: String {
        if !persistStats {
            return "gray"
        } else if aiXpFactor >= 0.25 {
            return "green"
        } else if aiXpFactor >= 0.15 {
            return "orange"
        } else {
            return "red"
        }
    }
}

struct Progressible: Codable {
    let name: String
    let category: String
    let kind: ProgressibleKind
    let id: String
}

struct ProgressibleKind: Codable {
    let mutatorFloat: MutatorFloat?
    let mutatorBoolean: MutatorBoolean?
    let mutatorSparseBoolean: MutatorSparseBoolean?
}

struct MutatorFloat: Codable {
    let value: Double?

    init(value: Double?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIfPresent(Double.self, forKey: .value)
    }

    enum CodingKeys: String, CodingKey {
        case value
    }
}

struct MutatorBoolean: Codable {
    let value: Bool?

    init(value: Bool?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIfPresent(Bool.self, forKey: .value)
    }

    enum CodingKeys: String, CodingKey {
        case value
    }
}

struct MutatorSparseBoolean: Codable {
    let defaultValue: Bool?
    let size: Int?
    let sparseValues: [SparseValue]?

    struct SparseValue: Codable {
        let index: Int?
        let value: Bool?
    }
}
