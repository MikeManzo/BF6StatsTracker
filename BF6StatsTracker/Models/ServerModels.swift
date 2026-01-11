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
//  ServerModels.swift
//  BF6StatsTracker
//
//  Models for BF6 server data
//

import Foundation

// MARK: - Server List Response

struct ServerListResponse: Codable {
    let servers: [BF6Server]
}

// MARK: - BF6 Server

struct BF6Server: Codable, Identifiable {
    let id: String
    let serverName: String
    let region: String

    // Server Status
    let maxPlayers: Int
    let playerAmount: Int
    let mode: String
    let map: String
    let mapImage: String?

    // Owner info
    let owner: ServerOwner?

    // Additional info
    let adventure: String?
    let subParam: String?
    let latency: Int?
    let regionId: String?

    var platform: String {
        owner?.platform ?? "unknown"
    }

    var country: String {
        regionId ?? ""
    }

    var playerCount: String {
        "\(playerAmount)/\(maxPlayers)"
    }

    var isFull: Bool {
        playerAmount >= maxPlayers
    }

    var hasQueue: Bool {
        false // Queue info not in this API version
    }

    var slots: ServerSlots {
        ServerSlots(inQueue: 0, inGame: playerAmount, capacity: maxPlayers)
    }

    var serverInfo: String? {
        nil // Not provided in this API version
    }

    var experience: String? {
        subParam
    }

    var rotation: [String]? {
        nil // Not provided in this API version
    }

    enum CodingKeys: String, CodingKey {
        case id = "serverId"
        case serverName = "prefix"
        case region
        case maxPlayers
        case playerAmount
        case mode
        case map = "currentMap"
        case mapImage = "url"
        case owner
        case adventure
        case subParam
        case latency
        case regionId
    }
}

struct ServerOwner: Codable {
    let platformId: Int
    let nucleusId: Int?
    let personaId: Int?
    let platform: String
}

// MARK: - Server Slots

struct ServerSlots: Codable {
    let inQueue: Int
    let inGame: Int
    let capacity: Int

    enum CodingKeys: String, CodingKey {
        case inQueue
        case inGame = "soldiers"
        case capacity = "max"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inQueue = try container.decodeIfPresent(Int.self, forKey: .inQueue) ?? 0
        inGame = try container.decodeIfPresent(Int.self, forKey: .inGame) ?? 0
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity) ?? 0
    }

    init(inQueue: Int, inGame: Int, capacity: Int) {
        self.inQueue = inQueue
        self.inGame = inGame
        self.capacity = capacity
    }
}

// MARK: - Server Filters

struct ServerFilters {
    var platform: Platform
    var region: String = "all"  // Default to "all" which is required by the API
    var mode: String?
    var mapName: String?
    var showFull: Bool = true
    var showEmpty: Bool = true

    var queryParams: [String: String] {
        var params: [String: String] = [
            "region": region  // Region is required, not platform
        ]

        // Platform filtering will be done client-side since API doesn't support it
        if let mode = mode {
            params["mode"] = mode
        }
        if let mapName = mapName {
            params["mapName"] = mapName
        }

        return params
    }
}
