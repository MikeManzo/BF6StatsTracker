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
//  SquadComparison.swift
//  BF6StatsTracker
//
//  Squad comparison models and ranking logic
//

import Foundation

// MARK: - Squad Comparison Models

/// Represents a squad member for comparison
struct SquadMember: Identifiable, Codable, Hashable {
    let id: UUID
    var eaId: String
    var platform: Platform
    var displayName: String?
    var stats: PlayerStats?
    var profileData: ProfileData?
    var lastFetched: Date?
    var fetchError: String?
    
    var isLoaded: Bool { stats != nil }
    var hasError: Bool { fetchError != nil }
    
    var effectiveName: String {
        displayName ?? eaId
    }
    
    init(id: UUID = UUID(), eaId: String, platform: Platform, displayName: String? = nil) {
        self.id = id
        self.eaId = eaId
        self.platform = platform
        self.displayName = displayName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SquadMember, rhs: SquadMember) -> Bool {
        lhs.id == rhs.id
    }
}

/// Squad comparison data with ranking calculations
struct SquadComparison {
    let members: [SquadMember]
    
    var loadedMembers: [SquadMember] {
        members.filter { $0.isLoaded }
    }
    
    /// Calculate rankings for a specific metric
    func rankings(for metric: ComparisonMetric) -> [UUID: Int] {
        let membersWithStats = loadedMembers
        
        guard !membersWithStats.isEmpty else { return [:] }
        
        // Extract values
        let values: [(UUID, Double)] = membersWithStats.compactMap { member in
            guard let stats = member.stats else { return nil }
            return (member.id, metric.extractValue(from: stats))
        }
        
        // Sort based on higherIsBetter
        let sorted = metric.higherIsBetter
            ? values.sorted { $0.1 > $1.1 }  // Descending
            : values.sorted { $0.1 < $1.1 }  // Ascending
        
        // Assign ranks (handle ties)
        var rankings: [UUID: Int] = [:]
        var currentRank = 1
        var previousValue: Double? = nil
        var sameRankCount = 0
        
        for (id, value) in sorted {
            if let prev = previousValue, abs(value - prev) < 0.001 {
                // Tie - use same rank
                rankings[id] = currentRank - 1
                sameRankCount += 1
            } else {
                currentRank += sameRankCount
                rankings[id] = currentRank
                sameRankCount = 1
            }
            previousValue = value
        }
        
        return rankings
    }
    
    /// Get value for a specific member and metric
    func value(for member: SquadMember, metric: ComparisonMetric) -> Double? {
        guard let stats = member.stats else { return nil }
        return metric.extractValue(from: stats)
    }
}
