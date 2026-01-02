//
//  SessionHistoryView.swift
//  BF6StatsTracker
//
//  Displays all SwiftData snapshots with delete functionality
//

import SwiftUI

struct SessionHistoryView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @EnvironmentObject var viewModel: StatsViewModel

    @State private var showingDeleteAlert = false
    @State private var showingDeleteAllAlert = false
    @State private var snapshotToDelete: StatsSnapshot?
    @State private var searchText = ""

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
            Text("Are you sure you want to delete all \(historyManager.recentSnapshots.count) snapshots?\n\nThis will permanently remove all historical data and cannot be undone.")
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
                        Text("\(historyManager.recentSnapshots.count)")
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

            // Delete All button
            if !historyManager.recentSnapshots.isEmpty {
                Button(role: .destructive) {
                    showingDeleteAllAlert = true
                } label: {
                    Label("Delete All", systemImage: "trash.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(8)
                }
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
            return historyManager.recentSnapshots
        } else {
            let lowercased = searchText.lowercased()
            return historyManager.recentSnapshots.filter { snapshot in
                snapshot.playerName.lowercased().contains(lowercased) ||
                (snapshot.eaId?.lowercased().contains(lowercased) ?? false) ||
                "\(snapshot.kills)".contains(lowercased) ||
                "\(snapshot.deaths)".contains(lowercased) ||
                snapshot.timestamp.formatted().lowercased().contains(lowercased)
            }
        }
    }

    private var totalStorageSize: Int {
        historyManager.recentSnapshots.reduce(0) { $0 + $1.approximateStorageSize }
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
            context.delete(snapshot)
            try? context.save()
            historyManager.loadRecentData()
        }
    }

    private func deleteAllSnapshots() {
        guard let context = historyManager.modelContext else { return }

        withAnimation {
            for snapshot in historyManager.recentSnapshots {
                context.delete(snapshot)
            }
            try? context.save()
            historyManager.loadRecentData()
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
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    StatChip(label: "K/D", value: String(format: "%.2f", snapshot.kdRatio), color: snapshot.kdRatio >= 1.0 ? .green : .orange)
                    StatChip(label: "Kills", value: "\(snapshot.kills)", color: .red)
                    StatChip(label: "Deaths", value: "\(snapshot.deaths)", color: Theme.textSecondary)
                    StatChip(label: "Wins", value: "\(snapshot.wins)", color: .blue)
                    StatChip(label: "Matches", value: "\(snapshot.matchesPlayed)", color: .cyan)
                }

                HStack(spacing: 12) {
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
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    SessionHistoryView()
        .environmentObject(StatsViewModel())
}
