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
//  SquadService.swift
//  BF6StatsTracker
//
//  Service for managing squad member data and fetching stats
//

import Foundation
import SwiftUI

@MainActor
class SquadService: ObservableObject {
    static let shared = SquadService()
    
    @Published var squadMembers: [SquadMember] = []
    @Published var isRefreshing = false
    @Published var lastRefreshDate: Date?
    
    private let apiService = APIService.shared
    private let cacheManager = CacheManager.shared
    
    private init() {
        loadSquadFromStorage()
    }
    
    // MARK: - Squad Management
    
    func addMember(eaId: String, platform: Platform, displayName: String? = nil) async throws {
        // Check if member already exists
        if squadMembers.contains(where: { $0.eaId.lowercased() == eaId.lowercased() && $0.platform == platform }) {
            throw SquadError.memberAlreadyExists
        }
        
        // Check squad size limit (max 3 additional members + user)
        if squadMembers.count >= 3 {
            throw SquadError.squadFull
        }
        
        var newMember = SquadMember(eaId: eaId, platform: platform, displayName: displayName)
        
        // Fetch stats immediately
        do {
            let identifier = PlayerIdentifier(name: eaId, platform: platform)
            let stats = try await apiService.fetchPlayerStats(identifier: identifier)
            newMember.stats = stats
            newMember.lastFetched = Date()
            newMember.fetchError = nil
            
            LoggerService.shared.info("Successfully fetched stats for squad member: \(eaId)", category: .api)
        } catch {
            newMember.fetchError = error.localizedDescription
            LoggerService.shared.error("Failed to fetch stats for squad member \(eaId): \(error)", category: .error)
        }
        
        squadMembers.append(newMember)
        saveSquadToStorage()
    }
    
    func removeMember(id: UUID) {
        squadMembers.removeAll { $0.id == id }
        saveSquadToStorage()
        LoggerService.shared.info("Removed squad member with ID: \(id)", category: .general)
    }
    
    func updateDisplayName(for id: UUID, newName: String) {
        if let index = squadMembers.firstIndex(where: { $0.id == id }) {
            squadMembers[index].displayName = newName
            saveSquadToStorage()
        }
    }
    
    // MARK: - Stats Fetching
    
    func refreshAllMembers() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        LoggerService.shared.info("Refreshing stats for \(squadMembers.count) squad members", category: .api)
        
        await withTaskGroup(of: (UUID, Result<PlayerStats, Error>).self) { group in
            for member in squadMembers {
                group.addTask {
                    let identifier = PlayerIdentifier(name: member.eaId, platform: member.platform)
                    do {
                        let stats = try await self.apiService.fetchPlayerStats(identifier: identifier)
                        return (member.id, .success(stats))
                    } catch {
                        return (member.id, .failure(error))
                    }
                }
            }
            
            for await (memberId, result) in group {
                if let index = squadMembers.firstIndex(where: { $0.id == memberId }) {
                    switch result {
                    case .success(let stats):
                        squadMembers[index].stats = stats
                        squadMembers[index].lastFetched = Date()
                        squadMembers[index].fetchError = nil
                        LoggerService.shared.info("Refreshed stats for member: \(squadMembers[index].eaId)", category: .api)
                    case .failure(let error):
                        squadMembers[index].fetchError = error.localizedDescription
                        LoggerService.shared.error("Failed to refresh member \(squadMembers[index].eaId): \(error)", category: .error)
                    }
                }
            }
        }
        
        lastRefreshDate = Date()
        saveSquadToStorage()
    }
    
    func retryMember(id: UUID) async {
        guard let index = squadMembers.firstIndex(where: { $0.id == id }) else { return }
        
        let member = squadMembers[index]
        let identifier = PlayerIdentifier(name: member.eaId, platform: member.platform)
        
        do {
            let stats = try await apiService.fetchPlayerStats(identifier: identifier)
            squadMembers[index].stats = stats
            squadMembers[index].lastFetched = Date()
            squadMembers[index].fetchError = nil
            saveSquadToStorage()
            LoggerService.shared.info("Successfully retried fetching stats for: \(member.eaId)", category: .api)
        } catch {
            squadMembers[index].fetchError = error.localizedDescription
            LoggerService.shared.error("Retry failed for member \(member.eaId): \(error)", category: .error)
        }
    }
    
    // MARK: - Persistence
    
    private func saveSquadToStorage() {
        // Save only essential data (not full PlayerStats which can be large)
        let persistableData = squadMembers.map { member in
            PersistableSquadMember(
                id: member.id,
                eaId: member.eaId,
                platform: member.platform,
                displayName: member.displayName
            )
        }
        
        if let encoded = try? JSONEncoder().encode(persistableData) {
            UserDefaults.standard.set(encoded, forKey: "squadMembers")
            LoggerService.shared.info("Saved \(persistableData.count) squad members to storage", category: .storage)
        }
    }
    
    private func loadSquadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: "squadMembers"),
              let persistableMembers = try? JSONDecoder().decode([PersistableSquadMember].self, from: data) else {
            LoggerService.shared.info("No saved squad members found", category: .storage)
            return
        }
        
        squadMembers = persistableMembers.map { pm in
            SquadMember(id: pm.id, eaId: pm.eaId, platform: pm.platform, displayName: pm.displayName)
        }
        
        LoggerService.shared.info("Loaded \(squadMembers.count) squad members from storage", category: .storage)
        
        // Fetch stats in background
        Task {
            await refreshAllMembers()
        }
    }
    
    func clearSquad() {
        squadMembers.removeAll()
        saveSquadToStorage()
        LoggerService.shared.info("Cleared all squad members", category: .general)
    }
}

// MARK: - Persistable Squad Member

private struct PersistableSquadMember: Codable {
    let id: UUID
    let eaId: String
    let platform: Platform
    let displayName: String?
}

// MARK: - Squad Errors

enum SquadError: LocalizedError {
    case memberAlreadyExists
    case squadFull
    case invalidEAId
    
    var errorDescription: String? {
        switch self {
        case .memberAlreadyExists:
            return "This player is already in your squad"
        case .squadFull:
            return "Squad is full (maximum 3 members)"
        case .invalidEAId:
            return "Invalid EA ID"
        }
    }
}
