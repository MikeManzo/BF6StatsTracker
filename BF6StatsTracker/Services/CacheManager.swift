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
//  CacheManager.swift
//  BF6StatsTracker
//
//  Handles caching of player statistics with 5-minute expiration
//

import Foundation

actor CacheManager {
    static let shared = CacheManager()
    
    private let cacheDirectory: URL
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    private var memoryCache: [String: CachedPlayerStats] = [:]
    
    private init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("BF6StatsTracker/Cache", isDirectory: true)
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Load existing cache into memory
        Task {
            await loadCacheFromDisk()
        }
    }
    
    // MARK: - Cache Key Generation
    
    private func cacheKey(for playerName: String, platform: Platform) -> String {
        return "\(platform.rawValue)_\(playerName.lowercased())"
    }
    
    private func cacheFileURL(for key: String) -> URL {
        return cacheDirectory.appendingPathComponent("\(key).json")
    }
    
    // MARK: - Cache Operations
    
    /// Store player stats in cache
    func cache(stats: PlayerStats, playerName: String, platform: Platform) async {
        let key = cacheKey(for: playerName, platform: platform)
        let now = Date()
        let cachedStats = CachedPlayerStats(
            stats: stats,
            cachedAt: now,
            expiresAt: now.addingTimeInterval(cacheExpiration)
        )
        
        // Store in memory
        memoryCache[key] = cachedStats

        // Store on disk
        await saveToDisk(cachedStats, key: key)

        logInfo("Cached stats for \(playerName) on \(platform.displayName)", category: .cache)
    }
    
    /// Retrieve cached stats if available and not expired
    func getCachedStats(for playerName: String, platform: Platform) async -> PlayerStats? {
        let key = cacheKey(for: playerName, platform: platform)
        
        // Check memory cache first
        if let cached = memoryCache[key] {
            if !cached.isExpired {
                logInfo("Using memory cached stats for \(playerName)", category: .cache)
                return cached.stats
            } else {
                // Remove expired cache
                memoryCache.removeValue(forKey: key)
            }
        }

        // Check disk cache
        if let cached = await loadFromDisk(key: key) {
            if !cached.isExpired {
                // Restore to memory cache
                memoryCache[key] = cached
                logInfo("Using disk cached stats for \(playerName)", category: .cache)
                return cached.stats
            } else {
                // Remove expired cache file
                await removeFromDisk(key: key)
            }
        }
        
        return nil
    }
    
    /// Check if cached stats exist and are valid
    func hasCachedStats(for playerName: String, platform: Platform) async -> Bool {
        return await getCachedStats(for: playerName, platform: platform) != nil
    }
    
    /// Get cache age for a player
    func getCacheAge(for playerName: String, platform: Platform) async -> TimeInterval? {
        let key = cacheKey(for: playerName, platform: platform)
        
        if let cached = memoryCache[key] {
            return Date().timeIntervalSince(cached.cachedAt)
        }
        
        if let cached = await loadFromDisk(key: key) {
            return Date().timeIntervalSince(cached.cachedAt)
        }
        
        return nil
    }
    
    /// Clear all cached data
    func clearCache() async {
        memoryCache.removeAll()

        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }

        logInfo("Cache cleared", category: .cleanup)
    }

    /// Clear cached data for a specific player
    func clearCache(for playerName: String, platform: Platform) async {
        let key = cacheKey(for: playerName, platform: platform)
        memoryCache.removeValue(forKey: key)
        await removeFromDisk(key: key)

        logInfo("Cache cleared for \(playerName)", category: .cleanup)
    }
    
    // MARK: - Disk Operations
    
    private func saveToDisk(_ cachedStats: CachedPlayerStats, key: String) async {
        let fileURL = cacheFileURL(for: key)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cachedStats)
            try data.write(to: fileURL)
        } catch {
            logWarning("Failed to save cache to disk: \(error)", category: .cache)
        }
    }

    private func loadFromDisk(key: String) async -> CachedPlayerStats? {
        let fileURL = cacheFileURL(for: key)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CachedPlayerStats.self, from: data)
        } catch {
            logWarning("Failed to load cache from disk: \(error)", category: .cache)
            return nil
        }
    }
    
    private func removeFromDisk(key: String) async {
        let fileURL = cacheFileURL(for: key)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    private func loadCacheFromDisk() async {
        let fileManager = FileManager.default
        
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files where file.pathExtension == "json" {
            let key = file.deletingPathExtension().lastPathComponent
            if let cached = await loadFromDisk(key: key), !cached.isExpired {
                memoryCache[key] = cached
            }
        }

        logInfo("Loaded \(memoryCache.count) cached entries from disk", category: .cache)
    }
    
    // MARK: - Cache Statistics
    
    var cacheSize: Int {
        memoryCache.count
    }
    
    func getCacheInfo() async -> [(key: String, cachedAt: Date, expiresAt: Date, isExpired: Bool)] {
        return memoryCache.map { (key: $0.key, cachedAt: $0.value.cachedAt, expiresAt: $0.value.expiresAt, isExpired: $0.value.isExpired) }
    }
}

// MARK: - Settings Storage

actor SettingsManager {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "BF6TrackerSettings"
    
    private init() {}
    
    func saveSettings(_ settings: AppSettings) async {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsKey)

            // Also save menuBarOnlyMode separately for quick access at app launch
            userDefaults.set(settings.menuBarOnlyMode, forKey: "menuBarOnlyMode")
        } catch {
            logWarning("Failed to save settings: \(error)", category: .storage)
        }
    }

    func loadSettings() async -> AppSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            return AppSettings()
        }

        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            logWarning("Failed to load settings: \(error)", category: .storage)
            return AppSettings()
        }
    }
    
    func saveTilePositions(_ positions: [String: TilePosition]) async {
        var settings = await loadSettings()
        settings.tilePositions = positions
        await saveSettings(settings)
    }
    
    func loadTilePositions() async -> [String: TilePosition] {
        return await loadSettings().tilePositions
    }
}
