//
//  StatsViewModel.swift
//  BF6StatsTracker
//
//  Main view model for managing Battlefield 6 statistics
//  Integrated with EAIdentityKit for EA authentication
//

import SwiftUI
import EAIdentityKit
import Combine

@MainActor
class StatsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var playerStats: PlayerStats?
    @Published var classStats: [ClassStats] = []
    @Published var weaponStats: [WeaponStats] = []
    @Published var vehicleStats: [VehicleStats] = []
    @Published var gadgetStats: [GadgetStats] = []
    @Published var progressionModes: [ProgressionMode] = []
    @Published var currentProgressionMode: ProgressionMode?

    @Published var isLoading = false
    @Published var error: BF6TrackerError?
    @Published var lastUpdated: Date?
    @Published var cacheAge: TimeInterval?

    @Published var settings: AppSettings = AppSettings()
    @Published var tilePositions: [String: TilePosition] = [:]

    @Published var selectedTab: StatTab = .overview
    @Published var selectedClass: BF6Class?
    @Published var selectedWeaponCategory: WeaponCategory?
    @Published var selectedVehicleCategory: VehicleCategory?

    // EA Authentication state
    @Published var isEAAuthenticated = false
    @Published var eaAuthError: String?
    @Published var isAuthenticating = false

    // App initialization state
    @Published var isInitializing = true

    // MARK: - Private Properties

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization

    init() {
        Task {
            await loadSettings()
            await checkEAAuthenticationStatus()

            // Fetch progression types (XP multipliers) - do this early as it's static data
            await fetchProgressionTypes()

            // Auto-login: If we have stored accounts but no current player data, use the most recent account
            if settings.playerName.isEmpty && !EAAccountStore.shared.accounts.isEmpty {
                if let mostRecent = EAAccountStore.shared.mostRecentAccount {
                    print("🔐 Auto-login: Loading most recent account - \(mostRecent.displayText)")
                    let identity = EAAccountStore.shared.selectAccount(mostRecent)
                    await loadWithStoredIdentity(identity)
                }
            } else if !settings.playerName.isEmpty {
                // Force fresh data fetch on app startup
                await forceRefreshStats()
            }

            // Mark initialization as complete
            self.isInitializing = false
            setupAutoRefresh()
        }
    }

    // MARK: - EA Authentication

    /// Check if user is authenticated with EA and update state
    private func checkEAAuthenticationStatus() async {
        let isAuth = await EAIdentityManager.shared.isAuthenticated
        self.isEAAuthenticated = isAuth || settings.isEAAuthenticated

        // If we have stored identity but manager says not authenticated, try to restore
        if settings.isEAAuthenticated && !isAuth {
            // Token may have expired - user will need to re-authenticate
            self.isEAAuthenticated = false
            settings.isEAAuthenticated = false
        }
    }

    /// Authenticate with EA using an access token
    /// - Parameter token: EA OAuth access token obtained from web login
    func authenticateWithEA(token: String) async {
        isAuthenticating = true
        eaAuthError = nil

        do {
            let identity = try await EAIdentityManager.shared.authenticate(with: token)

            // Save to account store for future quick access
            EAAccountStore.shared.saveCurrentAccount(from: identity)
            print("📝 Saved account to store. Total accounts: \(EAAccountStore.shared.accounts.count)")

            // Update settings with EA identity
            settings.updateWithEAIdentity(
                nucleusId: identity.nucleusId,
                personaId: identity.personaId,
                eaId: identity.eaId
            )

            await saveSettings()

            self.isEAAuthenticated = true
            self.eaAuthError = nil

            print("✅ EA Authentication successful - EA ID: \(identity.eaId), Nucleus ID: \(identity.nucleusId)")

            // Automatically fetch stats for the authenticated user
            await fetchStats(forceRefresh: true)

        } catch let error as EAIdentityError {
            self.eaAuthError = error.errorDescription
            self.isEAAuthenticated = false
            print("❌ EA Authentication failed: \(error.errorDescription ?? "unknown")")
        } catch {
            self.eaAuthError = error.localizedDescription
            self.isEAAuthenticated = false
            print("❌ EA Authentication failed: \(error.localizedDescription)")
        }

        isAuthenticating = false
    }

    /// Authenticate with EA using GamerID via rip-bf.com API
    /// - Parameter gamerID: EA GamerID (username)
    func authenticateWithGamerID(gamerID: String) async {
        isAuthenticating = true
        eaAuthError = nil

        do {
            // Call the rip-bf.com API
            guard let url = URL(string: "https://rip-bf.com/api/eaid/?name=\(gamerID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? gamerID)") else {
                throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(RipBFAPIResponse.self, from: data)

            // Check if there was an error
            if response.error {
                self.eaAuthError = response.message
                self.isEAAuthenticated = false
                print("❌ EA Authentication failed: \(response.message)")
                isAuthenticating = false
                return
            }

            // Get the first user from the response
            guard let apiUser = response.users?.first else {
                self.eaAuthError = "No user found with that GamerID"
                self.isEAAuthenticated = false
                print("❌ EA Authentication failed: No user found")
                isAuthenticating = false
                return
            }

            // Create StoredEAAccount from API response
            let account = StoredEAAccount(from: apiUser)

            // Convert to EAPlayerIdentity for compatibility with existing system
            let identity = account.toIdentity()

            // Load the identity into the manager (no token needed)
            let loadedIdentity = await EAIdentityManager.shared.loadFromStoredAccount(identity)

            // Save to account store for future quick access
            EAAccountStore.shared.saveAccount(account)
            print("📝 Saved account to store. Total accounts: \(EAAccountStore.shared.accounts.count)")

            // Update settings with EA identity
            settings.updateWithEAIdentity(
                nucleusId: loadedIdentity.nucleusId,
                personaId: loadedIdentity.personaId,
                eaId: loadedIdentity.eaId
            )

            await saveSettings()

            self.isEAAuthenticated = true
            self.eaAuthError = nil

            print("✅ EA Authentication successful - EA ID: \(identity.eaId), Nucleus ID: \(identity.nucleusId)")

            // Clear old player's daily performance and load new player's data
            await MainActor.run {
                HistoryManager.shared.loadDailyPerformances(playerName: loadedIdentity.eaId)
            }

            // Automatically fetch stats for the authenticated user
            await fetchStats(forceRefresh: true)

        } catch {
            self.eaAuthError = error.localizedDescription
            self.isEAAuthenticated = false
            print("❌ EA Authentication failed: \(error.localizedDescription)")
        }

        isAuthenticating = false
    }

    /// Load identity from a stored account without re-authentication
    /// - Parameter identity: The stored player identity
    func loadWithStoredIdentity(_ identity: EAPlayerIdentity) async {
        isAuthenticating = true
        eaAuthError = nil

        // Load the identity into the manager (no token needed)
        let loadedIdentity = await EAIdentityManager.shared.loadFromStoredAccount(identity)

        // Update settings with EA identity
        settings.updateWithEAIdentity(
            nucleusId: loadedIdentity.nucleusId,
            personaId: loadedIdentity.personaId,
            eaId: loadedIdentity.eaId
        )

        await saveSettings()

        self.isEAAuthenticated = true
        self.eaAuthError = nil

        print("✅ Loaded stored account - EA ID: \(loadedIdentity.eaId)")

        // Clear old player's daily performance and load new player's data
        await MainActor.run {
            HistoryManager.shared.loadDailyPerformances(playerName: loadedIdentity.eaId)
        }

        // Automatically fetch stats for the selected account
        await fetchStats(forceRefresh: true)

        isAuthenticating = false
    }

    /// Get the current player identifier for API calls
    var currentPlayerIdentifier: PlayerIdentifier {
        PlayerIdentifier(from: settings)
    }
    
    // MARK: - Data Loading
    
    func searchPlayer(name: String, platform: Platform) async {
        settings.playerName = name
        settings.platform = platform
        await saveSettings()
        await fetchStats(forceRefresh: true)
    }
    
    func refreshStats() async {
        await fetchStats(forceRefresh: false)
    }
    
    func forceRefreshStats() async {
        await fetchStats(forceRefresh: true)
    }

    func retryMissingData() async {
        guard hasPlayerData else { return }

        print("🔄 Retrying missing data sections...")

        // Use current player identifier with EA identity if authenticated
        let identifier = currentPlayerIdentifier

        // Force fetch all additional stats regardless of current state
        await fetchAdditionalStats(identifier: identifier)
    }
    
    private func fetchStats(forceRefresh: Bool) async {
        guard !settings.playerName.isEmpty else { return }

        isLoading = true
        error = nil

        // Create player identifier from current settings (includes EA identity if authenticated)
        let identifier = currentPlayerIdentifier
        let playerName = identifier.name
        let platform = identifier.platform

        // Log the identity being used for API calls
        if settings.isEAAuthenticated {
            print("📊 fetchStats called (EA Authenticated)")
            print("   EA ID: \(settings.eaId ?? "N/A")")
            print("   Nucleus ID: \(settings.nucleusId ?? "N/A")")
            print("   Persona ID: \(settings.personaId ?? "N/A")")
            print("   Platform: \(platform.rawValue)")
            print("   Force Refresh: \(forceRefresh)")
        } else {
            print("📊 fetchStats called - playerName: \(playerName), platform: \(platform.rawValue), forceRefresh: \(forceRefresh)")
        }

        // Check cache first (unless force refresh)
        if !forceRefresh {
            if let cached = await CacheManager.shared.getCachedStats(for: playerName, platform: platform) {
                print("💾 Loading from cache")
                self.playerStats = cached

                // Filter out invalid entries with "Unknown" className and no meaningful data
                self.classStats = (cached.classes ?? []).filter { classItem in
                    classItem.className != "Unknown" || (classItem.kills > 0 || classItem.timePlayed > 0)
                }
                self.weaponStats = cached.weapons ?? []
                self.vehicleStats = cached.vehicles ?? []
                self.gadgetStats = cached.gadgets ?? []
                self.cacheAge = await CacheManager.shared.getCacheAge(for: playerName, platform: platform)
                self.lastUpdated = Date().addingTimeInterval(-(cacheAge ?? 0))

                print("💾 Cache loaded - Classes: \(self.classStats.count), Weapons: \(self.weaponStats.count), Vehicles: \(self.vehicleStats.count), Gadgets: \(self.gadgetStats.count)")

                // CRITICAL FIX: Always fetch additional stats even from cache to ensure completeness
                await fetchAdditionalStats(identifier: identifier)

                self.isLoading = false
                return
            }
        }

        do {
            // Fetch main player stats using identifier (includes EA identity if authenticated)
            print("🌐 Fetching fresh stats from API")
            let stats = try await APIService.shared.fetchPlayerStats(identifier: identifier)

            self.playerStats = stats

            // Filter out invalid entries with "Unknown" className and no meaningful data
            self.classStats = (stats.classes ?? []).filter { classItem in
                classItem.className != "Unknown" || (classItem.kills > 0 || classItem.timePlayed > 0)
            }
            self.weaponStats = stats.weapons ?? []
            self.vehicleStats = stats.vehicles ?? []
            self.gadgetStats = stats.gadgets ?? []
            self.lastUpdated = Date()
            self.cacheAge = 0

            print("🌐 Fresh stats loaded - Classes: \(self.classStats.count), Weapons: \(self.weaponStats.count), Vehicles: \(self.vehicleStats.count), Gadgets: \(self.gadgetStats.count)")

            // Cache the results
            await CacheManager.shared.cache(stats: stats, playerName: playerName, platform: platform)

            // Save snapshot to SwiftData for historical tracking
            await MainActor.run {
                // Try to get EA ID from settings first, then fall back to most recent account
                let eaId = settings.eaId ?? EAAccountStore.shared.mostRecentAccount?.eaId
                let progressionModeId = self.currentProgressionMode?.progressionMode
                HistoryManager.shared.saveSnapshot(from: stats, eaId: eaId, progressionMode: progressionModeId)
                MapTracker.shared.updateMapStats(from: stats)
                print("💾 Saved stats snapshot and updated map stats in SwiftData (EA ID: \(eaId ?? "N/A"), Mode: \(progressionModeId ?? "N/A"))")

                // Rebuild DailyPerformance records if needed (only on first load)
                if HistoryManager.shared.recentDailyPerformances.isEmpty {
                    print("🔧 No DailyPerformance records found, rebuilding...")
                    HistoryManager.shared.rebuildDailyPerformances(playerName: stats.userName)
                }
            }

            // Fetch additional detailed stats if main stats are incomplete
            await fetchAdditionalStats(identifier: identifier)

        } catch let error as BF6TrackerError {
            print("❌ Error fetching stats: \(error.errorDescription ?? "unknown")")
            self.error = error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            self.error = .networkError(error)
        }

        isLoading = false
        print("✅ fetchStats completed")
    }
    
    private func fetchAdditionalStats(identifier: PlayerIdentifier) async {
        print("🔄 fetchAdditionalStats called")

        // IMPROVED LOGIC: Always attempt to fetch detailed stats to ensure data completeness
        // We'll merge with existing data rather than replacing it

        // Fetch detailed weapon stats
        let shouldFetchWeapons = weaponStats.isEmpty || weaponStats.count < 3
        if shouldFetchWeapons {
            do {
                print("   Attempting to fetch weapon stats...")
                let weapons = try await APIService.shared.fetchWeaponStats(identifier: identifier)
                if !weapons.isEmpty {
                    self.weaponStats = weapons
                    print("   ✅ Updated weapon stats: \(weapons.count) items")

                    // Debug: Show all unique weapon types from API
                    let uniqueTypes = Set(weapons.map { $0.type })
                    print("   📋 Weapon types from API: \(uniqueTypes.sorted())")
                }
            } catch {
                print("   ⚠️ Failed to fetch weapon stats: \(error)")
            }
        } else {
            print("   ⏭️ Skipping weapon stats (have \(weaponStats.count) items)")
        }

        // Fetch detailed vehicle stats
        let shouldFetchVehicles = vehicleStats.isEmpty || vehicleStats.count < 3
        if shouldFetchVehicles {
            do {
                print("   Attempting to fetch vehicle stats...")
                let vehicles = try await APIService.shared.fetchVehicleStats(identifier: identifier)
                if !vehicles.isEmpty {
                    self.vehicleStats = vehicles
                    print("   ✅ Updated vehicle stats: \(vehicles.count) items")

                    // Debug: Show all unique vehicle types from API
                    let uniqueTypes = Set(vehicles.map { $0.type })
                    print("   📋 Vehicle types from API: \(uniqueTypes.sorted())")
                }
            } catch {
                print("   ⚠️ Failed to fetch vehicle stats: \(error)")
            }
        } else {
            print("   ⏭️ Skipping vehicle stats (have \(vehicleStats.count) items)")
        }

        // Note: Gadget stats are included in the main stats response, no separate fetch needed

        // Fetch detailed class stats
        let shouldFetchClasses = classStats.isEmpty || classStats.count < 4
        if shouldFetchClasses {
            do {
                print("   Attempting to fetch class stats...")
                let classes = try await APIService.shared.fetchClassStats(identifier: identifier)
                if !classes.isEmpty {
                    // Filter out invalid entries with "Unknown" className and no meaningful data
                    let validClasses = classes.filter { classItem in
                        classItem.className != "Unknown" || (classItem.kills > 0 || classItem.timePlayed > 0)
                    }
                    self.classStats = validClasses
                    print("   ✅ Updated class stats: \(validClasses.count) items (filtered from \(classes.count))")
                }
            } catch {
                print("   ⚠️ Failed to fetch class stats: \(error)")
            }
        } else {
            print("   ⏭️ Skipping class stats (have \(classStats.count) items)")
        }

        print("🔄 fetchAdditionalStats completed - Final counts: Classes(\(classStats.count)), Weapons(\(weaponStats.count)), Vehicles(\(vehicleStats.count)), Gadgets(\(gadgetStats.count))")
    }

    // MARK: - Progression Types

    /// Fetch progression types (XP multipliers and stat tracking rules) from API
    func fetchProgressionTypes() async {
        do {
            print("🎯 Fetching progression types...")
            let modes = try await APIService.shared.fetchProgressionTypes()
            self.progressionModes = modes

            // Set default progression mode to official-progression if available
            if let officialMode = modes.first(where: { $0.progressionMode == "official-progression" }) {
                self.currentProgressionMode = officialMode
                print("🎯 Set current progression mode to: \(officialMode.displayName)")
            } else if let firstMode = modes.first {
                self.currentProgressionMode = firstMode
                print("🎯 Set current progression mode to: \(firstMode.displayName)")
            }

            print("✅ Loaded \(modes.count) progression modes")
        } catch {
            print("❌ Failed to fetch progression types: \(error)")
        }
    }

    // MARK: - Auto Refresh
    
    private func setupAutoRefresh() {
        refreshTimer?.invalidate()
        
        guard settings.autoRefresh else { return }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshStats()
            }
        }
    }
    
    func toggleAutoRefresh() {
        settings.autoRefresh.toggle()
        Task {
            await saveSettings()
        }
        setupAutoRefresh()
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        Task {
            await CacheManager.shared.clearCache()
            await forceRefreshStats()
        }
    }
    
    func clearPlayerCache() {
        Task {
            await CacheManager.shared.clearCache(for: settings.playerName, platform: settings.platform)
        }
    }
    
    // MARK: - Settings Management
    
    func loadSettings() async {
        settings = await SettingsManager.shared.loadSettings()
        tilePositions = await SettingsManager.shared.loadTilePositions()
        Theme.setAccentScheme(settings.selectedColorScheme)
    }
    
    func saveSettings() async {
        await SettingsManager.shared.saveSettings(settings)
    }
    
    func updateTilePosition(_ classId: String, position: TilePosition) {
        tilePositions[classId] = position
        Task {
            await SettingsManager.shared.saveTilePositions(tilePositions)
        }
    }
    
    // MARK: - Computed Properties

    var hasPlayerData: Bool {
        playerStats != nil
    }

    var hasCompleteData: Bool {
        guard playerStats != nil else { return false }
        return !classStats.isEmpty && !weaponStats.isEmpty
    }

    // MARK: - Trend Indicators

    var killsTrend: TrendDirection {
        HistoryManager.shared.calculateKillsTrend(days: 7)
    }

    var kdTrend: TrendDirection {
        HistoryManager.shared.calculateKDTrend(days: 7)
    }

    var wlTrend: TrendDirection {
        HistoryManager.shared.calculateWLTrend(days: 7)
    }

    var dataCompletenessPercentage: Double {
        guard playerStats != nil else { return 0.0 }

        var complete = 0
        let total = 4

        if !classStats.isEmpty { complete += 1 }
        if !weaponStats.isEmpty { complete += 1 }
        if !vehicleStats.isEmpty { complete += 1 }
        if !gadgetStats.isEmpty { complete += 1 }

        return Double(complete) / Double(total) * 100.0
    }

    var missingDataSections: [String] {
        var missing: [String] = []
        if classStats.isEmpty { missing.append("Classes") }
        if weaponStats.isEmpty { missing.append("Weapons") }
        if vehicleStats.isEmpty { missing.append("Vehicles") }
        if gadgetStats.isEmpty { missing.append("Gadgets") }
        return missing
    }

    var formattedPlayTime: String {
        guard let stats = playerStats else { return "0h 0m" }
        let hours = stats.timePlayed / 3600
        let minutes = (stats.timePlayed % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    var topWeapons: [WeaponStats] {
        weaponStats.sorted { $0.kills > $1.kills }.prefix(5).map { $0 }
    }

    var topVehicles: [VehicleStats] {
        vehicleStats.sorted { $0.kills > $1.kills }.prefix(5).map { $0 }
    }

    var topClass: ClassStats? {
        classStats.max { $0.timePlayed < $1.timePlayed }
    }
    
    var weaponsByCategory: [WeaponCategory: [WeaponStats]] {
        Dictionary(grouping: weaponStats) { weapon -> WeaponCategory in
            let type = weapon.type.lowercased()
            switch type {
            case let t where t.contains("assault"): return .assaultRifles
            case let t where t.contains("carbine"): return .carbines
            case let t where t.contains("smg") || t.contains("submachine") || t.contains("pdw"): return .smgs
            case let t where t.contains("lmg") || t.contains("light machine") || t.contains("machine gun"): return .lmgs
            case let t where t.contains("dmr") || t.contains("marksman"): return .dmrs
            case let t where t == "rifles" || t.contains("sniper"): return .sniperRifles
            case let t where t.contains("shotgun"): return .shotguns
            case let t where t.contains("pistol") || t.contains("sidearm"): return .pistols
            default: return .assaultRifles
            }
        }
    }
    
    var vehiclesByCategory: [VehicleCategory: [VehicleStats]] {
        Dictionary(grouping: vehicleStats) { vehicle -> VehicleCategory in
            switch vehicle.type.lowercased() {
            case let t where t.contains("tank") || t.contains("mbt"): return .mainBattleTank
            case let t where t.contains("light") || t.contains("ifv"): return .lightArmor
            case let t where t.contains("aa") || t.contains("anti-air"): return .antiAircraft
            case let t where t.contains("attack") && t.contains("heli"): return .attackHelicopter
            case let t where t.contains("transport") && t.contains("heli"): return .transportHelicopter
            case let t where t.contains("jet") || t.contains("fighter"): return .jet
            case let t where t.contains("transport"): return .transportVehicle
            case let t where t.contains("boat") || t.contains("water"): return .watercraft
            default: return .lightArmor
            }
        }
    }
    
    // MARK: - Time Formatting
    
    func formatTimeAgo(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    func formatCacheAge() -> String {
        guard let age = cacheAge else { return "" }
        
        if age < 60 {
            return "Cache: Fresh"
        } else if age < 300 {
            return "Cache: \(Int(age / 60))m old"
        } else {
            return "Cache: Expired"
        }
    }
}

// MARK: - Tab Enum

enum StatTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case maps = "Maps"
    case charts = "Charts"
    case classes = "Classes"
    case weapons = "Weapons"
    case weaponMastery = "W.Mastery"
    case gadgets = "Gadgets"
    case utility = "Utility"
    case vehicles = "Vehicles"
    case vehicleSpec = "V.Specialist"
    case support = "Support"
    case intel = "Intel"
    case loadout = "Loadout"
    case xpCalculator = "XP Calc"
    case modeEfficiency = "Modes"
    case servers = "Servers"
    case history = "History"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .history: return "clock.arrow.circlepath"
        case .maps: return "map.fill"
        case .charts: return "chart.xyaxis.line"
        case .classes: return "person.3.fill"
        case .weapons: return "scope"
        case .weaponMastery: return "target"
        case .gadgets: return "wrench.and.screwdriver.fill"
        case .utility: return "circlebadge.fill"
        case .vehicles: return "car.fill"
        case .vehicleSpec: return "steeringwheel"
        case .support: return "heart.text.square.fill"
        case .intel: return "eye.fill"
        case .loadout: return "chart.bar.doc.horizontal"
        case .xpCalculator: return "chart.bar.doc.horizontal"
        case .modeEfficiency: return "chart.bar.xaxis"
        case .servers: return "server.rack"
        }
    }
}
