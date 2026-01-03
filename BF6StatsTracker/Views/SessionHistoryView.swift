//
//  SessionHistoryView.swift
//  BF6StatsTracker
//
//  Displays all SwiftData snapshots with delete functionality
//

import SwiftUI
import SwiftData

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
            LazyVStack(spacing: 12) {
                ForEach(filteredSnapshots, id: \.id) { snapshot in
                    SnapshotRow(snapshot: snapshot) {
                        snapshotToDelete = snapshot
                        showingDeleteAlert = true
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .padding()
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredSnapshots.count)
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
            print("⚠️ Error fetching DailyPerformance objects: \(error)")
            UserDefaults.standard.set(false, forKey: "HasCleanedCorruptDailyPerformance_v1")
        }
    }
}

// MARK: - Supporting Views

struct SnapshotRow: View {
    let snapshot: StatsSnapshot
    let onDelete: () -> Void

    var body: some View {
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

                // EA ID badge
                if let eaId = snapshot.eaId {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                        Text(eaId)
                            .font(.system(size: 9))
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
                }

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
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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

#Preview {
    SessionHistoryView()
        .environmentObject(StatsViewModel())
}
