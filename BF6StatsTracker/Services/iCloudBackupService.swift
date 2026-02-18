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
//  iCloudBackupService.swift
//  BF6StatsTracker
//
//  Service for backing up and restoring snapshot data to/from iCloud
//

import Foundation
import SwiftData

/// Backup frequency options
enum BackupFrequency: String, Codable, CaseIterable, Identifiable {
    case afterEachMatch = "After Each Match"
    case hourly = "Hourly"
    case daily = "Daily"
    case manual = "Manual Only"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .afterEachMatch:
            return "Backup automatically after completing each match"
        case .hourly:
            return "Backup once per hour when data changes"
        case .daily:
            return "Backup once per day at midnight"
        case .manual:
            return "Only backup when manually triggered"
        }
    }
}

/// Statistics about the backup
struct BackupStatus {
    var lastBackupDate: Date?
    var snapshotCount: Int
    var storageUsedBytes: Int
    var isEnabled: Bool
    
    var formattedStorageSize: String {
        let bytes = Double(storageUsedBytes)
        if bytes < 1024 {
            return String(format: "%.0f B", bytes)
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.2f MB", bytes / (1024 * 1024))
        }
    }
    
    var formattedLastBackup: String {
        guard let date = lastBackupDate else {
            return "Never backed up"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Codable model for storing snapshots in iCloud
struct BackupData: Codable {
    let version: Int
    let lastBackup: Date
    let snapshots: [SnapshotBackup]
    let dailyPerformances: [DailyPerformanceBackup]
    let eaId: String?
    let platform: String?
    
    struct SnapshotBackup: Codable {
        let timestamp: Date
        let playerName: String
        let platform: String
        let eaId: String?
        let kills: Int
        let deaths: Int
        let kdRatio: Double
        let wins: Int
        let losses: Int
        let matchesPlayed: Int
        let totalScore: Int
        let scorePerMinute: Double
        let killsPerMinute: Double
        let accuracy: Double
        let headshotPercentage: Double
        let timePlayed: Int
        let headshots: Int
        let assists: Int
        let revives: Int
        let resupplies: Int
        let progressionMode: String?
    }
    
    struct DailyPerformanceBackup: Codable {
        let date: Date
        let playerName: String
        let platform: String
        let matchesPlayed: Int
        let killsGained: Int
        let deathsGained: Int
        let scoreGained: Int
        let timePlayedMinutes: Int
        let avgKD: Double
        let progressionMode: String?
    }
}

@MainActor
class iCloudBackupService: ObservableObject {
    static let shared = iCloudBackupService()
    
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let backupKey = "BF6StatsTracker_SnapshotBackup"
    private let maxSnapshotsToBackup = 500
    private let maxDailyPerformancesToBackup = 90 // 3 months
    
    @Published var status: BackupStatus = BackupStatus(
        lastBackupDate: nil,
        snapshotCount: 0,
        storageUsedBytes: 0,
        isEnabled: false
    )
    
    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var lastError: String?
    
    private var lastHourlyBackup: Date?
    private var modelContext: ModelContext?
    
    private init() {
        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        
        // Sync with iCloud
        ubiquitousStore.synchronize()
        
        // Load current status
        updateStatus()
    }
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Check if iCloud is available
    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
    
    /// Update the current backup status
    func updateStatus() {
        guard let data = ubiquitousStore.data(forKey: backupKey),
              let backup = try? JSONDecoder().decode(BackupData.self, from: data) else {
            status = BackupStatus(
                lastBackupDate: nil,
                snapshotCount: 0,
                storageUsedBytes: 0,
                isEnabled: isICloudAvailable
            )
            return
        }
        
        status = BackupStatus(
            lastBackupDate: backup.lastBackup,
            snapshotCount: backup.snapshots.count,
            storageUsedBytes: data.count,
            isEnabled: isICloudAvailable
        )
    }
    
    /// Backup snapshots to iCloud
    func backupToICloud(settings: AppSettings) async throws {
        guard isICloudAvailable else {
            throw NSError(domain: "iCloudBackup", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "iCloud is not available. Please sign in to iCloud in System Settings."
            ])
        }
        
        guard let context = modelContext else {
            throw NSError(domain: "iCloudBackup", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Database context not initialized"
            ])
        }
        
        await MainActor.run {
            isBackingUp = true
            lastError = nil
        }
        
        do {
            // Fetch recent snapshots
            var descriptor = FetchDescriptor<StatsSnapshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = maxSnapshotsToBackup
            let snapshots = try context.fetch(descriptor)
            
            // Fetch recent daily performances
            var dailyDescriptor = FetchDescriptor<DailyPerformance>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            dailyDescriptor.fetchLimit = maxDailyPerformancesToBackup
            let dailyPerformances = try context.fetch(dailyDescriptor)
            
            // Convert to backup format
            let snapshotBackups = snapshots.map { snapshot in
                BackupData.SnapshotBackup(
                    timestamp: snapshot.timestamp,
                    playerName: snapshot.playerName,
                    platform: snapshot.platform,
                    eaId: snapshot.eaId,
                    kills: snapshot.kills,
                    deaths: snapshot.deaths,
                    kdRatio: snapshot.kdRatio,
                    wins: snapshot.wins,
                    losses: snapshot.losses,
                    matchesPlayed: snapshot.matchesPlayed,
                    totalScore: snapshot.totalScore,
                    scorePerMinute: snapshot.scorePerMinute,
                    killsPerMinute: snapshot.killsPerMinute,
                    accuracy: snapshot.accuracy,
                    headshotPercentage: snapshot.headshotPercentage,
                    timePlayed: snapshot.timePlayed,
                    headshots: snapshot.headshots,
                    assists: snapshot.assists,
                    revives: snapshot.revives,
                    resupplies: snapshot.resupplies,
                    progressionMode: snapshot.progressionMode
                )
            }
            
            let dailyBackups = dailyPerformances.map { daily in
                BackupData.DailyPerformanceBackup(
                    date: daily.date,
                    playerName: daily.playerName,
                    platform: daily.platform,
                    matchesPlayed: daily.matchesPlayed,
                    killsGained: daily.killsGained,
                    deathsGained: daily.deathsGained,
                    scoreGained: daily.scoreGained,
                    timePlayedMinutes: daily.timePlayedMinutes,
                    avgKD: daily.avgKD,
                    progressionMode: daily.progressionMode
                )
            }
            
            // Create backup data
            let backupData = BackupData(
                version: 1,
                lastBackup: Date(),
                snapshots: snapshotBackups,
                dailyPerformances: dailyBackups,
                eaId: settings.eaId,
                platform: settings.platform.rawValue
            )
            
            // Encode and save to iCloud
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(backupData)
            
            ubiquitousStore.set(data, forKey: backupKey)
            ubiquitousStore.synchronize()
            
            await MainActor.run {
                updateStatus()
                isBackingUp = false
                logSuccess("Backed up \(snapshotBackups.count) snapshots to iCloud (\(data.count) bytes)", category: .success)
            }
            
        } catch {
            await MainActor.run {
                isBackingUp = false
                lastError = error.localizedDescription
                logError("Failed to backup to iCloud: \(error)", category: .error)
            }
            throw error
        }
    }
    
    /// Restore snapshots from iCloud
    func restoreFromICloud() async throws -> (snapshotsRestored: Int, dailyPerformancesRestored: Int) {
        guard isICloudAvailable else {
            throw NSError(domain: "iCloudBackup", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "iCloud is not available"
            ])
        }
        
        guard let context = modelContext else {
            throw NSError(domain: "iCloudBackup", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Database context not initialized"
            ])
        }
        
        guard let data = ubiquitousStore.data(forKey: backupKey) else {
            throw NSError(domain: "iCloudBackup", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "No backup data found in iCloud"
            ])
        }
        
        await MainActor.run {
            isRestoring = true
            lastError = nil
        }
        
        do {
            // Decode backup data
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(BackupData.self, from: data)
            
            // Get existing snapshots to avoid duplicates
            let existingDescriptor = FetchDescriptor<StatsSnapshot>()
            let existingSnapshots = try context.fetch(existingDescriptor)
            let existingTimestamps = Set(existingSnapshots.map { $0.timestamp })
            
            // Get existing daily performances to avoid duplicates
            let existingDailyDescriptor = FetchDescriptor<DailyPerformance>()
            let existingDailies = try context.fetch(existingDailyDescriptor)
            let existingDailyKeys = Set(existingDailies.map { "\($0.playerName)-\($0.date)" })
            
            var restoredSnapshots = 0
            var restoredDailies = 0
            
            // Restore snapshots
            for snapshotBackup in backup.snapshots {
                // Skip if already exists
                if existingTimestamps.contains(snapshotBackup.timestamp) {
                    continue
                }
                
                let snapshot = StatsSnapshot(
                    playerName: snapshotBackup.playerName,
                    platform: snapshotBackup.platform,
                    eaId: snapshotBackup.eaId,
                    kills: snapshotBackup.kills,
                    deaths: snapshotBackup.deaths,
                    wins: snapshotBackup.wins,
                    losses: snapshotBackup.losses,
                    matchesPlayed: snapshotBackup.matchesPlayed,
                    totalScore: snapshotBackup.totalScore,
                    timePlayed: snapshotBackup.timePlayed,
                    headshots: snapshotBackup.headshots,
                    assists: snapshotBackup.assists,
                    revives: snapshotBackup.revives,
                    resupplies: snapshotBackup.resupplies,
                    sessionId: nil,
                    progressionMode: snapshotBackup.progressionMode
                )
                snapshot.timestamp = snapshotBackup.timestamp
                
                context.insert(snapshot)
                restoredSnapshots += 1
            }
            
            // Restore daily performances
            for dailyBackup in backup.dailyPerformances {
                let key = "\(dailyBackup.playerName)-\(dailyBackup.date)"
                if existingDailyKeys.contains(key) {
                    continue
                }
                
                let daily = DailyPerformance(
                    date: dailyBackup.date,
                    playerName: dailyBackup.playerName,
                    platform: dailyBackup.platform,
                    matchesPlayed: dailyBackup.matchesPlayed,
                    killsGained: dailyBackup.killsGained,
                    deathsGained: dailyBackup.deathsGained,
                    scoreGained: dailyBackup.scoreGained,
                    timePlayedMinutes: dailyBackup.timePlayedMinutes,
                    avgKD: dailyBackup.avgKD,
                    progressionMode: dailyBackup.progressionMode
                )
                
                context.insert(daily)
                restoredDailies += 1
            }
            
            try context.save()
            
            await MainAactor.run {
                isRestoring = false
                logSuccess("Restored \(restoredSnapshots) snapshots and \(restoredDailies) daily performances from iCloud", category: .success)
            }
            
            return (restoredSnapshots, restoredDailies)
            
        } catch {
            await MainActor.run {
                isRestoring = false
                lastError = error.localizedDescription
                logError("Failed to restore from iCloud: \(error)", category: .error)
            }
            throw error
        }
    }
    
    /// Check if backup should run based on frequency setting
    func shouldBackupNow(frequency: BackupFrequency) -> Bool {
        switch frequency {
        case .afterEachMatch:
            return true
        case .hourly:
            if let lastBackup = lastHourlyBackup {
                return Date().timeIntervalSince(lastBackup) >= 3600
            }
            return true
        case .daily:
            if let lastBackup = status.lastBackupDate {
                let calendar = Calendar.current
                return !calendar.isDateInToday(lastBackup)
            }
            return true
        case .manual:
            return false
        }
    }
    
    /// Trigger automatic backup if needed
    func autoBackupIfNeeded(frequency: BackupFrequency, settings: AppSettings) async {
        guard shouldBackupNow(frequency: frequency) else { return }
        
        do {
            try await backupToICloud(settings: settings)
            
            if frequency == .hourly {
                lastHourlyBackup = Date()
            }
        } catch {
            logWarning("Auto-backup failed: \(error.localizedDescription)", category: .general)
        }
    }
    
    @objc private func iCloudStoreDidChange(_ notification: Notification) {
        DispatchQueue.main.async {
            self.updateStatus()
            logInfo("iCloud store updated externally", category: .general)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
