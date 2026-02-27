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
//  ProfileData.swift
//  BF6StatsTracker
//
//  Profile and rank data models from /bf6/profile endpoint
//

import Foundation

// MARK: - Profile Data

/// Rank image URLs from profile endpoint
struct RankImage: Codable {
    let small: String?
    let large: String?
}

/// Player card information from profile endpoint
struct PlayerCard: Codable {
    let badges: Int?
    let rank: Int?
    let rankImage: RankImage?
}

/// Profile information from /bf6/profile endpoint
struct ProfileData: Codable {
    let playerProfiles: [PlayerProfile]?
    
    /// Convenience accessor for the first player profile's card
    var playerCard: PlayerCard? {
        return playerProfiles?.first?.playerCard
    }
    
    /// Convenience accessor for rank
    var rank: Int? {
        return playerCard?.rank
    }
    
    /// Convenience accessor for badges
    var badges: Int? {
        return playerCard?.badges
    }
    
    /// Convenience accessor for rank image URL (uses small image)
    var rankImg: String? {
        return playerCard?.rankImage?.small
    }
    
    /// Parse extended stats from profile stats array
    var extendedStats: ExtendedProfileStats? {
        guard let profile = playerProfiles?.first,
              let stats = profile.stats else {
            return nil
        }
        return ExtendedProfileStats(from: stats)
    }
}

/// Individual player profile entry
struct PlayerProfile: Codable {
    let playerCard: PlayerCard?
    let stats: [ProfileStat]?
    let intValue: Int?
}

/// Individual stat entry in profile
struct ProfileStat: Codable {
    let name: String?
    let value: Int?
}
