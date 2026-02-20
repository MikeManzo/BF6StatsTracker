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
//  Enums.swift
//  BF6StatsTracker
//
//  Enumeration types for platforms, classes, categories, and metrics
//

import Foundation
import SwiftUI

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
    case smgs = "SMG-PDW"  // API uses "SMG-PDW"
    case lmgs = "LMG"      // API uses "LMG" (singular)
    case dmrs = "DMR"      // API uses "DMR" (singular)
    case sniperRifles = "Rifles"  // API uses "Rifles"
    case shotguns = "Shotgun"     // API uses "Shotgun" (singular)
    case pistols = "Pistols"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .assaultRifles: return "Assault Rifles"
        case .carbines: return "Carbines"
        case .smgs: return "SMGs"
        case .lmgs: return "LMGs"
        case .dmrs: return "DMRs"
        case .sniperRifles: return "Sniper Rifles"
        case .shotguns: return "Shotguns"
        case .pistols: return "Pistols"
        }
    }

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
    case airCombat = "Air Combat"
    case airTransport = "Air Transport"
    case groundCombat = "Ground Combat"
    case groundTransport = "Ground Transport"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .airCombat: return "airplane"
        case .airTransport: return "fan.oscillation.fill"
        case .groundCombat: return "shield.fill"
        case .groundTransport: return "car.fill"
        }
    }

    var color: Color {
        switch self {
        case .airCombat: return Theme.bf6Red
        case .airTransport: return Theme.bf6Blue
        case .groundCombat: return Theme.bf6Orange
        case .groundTransport: return Theme.bf6Green
        }
    }
}

// MARK: - Metric Category
/// Metric categories for organizing comparisons
enum MetricCategory: String, CaseIterable, Identifiable {
    case combat = "Combat"
    case teamSupport = "Team Support"
    case progression = "Progression"
    case winRate = "Win Performance"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .combat: return "scope"
        case .teamSupport: return "person.2.fill"
        case .progression: return "chart.line.uptrend.xyaxis"
        case .winRate: return "trophy.fill"
        }
    }
}

// MARK: - Comparison Metric
/// Individual metrics for comparison
enum ComparisonMetric: String, CaseIterable, Identifiable {
    // Combat Performance
    case kdRatio = "K/D Ratio"
    case kdaRatio = "KDA Ratio"
    case kills = "Kills"
    case deaths = "Deaths"
    case headshotPercent = "Headshot %"
    case accuracy = "Accuracy %"
    case killsPerMinute = "Kills/Min"
    case scorePerMinute = "Score/Min"
    
    // Team Support
    case revives = "Revives"
    case assists = "Assists"
    case spotAssists = "Spot Assists"
    case resupplies = "Resupplies"
    
    // Progression
    case totalXP = "Total XP"
    case playtime = "Hours Played"
    case matchesPlayed = "Matches"
    
    // Win Performance
    case winPercent = "Win %"
    case wins = "Wins"
    case matchesWon = "Matches Won"
    
    var id: String { rawValue }
    
    var category: MetricCategory {
        switch self {
        case .kdRatio, .kdaRatio, .kills, .deaths, .headshotPercent, .accuracy, .killsPerMinute, .scorePerMinute:
            return .combat
        case .revives, .assists, .spotAssists, .resupplies:
            return .teamSupport
        case .totalXP, .playtime, .matchesPlayed:
            return .progression
        case .winPercent, .wins, .matchesWon:
            return .winRate
        }
    }
    
    var icon: String {
        switch self {
        case .kdRatio, .kdaRatio: return "chart.line.uptrend.xyaxis"
        case .kills: return "target"
        case .deaths: return "xmark.circle"
        case .headshotPercent: return "scope"
        case .accuracy: return "target"
        case .killsPerMinute: return "bolt.fill"
        case .scorePerMinute: return "star.fill"
        case .revives: return "heart.fill"
        case .assists: return "hand.thumbsup.fill"
        case .spotAssists: return "eye.fill"
        case .resupplies: return "shippingbox.fill"
        case .totalXP: return "star.circle.fill"
        case .playtime: return "clock.fill"
        case .matchesPlayed: return "gamecontroller.fill"
        case .winPercent: return "percent"
        case .wins: return "trophy.fill"
        case .matchesWon: return "checkmark.circle.fill"
        }
    }
    
    var higherIsBetter: Bool {
        self != .deaths
    }
    
    func extractValue(from stats: PlayerStats) -> Double {
        switch self {
        case .kdRatio: return stats.kdRatio
        case .kdaRatio:
            // Calculate KDA: (Kills + Assists) / Deaths
            let killsAndAssists = stats.kills + stats.assists
            return stats.deaths > 0 ? Double(killsAndAssists) / Double(stats.deaths) : Double(killsAndAssists)
        case .kills: return Double(stats.kills)
        case .deaths: return Double(stats.deaths)
        case .headshotPercent: return stats.headshotPercentage
        case .accuracy: return stats.accuracy
        case .killsPerMinute: return stats.killsPerMinute
        case .scorePerMinute: return stats.scorePerMinute
        case .revives: return Double(stats.revives)
        case .assists: return Double(stats.assists)
        case .spotAssists: return Double(stats.enemiesSpotted)
        case .resupplies: return Double(stats.resupplies)
        case .totalXP: return Double(stats.totalScore)
        case .playtime: return Double(stats.secondsPlayed) / 3600.0
        case .matchesPlayed: return Double(stats.matchesPlayed)
        case .winPercent: return stats.wlRatio
        case .wins: return Double(stats.wins)
        case .matchesWon: return Double(stats.wins)
        }
    }
    
    func formatValue(_ value: Double) -> String {
        switch self {
        case .kdRatio, .kdaRatio:
            return String(format: "%.2f", value)
        case .headshotPercent, .accuracy, .winPercent:
            return String(format: "%.1f%%", value)
        case .killsPerMinute, .scorePerMinute:
            return String(format: "%.2f", value)
        case .playtime:
            return String(format: "%.1f hrs", value)
        case .totalXP:
            if value >= 1_000_000 {
                return String(format: "%.1fM", value / 1_000_000)
            } else if value >= 1_000 {
                return String(format: "%.1fK", value / 1_000)
            } else {
                return String(format: "%.0f", value)
            }
        default:
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Appearance Mode
enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil  // nil means system default
        }
    }
}
