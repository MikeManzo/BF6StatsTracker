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
    @State private var exportFormat: ExportFormat = .csv
    @State private var collapsedSections: Set<Date> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Search bar
            searchBar

            // Snapshots list
            if filteredSnapshots.isEmpty {
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

            // Export and Delete options
            if !allSnapshots.isEmpty {
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

                    // Export button
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

                    // Delete options menu
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
            print("⚠️ Error fetching DailyPerformance objects: \(error)")
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

            // Core stats
            HStack(spacing: 8) {
                StatChip(label: "K/D", value: String(format: "%.2f", snapshot.kdRatio), color: snapshot.kdRatio >= 1.0 ? .green : .orange)
                StatChip(label: "Kills", value: "\(snapshot.kills)", color: .red)
                StatChip(label: "Deaths", value: "\(snapshot.deaths)", color: Theme.textSecondary)
                StatChip(label: "Wins", value: "\(snapshot.wins)", color: .blue)
                StatChip(label: "Matches", value: "\(snapshot.matchesPlayed)", color: .cyan)
                StatChip(label: "Accuracy", value: String(format: "%.1f%%", snapshot.accuracy), color: .purple)
                StatChip(label: "HS%", value: String(format: "%.1f%%", snapshot.headshotPercentage), color: .yellow)
                StatChip(label: "KPM", value: String(format: "%.2f", snapshot.killsPerMinute), color: .pink)
                StatChip(label: "Score", value: formatScore(snapshot.totalScore), color: .indigo)
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
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let exportData = snapshots.map { snapshot -> [String: Any] in
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
                            "secondsPlayed": map.secondsPlayed,
                            "timePlayed": map.timePlayed
                        ]
                    }
                }

                var data: [String: Any] = [
                    "timestamp": ISO8601DateFormatter().string(from: snapshot.timestamp),
                    "playerName": snapshot.playerName,
                    "platform": snapshot.platform,
                    "eaId": snapshot.eaId ?? "",
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
                    "timePlayedMinutes": snapshot.timePlayed / 60,
                    "timePlayedSeconds": snapshot.timePlayed,
                    "headshots": snapshot.headshots,
                    "assists": snapshot.assists,
                    "revives": snapshot.revives,
                    "resupplies": snapshot.resupplies,
                    "maps": mapsData
                ]

                // Add optional fields only if they exist
                if let sessionId = snapshot.sessionId {
                    data["sessionId"] = sessionId.uuidString
                }
                if let progressionMode = snapshot.progressionMode {
                    data["progressionMode"] = progressionMode
                }

                return data
            }

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

#Preview {
    SessionHistoryView()
        .environmentObject(StatsViewModel())
}
