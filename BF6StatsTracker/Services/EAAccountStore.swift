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
//  EAAccountStore.swift
//  BF6StatsTracker
//
//  Created by Claude on 2025-12-29.
//

import Foundation

/// Manager for storing and retrieving multiple EA accounts
@MainActor
class EAAccountStore: ObservableObject {
    static let shared = EAAccountStore()

    @Published private(set) var accounts: [StoredEAAccount] = []

    private let storageKey = "StoredEAAccounts"
    private let userDefaults = UserDefaults.standard

    init() {
        loadAccounts()
    }

    // MARK: - Account Management

    /// Save the current authenticated account to the store
    /// - Parameters:
    ///   - identity: The EA player identity from authentication
    ///   - displayName: Optional custom display name for this account
    func saveCurrentAccount(from identity: EAPlayerIdentity, displayName: String? = nil) {
        logInfo("EAAccountStore: Saving account for \(identity.eaId)", category: .cache)

        // Check if account already exists (by nucleusId or personaId)
        if let existingIndex = accounts.firstIndex(where: { $0.nucleusId == identity.nucleusId || $0.personaId == identity.personaId }) {
            // Update existing account's last used time
            var updated = accounts[existingIndex].withUpdatedLastUsed()
            // Update display name if provided
            if let displayName = displayName {
                updated = updated.withDisplayName(displayName)
            }
            accounts[existingIndex] = updated
            logInfo("Updated existing account at index \(existingIndex)", category: .cache)
        } else {
            // Add new account
            let newAccount = StoredEAAccount(from: identity, displayName: displayName)
            accounts.append(newAccount)
            logInfo("Added new account. Total accounts: \(accounts.count)", category: .cache)
        }

        // Sort by last used (most recent first)
        accounts.sort { $0.lastUsed > $1.lastUsed }

        persistAccounts()
        logInfo("Persisted \(accounts.count) account(s) to UserDefaults with key: \(storageKey)", category: .cache)
    }

    /// Save an account directly to the store
    /// - Parameter account: The StoredEAAccount to save
    func saveAccount(_ account: StoredEAAccount) {
        logInfo("EAAccountStore: Saving account for \(account.eaId)", category: .cache)

        // Check if account already exists (by nucleusId or personaId)
        if let existingIndex = accounts.firstIndex(where: { $0.nucleusId == account.nucleusId || $0.personaId == account.personaId }) {
            // Update existing account's last used time
            accounts[existingIndex] = account.withUpdatedLastUsed()
            logInfo("Updated existing account at index \(existingIndex)", category: .cache)
        } else {
            // Add new account
            accounts.append(account)
            logInfo("Added new account. Total accounts: \(accounts.count)", category: .cache)
        }

        // Sort by last used (most recent first)
        accounts.sort { $0.lastUsed > $1.lastUsed }

        persistAccounts()
        logInfo("Persisted \(accounts.count) account(s) to UserDefaults with key: \(storageKey)", category: .cache)
    }

    /// Select an account and return its identity for use
    /// - Parameter account: The stored account to select
    /// - Returns: EAPlayerIdentity that can be used with existing auth system
    func selectAccount(_ account: StoredEAAccount) -> EAPlayerIdentity {
        // Update last used time
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account.withUpdatedLastUsed()
            accounts.sort { $0.lastUsed > $1.lastUsed }
            persistAccounts()
        }

        return account.toIdentity()
    }

    /// Delete an account from the store
    /// - Parameter account: The account to delete
    func deleteAccount(_ account: StoredEAAccount) {
        accounts.removeAll { $0.id == account.id }
        persistAccounts()
    }

    /// Delete an account by ID
    /// - Parameter id: The ID of the account to delete
    func deleteAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        persistAccounts()
    }

    /// Update the display name for an account
    /// - Parameters:
    ///   - account: The account to update
    ///   - name: The new display name (nil to remove custom name)
    func updateDisplayName(for account: StoredEAAccount, name: String?) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account.withDisplayName(name)
            persistAccounts()
        }
    }

    /// Check if an account with the given nucleus ID exists
    /// - Parameter nucleusId: The nucleus ID to check
    /// - Returns: True if an account exists with this nucleus ID
    func hasAccount(withNucleusId nucleusId: String) -> Bool {
        accounts.contains { $0.nucleusId == nucleusId }
    }

    /// Check if an account with the given persona ID exists
    /// - Parameter personaId: The persona ID to check
    /// - Returns: True if an account exists with this persona ID
    func hasAccount(withPersonaId personaId: String) -> Bool {
        accounts.contains { $0.personaId == personaId }
    }

    /// Get the most recently used account
    var mostRecentAccount: StoredEAAccount? {
        accounts.first
    }

    /// Clear all stored accounts
    func clearAllAccounts() {
        accounts.removeAll()
        persistAccounts()
    }
    
    /// Refresh account data from the API
    /// - Parameter account: The account to refresh
    /// - Returns: The updated account with fresh data from the API
    func refreshAccountData(for account: StoredEAAccount) async throws -> StoredEAAccount {
        logInfo("Refreshing account data for \(account.eaId)", category: .api)
        
        // Fetch fresh data from rip-bf.com API using the same endpoint as lookupEAAccount
        let encodedName = account.eaId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? account.eaId
        let urlString = "https://rip-bf.com/api/eaid/?name=\(encodedName)"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "EAAccountStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("BF6StatsTracker/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logError("Invalid HTTP response when refreshing account", category: .api)
            throw NSError(domain: "EAAccountStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        logInfo("API response status code: \(httpResponse.statusCode)", category: .api)
        
        guard httpResponse.statusCode == 200 else {
            logError("API returned status code \(httpResponse.statusCode)", category: .api)
            throw NSError(domain: "EAAccountStore", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned status \(httpResponse.statusCode)"])
        }
        
        // Log the raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            logDebug("API response: \(jsonString)", category: .api)
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(RipBFAPIResponse.self, from: data)
        
        guard let apiUser = apiResponse.users?.first else {
            logError("No user data found in API response", category: .api)
            throw NSError(domain: "EAAccountStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user data found in response"])
        }
        
        // Create updated account preserving the original ID and dates
        let updatedAccount = StoredEAAccount(
            id: account.id,
            nucleusId: apiUser.userId,
            personaId: apiUser.id,
            eaId: apiUser.EAID,
            displayName: account.displayName,
            lastUsed: account.lastUsed,
            addedAt: account.addedAt,
            userId: apiUser.userId,
            avatarUrl: apiUser.avatarUrl,
            subscriptionLevel: apiUser.subscriptionLevel,
            nickname: apiUser.nickname,
            platform: apiUser.platform,
            status: apiUser.status,
            createdAt: apiUser.createdAt,
            platformIcon: apiUser.platformIcon,
            lastRefreshed: Date()
        )
        
        // Update in store
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = updatedAccount
            persistAccounts()
        }
        
        logSuccess("Successfully refreshed account data for \(account.eaId)", category: .success)
        return updatedAccount
    }

    // MARK: - Persistence

    private func loadAccounts() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            accounts = []
            return
        }

        do {
            let decoder = JSONDecoder()
            accounts = try decoder.decode([StoredEAAccount].self, from: data)
            // Sort by last used
            accounts.sort { $0.lastUsed > $1.lastUsed }
        } catch {
            logInfo("Failed to load stored accounts: \(error)", category: .general)
            accounts = []
        }
    }

    private func persistAccounts() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(accounts)
            userDefaults.set(data, forKey: storageKey)
            userDefaults.synchronize()
            logSuccess("Successfully persisted accounts to UserDefaults", category: .success)

            // Verify it was saved
            if let verifyData = userDefaults.data(forKey: storageKey) {
                logSuccess("Verified: Data exists in UserDefaults (\(verifyData.count) bytes)", category: .success)
            } else {
                logError("Warning: Data not found in UserDefaults after save", category: .error)
            }
        } catch {
            logError("Failed to persist accounts: \(error)", category: .error)
        }
    }
}
