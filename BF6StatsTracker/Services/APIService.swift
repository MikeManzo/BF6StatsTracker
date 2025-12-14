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

    // MARK: - Player Stats

    /// Fetch player statistics from GameTools.Network API using EA Identity
    /// - Parameter identifier: Player identifier containing name, platform, and optional EA identity
    /// - Returns: PlayerStats object with all available statistics
    func fetchPlayerStats(identifier: PlayerIdentifier) async throws -> PlayerStats {
        // Use the identifier's name (which should be the EA ID if authenticated)
        return try await fetchPlayerStats(playerName: identifier.name, platform: identifier.platform)
    }

    /// Fetch player statistics from GameTools.Network API
    /// - Parameters:
    ///   - playerName: Exact player name (case-sensitive) - preferably the EA ID
    ///   - platform: Gaming platform (pc, ps5, xboxseries, steam)
    /// - Returns: PlayerStats object with all available statistics
    func fetchPlayerStats(playerName: String, platform: Platform) async throws -> PlayerStats {
        // Rate limiting
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < minimumRequestInterval {
                try await Task.sleep(nanoseconds: UInt64((minimumRequestInterval - timeSinceLastRequest) * 1_000_000_000))
            }
        }
        
        let encodedName = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        let urlString = "\(baseURL)/bf6/stats/?name=\(encodedName)&platform=\(platform.rawValue)"
        
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
                    print("❌ Decoding error: \(error)")
                    // DEBUG: Print raw response on decoding errors
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📋 API Response (first 500 chars): \(jsonString.prefix(500))...")
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
    
    // MARK: - Detailed Stats Endpoints

    /// Fetch detailed weapon statistics using EA Identity
    func fetchWeaponStats(identifier: PlayerIdentifier) async throws -> [WeaponStats] {
        return try await fetchWeaponStats(playerName: identifier.name, platform: identifier.platform)
    }

    /// Fetch detailed weapon statistics
    func fetchWeaponStats(playerName: String, platform: Platform) async throws -> [WeaponStats] {
        let encodedName = playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName
        let urlString = "\(baseURL)/bf6/weapons/?name=\(encodedName)&platform=\(platform.rawValue)"

        print("🔫 Fetching weapon stats from: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw BF6TrackerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Weapon stats request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw BF6TrackerError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()

        // Try decoding as array first
        if let weapons = try? decoder.decode([WeaponStats].self, from: data) {
            print("✅ Decoded \(weapons.count) weapons as array")
            return weapons
        }

        // Try decoding as dictionary with weapons key
        if let wrapper = try? decoder.decode([String: [WeaponStats]].self, from: data),
           let weapons = wrapper["weapons"] {
            print("✅ Decoded \(weapons.count) weapons from wrapper")
            return weapons
        }

        print("⚠️ No weapons decoded - returning empty array")
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

        print("🚗 Fetching vehicle stats from: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw BF6TrackerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Vehicle stats request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw BF6TrackerError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()

        if let vehicles = try? decoder.decode([VehicleStats].self, from: data) {
            print("✅ Decoded \(vehicles.count) vehicles as array")
            return vehicles
        }

        if let wrapper = try? decoder.decode([String: [VehicleStats]].self, from: data),
           let vehicles = wrapper["vehicles"] {
            print("✅ Decoded \(vehicles.count) vehicles from wrapper")
            return vehicles
        }

        print("⚠️ No vehicles decoded - returning empty array")
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

        print("👤 Fetching class stats from: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw BF6TrackerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Class stats request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw BF6TrackerError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()

        if let classes = try? decoder.decode([ClassStats].self, from: data) {
            print("✅ Decoded \(classes.count) classes")
            return classes
        }

        if let wrapper = try? decoder.decode([String: [ClassStats]].self, from: data),
           let classes = wrapper["classes"] {
            print("✅ Decoded \(classes.count) classes from wrapper")
            return classes
        }

        print("⚠️ No classes decoded - returning empty array")
        return []
    }
    
    // MARK: - Image URLs
    
    /// Get image URL for a weapon
    func getWeaponImageURL(weaponName: String) -> URL? {
        let cleanName = weaponName.replacingOccurrences(of: " ", with: "_").lowercased()
        return URL(string: "https://eaassets-a.akamaihd.net/battlelog/bf6/weapons/\(cleanName).png")
    }
    
    /// Get image URL for a vehicle
    func getVehicleImageURL(vehicleName: String) -> URL? {
        let cleanName = vehicleName.replacingOccurrences(of: " ", with: "_").lowercased()
        return URL(string: "https://eaassets-a.akamaihd.net/battlelog/bf6/vehicles/\(cleanName).png")
    }
    
    /// Get image URL for a gadget
    func getGadgetImageURL(gadgetName: String) -> URL? {
        let cleanName = gadgetName.replacingOccurrences(of: " ", with: "_").lowercased()
        return URL(string: "https://eaassets-a.akamaihd.net/battlelog/bf6/gadgets/\(cleanName).png")
    }
    
    /// Get image URL for a class
    func getClassImageURL(className: String) -> URL? {
        let cleanName = className.lowercased()
        return URL(string: "https://eaassets-a.akamaihd.net/battlelog/bf6/classes/\(cleanName).png")
    }
    
    /// Get rank emblem image URL
    func getRankImageURL(rank: Int) -> URL? {
        return URL(string: "https://eaassets-a.akamaihd.net/battlelog/bf6/ranks/\(rank).png")
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

        print("🌐 Fetching servers from: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Server request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw BF6TrackerError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()

        // Try decoding as ServerListResponse first
        if let serverResponse = try? decoder.decode(ServerListResponse.self, from: data) {
            print("✅ Fetched \(serverResponse.servers.count) servers")
            return serverResponse.servers
        }

        // Try decoding as array directly
        if let servers = try? decoder.decode([BF6Server].self, from: data) {
            print("✅ Fetched \(servers.count) servers (direct array)")
            return servers
        }

        // Log response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("⚠️ Could not decode server response. Raw response: \(jsonString)")
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
