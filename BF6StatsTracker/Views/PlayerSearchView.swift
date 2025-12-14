//
//  PlayerSearchView.swift
//  BF6StatsTracker
//
//  Player search interface for finding BF6 players
//  Updated to support EA authentication via EAIdentityKit
//

import SwiftUI

struct PlayerSearchView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var playerName = ""
    @State private var selectedPlatform: Platform = .pc
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var recentSearches: [RecentSearch] = []
    @State private var showEALogin = false

    var body: some View {
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
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.2))

            // Search Form
            VStack(spacing: 20) {
                // EA Authentication Section
                if viewModel.isEAAuthenticated {
                    // Show logged-in user info
                    eaAuthenticatedSection
                } else {
                    // Show EA login option
                    eaLoginSection
                }

                Divider()
                    .padding(.vertical, 4)

                // Player Name Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Player Name")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        if viewModel.isEAAuthenticated {
                            Text("(Using EA ID)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)

                        TextField("Enter exact player name", text: $playerName)
                            .textFieldStyle(.plain)
                            .font(.title3)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)

                    Text("Player names are case-sensitive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Platform Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Platform")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(Platform.allCases) { platform in
                            PlatformButton(
                                platform: platform,
                                isSelected: selectedPlatform == platform
                            ) {
                                selectedPlatform = platform
                            }
                        }
                    }
                }
                
                // Error Message
                if let error = searchError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        
                        Text(error)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
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
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: playerName.isEmpty ? [.gray] : [.blue, .purple],
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
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Clear") {
                                recentSearches.removeAll()
                                saveRecentSearches()
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        ForEach(recentSearches) { search in
                            RecentSearchRow(search: search) {
                                playerName = search.name
                                selectedPlatform = search.platform
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
        .background(Color(red: 0.1, green: 0.1, blue: 0.15))
        .onAppear {
            loadRecentSearches()
            // Pre-fill with EA ID if authenticated
            if viewModel.isEAAuthenticated, let eaId = viewModel.settings.eaId {
                playerName = eaId
            }
        }
        .sheet(isPresented: $showEALogin) {
            EALoginView()
                .environmentObject(viewModel)
        }
    }

    // MARK: - EA Authentication Section (Logged In)

    private var eaAuthenticatedSection: some View {
        VStack(spacing: 12) {
            HStack {
                // EA Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "person.badge.key.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(viewModel.settings.eaId ?? "EA User")
                            .font(.headline)
                            .foregroundColor(.white)

                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }

                    Text("EA Account Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Spacer()

                // Use My Stats button
                Button {
                    if let eaId = viewModel.settings.eaId {
                        playerName = eaId
                        performSearch()
                    }
                } label: {
                    Text("Use My Stats")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )

            // Identity details (collapsible)
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    IdentityDetailRow(label: "EA ID", value: viewModel.settings.eaId ?? "N/A")
                    IdentityDetailRow(label: "Nucleus ID", value: viewModel.settings.nucleusId ?? "N/A")
                    IdentityDetailRow(label: "Persona ID", value: viewModel.settings.personaId ?? "N/A")
                }
                .padding(.top, 8)
            } label: {
                Text("View Identity Details")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .tint(.secondary)
        }
    }

    // MARK: - EA Login Section (Not Logged In)

    private var eaLoginSection: some View {
        Button {
            showEALogin = true
        } label: {
            HStack {
                Image(systemName: "person.badge.key.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in with EA")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Automatically detect your EA ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func performSearch() {
        guard !playerName.isEmpty else { return }
        
        isSearching = true
        searchError = nil
        
        Task {
            do {
                await viewModel.searchPlayer(name: playerName, platform: selectedPlatform)
                
                if viewModel.error == nil {
                    // Save to recent searches
                    addRecentSearch(name: playerName, platform: selectedPlatform)
                    dismiss()
                } else {
                    searchError = viewModel.error?.localizedDescription
                }
            }
            
            isSearching = false
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

// MARK: - Platform Button

struct PlatformButton: View {
    let platform: Platform
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                PlatformIconView(platform: platform, size: 24)
                
                Text(platform.displayName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Search Row

struct RecentSearchRow: View {
    let search: RecentSearch
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                PlatformIconView(platform: search.platform, size: 18)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(search.name)
                        .fontWeight(.medium)
                    
                    Text(search.platform.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(search.date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Identity Detail Row

struct IdentityDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
    }
}

// MARK: - Preview

#Preview {
    PlayerSearchView()
        .environmentObject(StatsViewModel())
}
