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
        print("💾 EAAccountStore: Saving account for \(identity.eaId)")

        // Check if account already exists (by nucleusId or personaId)
        if let existingIndex = accounts.firstIndex(where: { $0.nucleusId == identity.nucleusId || $0.personaId == identity.personaId }) {
            // Update existing account's last used time
            var updated = accounts[existingIndex].withUpdatedLastUsed()
            // Update display name if provided
            if let displayName = displayName {
                updated = updated.withDisplayName(displayName)
            }
            accounts[existingIndex] = updated
            print("💾 Updated existing account at index \(existingIndex)")
        } else {
            // Add new account
            let newAccount = StoredEAAccount(from: identity, displayName: displayName)
            accounts.append(newAccount)
            print("💾 Added new account. Total accounts: \(accounts.count)")
        }

        // Sort by last used (most recent first)
        accounts.sort { $0.lastUsed > $1.lastUsed }

        persistAccounts()
        print("💾 Persisted \(accounts.count) account(s) to UserDefaults with key: \(storageKey)")
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
            print("Failed to load stored accounts: \(error)")
            accounts = []
        }
    }

    private func persistAccounts() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(accounts)
            userDefaults.set(data, forKey: storageKey)
            userDefaults.synchronize()
            print("✅ Successfully persisted accounts to UserDefaults")

            // Verify it was saved
            if let verifyData = userDefaults.data(forKey: storageKey) {
                print("✅ Verified: Data exists in UserDefaults (\(verifyData.count) bytes)")
            } else {
                print("❌ Warning: Data not found in UserDefaults after save")
            }
        } catch {
            print("❌ Failed to persist accounts: \(error)")
        }
    }
}
