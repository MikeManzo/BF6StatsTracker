//
// This file is part of BF6StatsTracker.
//
// BF6StatsTracker is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 or later.
//
// Copyright (c) 2026 CitizenCoder
//

import Foundation
import Sparkle

/// Service to manage application updates using Sparkle framework
class UpdaterService: ObservableObject {
    static let shared = UpdaterService()
    
    private let updaterController: SPUStandardUpdaterController
    
    @Published var canCheckForUpdates: Bool = false
    @Published var automaticallyChecksForUpdates: Bool = true
    @Published var automaticallyDownloadsUpdates: Bool = false
    
    private init() {
        // Initialize Sparkle updater controller
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Observe updater state
        updateCanCheckForUpdates()
        
        // Load preferences
        loadPreferences()
        
        logInfo("Sparkle updater initialized", category: .general)
    }
    
    /// Check if the app can check for updates
    func updateCanCheckForUpdates() {
        canCheckForUpdates = updaterController.updater.canCheckForUpdates
    }
    
    /// Manually check for updates
    func checkForUpdates() {
        guard canCheckForUpdates else {
            logWarning("Cannot check for updates at this time", category: .general)
            return
        }
        
        logInfo("Checking for app updates...", category: .general)
        updaterController.checkForUpdates(nil)
    }
    
    /// Get the current app version
    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    /// Get the current build number
    var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
    
    /// Get the feed URL from Info.plist
    var feedURL: String? {
        updaterController.updater.feedURL?.absoluteString
    }
    
    // MARK: - Preferences
    
    private let automaticCheckKey = "SUEnableAutomaticChecks"
    private let automaticDownloadKey = "SUAutomaticallyUpdate"
    
    private func loadPreferences() {
        automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updaterController.updater.automaticallyDownloadsUpdates
    }
    
    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = enabled
        logInfo("Automatic update checks: \(enabled ? "enabled" : "disabled")", category: .general)
    }
    
    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyDownloadsUpdates = enabled
        automaticallyDownloadsUpdates = enabled
        logInfo("Automatic update downloads: \(enabled ? "enabled" : "disabled")", category: .general)
    }
}
