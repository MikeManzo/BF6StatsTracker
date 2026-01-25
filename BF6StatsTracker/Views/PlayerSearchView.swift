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
//  PlayerSearchView.swift
//  BF6StatsTracker
//
//  Player search interface for finding BF6 players
//  Updated to support EA authentication via EAIdentityKit
//

import SwiftUI

struct PlayerSearchView: View {
    @Environment(\.accentColor) private var accentColor
    @EnvironmentObject var viewModel: StatsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var playerName = ""
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var recentSearches: [RecentSearch] = []
    @State private var foundPlayer: PlayerStats?
    @State private var showPlayerPreview = false

    // Default platform - PC is the most common
    private let defaultPlatform: Platform = .pc

    var body: some View {
        Group {
            if showPlayerPreview, let player = foundPlayer {
                PlayerPreviewView(
                    playerStats: player,
                    playerName: playerName,
                    platform: defaultPlatform,
                    onReplace: {
                        replaceCurrentUser()
                    },
                    onCancel: {
                        showPlayerPreview = false
                        foundPlayer = nil
                    }
                )
            } else {
                searchFormView
            }
        }
    }

    private var searchFormView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Search Player")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Theme.overlayColor)

            // Search Form
            VStack(spacing: 20) {
                // Player Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Player Name")
                        .font(.headline)
                        .foregroundColor(Theme.textSecondary)

                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(Theme.textSecondary)

                        TextField("Enter exact player name", text: $playerName)
                            .textFieldStyle(.plain)
                            .font(.title3)
                    }
                    .padding()
                    .background(Theme.overlayColor)
                    .cornerRadius(10)

                    Text("Player names are case-sensitive")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                // Error Message
                if let error = searchError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Theme.bf6Red)
                        
                        Text(error)
                            .foregroundColor(Theme.bf6Red)
                    }
                    .padding()
                    .background(Theme.bf6Red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Search Button
                Button {
                    performSearch()
                } label: {
                    HStack {
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        
                        Text(isSearching ? "Searching..." : "Search")
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: playerName.isEmpty ? [Theme.textSecondary] : [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(playerName.isEmpty || isSearching)
                
                Divider()
                    .padding(.vertical)
                
                // Recent Searches
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Searches")
                                .font(.headline)
                                .foregroundColor(Theme.textSecondary)
                            
                            Spacer()
                            
                            Button("Clear") {
                                recentSearches.removeAll()
                                saveRecentSearches()
                            }
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        }
                        
                        ForEach(recentSearches) { search in
                            RecentSearchRow(search: search) {
                                playerName = search.name
                                performSearch()
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(width: 500, height: 700)
        .background(Theme.backgroundPrimary)
        .onAppear {
            loadRecentSearches()
        }
    }

    // MARK: - Actions
    
    private func performSearch() {
        guard !playerName.isEmpty else { return }

        isSearching = true
        searchError = nil

        Task {
            do {
                // Step 1: Authenticate with GamerID to get EA identity (nucleusId, personaId)
                guard let url = URL(string: "https://rip-bf.com/api/eaid/?name=\(playerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? playerName)") else {
                    throw BF6TrackerError.invalidURL
                }

                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(RipBFAPIResponse.self, from: data)

                // Check if there was an error
                if response.error {
                    searchError = response.message
                    isSearching = false
                    return
                }

                // Get the first user from the response
                guard let apiUser = response.users?.first else {
                    searchError = "No player found with that name"
                    isSearching = false
                    return
                }

                // Step 2: Create a full PlayerIdentifier with EA identity
                let identifier = PlayerIdentifier(
                    name: apiUser.EAID,
                    platform: defaultPlatform,
                    nucleusId: apiUser.userId,
                    personaId: apiUser.id
                )

                // Step 3: Fetch stats from gametools API using the full identifier
                let stats = try await APIService.shared.fetchPlayerStats(identifier: identifier)

                // Save the found player and show preview
                foundPlayer = stats
                showPlayerPreview = true

                // Save to recent searches
                addRecentSearch(name: playerName, platform: defaultPlatform)
            } catch let error as BF6TrackerError {
                searchError = error.errorDescription ?? "Player not found"
            } catch {
                searchError = "Network error: \(error.localizedDescription)"
            }

            isSearching = false
        }
    }

    private func replaceCurrentUser() {
        // Now actually update the current user with the searched player
        Task {
            await viewModel.searchPlayer(name: playerName, platform: defaultPlatform)

            // Close the preview and search view
            showPlayerPreview = false
            foundPlayer = nil
            dismiss()
        }
    }
    
    // MARK: - Recent Searches
    
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: "RecentSearches"),
           let searches = try? JSONDecoder().decode([RecentSearch].self, from: data) {
            recentSearches = searches
        }
    }
    
    private func saveRecentSearches() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: "RecentSearches")
        }
    }
    
    private func addRecentSearch(name: String, platform: Platform) {
        // Remove duplicate if exists
        recentSearches.removeAll { $0.name == name && $0.platform == platform }
        
        // Add to beginning
        recentSearches.insert(RecentSearch(name: name, platform: platform), at: 0)
        
        // Keep only last 10
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        saveRecentSearches()
    }
}

// MARK: - Recent Search Model

struct RecentSearch: Codable, Identifiable {
    var id: String { "\(platform.rawValue)_\(name)" }
    let name: String
    let platform: Platform
    let date: Date
    
    init(name: String, platform: Platform) {
        self.name = name
        self.platform = platform
        self.date = Date()
    }
}

// MARK: - Recent Search Row

struct RecentSearchRow: View {
    let search: RecentSearch
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(search.name)
                    .fontWeight(.medium)

                Spacer()

                Text(search.date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Player Preview View

struct PlayerPreviewView: View {
    let playerStats: PlayerStats
    let playerName: String
    let platform: Platform
    let onReplace: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.accentColor) private var accentColor

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Player Found")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()
            }
            .padding()
            .background(Theme.overlayColor)

            // Player Summary
            VStack(spacing: 20) {
                // Player Name
                VStack(spacing: 8) {
                    Text(playerName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                }

                // Key Stats Grid
                VStack(spacing: 12) {
                    Text("Player Statistics")
                        .font(.headline)
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        StatPreviewCard(
                            title: "Rank",
                            value: "\(playerStats.rank)",
                            icon: "star.fill",
                            color: accentColor
                        )

                        StatPreviewCard(
                            title: "Mastery",
                            value: "\(playerStats.masteryLevel)",
                            icon: "arrow.up.circle.fill",
                            color: Theme.bf6Blue
                        )

                        StatPreviewCard(
                            title: "K/D Ratio",
                            value: String(format: "%.2f", playerStats.kdRatio),
                            icon: "target",
                            color: playerStats.kdRatio >= 1.0 ? Theme.bf6Green : Theme.bf6Red
                        )

                        StatPreviewCard(
                            title: "Win Rate",
                            value: playerStats.wlPercent,
                            icon: "trophy.fill",
                            color: playerStats.wlRatio >= 50.0 ? Theme.bf6Green : accentColor
                        )

                        StatPreviewCard(
                            title: "Kills",
                            value: formatNumber(playerStats.kills),
                            icon: "scope",
                            color: Theme.textPrimary
                        )

                        StatPreviewCard(
                            title: "Playtime",
                            value: formatPlaytime(playerStats.timePlayed),
                            icon: "clock.fill",
                            color: Theme.textPrimary
                        )
                    }
                }

                Spacer()

                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        onReplace()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Replace Current User")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.title3)
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 700)
        .background(Theme.backgroundPrimary)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatPlaytime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        if hours < 1000 {
            return "\(hours)h"
        } else {
            return String(format: "%.1fk h", Double(hours) / 1000.0)
        }
    }
}

// MARK: - Stat Preview Card

struct StatPreviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(10)
    }
}

// MARK: - Preview

#Preview {
    PlayerSearchView()
        .environmentObject(StatsViewModel())
}
