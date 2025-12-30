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
    }

    /// Initialize with all fields (for decoding or testing)
    init(id: UUID = UUID(), nucleusId: String, personaId: String, eaId: String, displayName: String? = nil, lastUsed: Date = Date(), addedAt: Date = Date()) {
        self.id = id
        self.nucleusId = nucleusId
        self.personaId = personaId
        self.eaId = eaId
        self.displayName = displayName
        self.lastUsed = lastUsed
        self.addedAt = addedAt
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
            addedAt: addedAt
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
            addedAt: addedAt
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
