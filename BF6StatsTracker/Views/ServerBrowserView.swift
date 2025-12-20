//
//  ServerBrowserView.swift
//  BF6StatsTracker
//
//  Enhanced server browser with advanced filtering and details
//

import SwiftUI

struct ServerBrowserView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var servers: [BF6Server] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedPlatform: Platform = .pc
    @State private var selectedRegion: ServerRegion = .all
    @State private var selectedMode: ServerMode = .all
    @State private var showFullServers = true
    @State private var showEmptyServers = true
    @State private var sortBy: ServerSortOption = .players
    @State private var expandedServerId: String?
    @State private var favoriteServerIds: Set<String> = []

    var filteredAndSortedServers: [BF6Server] {
        var filtered = servers.filter { server in
            // Platform filter (client-side since API doesn't support it)
            let matchesPlatform = server.platform.localizedCaseInsensitiveContains(selectedPlatform.rawValue)

            // Search filter
            let matchesSearch = searchText.isEmpty ||
                server.serverName.localizedCaseInsensitiveContains(searchText) ||
                server.map.localizedCaseInsensitiveContains(searchText) ||
                server.mode.localizedCaseInsensitiveContains(searchText)

            // Region filter
            let matchesRegion = selectedRegion == .all ||
                server.region.localizedCaseInsensitiveContains(selectedRegion.rawValue)

            // Mode filter
            let matchesMode = selectedMode == .all ||
                server.mode.localizedCaseInsensitiveContains(selectedMode.rawValue)

            // Capacity filters
            let matchesFull = showFullServers || !server.isFull
            let matchesEmpty = showEmptyServers || server.playerAmount > 0

            return matchesPlatform && matchesSearch && matchesRegion && matchesMode && matchesFull && matchesEmpty
        }

        // Sort
        switch sortBy {
        case .players:
            filtered.sort { $0.playerAmount > $1.playerAmount }
        case .name:
            filtered.sort { $0.serverName < $1.serverName }
        case .region:
            filtered.sort { $0.region < $1.region }
        case .favorites:
            filtered.sort { (favoriteServerIds.contains($0.id) ? 0 : 1) < (favoriteServerIds.contains($1.id) ? 0 : 1) }
        }

        return filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with stats summary
            headerWithFilters

            // Active filters indicator
            if hasActiveFilters {
                activeFiltersBar
            }

            // Server list
            if isLoading {
                loadingState
            } else if servers.isEmpty {
                emptyState
            } else if filteredAndSortedServers.isEmpty {
                noResultsState
            } else {
                serverListView
            }
        }
        .background(Theme.backgroundPrimary)
        .task {
            await loadServers()
        }
    }

    // MARK: - Header & Filters

    private var headerWithFilters: some View {
        VStack(spacing: 16) {
            // Title row
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.green)
                    .font(.title2)

                Text("Server Browser")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // Stats summary
                if !servers.isEmpty {
                    HStack(spacing: 16) {
                        ServerStatBadge(
                            value: "\(servers.count)",
                            label: "Total",
                            color: .blue
                        )
                        ServerStatBadge(
                            value: "\(filteredAndSortedServers.count)",
                            label: "Shown",
                            color: .green
                        )
                    }
                }

                // Refresh button
                Button(action: { Task { await loadServers() } }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.green)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }

            // Platform & Sort selector
            HStack(spacing: 12) {
                // Platform selector (client-side filtering)
                HStack(spacing: 8) {
                    ForEach([Platform.pc, Platform.playstation, Platform.xbox], id: \.self) { platform in
                        Button(action: {
                            selectedPlatform = platform
                            // No need to reload - filtering is done client-side
                        }) {
                            HStack(spacing: 4) {
                                PlatformIconView(platform: platform, size: 14)
                                Text(platform.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedPlatform == platform ? Color.green : Theme.overlayColor)
                            .foregroundColor(selectedPlatform == platform ? .black : Theme.textPrimary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Sort menu
                Menu {
                    ForEach(ServerSortOption.allCases) { option in
                        Button(action: { sortBy = option }) {
                            Label(option.rawValue, systemImage: sortBy == option ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label("Sort: \(sortBy.rawValue)", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
            }

            // Filter row
            HStack(spacing: 12) {
                // Region filter
                Menu {
                    ForEach(ServerRegion.allCases) { region in
                        Button(action: { selectedRegion = region }) {
                            Label(region.rawValue, systemImage: selectedRegion == region ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label(selectedRegion.rawValue, systemImage: "globe")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedRegion != .all ? Color.purple.opacity(0.2) : Theme.overlayColor)
                        .cornerRadius(8)
                }

                // Mode filter
                Menu {
                    ForEach(ServerMode.allCases) { mode in
                        Button(action: { selectedMode = mode }) {
                            Label(mode.rawValue, systemImage: selectedMode == mode ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label(selectedMode.rawValue, systemImage: "gamecontroller")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedMode != .all ? Color.orange.opacity(0.2) : Theme.overlayColor)
                        .cornerRadius(8)
                }

                // Capacity toggles
                Toggle(isOn: $showFullServers) {
                    Label("Full", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(showFullServers ? .red.opacity(0.3) : .secondary.opacity(0.2))
                .buttonStyle(.plain)

                Toggle(isOn: $showEmptyServers) {
                    Label("Empty", systemImage: "person.slash")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(showEmptyServers ? Theme.textSecondary.opacity(0.3) : .secondary.opacity(0.2))
                .buttonStyle(.plain)
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search servers, maps, modes...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Theme.overlayColor)
            .cornerRadius(10)
        }
        .padding()
        .background(Theme.overlayColor)
    }

    private var activeFiltersBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(.cyan)
                .font(.caption)

            Text("Active filters:")
                .font(.caption2)
                .foregroundColor(.secondary)

            if selectedRegion != .all {
                FilterChip(text: selectedRegion.rawValue, color: .purple) {
                    selectedRegion = .all
                }
            }

            if selectedMode != .all {
                FilterChip(text: selectedMode.rawValue, color: .orange) {
                    selectedMode = .all
                }
            }

            if !showFullServers {
                FilterChip(text: "Hide Full", color: .red) {
                    showFullServers = true
                }
            }

            if !showEmptyServers {
                FilterChip(text: "Hide Empty", color: Theme.textSecondary) {
                    showEmptyServers = true
                }
            }

            Spacer()

            Button("Clear All") {
                selectedRegion = .all
                selectedMode = .all
                showFullServers = true
                showEmptyServers = true
            }
            .font(.caption2)
            .foregroundColor(.cyan)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.cyan.opacity(0.1))
    }

    // MARK: - Server List

    private var serverListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredAndSortedServers) { server in
                    EnhancedServerCard(
                        server: server,
                        isFavorite: favoriteServerIds.contains(server.id),
                        isExpanded: expandedServerId == server.id,
                        onToggleFavorite: {
                            toggleFavorite(server.id)
                        },
                        onToggleExpanded: {
                            withAnimation(.spring(response: 0.3)) {
                                expandedServerId = expandedServerId == server.id ? nil : server.id
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading servers...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Servers Available")
                .font(.headline)

            VStack(spacing: 8) {
                Text("The BF6 servers list is currently empty.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("This may be because:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("•")
                        Text("BF6 hasn't been released yet")
                    }
                    HStack {
                        Text("•")
                        Text("No active servers for this platform")
                    }
                    HStack {
                        Text("•")
                        Text("API doesn't track BF6 servers yet")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.horizontal, 40)

            Button(action: { Task { await loadServers() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Debug info
            if servers.isEmpty && !isLoading {
                Text("Checked: \(selectedPlatform.displayName)")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Servers Match Filters")
                .font(.headline)

            Text("Try adjusting your filters or search terms")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Clear Filters") {
                selectedRegion = .all
                selectedMode = .all
                showFullServers = true
                showEmptyServers = true
                searchText = ""
            }
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.cyan.opacity(0.2))
            .cornerRadius(8)
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Functions

    private var hasActiveFilters: Bool {
        selectedRegion != .all || selectedMode != .all || !showFullServers || !showEmptyServers
    }

    private func loadServers() async {
        isLoading = true
        defer { isLoading = false }

        let filters = ServerFilters(platform: selectedPlatform)

        do {
            servers = try await APIService.shared.fetchServers(filters: filters, limit: 100)
        } catch {
            print("Error loading servers: \(error)")
        }
    }

    private func toggleFavorite(_ serverId: String) {
        if favoriteServerIds.contains(serverId) {
            favoriteServerIds.remove(serverId)
        } else {
            favoriteServerIds.insert(serverId)
        }
    }
}

// MARK: - Enhanced Server Card

struct EnhancedServerCard: View {
    let server: BF6Server
    let isFavorite: Bool
    let isExpanded: Bool
    let onToggleFavorite: () -> Void
    let onToggleExpanded: () -> Void

    var fillPercentage: Double {
        Double(server.slots.inGame) / Double(max(server.slots.capacity, 1))
    }

    var statusColor: Color {
        if server.isFull { return .red }
        if fillPercentage > 0.8 { return .orange }
        if server.slots.inGame == 0 { return Theme.textSecondary }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main row
            HStack(alignment: .top, spacing: 12) {
                // Favorite button
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundColor(isFavorite ? .yellow : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                // Server info
                VStack(alignment: .leading, spacing: 6) {
                    // Name
                    Text(server.serverName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(2)

                    // Map & Mode
                    HStack(spacing: 12) {
                        Label(server.map, systemImage: "map.fill")
                            .font(.caption)
                            .foregroundColor(.blue)

                        Label(server.mode, systemImage: "gamecontroller.fill")
                            .font(.caption)
                            .foregroundColor(.purple)

                        if let region = server.region.isEmpty ? nil : server.region {
                            Label(region, systemImage: "globe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Player count
                VStack(alignment: .trailing, spacing: 4) {
                    Text(server.playerCount)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)

                    Text(server.isFull ? "FULL" : "\(server.slots.capacity - server.slots.inGame) slots")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if server.hasQueue {
                        HStack(spacing: 4) {
                            Image(systemName: "hourglass")
                                .font(.caption2)
                            Text("\(server.slots.inQueue) queued")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }

            // Capacity bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Theme.overlayColor)

                    // Fill
                    Rectangle()
                        .fill(statusColor.gradient)
                        .frame(width: geometry.size.width * fillPercentage)
                }
            }
            .frame(height: 6)
            .cornerRadius(3)

            // Expand/Collapse button
            Button(action: onToggleExpanded) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)

                    Text(isExpanded ? "Hide Details" : "Show Details")
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    // Quick join button
                    if !server.isFull {
                        Label("Quick Join", systemImage: "person.badge.plus")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(Theme.borderColor)

                    // Server details grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        if let experience = server.experience {
                            ServerDetailRow(label: "Experience", value: experience, icon: "star.circle")
                        }

                        ServerDetailRow(label: "Platform", value: server.platform, icon: "gamecontroller")

                        if !server.country.isEmpty {
                            ServerDetailRow(label: "Country", value: server.country, icon: "flag")
                        }

                        ServerDetailRow(
                            label: "Status",
                            value: server.isFull ? "Full" : "Available",
                            icon: server.isFull ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                        )
                    }

                    // Map rotation
                    if let rotation = server.rotation, !rotation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.cyan)
                                    .font(.caption)

                                Text("Map Rotation")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(rotation.prefix(10), id: \.self) { mapName in
                                        Text(mapName)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(4)
                                    }

                                    if rotation.count > 10 {
                                        Text("+\(rotation.count - 10) more")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // Server info/description
                    if let info = server.serverInfo, !info.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)

                                Text("Server Info")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }

                            Text(info)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Supporting Views

struct ServerStatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct FilterChip: View {
    let text: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption2)
                .foregroundColor(color)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(color)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .cornerRadius(4)
    }
}

struct ServerDetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .font(.caption)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Filter Types

enum ServerRegion: String, CaseIterable, Identifiable {
    case all = "All Regions"
    case americas = "Americas"
    case europe = "Europe"
    case asia = "Asia"
    case oceania = "Oceania"

    var id: String { rawValue }
}

enum ServerMode: String, CaseIterable, Identifiable {
    case all = "All Modes"
    case conquest = "Conquest"
    case breakthrough = "Breakthrough"
    case rush = "Rush"
    case tdm = "Team Deathmatch"
    case hazardZone = "Hazard Zone"

    var id: String { rawValue }
}

enum ServerSortOption: String, CaseIterable, Identifiable {
    case players = "Players"
    case name = "Name"
    case region = "Region"
    case favorites = "Favorites"

    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    ServerBrowserView()
        .environmentObject(StatsViewModel())
}
