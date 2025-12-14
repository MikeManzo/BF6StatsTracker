//
//  EAIdentityManager.swift
//  BF6StatsTracker
//
//  Manages EA Identity authentication and credential storage using EAIdentityKit
//  Uses EAIdentityAPI directly to avoid keychain storage issues
//

import Foundation
import EAIdentityKit
import WebKit

/// Represents the authenticated EA player identity
struct EAPlayerIdentity: Codable, Equatable {
    let nucleusId: String      // pidId - Master account identifier
    let personaId: String      // Per-game/platform identifier
    let eaId: String           // Public username (EA ID)
    let authenticatedAt: Date

    /// Whether the identity is still considered valid (tokens typically expire in 1 hour)
    var isExpired: Bool {
        Date().timeIntervalSince(authenticatedAt) > 3600 // 1 hour
    }
}

/// Manages EA authentication and identity retrieval
/// Uses EAIdentityAPI directly to avoid keychain storage issues in sandboxed apps
actor EAIdentityManager {
    static let shared = EAIdentityManager()

    private var cachedIdentity: EAPlayerIdentity?
    private var currentToken: String?

    private let identityKey = "EAPlayerIdentity"
    private let tokenKey = "EAAccessToken"

    private init() {
        // Defer actor-isolated work to an asynchronous task to respect actor isolation in Swift 6
        Task { [weak self] in
            guard let self else { return }
            await self.loadCachedIdentity()
        }
    }

    // MARK: - Public API

    /// Returns the current authenticated identity, if available
    var currentIdentity: EAPlayerIdentity? {
        cachedIdentity
    }

    /// Whether the user is currently authenticated with a valid identity
    var isAuthenticated: Bool {
        guard let identity = cachedIdentity else { return false }
        return !identity.isExpired
    }

    /// Authenticate with an EA access token and retrieve identity
    /// Uses EAIdentityAPI directly to avoid keychain issues
    /// - Parameter token: EA OAuth access token
    /// - Returns: The authenticated player identity
    func authenticate(with token: String) async throws -> EAPlayerIdentity {
        // Use EAIdentityAPI directly with the token - no keychain storage
        let api = EAIdentityAPI(accessToken: token)

        // Get the full identity information
        let eaIdentity = try await api.getFullIdentity()

        // Create our internal identity model
        let identity = EAPlayerIdentity(
            nucleusId: eaIdentity.pidId,
            personaId: eaIdentity.personaId,
            eaId: eaIdentity.eaId,
            authenticatedAt: Date()
        )

        // Cache in memory and persist to UserDefaults (not keychain)
        self.cachedIdentity = identity
        self.currentToken = token
        saveIdentity(identity)
        saveToken(token)

        print("✅ EA Identity retrieved - EA ID: \(identity.eaId), Nucleus ID: \(identity.nucleusId)")

        return identity
    }

    /// Get the current identity, refreshing if needed
    /// - Returns: The current player identity
    func getIdentity() async throws -> EAPlayerIdentity {
        // Check if we have a valid cached identity
        if let identity = cachedIdentity, !identity.isExpired {
            return identity
        }

        // Try to refresh using stored token
        if let token = currentToken ?? loadToken() {
            let api = EAIdentityAPI(accessToken: token)
            let eaIdentity = try await api.getFullIdentity()

            let identity = EAPlayerIdentity(
                nucleusId: eaIdentity.pidId,
                personaId: eaIdentity.personaId,
                eaId: eaIdentity.eaId,
                authenticatedAt: Date()
            )

            self.cachedIdentity = identity
            saveIdentity(identity)

            return identity
        }

        throw EAIdentityError.notAuthenticated
    }

    /// Get just the nucleus ID for API calls
    func getNucleusId() async throws -> String {
        let identity = try await getIdentity()
        return identity.nucleusId
    }

    /// Get just the persona ID for API calls
    func getPersonaId() async throws -> String {
        let identity = try await getIdentity()
        return identity.personaId
    }

    /// Get just the EA ID (public username)
    func getEAId() async throws -> String {
        let identity = try await getIdentity()
        return identity.eaId
    }

    /// Log out and clear all stored credentials
    func logout() {
        cachedIdentity = nil
        currentToken = nil
        clearPersistedIdentity()
        clearToken()
        print("🚪 EA Identity cleared")
    }

    /// Clear all EA-related web cookies and website data
    /// This ensures a fresh login experience next time
    @MainActor
    static func clearAllEAWebData() async {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        // Get all data records
        let records = await dataStore.dataRecords(ofTypes: dataTypes)

        // Filter for EA-related domains
        let eaDomains = ["ea.com", "origin.com", "accounts.ea.com", "signin.ea.com"]
        let eaRecords = records.filter { record in
            eaDomains.contains { domain in
                record.displayName.contains(domain)
            }
        }

        // Delete EA-related data
        if !eaRecords.isEmpty {
            await dataStore.removeData(ofTypes: dataTypes, for: eaRecords)
            print("🧹 Cleared EA web data for \(eaRecords.count) domains")
        }

        // Also clear all cookies to be thorough
        let cookieStore = dataStore.httpCookieStore
        let cookies = await cookieStore.allCookies()
        for cookie in cookies {
            if eaDomains.contains(where: { cookie.domain.contains($0) }) {
                await cookieStore.deleteCookie(cookie)
                print("🍪 Deleted cookie: \(cookie.name) for \(cookie.domain)")
            }
        }

        print("✅ All EA web data cleared")
    }

    /// Test if the current token is still valid
    func testToken() async throws -> Bool {
        guard let token = currentToken ?? loadToken() else { return false }

        do {
            let api = EAIdentityAPI(accessToken: token)
            _ = try await api.getNucleusId()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Persistence (using UserDefaults instead of Keychain)

    private func loadCachedIdentity() async {
        guard let data = UserDefaults.standard.data(forKey: identityKey),
              let identity = try? JSONDecoder().decode(EAPlayerIdentity.self, from: data) else {
            return
        }

        // Only load if not expired
        if !identity.isExpired {
            self.cachedIdentity = identity
            // Also load the token
            self.currentToken = loadToken()
        } else {
            clearPersistedIdentity()
            clearToken()
        }
    }

    private func saveIdentity(_ identity: EAPlayerIdentity) {
        guard let data = try? JSONEncoder().encode(identity) else { return }
        UserDefaults.standard.set(data, forKey: identityKey)
    }

    private func clearPersistedIdentity() {
        UserDefaults.standard.removeObject(forKey: identityKey)
    }

    private func saveToken(_ token: String) {
        // Store token in UserDefaults (base64 encoded for minimal obfuscation)
        // Note: For production, consider using a more secure storage mechanism
        let encoded = Data(token.utf8).base64EncodedString()
        UserDefaults.standard.set(encoded, forKey: tokenKey)
    }

    private func loadToken() -> String? {
        guard let encoded = UserDefaults.standard.string(forKey: tokenKey),
              let data = Data(base64Encoded: encoded) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func clearToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}

// MARK: - Errors

enum EAIdentityError: LocalizedError {
    case invalidToken
    case notAuthenticated
    case tokenExpired
    case networkError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "The provided EA access token is invalid."
        case .notAuthenticated:
            return "Not authenticated. Please log in with your EA account."
        case .tokenExpired:
            return "Your session has expired. Please log in again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred during authentication."
        }
    }
}

