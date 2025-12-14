//
//  HistoryManager.swift
//  BF6StatsTracker
//
//  Manages stat snapshots and session tracking using SwiftData
//

import Foundation
import SwiftData

@MainActor
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    var modelContext: ModelContext?  // Made public for access from SettingsView
    private var currentSession: PlaySession?

    @Published var snapshots: [StatsSnapshot] = []
    @Published var sessions: [PlaySession] = []
    @Published var recentSnapshots: [StatsSnapshot] = []

    private init() {}

    /// Initialize with SwiftData model context
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadRecentData()
    }

    // MARK: - Snapshots

    /// Save a stats snapshot
    func saveSnapshot(from stats: PlayerStats, sessionId: UUID? = nil) {
        guard let context = modelContext else { return }

        let snapshot = StatsSnapshot(from: stats, sessionId: sessionId)
        context.insert(snapshot)

        if let session = currentSession {
            session.snapshots.append(snapshot)
        }

        try? context.save()
        loadRecentData()
    }

    /// Get snapshots for a date range
    func getSnapshots(from startDate: Date, to endDate: Date) -> [StatsSnapshot] {
        guard let context = modelContext else { return [] }

        let predicate = #Predicate<StatsSnapshot> { snapshot in
            snapshot.timestamp >= startDate && snapshot.timestamp <= endDate
        }

        let descriptor = FetchDescriptor<StatsSnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Get last N snapshots
    func getRecentSnapshots(limit: Int = 20) -> [StatsSnapshot] {
        guard let context = modelContext else { return [] }

        var descriptor = FetchDescriptor<StatsSnapshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Sessions

    /// Start a new play session
    func startSession(playerName: String, platform: String) {
        guard let context = modelContext else { return }

        // End current session if exists
        if let current = currentSession {
            // Session will be ended when next snapshot is saved
        }

        let session = PlaySession(playerName: playerName, platform: platform)
        context.insert(session)
        currentSession = session

        try? context.save()
    }

    /// End the current session
    func endSession(with finalStats: PlayerStats) {
        guard let context = modelContext, let session = currentSession else { return }

        let finalSnapshot = StatsSnapshot(from: finalStats, sessionId: session.id)
        session.endSession(with: finalSnapshot)
        context.insert(finalSnapshot)

        try? context.save()
        currentSession = nil
        loadRecentData()
    }

    /// Get all sessions
    func getAllSessions() -> [PlaySession] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<PlaySession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Get recent sessions
    func getRecentSessions(limit: Int = 10) -> [PlaySession] {
        guard let context = modelContext else { return [] }

        var descriptor = FetchDescriptor<PlaySession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Analytics

    /// Calculate K/D trend over time
    func getKDTrend(days: Int = 7) -> [(Date, Double)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = getSnapshots(from: startDate, to: Date())

        return snapshots.map { ($0.timestamp, $0.kdRatio) }
    }

    /// Calculate kills per minute trend
    func getKPMTrend(days: Int = 7) -> [(Date, Double)] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshots = getSnapshots(from: startDate, to: Date())

        return snapshots.map { ($0.timestamp, $0.killsPerMinute) }
    }

    /// Get performance summary for period
    func getPerformanceSummary(days: Int = 7) -> PerformanceSummary? {
        let snapshots = getKDTrend(days: days)
        guard !snapshots.isEmpty else { return nil }

        let kdValues = snapshots.map { $0.1 }
        let avgKD = kdValues.reduce(0, +) / Double(kdValues.count)
        let maxKD = kdValues.max() ?? 0
        let minKD = kdValues.min() ?? 0

        return PerformanceSummary(
            averageKD: avgKD,
            maxKD: maxKD,
            minKD: minKD,
            trend: calculateTrend(values: kdValues),
            snapshotCount: snapshots.count
        )
    }

    private func calculateTrend(values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }

        let firstHalf = values.prefix(values.count / 2)
        let secondHalf = values.suffix(values.count / 2)

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        let difference = secondAvg - firstAvg
        let percentChange = (difference / firstAvg) * 100

        if percentChange > 5 {
            return .improving
        } else if percentChange < -5 {
            return .declining
        } else {
            return .stable
        }
    }

    func loadRecentData() {  // Made public for refresh after clearing
        recentSnapshots = getRecentSnapshots(limit: 20)
        sessions = getRecentSessions(limit: 10)
    }
}

// MARK: - Supporting Types

struct PerformanceSummary {
    let averageKD: Double
    let maxKD: Double
    let minKD: Double
    let trend: TrendDirection
    let snapshotCount: Int
}

enum TrendDirection {
    case improving
    case declining
    case stable

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var color: String {
        switch self {
        case .improving: return "green"
        case .declining: return "red"
        case .stable: return "gray"
        }
    }
}
