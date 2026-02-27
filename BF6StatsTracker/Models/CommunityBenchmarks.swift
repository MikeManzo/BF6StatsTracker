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
//  CommunityBenchmarks.swift
//  BF6StatsTracker
//
//  Community-based performance benchmarks and percentile calculations
//  Based on research from Tracker.gg, EA Forums, and community discussions
//

// There is no public API for this data, so I turned to AI to help define it.
// Below is the prompt used in the first generation of this file.

/*
 AI PROMPT FOR UPDATING BENCHMARKS:
 
 I need you to update the CommunityBenchmarks.swift file with new performance thresholds based on recent community data for Battlefild 6 only.
 
 Instructions:
 1. Research the latest Battlefield 6 community statistics from these sources:
    - Tracker.gg leaderboards and percentile data
    - Steam Community forum discussions about player performance
    - EA Forums player statistics discussions
    - Reddit r/battlefield6 community data posts
 
 2. For each metric below, provide updated threshold ranges for the 9 performance tiers:
    - Bottom (0-10th percentile)
    - Below Average (10th-30th percentile)
    - Low Average (30th-50th percentile)
    - Average (50th-70th percentile)
    - Above Average (70th-85th percentile)
    - Good (85th-93rd percentile)
    - Very Good (93rd-97th percentile)
    - Excellent (97th-99th percentile)
    - Elite (Top 1%)
 
 3. Metrics to update:
    a) K/D Ratio (kdPercentile function)
    b) Win Rate Percentage (winRatePercentile function)
    c) Kills Per Minute (kpmPercentile function)
    d) Score Per Minute (spmPercentile function)
    e) Accuracy Percentage (accuracyPercentile function)
    f) Weapon Kills (weaponKillsPercentile function)
    g) Revives Per Match (revivesPercentile function)
    h) Assists Per Match (assistsPercentile function)
 
 4. Update each function's switch statement with the new thresholds
 
 5. Update the inline comments documenting:
    - What constitutes "average" for that metric
    - What elite players typically achieve
    - Any notable percentile landmarks (e.g., "2.0 K/D = Top 5%")
 
 6. Preserve the existing code structure, PerformanceTier enum, and disclaimer text
 
 7. Add a comment at the top noting when the benchmarks were last updated and the data sources used
 
 Example output format for each function:
 ```swift
 /// Calculate K/D performance tier
 /// Updated: [DATE]
 /// Average K/D: ~[VALUE], Top 10%: [VALUE]+, Elite: [VALUE]+
 /// Sources: [List sources]
 static func kdPercentile(kd: Double) -> PerformanceTier {
     switch kd {
     case 0..<[THRESHOLD]: return .bottom
     case [THRESHOLD]..<[THRESHOLD]: return .belowAverage
     // ... etc
     }
 }
 ```
 
 After researching and updating, provide a summary of the major changes in threshold values.
*/

import Foundation
import SwiftUI

// MARK: - Performance Tier

enum PerformanceTier: Equatable {
    case bottom      // Bottom 10%
    case belowAverage // 10th-30th percentile
    case lowAverage  // 30th-50th percentile
    case average     // 50th-70th percentile
    case aboveAverage // 70th-85th percentile
    case good        // 85th-93rd percentile
    case veryGood    // 93rd-97th percentile
    case excellent   // 97th-99th percentile
    case elite       // Top 1%
    
    var color: Color {
        switch self {
        case .bottom: return .red
        case .belowAverage: return .orange
        case .lowAverage: return .yellow
        case .average: return Theme.bf6Blue
        case .aboveAverage: return Theme.bf6Green
        case .good: return .green
        case .veryGood: return .cyan
        case .excellent: return .purple
        case .elite: return .pink
        }
    }
    
    var label: String {
        switch self {
        case .bottom: return "Bottom 10%"
        case .belowAverage: return "Below Average"
        case .lowAverage: return "Low Average"
        case .average: return "Average"
        case .aboveAverage: return "Above Average"
        case .good: return "Good"
        case .veryGood: return "Very Good"
        case .excellent: return "Excellent"
        case .elite: return "Elite"
        }
    }
    
    var percentileRange: String {
        switch self {
        case .bottom: return "Bottom 10%"
        case .belowAverage: return "10th-30th"
        case .lowAverage: return "30th-50th"
        case .average: return "50th-70th"
        case .aboveAverage: return "70th-85th"
        case .good: return "85th-93rd"
        case .veryGood: return "93rd-97th"
        case .excellent: return "97th-99th"
        case .elite: return "Top 1%"
        }
    }
    
    var icon: String {
        switch self {
        case .bottom: return "arrow.down.circle.fill"
        case .belowAverage: return "arrow.down.circle"
        case .lowAverage: return "minus.circle"
        case .average: return "equal.circle"
        case .aboveAverage: return "arrow.up.circle"
        case .good: return "arrow.up.circle.fill"
        case .veryGood: return "star.circle.fill"
        case .excellent: return "star.fill"
        case .elite: return "crown.fill"
        }
    }
}

// MARK: - Community Benchmarks

struct CommunityBenchmarks {
    
    // MARK: - Disclaimer
    
    static let disclaimer = "Percentile estimates based on community data and public leaderboard analysis. Rankings are approximate and may not reflect actual statistics."
    
    // MARK: - K/D Ratio Percentiles
    
    /// Calculate K/D performance tier based on community benchmarks
    /// Research sources: Tracker.gg leaderboards, Steam Community discussions
    /// Average community K/D: ~0.98-1.0
    /// 2.6 K/D = Top 10-11%, 2.0 K/D ≈ Top 5%
    static func kdPercentile(kd: Double) -> PerformanceTier {
        switch kd {
        case 0..<0.50: return .bottom
        case 0.50..<0.80: return .belowAverage
        case 0.80..<1.00: return .lowAverage
        case 1.00..<1.30: return .average
        case 1.30..<1.50: return .aboveAverage
        case 1.50..<2.00: return .good
        case 2.00..<2.60: return .veryGood
        case 2.60..<3.50: return .excellent
        default: return .elite
        }
    }
    
    // MARK: - Win Rate Percentiles
    
    /// Calculate win rate performance tier
    /// Research: 50% win rate = baseline/average
    /// Solo players: 40-55%, Squad players: 50-65%
    static func winRatePercentile(winRate: Double) -> PerformanceTier {
        switch winRate {
        case 0..<35: return .bottom
        case 35..<45: return .belowAverage
        case 45..<50: return .lowAverage
        case 50..<55: return .average
        case 55..<60: return .aboveAverage
        case 60..<65: return .good
        case 65..<70: return .veryGood
        case 70..<75: return .excellent
        default: return .elite
        }
    }
    
    // MARK: - Kills Per Minute Percentiles
    
    /// Calculate KPM performance tier
    /// Estimated average: 0.6-0.8 KPM
    /// Aggressive players: 1.0-1.5 KPM, Elite: 1.5+ KPM
    static func kpmPercentile(kpm: Double) -> PerformanceTier {
        switch kpm {
        case 0..<0.30: return .bottom
        case 0.30..<0.50: return .belowAverage
        case 0.50..<0.70: return .lowAverage
        case 0.70..<0.90: return .average
        case 0.90..<1.20: return .aboveAverage
        case 1.20..<1.50: return .good
        case 1.50..<2.00: return .veryGood
        case 2.00..<2.50: return .excellent
        default: return .elite
        }
    }
    
    // MARK: - Score Per Minute Percentiles
    
    /// Calculate SPM performance tier
    static func spmPercentile(spm: Double) -> PerformanceTier {
        switch spm {
        case 0..<200: return .bottom
        case 200..<300: return .belowAverage
        case 300..<400: return .lowAverage
        case 400..<500: return .average
        case 500..<600: return .aboveAverage
        case 600..<700: return .good
        case 700..<850: return .veryGood
        case 850..<1000: return .excellent
        default: return .elite
        }
    }
    
    // MARK: - Accuracy Percentiles
    
    /// Calculate accuracy performance tier
    static func accuracyPercentile(accuracy: Double) -> PerformanceTier {
        switch accuracy {
        case 0..<10: return .bottom
        case 10..<15: return .belowAverage
        case 15..<20: return .lowAverage
        case 20..<25: return .average
        case 25..<30: return .aboveAverage
        case 30..<35: return .good
        case 35..<40: return .veryGood
        case 40..<45: return .excellent
        default: return .elite
        }
    }
    
    // MARK: - Weapon Kills Percentiles
    
    /// Calculate weapon mastery tier based on kills with a single weapon
    /// Mastery Level 12 = 360 kills, Level 40 (T1) ≈ 1,200 kills
    static func weaponKillsPercentile(kills: Int) -> PerformanceTier {
        switch kills {
        case 0..<50: return .bottom
        case 50..<100: return .belowAverage
        case 100..<250: return .lowAverage
        case 250..<500: return .average
        case 500..<1000: return .aboveAverage
        case 1000..<2000: return .good
        case 2000..<5000: return .veryGood
        case 5000..<10000: return .excellent
        default: return .elite
        }
    }
    
    // MARK: - Revives Per Match Percentiles
    
    /// Calculate revives performance tier (per match average)
    /// Highly dependent on class - Support/Assault have revival capability
    static func revivesPercentile(revivesPerMatch: Double) -> PerformanceTier {
        switch revivesPerMatch {
        case 0..<1: return .bottom
        case 1..<2: return .belowAverage
        case 2..<3: return .lowAverage
        case 3..<5: return .average
        case 5..<8: return .aboveAverage
        case 8..<11: return .good
        case 11..<15: return .veryGood
        case 15..<20: return .excellent
        default: return .elite
        }
    }
    
    // MARK: - Assists Percentiles
    
    /// Calculate assists performance tier (total career assists)
    static func assistsPercentile(assistsPerMatch: Double) -> PerformanceTier {
        switch assistsPerMatch {
        case 0..<1: return .bottom
        case 1..<2: return .belowAverage
        case 2..<3: return .lowAverage
        case 3..<4: return .average
        case 4..<5: return .aboveAverage
        case 5..<7: return .good
        case 7..<10: return .veryGood
        case 10..<15: return .excellent
        default: return .elite
        }
    }
}
