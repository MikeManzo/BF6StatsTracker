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
//  AppSettings.swift
//  BF6StatsTracker
//
//  Application settings and configuration models
//

import Foundation
import CoreGraphics

// MARK: - Tile Position
struct TilePosition: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
}

// MARK: - App Settings
struct AppSettings: Codable {
    var playerName: String
    var platform: Platform
    var autoRefresh: Bool
    var refreshInterval: TimeInterval
    var tilePositions: [String: TilePosition]
    var showNotifications: Bool
    var compactMode: Bool
    var selectedColorScheme: AppColorScheme
    var debugMode: Bool
    var playSoundOnSnapshot: Bool
    var selectedSound: String     // System sound name for notifications
    var menuBarOnlyMode: Bool
    var appearanceMode: AppearanceMode

    // EA Identity fields - populated from EAIdentityKit
    var nucleusId: String?        // pidId - Master account identifier
    var personaId: String?        // Per-game/platform identifier
    var eaId: String?             // Public username (EA ID)
    var isEAAuthenticated: Bool   // Whether user has logged in via EA

    // Experimental features
    var aiCoachEnabled: Bool      // Enable on-device AI coaching feature

    // Liquid Glass (macOS 26+)
    var liquidGlassEnabled: Bool  // Use Liquid Glass material on navigation chrome
    
    // Hidden tabs
    var hiddenTabs: Set<String>   // Set of hidden tab raw values
    
    // Tab order
    var tabOrder: [String]        // Ordered list of tab raw values
    
    // iCloud Backup
    var iCloudBackupEnabled: Bool      // Enable automatic iCloud backup
    var backupFrequency: String        // Backup frequency (stored as raw value)

    init() {
        self.playerName = ""
        self.platform = .pc
        self.autoRefresh = true
        self.refreshInterval = 300 // 5 minutes
        self.tilePositions = [:]
        self.showNotifications = true
        self.compactMode = false
        self.selectedColorScheme = .orange
        self.debugMode = false
        self.playSoundOnSnapshot = true
        self.selectedSound = "Glass"
        self.menuBarOnlyMode = false
        self.appearanceMode = .auto
        self.nucleusId = nil
        self.personaId = nil
        self.eaId = nil
        self.isEAAuthenticated = false
        self.aiCoachEnabled = false
        self.liquidGlassEnabled = true  // On by default when running on Tahoe
        self.hiddenTabs = []  // No tabs hidden by default
        self.tabOrder = []    // Empty means use default order
        self.iCloudBackupEnabled = false  // Off by default, user must enable
        self.backupFrequency = "Automatically"  // Default to most frequent
    }

    /// Update settings with EA identity information
    mutating func updateWithEAIdentity(nucleusId: String, personaId: String, eaId: String) {
        self.nucleusId = nucleusId
        self.personaId = personaId
        self.eaId = eaId
        self.playerName = eaId  // Use EA ID as the player name
        self.isEAAuthenticated = true
    }

    /// Clear EA identity information on logout
    mutating func clearEAIdentity() {
        self.nucleusId = nil
        self.personaId = nil
        self.eaId = nil
        self.isEAAuthenticated = false
    }

    // Custom decoding to handle backward compatibility
    enum CodingKeys: String, CodingKey {
        case playerName, platform, autoRefresh, refreshInterval, tilePositions
        case showNotifications, compactMode, selectedColorScheme, debugMode
        case playSoundOnSnapshot, selectedSound, menuBarOnlyMode, appearanceMode
        case nucleusId, personaId, eaId, isEAAuthenticated
        case aiCoachEnabled
        case liquidGlassEnabled
        case hiddenTabs
        case tabOrder
        case iCloudBackupEnabled
        case backupFrequency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerName = try container.decode(String.self, forKey: .playerName)
        platform = try container.decode(Platform.self, forKey: .platform)
        autoRefresh = try container.decode(Bool.self, forKey: .autoRefresh)
        refreshInterval = try container.decode(TimeInterval.self, forKey: .refreshInterval)
        tilePositions = try container.decode([String: TilePosition].self, forKey: .tilePositions)
        showNotifications = try container.decode(Bool.self, forKey: .showNotifications)
        compactMode = try container.decode(Bool.self, forKey: .compactMode)
        selectedColorScheme = try container.decode(AppColorScheme.self, forKey: .selectedColorScheme)

        // Default to false if debugMode doesn't exist in saved settings
        debugMode = try container.decodeIfPresent(Bool.self, forKey: .debugMode) ?? false

        // Default to true if playSoundOnSnapshot doesn't exist in saved settings
        playSoundOnSnapshot = try container.decodeIfPresent(Bool.self, forKey: .playSoundOnSnapshot) ?? true

        // Default to "Glass" if selectedSound doesn't exist in saved settings
        selectedSound = try container.decodeIfPresent(String.self, forKey: .selectedSound) ?? "Glass"

        // Default to false if menuBarOnlyMode doesn't exist in saved settings
        menuBarOnlyMode = try container.decodeIfPresent(Bool.self, forKey: .menuBarOnlyMode) ?? false

        // Default to auto if appearanceMode doesn't exist in saved settings
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .auto

        nucleusId = try container.decodeIfPresent(String.self, forKey: .nucleusId)
        personaId = try container.decodeIfPresent(String.self, forKey: .personaId)
        eaId = try container.decodeIfPresent(String.self, forKey: .eaId)
        isEAAuthenticated = try container.decode(Bool.self, forKey: .isEAAuthenticated)

        // Default to false if aiCoachEnabled doesn't exist in saved settings
        aiCoachEnabled = try container.decodeIfPresent(Bool.self, forKey: .aiCoachEnabled) ?? false

        // Default to true if liquidGlassEnabled doesn't exist in saved settings
        liquidGlassEnabled = try container.decodeIfPresent(Bool.self, forKey: .liquidGlassEnabled) ?? true
        
        // Default to empty set if hiddenTabs doesn't exist in saved settings
        hiddenTabs = try container.decodeIfPresent(Set<String>.self, forKey: .hiddenTabs) ?? []
        
        // Default to empty array if tabOrder doesn't exist in saved settings
        tabOrder = try container.decodeIfPresent([String].self, forKey: .tabOrder) ?? []
        
        // Default to false if iCloudBackupEnabled doesn't exist in saved settings
        iCloudBackupEnabled = try container.decodeIfPresent(Bool.self, forKey: .iCloudBackupEnabled) ?? false
        
        // Default to "Automatically" if backupFrequency doesn't exist in saved settings
        backupFrequency = try container.decodeIfPresent(String.self, forKey: .backupFrequency) ?? "Automatically"
    }
}
