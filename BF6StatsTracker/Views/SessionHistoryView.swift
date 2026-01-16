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
//  SessionHistoryView.swift
//  BF6StatsTracker
//
//  Displays all SwiftData snapshots with delete functionality
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct SessionHistoryView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @EnvironmentObject var viewModel: StatsViewModel

    // Use @Query to automatically handle object lifecycle
    @Query(sort: \StatsSnapshot.timestamp, order: .reverse)
    private var allSnapshots: [StatsSnapshot]

    @State private var showingDeleteAlert = false
    @State private var showingDeleteAllAlert = false
    @State private var showingDeleteByDateAlert = false
    @State private var showingDeleteByEAIDAlert = false
    @State private var snapshotToDelete: StatsSnapshot?
    @State private var searchText = ""
    @State private var deleteStartDate = Date()
    @State private var deleteEndDate = Date()
    @State private var selectedEAID: String = ""
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var exportFormat: ExportFormat = .csv
    @State private var collapsedSections: Set<Date> = []
    @State private var shimmerOpacity: Double = 0.1
    @State private var isInitialLoad: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Search bar
            searchBar

            // Snapshots list
            if isInitialLoad && allSnapshots.isEmpty {
                skeletonLoader
            } else if filteredSnapshots.isEmpty {
                emptyStateView
            } else {
                snapshotsList
            }
        }
        .background(Theme.backgroundPrimary)
        .alert("Delete Snapshot", isPresented: $showingDeleteAlert, presenting: snapshotToDelete) { snapshot in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSnapshot(snapshot)
            }
        } message: { snapshot in
            Text("Are you sure you want to delete the snapshot from \(snapshot.timestamp.formatted(date: .abbreviated, time: .shortened))?\n\nThis action cannot be undone.")
        }
        .alert("Delete All Snapshots", isPresented: $showingDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllSnapshots()
            }
        } message: {
            Text("Are you sure you want to delete all \(allSnapshots.count) snapshots?\n\nThis will permanently remove all historical data and cannot be undone.")
        }
        .sheet(isPresented: $showingDeleteByDateAlert) {
            DeleteByDateRangeView(
                allSnapshots: allSnapshots,
                onDelete: { count in
                    deleteSnapshotsByDateRange()
                }
            )
        }
        .sheet(isPresented: $showingDeleteByEAIDAlert) {
            DeleteByEAIDView(
                allSnapshots: allSnapshots,
                onDelete: { eaId in
                    selectedEAID = eaId
                    deleteSnapshotsByEAID()
                }
            )
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportHistoryView(
                snapshots: filteredSnapshots,
                exportFormat: $exportFormat
            )
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportHistoryView()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.cyan)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Snapshot History")
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("\(allSnapshots.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("snapshots")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.caption)

                    HStack(spacing: 4) {
                        Image(systemName: "internaldrive")
                            .font(.caption2)
                        Text(totalStorageFormatted)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Export, Import and Delete options
            HStack(spacing: 8) {
                // Debug: Create synthetic snapshot button
                if viewModel.settings.debugMode {
                    Button {
                        historyManager.createSyntheticSnapshot()
                    } label: {
                        Label("Create Synthetic", systemImage: "flask")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Create a synthetic snapshot with random stat increases for testing")
                }

                // Import button
                Button {
                    showingImportSheet = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Import snapshot history from JSON file")

                // Export button
                if !allSnapshots.isEmpty {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Export snapshot history to file")
                }

                // Delete options menu
                if !allSnapshots.isEmpty {
                    Menu {
                        Button(role: .destructive) {
                            showingDeleteByDateAlert = true
                        } label: {
                            Label("Delete by Date Range", systemImage: "calendar")
                        }

                        Button(role: .destructive) {
                            showingDeleteByEAIDAlert = true
                        } label: {
                            Label("Delete by EA ID", systemImage: "person.badge.key")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteAllAlert = true
                        } label: {
                            Label("Delete All", systemImage: "trash.fill")
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Theme.overlayColor)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search by EA ID, date, or stats...", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Theme.overlayColor.opacity(0.5))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var snapshotsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedSnapshots.keys.sorted(by: >), id: \.self) { date in
                    Section {
                        if !collapsedSections.contains(date) {
                            ForEach(groupedSnapshots[date] ?? [], id: \.id) { snapshot in
                                SnapshotRow(snapshot: snapshot) {
                                    snapshotToDelete = snapshot
                                    showingDeleteAlert = true
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                            }
                        }
                    } header: {
                        DaySectionHeader(
                            date: date,
                            snapshotCount: groupedSnapshots[date]?.count ?? 0,
                            isCollapsed: collapsedSections.contains(date)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if collapsedSections.contains(date) {
                                    collapsedSections.remove(date)
                                } else {
                                    collapsedSections.insert(date)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(Theme.backgroundPrimary)
                    }
                }
            }
        }
        .background(Theme.backgroundPrimary)
    }

    /// Group snapshots by day
    private var groupedSnapshots: [Date: [StatsSnapshot]] {
        let calendar = Calendar.current
        var grouped: [Date: [StatsSnapshot]] = [:]

        for snapshot in filteredSnapshots {
            let startOfDay = calendar.startOfDay(for: snapshot.timestamp)
            grouped[startOfDay, default: []].append(snapshot)
        }

        return grouped
    }

    private var skeletonLoader: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<5) { _ in
                    HStack(spacing: 16) {
                        // Time placeholder
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(shimmerOpacity))
                                .frame(width: 100, height: 16)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(shimmerOpacity))
                                .frame(width: 80, height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(shimmerOpacity))
                                .frame(width: 90, height: 10)
                        }
                        .frame(width: 120, alignment: .leading)

                        Divider()

                        // Stats placeholders
                        HStack(spacing: 8) {
                            ForEach(0..<8) { _ in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(shimmerOpacity))
                                    .frame(width: 60, height: 32)
                            }
                        }

                        Spacer()

                        // Delete button placeholder
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(shimmerOpacity))
                            .frame(width: 32, height: 32)
                    }
                    .padding()
                    .background(Theme.overlayColor)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                shimmerOpacity = 0.3
            }
            // Mark initial load as complete after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInitialLoad = false
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(searchText.isEmpty ? "No snapshots recorded yet" : "No snapshots match your search")
                .font(.title3)
                .foregroundColor(.secondary)

            if searchText.isEmpty {
                Text("Snapshots are automatically saved when you refresh your stats")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var filteredSnapshots: [StatsSnapshot] {
        if searchText.isEmpty {
            return allSnapshots
        } else {
            let lowercased = searchText.lowercased()
            return allSnapshots.filter { snapshot in
                snapshot.playerName.lowercased().contains(lowercased) ||
                (snapshot.eaId?.lowercased().contains(lowercased) ?? false) ||
                "\(snapshot.kills)".contains(lowercased) ||
                "\(snapshot.deaths)".contains(lowercased) ||
                snapshot.timestamp.formatted().lowercased().contains(lowercased)
            }
        }
    }

    private var totalStorageSize: Int {
        allSnapshots.reduce(0) { $0 + $1.approximateStorageSize }
    }

    private var totalStorageFormatted: String {
        let bytes = Double(totalStorageSize)
        if bytes < 1024 {
            return String(format: "%.0f B", bytes)
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.2f MB", bytes / (1024 * 1024))
        }
    }

    // MARK: - Actions

    private func deleteSnapshot(_ snapshot: StatsSnapshot) {
        guard let context = historyManager.modelContext else { return }

        withAnimation {
            // Delete related DailyPerformance objects that reference this snapshot
            cleanupDailyPerformance(for: [snapshot])

            context.delete(snapshot)
            try? context.save()
        }
    }

    private func deleteAllSnapshots() {
        guard let context = historyManager.modelContext else { return }

        withAnimation {
            // Delete all DailyPerformance objects first
            cleanupDailyPerformance(for: allSnapshots)

            for snapshot in allSnapshots {
                context.delete(snapshot)
            }
            try? context.save()
        }
    }

    private func deleteSnapshotsByDateRange() {
        guard let context = historyManager.modelContext else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: deleteStartDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: deleteEndDate)) ?? deleteEndDate

        withAnimation {
            let snapshotsToDelete = allSnapshots.filter { snapshot in
                snapshot.timestamp >= startOfDay && snapshot.timestamp < endOfDay
            }

            // Delete related DailyPerformance objects first
            cleanupDailyPerformance(for: snapshotsToDelete)

            for snapshot in snapshotsToDelete {
                context.delete(snapshot)
            }
            try? context.save()
        }

        showingDeleteByDateAlert = false
    }

    private func deleteSnapshotsByEAID() {
        guard let context = historyManager.modelContext else { return }
        guard !selectedEAID.isEmpty else { return }

        withAnimation {
            let snapshotsToDelete = allSnapshots.filter { snapshot in
                snapshot.eaId?.lowercased() == selectedEAID.lowercased()
            }

            // Delete related DailyPerformance objects first
            cleanupDailyPerformance(for: snapshotsToDelete)

            for snapshot in snapshotsToDelete {
                context.delete(snapshot)
            }
            try? context.save()
        }

        showingDeleteByEAIDAlert = false
    }

    private func cleanupDailyPerformance(for snapshots: [StatsSnapshot]) {
        guard let context = historyManager.modelContext else { return }

        // Delete ALL DailyPerformance objects to avoid accessing potentially deleted snapshot references
        // They will be recalculated from snapshots when needed
        let descriptor = FetchDescriptor<DailyPerformance>()

        do {
            let allPerformances = try context.fetch(descriptor)
            for performance in allPerformances {
                context.delete(performance)
            }
            try context.save()
        } catch {
            // If we can't fetch (likely due to corrupt data), reset the cleanup flag
            // so it runs again on next app launch
            logWarning("Error fetching DailyPerformance objects: \(error)", category: .general)
            UserDefaults.standard.set(false, forKey: "HasCleanedCorruptDailyPerformance_v1")
        }
    }
}

// MARK: - Supporting Views

struct DaySectionHeader: View {
    let date: Date
    let snapshotCount: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    private var dateText: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)

        if calendar.isDate(date, inSameDayAs: today) {
            return "Today"
        } else if let yesterday = yesterday, calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .foregroundColor(Theme.bf6Orange)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 12)

                Image(systemName: "calendar")
                    .foregroundColor(Theme.bf6Orange)
                    .font(.headline)

                Text(dateText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text("•")
                    .foregroundColor(Theme.textSecondary)
                    .font(.caption)

                Text("\(snapshotCount) snapshot\(snapshotCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Theme.overlayColor.opacity(0.5))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

struct SnapshotRow: View {
    let snapshot: StatsSnapshot
    let onDelete: () -> Void
    @State private var showingMapsDetail = false

    var body: some View {
        VStack(spacing: 12) {
            // Main snapshot row
            mainRow

            // Maps played section (if available)
            if let mapsPlayed = getMapsPlayed(), !mapsPlayed.isEmpty {
                mapsPlayedSection(mapsPlayed)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private var mainRow: some View {
        HStack(spacing: 16) {
            // Time and player indicator
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.timestamp, style: .date)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text(snapshot.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Player Name badge
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                    Text(snapshot.playerName)
                        .font(.system(size: 9))
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)

                // Storage size
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(snapshot.formattedStorageSize)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, alignment: .leading)

            Divider()

            // Core stats - show delta values
            if let deltaStats = getDeltaStats() {
                HStack(spacing: 8) {
                    StatChip(label: "K/D", value: String(format: "%.2f", deltaStats.kdRatio), color: deltaStats.kdRatio >= 1.0 ? .green : .orange)
                    StatChip(label: "Kills", value: formatDelta(deltaStats.kills), color: .red)
                    StatChip(label: "Deaths", value: formatDelta(deltaStats.deaths), color: Theme.textSecondary)
                    StatChip(label: "Assists", value: formatDelta(deltaStats.assists), color: .cyan)
                    StatChip(label: "Wins", value: formatDelta(deltaStats.wins), color: .blue)
                    StatChip(label: "Matches", value: formatDelta(deltaStats.matches), color: .cyan)
                    StatChip(label: "Accuracy", value: String(format: "%.1f%%", deltaStats.accuracy), color: .purple)
                    StatChip(label: "HS%", value: String(format: "%.1f%%", deltaStats.headshotPercentage), color: .yellow)
                    StatChip(label: "KPM", value: String(format: "%.2f", deltaStats.killsPerMinute), color: .pink)
                    StatChip(label: "Score", value: formatScore(deltaStats.totalScore), color: .indigo)
                }
            } else {
                // First snapshot - show cumulative values
                HStack(spacing: 8) {
                    StatChip(label: "K/D", value: String(format: "%.2f", snapshot.kdRatio), color: snapshot.kdRatio >= 1.0 ? .green : .orange)
                    StatChip(label: "Kills", value: "\(snapshot.kills)", color: .red)
                    StatChip(label: "Deaths", value: "\(snapshot.deaths)", color: Theme.textSecondary)
                    StatChip(label: "Assists", value: "\(snapshot.assists)", color: .cyan)
                    StatChip(label: "Wins", value: "\(snapshot.wins)", color: .blue)
                    StatChip(label: "Matches", value: "\(snapshot.matchesPlayed)", color: .cyan)
                    StatChip(label: "Accuracy", value: String(format: "%.1f%%", snapshot.accuracy), color: .purple)
                    StatChip(label: "HS%", value: String(format: "%.1f%%", snapshot.headshotPercentage), color: .yellow)
                    StatChip(label: "KPM", value: String(format: "%.2f", snapshot.killsPerMinute), color: .pink)
                    StatChip(label: "Score", value: formatScore(snapshot.totalScore), color: .indigo)
                }
            }

            Spacer()

            // Delete button
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help("Delete this snapshot")
        }
    }

    private func getDeltaStats() -> DeltaStats? {
        // Get all snapshots from HistoryManager
        guard let allSnapshots = try? HistoryManager.shared.modelContext?.fetch(
            FetchDescriptor<StatsSnapshot>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        ) else {
            return nil
        }

        // Find the snapshot immediately before this one
        guard let currentIndex = allSnapshots.firstIndex(where: { $0.id == snapshot.id }),
              currentIndex + 1 < allSnapshots.count else {
            return nil
        }

        let previous = allSnapshots[currentIndex + 1]

        // Calculate deltas
        let deltaKills = snapshot.kills - previous.kills
        let deltaDeaths = snapshot.deaths - previous.deaths
        let deltaAssists = snapshot.assists - previous.assists
        let deltaWins = snapshot.wins - previous.wins
        let deltaMatches = snapshot.matchesPlayed - previous.matchesPlayed
        let deltaScore = snapshot.totalScore - previous.totalScore

        // Calculate K/D from deltas
        let kdRatio = deltaDeaths > 0 ? Double(deltaKills) / Double(deltaDeaths) : Double(deltaKills)

        return DeltaStats(
            kills: deltaKills,
            deaths: deltaDeaths,
            assists: deltaAssists,
            wins: deltaWins,
            matches: deltaMatches,
            totalScore: deltaScore,
            kdRatio: kdRatio,
            accuracy: snapshot.accuracy,
            headshotPercentage: snapshot.headshotPercentage,
            killsPerMinute: snapshot.killsPerMinute
        )
    }

    private func getMapsPlayed() -> [MapActivity]? {
        // Get all snapshots from HistoryManager
        guard let allSnapshots = try? HistoryManager.shared.modelContext?.fetch(
            FetchDescriptor<StatsSnapshot>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        ) else {
            return nil
        }

        // Find the snapshot immediately before this one
        guard let currentIndex = allSnapshots.firstIndex(where: { $0.id == snapshot.id }),
              currentIndex + 1 < allSnapshots.count else {
            return nil
        }

        let previous = allSnapshots[currentIndex + 1]
        return snapshot.mapsPlayedSince(previous)
    }

    private func formatDelta(_ value: Int) -> String {
        if value > 0 {
            return "+\(value)"
        } else if value < 0 {
            return "\(value)"
        } else {
            return "0"
        }
    }

    private func mapsPlayedSection(_ maps: [MapActivity]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Image(systemName: "map.fill")
                    .font(.caption)
                    .foregroundColor(Theme.bf6Orange)

                Text("Maps Played")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                Text("\(maps.count) map\(maps.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }

            // Maps list
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(maps.prefix(6)) { mapActivity in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.bf6Orange)
                            .frame(width: 4, height: 4)

                        Text(mapActivity.mapName)
                            .font(.caption2)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(mapActivity.matchesPlayed)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.bf6Orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.bf6Orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            if maps.count > 6 {
                Text("+ \(maps.count - 6) more")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private func formatScore(_ score: Int) -> String {
        if score >= 1_000_000 {
            return String(format: "%.1fM", Double(score) / 1_000_000.0)
        } else if score >= 1_000 {
            return String(format: "%.1fK", Double(score) / 1_000.0)
        } else {
            return "\(score)"
        }
    }
}

struct StatChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(6)
        .fixedSize()
    }
}

// MARK: - Delete by Date Range View

struct DeleteByDateRangeView: View {
    let allSnapshots: [StatsSnapshot]
    let onDelete: (Int) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()

    private var snapshotsInRange: [StatsSnapshot] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate

        return allSnapshots.filter { snapshot in
            snapshot.timestamp >= startOfDay && snapshot.timestamp < endOfDay
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Delete Snapshots by Date Range")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Select date range:")
                    .font(.headline)

                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text("\(snapshotsInRange.count) snapshot\(snapshotsInRange.count == 1 ? "" : "s") will be deleted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding()
            .background(Theme.overlayColor)
            .cornerRadius(12)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(role: .destructive) {
                    onDelete(snapshotsInRange.count)
                    dismiss()
                } label: {
                    Text("Delete \(snapshotsInRange.count)")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(snapshotsInRange.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// MARK: - Delete by EA ID View

struct DeleteByEAIDView: View {
    let allSnapshots: [StatsSnapshot]
    let onDelete: (String) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var selectedEAID: String = ""

    private var uniqueEAIDs: [String] {
        let eaIds = allSnapshots.compactMap { $0.eaId }.filter { !$0.isEmpty }
        return Array(Set(eaIds)).sorted()
    }

    private var snapshotsForEAID: [StatsSnapshot] {
        guard !selectedEAID.isEmpty else { return [] }
        return allSnapshots.filter { $0.eaId?.lowercased() == selectedEAID.lowercased() }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Delete Snapshots by EA ID")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Select EA ID:")
                    .font(.headline)

                if uniqueEAIDs.isEmpty {
                    Text("No EA IDs found in snapshots")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Picker("EA ID", selection: $selectedEAID) {
                        Text("Select EA ID").tag("")
                        ForEach(uniqueEAIDs, id: \.self) { eaId in
                            Text(eaId).tag(eaId)
                        }
                    }
                    .pickerStyle(.menu)

                    if !selectedEAID.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text("\(snapshotsForEAID.count) snapshot\(snapshotsForEAID.count == 1 ? "" : "s") will be deleted")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding()
            .background(Theme.overlayColor)
            .cornerRadius(12)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(role: .destructive) {
                    onDelete(selectedEAID)
                    dismiss()
                } label: {
                    Text("Delete \(snapshotsForEAID.count)")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedEAID.isEmpty || snapshotsForEAID.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }
}

// MARK: - Export History View

struct ExportHistoryView: View {
    let snapshots: [StatsSnapshot]
    @Binding var exportFormat: ExportFormat
    @Environment(\.dismiss) var dismiss

    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showingSavePanel = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Snapshot History")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Select export format:")
                    .font(.headline)

                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("\(snapshots.count) snapshot\(snapshots.count == 1 ? "" : "s") will be exported")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                if let error = exportError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Theme.overlayColor)
            .cornerRadius(12)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    exportData()
                } label: {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 100)
                    } else {
                        Text("Export")
                            .frame(width: 100)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(snapshots.isEmpty || isExporting)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func exportData() {
        isExporting = true
        exportError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<String, Error>

            switch exportFormat {
            case .csv:
                result = generateCSV()
            case .json:
                result = generateJSON()
            }

            DispatchQueue.main.async {
                isExporting = false

                switch result {
                case .success(let content):
                    saveFile(content: content)
                case .failure(let error):
                    exportError = error.localizedDescription
                }
            }
        }
    }

    private func generateCSV() -> Result<String, Error> {
        var csv = "Timestamp,Player Name,Platform,EA ID,Session ID,Progression Mode,Kills,Deaths,K/D Ratio,Wins,Losses,Matches Played,Total Score,Score Per Minute,Kills Per Minute,Accuracy,Headshot %,Time Played (min),Headshots,Assists,Revives,Resupplies,Maps Played Count,Top Maps\n"

        for snapshot in snapshots {
            let timePlayedMinutes = snapshot.timePlayed / 60
            let eaId = snapshot.eaId ?? ""
            let sessionId = snapshot.sessionId?.uuidString ?? ""
            let progressionMode = snapshot.progressionMode ?? ""

            // Get map information
            let maps = snapshot.maps ?? []
            let mapsCount = maps.count
            let topMaps = maps.prefix(3).map { "\($0.mapName)(\($0.matches))" }.joined(separator: "; ")

            let row = [
                snapshot.timestamp.ISO8601Format(),
                escapeCSVField(snapshot.playerName),
                snapshot.platform,
                escapeCSVField(eaId),
                escapeCSVField(sessionId),
                escapeCSVField(progressionMode),
                "\(snapshot.kills)",
                "\(snapshot.deaths)",
                String(format: "%.2f", snapshot.kdRatio),
                "\(snapshot.wins)",
                "\(snapshot.losses)",
                "\(snapshot.matchesPlayed)",
                "\(snapshot.totalScore)",
                String(format: "%.2f", snapshot.scorePerMinute),
                String(format: "%.2f", snapshot.killsPerMinute),
                String(format: "%.2f", snapshot.accuracy),
                String(format: "%.2f", snapshot.headshotPercentage),
                "\(timePlayedMinutes)",
                "\(snapshot.headshots)",
                "\(snapshot.assists)",
                "\(snapshot.revives)",
                "\(snapshot.resupplies)",
                "\(mapsCount)",
                escapeCSVField(topMaps)
            ].joined(separator: ",")

            csv += row + "\n"
        }

        return .success(csv)
    }

    private func generateJSON() -> Result<String, Error> {
        do {
            // Create versioned export structure
            let exportData: [String: Any] = [
                "version": "1.0",
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                "snapshotCount": snapshots.count,
                "snapshots": snapshots.map { snapshot -> [String: Any] in
                    // Prepare maps array if available
                    var mapsData: [[String: Any]] = []
                    if let maps = snapshot.maps {
                        mapsData = maps.map { map in
                            return [
                                "mapId": map.mapId,
                                "mapName": map.mapName,
                                "image": map.image,
                                "wins": map.wins,
                                "losses": map.losses,
                                "matches": map.matches,
                                "winPercent": map.winPercentString,
                                "secondsPlayed": map.secondsPlayed
                            ]
                        }
                    }

                    var data: [String: Any] = [
                        "id": snapshot.id.uuidString,
                        "timestamp": ISO8601DateFormatter().string(from: snapshot.timestamp),
                        "playerName": snapshot.playerName,
                        "platform": snapshot.platform,
                        "kills": snapshot.kills,
                        "deaths": snapshot.deaths,
                        "kdRatio": snapshot.kdRatio,
                        "wins": snapshot.wins,
                        "losses": snapshot.losses,
                        "matchesPlayed": snapshot.matchesPlayed,
                        "totalScore": snapshot.totalScore,
                        "scorePerMinute": snapshot.scorePerMinute,
                        "killsPerMinute": snapshot.killsPerMinute,
                        "accuracy": snapshot.accuracy,
                        "headshotPercentage": snapshot.headshotPercentage,
                        "timePlayed": snapshot.timePlayed,
                        "headshots": snapshot.headshots,
                        "assists": snapshot.assists,
                        "revives": snapshot.revives,
                        "resupplies": snapshot.resupplies,
                        "maps": mapsData
                    ]

                    // Add optional fields only if they exist
                    if let eaId = snapshot.eaId, !eaId.isEmpty {
                        data["eaId"] = eaId
                    }
                    if let sessionId = snapshot.sessionId {
                        data["sessionId"] = sessionId.uuidString
                    }
                    if let progressionMode = snapshot.progressionMode, !progressionMode.isEmpty {
                        data["progressionMode"] = progressionMode
                    }

                    return data
                }
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return .success(jsonString)
            } else {
                return .failure(NSError(domain: "ExportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON data to string"]))
            }
        } catch {
            return .failure(error)
        }
    }

    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    private func saveFile(content: String) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Snapshot History"
        savePanel.nameFieldStringValue = "snapshot_history_\(Date().ISO8601Format().prefix(10)).\(exportFormat.fileExtension)"
        savePanel.canCreateDirectories = true

        // Set allowed file type based on export format
        switch exportFormat {
        case .csv:
            savePanel.allowedContentTypes = [UTType.commaSeparatedText]
        case .json:
            savePanel.allowedContentTypes = [UTType.json]
        }

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    dismiss()
                } catch {
                    exportError = "Failed to save file: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Import History View

struct ImportHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var historyManager = HistoryManager.shared

    @State private var isImporting = false
    @State private var importError: String?
    @State private var importSuccess = false
    @State private var showingFilePicker = false
    @State private var showingReplaceWarning = false
    @State private var selectedFileURL: URL?
    @State private var importPreview: ImportPreview?

    var body: some View {
        VStack(spacing: 20) {
            Text("Import Snapshot History")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                // File selection
                HStack {
                    Text("Selected File:")
                        .font(.headline)

                    Spacer()

                    Button {
                        showFilePicker()
                    } label: {
                        Label("Choose File", systemImage: "folder")
                            .font(.caption)
                    }
                }

                if let url = selectedFileURL {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(8)
                    .background(Theme.overlayColor.opacity(0.5))
                    .cornerRadius(8)
                }

                // Import preview
                if let preview = importPreview {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        Text("Import Preview")
                            .font(.headline)

                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Format Version: \(preview.version)")
                                    .font(.caption)
                                Text("Snapshots: \(preview.snapshotCount)")
                                    .font(.caption)
                                if let exportDate = preview.exportDate {
                                    Text("Exported: \(exportDate.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                }
                                if let appVersion = preview.appVersion {
                                    Text("Created by: BF6StatsTracker v\(appVersion)")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                // Warning message
                if showingReplaceWarning {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Warning: This will replace all existing data")
                                    .font(.headline)
                                    .foregroundColor(.orange)

                                Text("All current snapshots will be permanently deleted and replaced with the imported data. This action cannot be undone.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                // Error message
                if let error = importError {
                    HStack(alignment: .top) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                // Success message
                if importSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Import completed successfully!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Theme.overlayColor)
            .cornerRadius(12)

            // Buttons
            HStack(spacing: 12) {
                Button(importSuccess ? "Done" : "Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                if !importSuccess {
                    Button {
                        if showingReplaceWarning {
                            performImport()
                        } else if selectedFileURL != nil {
                            showingReplaceWarning = true
                        }
                    } label: {
                        if isImporting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 100)
                        } else {
                            Text(showingReplaceWarning ? "Confirm Import" : "Import")
                                .frame(width: 100)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedFileURL == nil || isImporting)
                    .buttonStyle(.borderedProminent)
                    .tint(showingReplaceWarning ? .orange : .blue)
                }
            }
        }
        .padding()
        .frame(width: 500)
    }

    private func showFilePicker() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Snapshot History JSON File"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [UTType.json]

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                selectedFileURL = url
                importError = nil
                showingReplaceWarning = false
                loadPreview(from: url)
            }
        }
    }

    private func loadPreview(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let json = json else {
                importError = "Invalid JSON format"
                return
            }

            // Extract metadata
            let version = json["version"] as? String ?? "Unknown"
            let snapshotCount = json["snapshotCount"] as? Int ?? 0
            let appVersion = json["appVersion"] as? String

            var exportDate: Date?
            if let exportDateString = json["exportDate"] as? String {
                exportDate = ISO8601DateFormatter().date(from: exportDateString)
            }

            importPreview = ImportPreview(
                version: version,
                snapshotCount: snapshotCount,
                exportDate: exportDate,
                appVersion: appVersion
            )
        } catch {
            importError = "Failed to read file: \(error.localizedDescription)"
        }
    }

    private func performImport() {
        guard let url = selectedFileURL else { return }
        guard let context = historyManager.modelContext else {
            importError = "Database context not available"
            return
        }

        isImporting = true
        importError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Read and parse JSON
                let data = try Data(contentsOf: url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                guard let json = json else {
                    throw ImportError.invalidFormat("Invalid JSON format")
                }

                // Validate version
                guard let version = json["version"] as? String else {
                    throw ImportError.missingVersion
                }

                // Currently only support version 1.0
                guard version == "1.0" else {
                    throw ImportError.unsupportedVersion(version)
                }

                // Extract snapshots array
                guard let snapshotsArray = json["snapshots"] as? [[String: Any]] else {
                    throw ImportError.invalidFormat("Missing or invalid snapshots array")
                }

                // Parse snapshots
                var parsedSnapshots: [StatsSnapshot] = []

                for (index, snapshotDict) in snapshotsArray.enumerated() {
                    do {
                        let snapshot = try parseSnapshot(from: snapshotDict)
                        parsedSnapshots.append(snapshot)
                    } catch {
                        throw ImportError.invalidSnapshot(index: index, error: error.localizedDescription)
                    }
                }

                // Perform import on main thread
                DispatchQueue.main.async {
                    // Delete all existing snapshots
                    let descriptor = FetchDescriptor<StatsSnapshot>()
                    do {
                        let existingSnapshots = try context.fetch(descriptor)
                        for snapshot in existingSnapshots {
                            context.delete(snapshot)
                        }

                        // Delete all DailyPerformance objects
                        let perfDescriptor = FetchDescriptor<DailyPerformance>()
                        let existingPerformances = try context.fetch(perfDescriptor)
                        for performance in existingPerformances {
                            context.delete(performance)
                        }

                        // Insert new snapshots
                        for snapshot in parsedSnapshots {
                            context.insert(snapshot)
                        }

                        // Save context
                        try context.save()

                        isImporting = false
                        importSuccess = true

                        // Auto-dismiss after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            dismiss()
                        }
                    } catch {
                        isImporting = false
                        importError = "Failed to save imported data: \(error.localizedDescription)"
                    }
                }
            } catch let error as ImportError {
                DispatchQueue.main.async {
                    isImporting = false
                    importError = error.localizedDescription
                }
            } catch {
                DispatchQueue.main.async {
                    isImporting = false
                    importError = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func parseSnapshot(from dict: [String: Any]) throws -> StatsSnapshot {
        // Required fields
        guard let timestampString = dict["timestamp"] as? String,
              let timestamp = ISO8601DateFormatter().date(from: timestampString) else {
            throw ImportError.missingRequiredField("timestamp")
        }

        guard let playerName = dict["playerName"] as? String else {
            throw ImportError.missingRequiredField("playerName")
        }

        guard let platform = dict["platform"] as? String else {
            throw ImportError.missingRequiredField("platform")
        }

        guard let kills = dict["kills"] as? Int else {
            throw ImportError.missingRequiredField("kills")
        }

        guard let deaths = dict["deaths"] as? Int else {
            throw ImportError.missingRequiredField("deaths")
        }

        guard let wins = dict["wins"] as? Int else {
            throw ImportError.missingRequiredField("wins")
        }

        guard let losses = dict["losses"] as? Int else {
            throw ImportError.missingRequiredField("losses")
        }

        guard let matchesPlayed = dict["matchesPlayed"] as? Int else {
            throw ImportError.missingRequiredField("matchesPlayed")
        }

        guard let totalScore = dict["totalScore"] as? Int else {
            throw ImportError.missingRequiredField("totalScore")
        }

        guard let timePlayed = dict["timePlayed"] as? Int else {
            throw ImportError.missingRequiredField("timePlayed")
        }

        guard let headshots = dict["headshots"] as? Int else {
            throw ImportError.missingRequiredField("headshots")
        }

        guard let assists = dict["assists"] as? Int else {
            throw ImportError.missingRequiredField("assists")
        }

        guard let revives = dict["revives"] as? Int else {
            throw ImportError.missingRequiredField("revives")
        }

        guard let resupplies = dict["resupplies"] as? Int else {
            throw ImportError.missingRequiredField("resupplies")
        }

        // Optional fields
        let eaId = dict["eaId"] as? String
        let progressionMode = dict["progressionMode"] as? String

        var sessionId: UUID?
        if let sessionIdString = dict["sessionId"] as? String {
            sessionId = UUID(uuidString: sessionIdString)
        }

        // Create snapshot
        let snapshot = StatsSnapshot(
            playerName: playerName,
            platform: platform,
            eaId: eaId,
            kills: kills,
            deaths: deaths,
            wins: wins,
            losses: losses,
            matchesPlayed: matchesPlayed,
            totalScore: totalScore,
            timePlayed: timePlayed,
            headshots: headshots,
            assists: assists,
            revives: revives,
            resupplies: resupplies,
            sessionId: sessionId,
            progressionMode: progressionMode
        )

        // Override computed fields with stored values
        if let kdRatio = dict["kdRatio"] as? Double {
            snapshot.kdRatio = kdRatio
        }
        if let scorePerMinute = dict["scorePerMinute"] as? Double {
            snapshot.scorePerMinute = scorePerMinute
        }
        if let killsPerMinute = dict["killsPerMinute"] as? Double {
            snapshot.killsPerMinute = killsPerMinute
        }
        if let accuracy = dict["accuracy"] as? Double {
            snapshot.accuracy = accuracy
        }
        if let headshotPercentage = dict["headshotPercentage"] as? Double {
            snapshot.headshotPercentage = headshotPercentage
        }

        // Override timestamp with imported value
        snapshot.timestamp = timestamp

        // Override ID if provided (to preserve original IDs)
        if let idString = dict["id"] as? String, let id = UUID(uuidString: idString) {
            snapshot.id = id
        }

        // Parse maps if available
        if let mapsArray = dict["maps"] as? [[String: Any]] {
            var maps: [MapPerformance] = []
            for mapDict in mapsArray {
                if let mapId = mapDict["mapId"] as? String,
                   let mapName = mapDict["mapName"] as? String,
                   let image = mapDict["image"] as? String,
                   let wins = mapDict["wins"] as? Int,
                   let losses = mapDict["losses"] as? Int,
                   let matches = mapDict["matches"] as? Int,
                   let winPercent = mapDict["winPercent"] as? String,
                   let secondsPlayed = mapDict["secondsPlayed"] as? Int {

                    let map = MapPerformance(
                        mapId: mapId,
                        mapName: mapName,
                        image: image,
                        wins: wins,
                        losses: losses,
                        matches: matches,
                        winPercentString: winPercent,
                        secondsPlayed: secondsPlayed
                    )
                    maps.append(map)
                }
            }
            snapshot.maps = maps
        }

        return snapshot
    }
}

// MARK: - Supporting Types

struct DeltaStats {
    let kills: Int
    let deaths: Int
    let assists: Int
    let wins: Int
    let matches: Int
    let totalScore: Int
    let kdRatio: Double
    let accuracy: Double
    let headshotPercentage: Double
    let killsPerMinute: Double
}

// MARK: - Import Supporting Types

struct ImportPreview {
    let version: String
    let snapshotCount: Int
    let exportDate: Date?
    let appVersion: String?
}

enum ImportError: LocalizedError {
    case invalidFormat(String)
    case missingVersion
    case unsupportedVersion(String)
    case missingRequiredField(String)
    case invalidSnapshot(index: Int, error: String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let message):
            return "Invalid file format: \(message)"
        case .missingVersion:
            return "Missing version information in import file"
        case .unsupportedVersion(let version):
            return "Unsupported file version: \(version). This app only supports version 1.0"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidSnapshot(let index, let error):
            return "Invalid snapshot at index \(index): \(error)"
        }
    }
}

#Preview {
    SessionHistoryView()
        .environmentObject(StatsViewModel())
}
