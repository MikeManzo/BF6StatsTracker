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
import EAIdentityKit
import SwiftUI

extension StatsViewModel {
    /// Logs out by clearing all loaded data, EA credentials, and resetting user-facing settings
    func logout() {
        // Stop any ongoing loading
        isLoading = false
        isInitializing = false

        // Clear cached data and player stats
        playerStats = nil
        weaponStats = []
        vehicleStats = []
        gadgetStats = []
        classStats = []

        // Clear cache metadata
        lastUpdated = nil
        cacheAge = nil
        error = nil

        // Stop refresh timers and reset progress
        stopRefreshTimers()

        // Reset selection states
        selectedClass = nil
        selectedWeaponCategory = nil
        selectedVehicleCategory = nil

        // Reset UI state
        selectedMainTab = .overview
        selectedSubTab = nil

        // Clear EA authentication and all web data (cookies, cache, etc.)
        Task {
            await EAIdentityManager.shared.logout()
            // Clear all EA-related cookies and web data for fresh login
            await EAIdentityManager.clearAllEAWebData()
        }
        isEAAuthenticated = false
        eaAuthError = nil

        // Clear EA identity from settings before resetting
        settings.clearEAIdentity()

        // Reset settings to defaults
        settings = AppSettings()

        // Save cleared settings
        Task {
            await saveSettings()
        }

        LoggerService.shared.info("User logged out - EA credentials and all web data cleared", category: .auth)
    }
}
