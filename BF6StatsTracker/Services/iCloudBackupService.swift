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
//  Service for backing up and restoring snapshot data to/from iCloud using CloudKit
//

import Foundation
@preconcurrency import SwiftData
import CloudKit

/// Backup frequency options
enum BackupFrequency: String, Codable, CaseIterable, Identifiable {
    case afterEachMatch = "Automatically"
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
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", bytes / (1024 * 1024 * 1024))
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
        let deltaKills: Int
        let deltaDeaths: Int
        let deltaHeadshots: Int
        let deltaAssists: Int
        let deltaRevives: Int
        let deltaResupplies: Int
        let deltaWins: Int
        let deltaLosses: Int
        let deltaMatchesPlayed: Int
        let deltaScore: Int
        let deltaTimePlayed: Int
        let dailyKD: Double
    }
}

@MainActor
class iCloudBackupService: ObservableObject {
    static let shared = iCloudBackupService()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordType = "SnapshotBackup"
    private let recordName = "BF6StatsTracker_Backup"
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
        // Use default container which uses the app's iCloud container
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
        
        // Check iCloud status on init
        Task {
            await checkICloudStatus()
        }
    }
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await updateStatus()
        }
    }
    
    /// Check if iCloud is available
    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
    
    /// Check iCloud account status
    private func checkICloudStatus() async {
        do {
            let accountStatus = try await container.accountStatus()
            let available = accountStatus == .available
            
            await MainActor.run {
                status.isEnabled = available
                if !available {
                    lastError = "iCloud is not available. Please sign in to iCloud in System Settings."
                }
            }
        } catch {
            await MainActor.run {
                status.isEnabled = false
                lastError = "Failed to check iCloud status: \(error.localizedDescription)"
                logError("Failed to check iCloud status: \(error)", category: .error)
            }
        }
    }
    
    /// Update the current backup status
    func updateStatus() async {
        guard isICloudAvailable else {
            await MainActor.run {
                status = BackupStatus(
                    lastBackupDate: nil,
                    snapshotCount: 0,
                    storageUsedBytes: 0,
                    isEnabled: false
                )
            }
            return
        }
        
        do {
            let recordID = CKRecord.ID(recordName: recordName)
            let record = try await privateDatabase.record(for: recordID)
            
            guard let dataAsset = record["backupData"] as? CKAsset,
                  let fileURL = dataAsset.fileURL,
                  let data = try? Data(contentsOf: fileURL) else {
                await MainActor.run {
                    status = BackupStatus(
                        lastBackupDate: nil,
                        snapshotCount: 0,
                        storageUsedBytes: 0,
                        isEnabled: true
                    )
                }
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            guard let backup = try? decoder.decode(BackupData.self, from: data) else {
                await MainActor.run {
                    status = BackupStatus(
                        lastBackupDate: nil,
                        snapshotCount: 0,
                        storageUsedBytes: 0,
                        isEnabled: true
                    )
                }
                return
            }
            
            await MainActor.run {
                status = BackupStatus(
                    lastBackupDate: backup.lastBackup,
                    snapshotCount: backup.snapshots.count,
                    storageUsedBytes: data.count,
                    isEnabled: true
                )
            }
            
        } catch let error as CKError where error.code == .unknownItem {
            // No backup exists yet
            await MainActor.run {
                status = BackupStatus(
                    lastBackupDate: nil,
                    snapshotCount: 0,
                    storageUsedBytes: 0,
                    isEnabled: true
                )
            }
        } catch {
            await MainActor.run {
                logWarning("Failed to fetch backup status: \(error.localizedDescription)", category: .general)
            }
        }
    }
    
    /// Backup snapshots to iCloud using CloudKit
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
            // Fetch ALL snapshots - no limit
            let descriptor = FetchDescriptor<StatsSnapshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
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
                    deltaKills: daily.deltaKills,
                    deltaDeaths: daily.deltaDeaths,
                    deltaHeadshots: daily.deltaHeadshots,
                    deltaAssists: daily.deltaAssists,
                    deltaRevives: daily.deltaRevives,
                    deltaResupplies: daily.deltaResupplies,
                    deltaWins: daily.deltaWins,
                    deltaLosses: daily.deltaLosses,
                    deltaMatchesPlayed: daily.deltaMatchesPlayed,
                    deltaScore: daily.deltaScore,
                    deltaTimePlayed: daily.deltaTimePlayed,
                    dailyKD: daily.dailyKD
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
            
            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(backupData)
            
            // Write to temporary file for CKAsset
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("backup_\(UUID().uuidString).json")
            try data.write(to: tempURL)
            
            // Create CKAsset from file
            let asset = CKAsset(fileURL: tempURL)
            
            // Fetch existing record or create new one
            let recordID = CKRecord.ID(recordName: recordName)
            let record: CKRecord
            
            do {
                // Try to fetch existing record
                record = try await privateDatabase.record(for: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                // Record doesn't exist, create new one
                record = CKRecord(recordType: recordType, recordID: recordID)
            }
            
            // Update record fields
            record["backupData"] = asset
            record["lastBackup"] = backupData.lastBackup
            record["snapshotCount"] = snapshotBackups.count
            record["eaId"] = settings.eaId
            record["platform"] = settings.platform.rawValue
            
            // Save to CloudKit
            _ = try await privateDatabase.save(record)
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            
            await MainActor.run {
                // Update status directly with the backup we just created
                status = BackupStatus(
                    lastBackupDate: backupData.lastBackup,
                    snapshotCount: snapshotBackups.count,
                    storageUsedBytes: data.count,
                    isEnabled: true
                )
                isBackingUp = false
                logSuccess("Backed up \(snapshotBackups.count) snapshots to iCloud (\(data.count) bytes)", category: .success)
            }
            
        } catch let error as CKError where error.code == .invalidArguments {
            await MainActor.run {
                isBackingUp = false
                lastError = "CloudKit schema not initialized. Please contact the developer to deploy the CloudKit schema to production."
                logError("CloudKit schema error: \(error). The SnapshotBackup record type needs to be created in CloudKit Dashboard and deployed to production.", category: .error)
            }
            throw NSError(domain: "iCloudBackup", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit schema not initialized. The app developer needs to deploy the CloudKit schema to production."
            ])
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
        
        await MainActor.run {
            isRestoring = true
            lastError = nil
        }
        
        do {
            // Fetch record from CloudKit
            let recordID = CKRecord.ID(recordName: recordName)
            let record = try await privateDatabase.record(for: recordID)
            
            guard let dataAsset = record["backupData"] as? CKAsset,
                  let fileURL = dataAsset.fileURL,
                  let data = try? Data(contentsOf: fileURL) else {
                throw NSError(domain: "iCloudBackup", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "No backup data found in iCloud"
                ])
            }
            
            // Decode backup data
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(BackupData.self, from: data)
            
            // Get existing snapshots to avoid duplicates
            let existingDescriptor = FetchDescriptor<StatsSnapshot>()
            let existingSnapshots = try context.fetch(existingDescriptor)
            let existingTimestamps = Set(existingSnapshots.map { $0.timestamp })
            
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
            
            // Skip restoring daily performances - they will be regenerated from snapshots by HistoryManager
            // This is safer and ensures data integrity
            restoredDailies = 0
            
            try context.save()
            
            await MainActor.run {
                isRestoring = false
                logSuccess("Restored \(restoredSnapshots) snapshots and \(restoredDailies) daily performances from iCloud", category: .success)
            }
            
            return (restoredSnapshots, restoredDailies)
            
        } catch let error as CKError where error.code == .unknownItem {
            await MainActor.run {
                isRestoring = false
                lastError = "No backup data found in iCloud"
                logError("No backup data found in iCloud", category: .error)
            }
            throw NSError(domain: "iCloudBackup", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "No backup data found in iCloud"
            ])
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
    
    /// Delete all backup data from iCloud
    func deleteBackupFromICloud() async throws {
        guard isICloudAvailable else {
            throw NSError(domain: "iCloudBackup", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "iCloud is not available"
            ])
        }
        
        await MainActor.run {
            lastError = nil
        }
        
        do {
            // Delete the record from CloudKit
            let recordID = CKRecord.ID(recordName: recordName)
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            
            await MainActor.run {
                // Update status to reflect no backup
                status = BackupStatus(
                    lastBackupDate: nil,
                    snapshotCount: 0,
                    storageUsedBytes: 0,
                    isEnabled: true
                )
                logSuccess("Deleted backup from iCloud", category: .success)
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist, that's fine
            await MainActor.run {
                status = BackupStatus(
                    lastBackupDate: nil,
                    snapshotCount: 0,
                    storageUsedBytes: 0,
                    isEnabled: true
                )
                logSuccess("No backup found to delete", category: .success)
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                logError("Failed to delete backup: \(error)", category: .error)
            }
            throw error
        }
    }
}
