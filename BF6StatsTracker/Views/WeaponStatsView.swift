//
//  WeaponStatsView.swift
//  BF6StatsTracker
//
//  Displays all weapon statistics for the player
//

import SwiftUI

struct WeaponStatsView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var selectedCategory: WeaponCategory?
    @State private var sortOption: WeaponSortOption = .kills
    @State private var searchText = ""
    
    private var filteredWeapons: [WeaponStats] {
        var weapons = viewModel.weaponStats
        
        // Filter by category
        if let category = selectedCategory {
            weapons = viewModel.weaponsByCategory[category] ?? []
        }
        
        // Filter by search
        if !searchText.isEmpty {
            weapons = weapons.filter { $0.weaponName.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Sort
        switch sortOption {
        case .kills:
            weapons.sort { $0.kills > $1.kills }
        case .accuracy:
            weapons.sort { $0.accuracy > $1.accuracy }
        case .headshots:
            weapons.sort { $0.headshots > $1.headshots }
        case .kpm:
            weapons.sort { $0.killsPerMinute > $1.killsPerMinute }
        case .name:
            weapons.sort { $0.weaponName < $1.weaponName }
        }
        
        return weapons
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with filters
            filterBar
            
            // Category Pills
            categoryPills
            
            // Weapons Grid
            if filteredWeapons.isEmpty {
                emptyStateView
            } else {
                weaponsGrid
            }
        }
    }
    
    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 16) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textSecondary)

                TextField("Search weapons...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.textPrimary)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Theme.overlayColor)
            .cornerRadius(10)
            .frame(maxWidth: 300)

            Spacer()

            // Sort Options
            HStack(spacing: 8) {
                Text("Sort by:")
                    .foregroundColor(Theme.textSecondary)

                Picker("Sort", selection: $sortOption) {
                    ForEach(WeaponSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            // Stats summary
            Text("\(filteredWeapons.count) weapons")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.overlayColor)
                .cornerRadius(6)
        }
    }
    
    // MARK: - Category Pills

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryPill(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    color: Theme.bf6Orange
                ) {
                    selectedCategory = nil
                }

                ForEach(WeaponCategory.allCases) { category in
                    CategoryPill(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        color: categoryColor(for: category)
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Weapons Grid
    
    private var weaponsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredWeapons, id: \.weaponName) { weapon in
                    WeaponCard(weapon: weapon)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "scope")
                .font(.system(size: 50))
                .foregroundColor(Theme.textSecondary)

            Text("No Weapons Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            if !searchText.isEmpty {
                Text("Try adjusting your search or filters")
                    .foregroundColor(Theme.textSecondary)
            } else {
                Text("Weapon data will appear after playing matches")
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(50)
    }

    // MARK: - Helpers

    private func categoryColor(for category: WeaponCategory) -> Color {
        switch category {
        case .assaultRifles: return Theme.bf6Red
        case .carbines: return Theme.bf6Orange
        case .smgs: return .yellow
        case .lmgs: return Theme.bf6Green
        case .dmrs: return .teal
        case .sniperRifles: return Theme.bf6Blue
        case .shotguns: return Theme.bf6Purple
        case .pistols: return .pink
        }
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? Theme.selectedText : Theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Theme.overlayColor)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Weapon Card

struct WeaponCard: View {
    let weapon: WeaponStats
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Weapon Image
                AsyncGameImage(
                    url: URL(string: weapon.image),
                    placeholder: Image(systemName: "scope")
                )
                .frame(width: 70, height: 50)
                .background(Theme.overlayColor)
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(weapon.weaponName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .foregroundColor(Theme.textPrimary)

                    Text(weapon.type)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                // Kills Badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(weapon.kills)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.bf6Red)

                    Text("kills")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Divider()
                .padding(.vertical, 12)

            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                WeaponStatItem(label: "Kills", value: "\(weapon.kills)", color: Theme.bf6Red)
                WeaponStatItem(label: "Accuracy", value: String(format: "%.1f%%", weapon.accuracy), color: Theme.bf6Blue)
                WeaponStatItem(label: "Headshots", value: "\(weapon.headshots)", color: .yellow)
                WeaponStatItem(label: "HS %", value: String(format: "%.1f%%", weapon.headshotPercentage), color: Theme.bf6Purple)
                WeaponStatItem(label: "KPM", value: String(format: "%.2f", weapon.killsPerMinute), color: Theme.bf6Orange)
                WeaponStatItem(label: "Time", value: formatTime(weapon.timePlayed), color: Theme.textSecondary)
            }

            // Additional Stats (on hover)
            if isHovered {
                Divider()
                    .padding(.vertical, 8)

                HStack {
                    Label("\(weapon.shotsFired.formatted()) shots", systemImage: "burst.fill")
                    Spacer()
                    Label("\(weapon.shotsHit.formatted()) hits", systemImage: "target")
                    Spacer()
                    Label("\(weapon.multiKills) multi-kills", systemImage: "star.fill")
                }
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.borderColor.opacity(isHovered ? 1.0 : 0.5), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Weapon Stat Item

struct WeaponStatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Sort Options

enum WeaponSortOption: String, CaseIterable, Identifiable {
    case kills = "Kills"
    case accuracy = "Accuracy"
    case headshots = "Headshots"
    case kpm = "KPM"
    case name = "Name"

    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    WeaponStatsView()
        .environmentObject(StatsViewModel())
        .frame(width: 1000, height: 700)
        .background(Theme.backgroundPrimary)
}
