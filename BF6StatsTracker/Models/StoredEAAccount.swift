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
//  StoredEAAccount.swift
//  BF6StatsTracker
//
//  Created by Claude on 2025-12-29.
//

import Foundation

/// Represents a stored EA account that can be used for quick login without re-authentication
struct StoredEAAccount: Codable, Identifiable, Equatable {
    let id: UUID
    let nucleusId: String
    let personaId: String
    let eaId: String
    let displayName: String?
    let lastUsed: Date
    let addedAt: Date

    // Additional fields from rip-bf.com API
    let userId: String?
    let avatarUrl: String?
    let subscriptionLevel: String?
    let nickname: String?
    let platform: String?
    let status: String?
    let createdAt: String?
    let platformIcon: String?

    /// The text to display in the UI (custom name or EA ID)
    var displayText: String {
        displayName ?? eaId
    }

    /// Initialize a new stored account from an EA identity
    init(from identity: EAPlayerIdentity, displayName: String? = nil) {
        self.id = UUID()
        self.nucleusId = identity.nucleusId
        self.personaId = identity.personaId
        self.eaId = identity.eaId
        self.displayName = displayName
        self.addedAt = Date()
        self.lastUsed = Date()
        self.userId = nil
        self.avatarUrl = nil
        self.subscriptionLevel = nil
        self.nickname = nil
        self.platform = nil
        self.status = nil
        self.createdAt = nil
        self.platformIcon = nil
    }

    /// Initialize from rip-bf.com API response
    /// Maps API fields to StoredEAAccount structure:
    /// - userId = nucleusId
    /// - id = personaId
    /// - EAID = eaId
    init(from apiUser: RipBFAPIUser, displayName: String? = nil) {
        self.id = UUID()
        self.nucleusId = apiUser.userId
        self.personaId = apiUser.id
        self.eaId = apiUser.EAID
        self.displayName = displayName
        self.addedAt = Date()
        self.lastUsed = Date()
        self.userId = apiUser.userId
        self.avatarUrl = apiUser.avatarUrl
        self.subscriptionLevel = apiUser.subscriptionLevel
        self.nickname = apiUser.nickname
        self.platform = apiUser.platform
        self.status = apiUser.status
        self.createdAt = apiUser.createdAt
        self.platformIcon = apiUser.platformIcon
    }

    /// Initialize with all fields (for decoding or testing)
    init(id: UUID = UUID(), nucleusId: String, personaId: String, eaId: String, displayName: String? = nil, lastUsed: Date = Date(), addedAt: Date = Date(), userId: String? = nil, avatarUrl: String? = nil, subscriptionLevel: String? = nil, nickname: String? = nil, platform: String? = nil, status: String? = nil, createdAt: String? = nil, platformIcon: String? = nil) {
        self.id = id
        self.nucleusId = nucleusId
        self.personaId = personaId
        self.eaId = eaId
        self.displayName = displayName
        self.lastUsed = lastUsed
        self.addedAt = addedAt
        self.userId = userId
        self.avatarUrl = avatarUrl
        self.subscriptionLevel = subscriptionLevel
        self.nickname = nickname
        self.platform = platform
        self.status = status
        self.createdAt = createdAt
        self.platformIcon = platformIcon
    }

    /// Convert to EAPlayerIdentity for use with existing authentication system
    func toIdentity() -> EAPlayerIdentity {
        EAPlayerIdentity(
            nucleusId: nucleusId,
            personaId: personaId,
            eaId: eaId,
            authenticatedAt: Date()
        )
    }

    /// Create a copy with updated last used time
    func withUpdatedLastUsed() -> StoredEAAccount {
        StoredEAAccount(
            id: id,
            nucleusId: nucleusId,
            personaId: personaId,
            eaId: eaId,
            displayName: displayName,
            lastUsed: Date(),
            addedAt: addedAt,
            userId: userId,
            avatarUrl: avatarUrl,
            subscriptionLevel: subscriptionLevel,
            nickname: nickname,
            platform: platform,
            status: status,
            createdAt: createdAt,
            platformIcon: platformIcon
        )
    }

    /// Create a copy with updated display name
    func withDisplayName(_ name: String?) -> StoredEAAccount {
        StoredEAAccount(
            id: id,
            nucleusId: nucleusId,
            personaId: personaId,
            eaId: eaId,
            displayName: name,
            lastUsed: lastUsed,
            addedAt: addedAt,
            userId: userId,
            avatarUrl: avatarUrl,
            subscriptionLevel: subscriptionLevel,
            nickname: nickname,
            platform: platform,
            status: status,
            createdAt: createdAt,
            platformIcon: platformIcon
        )
    }

    /// Formatted relative time since last use
    var lastUsedFormatted: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: lastUsed, to: now)

        if let weeks = components.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        } else if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - RipBF API Models

/// Response from rip-bf.com API endpoint
struct RipBFAPIResponse: Codable {
    let error: Bool
    let message: String
    let users: [RipBFAPIUser]?
}

/// User data from rip-bf.com API
struct RipBFAPIUser: Codable {
    let EAID: String
    let userId: String
    let id: String
    let avatarUrl: String?
    let subscriptionLevel: String?
    let nickname: String?
    let platform: String?
    let status: String?
    let createdAt: String?
    let platformIcon: String?
}
