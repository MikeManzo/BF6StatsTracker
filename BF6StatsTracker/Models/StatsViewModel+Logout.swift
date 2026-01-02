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

        // Reset selection states
        selectedClass = nil
        selectedWeaponCategory = nil
        selectedVehicleCategory = nil

        // Reset UI state
        selectedTab = .overview

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

        print("🚪 User logged out - EA credentials and all web data cleared")
    }
}
