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
//  WeaponStatsView.swift
//  BF6StatsTracker
//
//  Displays all weapon statistics for the player
//

import SwiftUI

struct WeaponStatsView: View {
    @Environment(\.accentColor) private var accentColor
    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var selectedCategory: WeaponCategory?
    @State private var sortOption: WeaponSortOption = .kills
    @State private var searchText = ""

    private var usesGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }
    
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
        GlassContainerWrapper(usesGlass: usesGlass) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    CategoryPill(
                        title: "All",
                        icon: "square.grid.2x2.fill",
                        isSelected: selectedCategory == nil,
                        color: accentColor
                    ) {
                        selectedCategory = nil
                    }
                    .id("all")

                    ForEach(WeaponCategory.allCases) { category in
                        CategoryPill(
                            title: category.displayName,
                            icon: category.icon,
                            isSelected: selectedCategory == category,
                            color: categoryColor(for: category)
                        ) {
                            selectedCategory = category
                        }
                        .id(category.rawValue)
                    }
                }
                .padding(.horizontal)
            }
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
        case .carbines: return accentColor
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

    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled

    private var usesGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }

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
            .background(usesGlass ? Color.clear : (isSelected ? color : Theme.overlayColor))
            .cornerRadius(20)
            .modifier(SubTabGlassModifier(
                isSelected: isSelected,
                accentColor: color,
                usesGlass: usesGlass
            ))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Weapon Card

struct WeaponCard: View {
    let weapon: WeaponStats
    @Environment(\.accentColor) private var accentColor

    var body: some View {
        VStack(spacing: 0) {
            // Header with weapon info and primary metric
            headerSection
                .padding(16)
            
            // Separator
            Divider()
                .background(Theme.borderColor.opacity(0.3))
            
            // Key performance metrics - 2 column layout
            keyMetricsSection
                .padding(16)
            
            // Additional details footer
            Divider()
                .background(Theme.borderColor.opacity(0.3))
            
            detailsFooter
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            weaponImage
            
            VStack(alignment: .leading, spacing: 3) {
                Text(weapon.weaponName)
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                Text(weapon.type)
                    .font(.system(.caption, design: .default))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()
            
            killsBadge
        }
    }
    
    private var weaponImage: some View {
        AsyncGameImage(
            url: URL(string: weapon.image),
            placeholder: Image(systemName: "scope")
        )
        .frame(width: 80, height: 56)
        .background(Theme.overlayColor.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var killsBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(weapon.kills)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Theme.bf6Red)

            Text("KILLS")
                .font(.system(.caption2, design: .default, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .tracking(0.5)
        }
    }
    
    private var keyMetricsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MetricCard(
                    icon: "scope",
                    label: "Accuracy",
                    value: String(format: "%.1f%%", weapon.accuracy),
                    color: Theme.bf6Blue
                )
                
                MetricCard(
                    icon: "headphones",
                    label: "Headshots",
                    value: "\(weapon.headshots) (\(String(format: "%.1f%%", weapon.headshotPercentage)))",
                    color: Theme.bf6Purple
                )
            }
            
            HStack(spacing: 12) {
                MetricCard(
                    icon: "timer",
                    label: "KPM",
                    value: String(format: "%.2f", weapon.killsPerMinute),
                    color: accentColor
                )
                
                MetricCard(
                    icon: "clock",
                    label: "Time",
                    value: formatTime(weapon.timePlayed),
                    color: .green
                )
            }
        }
    }
    
    private var detailsFooter: some View {
        HStack(spacing: 0) {
            FooterStat(label: "Shots Fired", value: weapon.shotsFired.formatted())
            
            Divider()
                .frame(height: 20)
                .background(Theme.borderColor.opacity(0.3))
            
            FooterStat(label: "Shots Hit", value: weapon.shotsHit.formatted())
            
            Divider()
                .frame(height: 20)
                .background(Theme.borderColor.opacity(0.3))
            
            FooterStat(label: "Multi-kills", value: "\(weapon.multiKills)")
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Theme.cardBackground)
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Theme.borderColor.opacity(0.5), lineWidth: 1)
    }

    // MARK: - Helpers
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color.opacity(0.8))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.caption, design: .default))
                    .foregroundColor(Theme.textSecondary)
                
                Text(value)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.overlayColor.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Footer Stat Component

struct FooterStat: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            
            Text(label)
                .font(.system(.caption2, design: .default))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
