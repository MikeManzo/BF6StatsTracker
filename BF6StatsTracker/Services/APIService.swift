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
//  APIService.swift
//  BF6StatsTracker
//
//  API service for fetching Battlefield 6 stats from GameTools.Network
//  Free, open-source API: https://api.gametools.network
//
//  Refactored to support EA Identity (nucleus_id, personaId, eaId) from EAIdentityKit
//

import Foundation

/// Parameters for identifying a player when making API calls
struct PlayerIdentifier {
    let name: String          // EA ID (public username)
    let platform: Platform
    let nucleusId: String?    // Optional: pidId from EAIdentityKit
    let personaId: String?    // Optional: persona ID from EAIdentityKit

    /// Create identifier with just name and platform (legacy mode)
    init(name: String, platform: Platform) {
        self.name = name
        self.platform = platform
        self.nucleusId = nil
        self.personaId = nil
    }

    /// Create identifier with full EA identity
    init(name: String, platform: Platform, nucleusId: String?, personaId: String?) {
        self.name = name
        self.platform = platform
        self.nucleusId = nucleusId
        self.personaId = personaId
    }

    /// Create identifier from AppSettings
    init(from settings: AppSettings) {
        self.name = settings.eaId ?? settings.playerName
        self.platform = settings.platform
        self.nucleusId = settings.nucleusId
        self.personaId = settings.personaId
    }
}

actor APIService {
    static let shared = APIService()

    private let baseURL = "https://api.gametools.network"
    private let session: URLSession
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 1.0 // Rate limiting

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    // MARK: - EA Identity Lookup
    
    /// Lookup EA Identity (nucleusId, personaId) for a player name
    /// Uses rip-bf.com API to get full EA account details
    /// - Parameter playerName: The EA ID/player name to lookup
    /// - Returns: RipBFAPIUser with nucleusId and personaId, or nil if not found
    func lookupEAIdentity(playerName: String) async throws -> RipBFAPIUser? {
        guard let url = URL(string: "https://rip-bf.com/api/eaid/?name=\(playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName)") else {
            throw BF6TrackerError.invalidURL
        }
        
        logInfo("Looking up EA identity for: \(playerName)", category: .api)
        
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(RipBFAPIResponse.self, from: data)
        
        // Check if there was an error
        if response.error {
            logWarning("EA identity lookup failed: \(response.message)", category: .api)
            return nil
        }
        
        // Get the first user from the response
        guard let apiUser = response.users?.first else {
            logWarning("No EA identity found for: \(playerName)", category: .api)
            return nil
        }
        
        logSuccess("Found EA identity for \(playerName): nucleusId=\(apiUser.userId), personaId=\(apiUser.id)", category: .api)
        return apiUser
    }
    
    // MARK: - Player Stats

    /// Fetch player statistics from GameTools.Network API using EA Identity
    /// Uses nucleus_id and playerid when available for more reliable lookups
    /// - Parameter identifier: Player identifier containing name, platform, and optional EA identity
    /// - Returns: PlayerStats object with all available statistics
    func fetchPlayerStats(identifier: PlayerIdentifier) async throws -> PlayerStats {
        // Rate limiting
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < minimumRequestInterval {
                try await Task.sleep(nanoseconds: UInt64((minimumRequestInterval - timeSinceLastRequest) * 1_000_000_000))
            }
        }

        // Build URL with all available identity parameters and API options
        let encodedName = identifier.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? identifier.name
        var urlString = "\(baseURL)/bf6/stats/?categories=multiplayer&raw=false&format_values=true&name=\(encodedName)&platform=\(identifier.platform.rawValue)"

        // Add playerid (persona ID) if available
        if let personaId = identifier.personaId, !personaId.isEmpty {
            urlString += "&playerid=\(personaId)"
        } else {
            logWarning("No persona ID found for \(identifier.name). Some statistics may be incomplete.", category: .auth)
        }

        // Add nucleus_id if available (master account identifier)
        if let nucleusId = identifier.nucleusId, !nucleusId.isEmpty {
            urlString += "&nucleus_id=\(nucleusId)"
        } else {
            logWarning("No nucleus ID found for \(identifier.name). Some statistics may be incomplete.", category: .auth)
        }

        // Add skip_battlelog parameter to improve API performance
        urlString += "&skip_battlelog=true"

        logInfo("Fetching player stats from: \(urlString)", category: .api)

        guard let url = URL(string: urlString) else {
            throw BF6TrackerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("BF6StatsTracker/1.0", forHTTPHeaderField: "User-Agent")

        lastRequestTime = Date()

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BF6TrackerError.unknown
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase

                do {
                    let stats = try decoder.decode(PlayerStats.self, from: data)
                    return stats
                } catch {
                    logError("Decoding error: \(error)", category: .api)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        logDebug("API Response (first 500 chars): \(jsonString.prefix(500))...", category: .api)
                    }
                    throw BF6TrackerError.decodingError(error)
                }

            case 404:
                throw BF6TrackerError.playerNotFound

            case 429:
                throw BF6TrackerError.rateLimited

            case 500...599:
                throw BF6TrackerError.serverError(httpResponse.statusCode)

            default:
                throw BF6TrackerError.serverError(httpResponse.statusCode)
            }
        } catch let error as BF6TrackerError {
            throw error
        } catch {
            throw BF6TrackerError.networkError(error)
        }
    }

    /// Fetch player statistics from GameTools.Network API (legacy method using name only)
    /// - Parameters:
    ///   - playerName: Exact player name (case-sensitive) - preferably the EA ID
    ///   - platform: Gaming platform (pc, ps5, xboxseries, steam)
    /// - Returns: PlayerStats object with all available statistics
    func fetchPlayerStats(playerName: String, platform: Platform) async throws -> PlayerStats {
        // Delegate to the identifier-based method with no EA identity
        let identifier = PlayerIdentifier(name: playerName, platform: platform)
        return try await fetchPlayerStats(identifier: identifier)
    }

    // MARK: - Detailed Stats Endpoints

    /// Fetch detailed weapon statistics using EA Identity
    func fetchWeaponStats(identifier: PlayerIdentifier) async throws -> [WeaponStats] {
        return try await fetchWeaponStats(playerName: identifier.name, platform: identifier.platform)
    }

    /// Fetch detailed weapon statistics
    func fetchWeaponStats(playerName: String, platform: Platform) async throws -> [WeaponStats] {
        let encodedName = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        let urlString = "\(baseURL)/bf6/weapons/?name=\(encodedName)&platform=\(platform.rawValue)"

        logInfo("Fetching weapon stats from: \(urlString)", category: .api)

        guard let url = URL(string: urlString) else {
            throw BF6TrackerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            logError("Weapon stats request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)", category: .api)
            throw BF6TrackerError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()

        // Try decoding as array first
        if let weapons = try? decoder.decode([WeaponStats].self, from: data) {
            logSuccess("Decoded \(weapons.count) weapons as array", category: .api)
            return weapons
        }

        // Try decoding as dictionary with weapons key
        if let wrapper = try? decoder.decode([String: [WeaponStats]].self, from: data),
           let weapons = wrapper["weapons"] {
            logSuccess("Decoded \(weapons.count) weapons from wrapper", category: .api)
            return weapons
        }

        logWarning("No weapons decoded - returning empty array", category: .api)
        return []
    }
    
    /// Fetch detailed vehicle statistics using EA Identity
    func fetchVehicleStats(identifier: PlayerIdentifier) async throws -> [VehicleStats] {
        return try await fetchVehicleStats(playerName: identifier.name, platform: identifier.platform)
    }

    /// Fetch detailed vehicle statistics
    func fetchVehicleStats(playerName: String, platform: Platform) async throws -> [VehicleStats] {
        let encodedName = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        let urlString = "\(baseURL)/bf6/vehicles/?name=\(encodedName)&platform=\(platform.rawValue)"

        logInfo("Fetching vehicle stats from: \(urlString)", category: .api)

        guard let url = URL(string: urlString) else {
            throw BF6TrackerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            logError("Vehicle stats request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)", category: .api)
            throw BF6TrackerError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()

        if let vehicles = try? decoder.decode([VehicleStats].self, from: data) {
            logSuccess("Decoded \(vehicles.count) vehicles as array", category: .api)
            return vehicles
        }

        if let wrapper = try? decoder.decode([String: [VehicleStats]].self, from: data),
           let vehicles = wrapper["vehicles"] {
            logSuccess("Decoded \(vehicles.count) vehicles from wrapper", category: .api)
            return vehicles
        }

        logWarning("No vehicles decoded - returning empty array", category: .api)
        return []
    }

    // Note: Gadget stats are included in the main PlayerStats response
    // No separate fetch endpoint is needed or available

    /// Fetch detailed class statistics using EA Identity
    func fetchClassStats(identifier: PlayerIdentifier) async throws -> [ClassStats] {
        return try await fetchClassStats(playerName: identifier.name, platform: identifier.platform)
    }

    /// Fetch detailed class statistics
    func fetchClassStats(playerName: String, platform: Platform) async throws -> [ClassStats] {
        let encodedName = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        let urlString = "\(baseURL)/bf6/classes/?name=\(encodedName)&platform=\(platform.rawValue)"

        logInfo("Fetching class stats from: \(urlString)", category: .api)

        guard let url = URL(string: urlString) else {
            throw BF6TrackerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            logError("Class stats request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)", category: .api)
            throw BF6TrackerError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()

        if let classes = try? decoder.decode([ClassStats].self, from: data) {
            logSuccess("Decoded \(classes.count) classes", category: .api)
            return classes
        }

        if let wrapper = try? decoder.decode([String: [ClassStats]].self, from: data),
           let classes = wrapper["classes"] {
            logSuccess("Decoded \(classes.count) classes from wrapper", category: .api)
            return classes
        }

        logWarning("No classes decoded - returning empty array", category: .api)
        return []
    }
    
    // MARK: - Image URLs

    /// Get image URL for a weapon
    nonisolated func getWeaponImageURL(weaponName: String) -> URL? {
        let cleanName = weaponName.replacingOccurrences(of: " ", with: "_").lowercased()
        return URL(string: "https://eaassets-a.akamaihd.net/battlelog/bf6/weapons/\(cleanName).png")
    }

    /// Get image URL for a vehicle
    nonisolated func getVehicleImageURL(vehicleName: String) -> URL? {
        let cleanName = vehicleName.replacingOccurrences(of: " ", with: "_").lowercased()
        return URL(string: "https://eaassets-a.akamaihd.net/battlelog/bf6/vehicles/\(cleanName).png")
    }

    /// Get image URL for a gadget
    nonisolated func getGadgetImageURL(gadgetName: String) -> URL? {
        let cleanName = gadgetName.replacingOccurrences(of: " ", with: "_").lowercased()
        return URL(string: "https://eaassets-a.akamaihd.net/battlelog/bf6/gadgets/\(cleanName).png")
    }

    /// Get image URL for a class
    nonisolated func getClassImageURL(className: String) -> URL? {
        let cleanName = className.lowercased()
        return URL(string: "https://eaassets-a.akamaihd.net/battlelog/bf6/classes/\(cleanName).png")
    }

    /// Get rank emblem image URL
    nonisolated func getRankImageURL(rank: Int) -> URL? {
        return URL(string: "https://eaassets-a.akamaihd.net/battlelog/bf6/ranks/\(rank).png")
    }

    // MARK: - Profile Data
    
    /// Fetch player profile data including rank, rank image, and badges
    /// - Parameter identifier: Player identifier containing name, platform, and optional EA identity
    /// - Returns: ProfileData object with rank information and badge count
    func fetchProfileData(identifier: PlayerIdentifier) async throws -> ProfileData {
        // Build URL with all available identity parameters
        let encodedName = identifier.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? identifier.name
        var urlString = "\(baseURL)/bf6/profile/?name=\(encodedName)&platform=\(identifier.platform.rawValue)"
        
        // Add playerid (persona ID) if available
        if let personaId = identifier.personaId, !personaId.isEmpty {
            urlString += "&playerid=\(personaId)"
        }
        
        // Add nucleus_id if available
        if let nucleusId = identifier.nucleusId, !nucleusId.isEmpty {
            urlString += "&nucleus_id=\(nucleusId)"
        }
        
        logInfo("Fetching profile data from: \(urlString)", category: .api)
        
        guard let url = URL(string: urlString) else {
            throw BF6TrackerError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("BF6StatsTracker/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BF6TrackerError.unknown
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let profileData = try decoder.decode(ProfileData.self, from: data)
                logSuccess("Fetched profile data: rank=\(profileData.rank ?? 0), badges=\(profileData.badges ?? 0)", category: .api)
                return profileData
            } catch {
                logError("Profile data decoding error: \(error)", category: .api)
                if let jsonString = String(data: data, encoding: .utf8) {
                    logDebug("API Response (first 500 chars): \(jsonString.prefix(500))...", category: .api)
                }
                throw BF6TrackerError.decodingError(error)
            }
            
        case 404:
            throw BF6TrackerError.playerNotFound
            
        case 429:
            throw BF6TrackerError.rateLimited
            
        case 500...599:
            throw BF6TrackerError.serverError(httpResponse.statusCode)
            
        default:
            throw BF6TrackerError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Progression Types

    /// Fetch BF6 progression types (XP multipliers and stat tracking rules)
    /// Returns array of progression modes with XP factors
    func fetchProgressionTypes() async throws -> [ProgressionMode] {
        let urlString = "\(baseURL)/bf6/progressiontypes/"

        logInfo("Fetching progression types from: \(urlString)", category: .api)

        guard let url = URL(string: urlString) else {
            throw BF6TrackerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            logError("Progression types request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)", category: .api)
            throw BF6TrackerError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()

        do {
            let progressionResponse = try decoder.decode(ProgressionTypeResponse.self, from: data)
            logSuccess("Decoded \(progressionResponse.entries.count) progression modes", category: .api)
            return progressionResponse.entries
        } catch {
            logError("Decoding error for progression types: \(error)", category: .api)
            if let jsonString = String(data: data, encoding: .utf8) {
                logDebug("Raw response: \(jsonString.prefix(500))...", category: .api)
            }
            throw BF6TrackerError.decodingError(error)
        }
    }

    // MARK: - Server Browser

    /// Fetch BF6 servers list
    func fetchServers(filters: ServerFilters, limit: Int = 50) async throws -> [BF6Server] {
        var urlComponents = URLComponents(string: "\(baseURL)/bf6/servers/")
        urlComponents?.queryItems = filters.queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        urlComponents?.queryItems?.append(URLQueryItem(name: "limit", value: "\(limit)"))

        guard let url = urlComponents?.url else {
            throw BF6TrackerError.invalidURL
        }

        logInfo("Fetching servers from: \(url.absoluteString)", category: .network)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            logError("Server request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)", category: .network)
            throw BF6TrackerError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()

        // Try decoding as ServerListResponse first
        if let serverResponse = try? decoder.decode(ServerListResponse.self, from: data) {
            logSuccess("Fetched \(serverResponse.servers.count) servers", category: .network)
            return serverResponse.servers
        }

        // Try decoding as array directly
        if let servers = try? decoder.decode([BF6Server].self, from: data) {
            logSuccess("Fetched \(servers.count) servers (direct array)", category: .network)
            return servers
        }

        // Log response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            logWarning("Could not decode server response. Raw response: \(jsonString)", category: .network)
        }

        return []
    }
}

// MARK: - API Response Wrappers

struct APIResponse<T: Codable>: Codable {
    let data: T?
    let error: String?
    let status: Int?
}

struct WeaponsResponse: Codable {
    let weapons: [WeaponStats]
}

struct VehiclesResponse: Codable {
    let vehicles: [VehicleStats]
}

struct GadgetsResponse: Codable {
    let gadgets: [GadgetStats]
}

struct ClassesResponse: Codable {
    let classes: [ClassStats]
}
