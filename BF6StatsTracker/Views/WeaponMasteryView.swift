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
//  WeaponMasteryView.swift
//  BF6StatsTracker
//
//  Weapon Mastery Analytics Dashboard
//  Shows hipfire vs scoped, body vs headshot kills, assist damage, hit-to-kill ratios
//

import SwiftUI
import Charts

struct WeaponMasteryView: View {
    @Environment(\.accentColor) private var accentColor
    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var selectedWeapon: WeaponStats?
    @State private var searchText = ""
    @AppStorage("weaponMastery_collapsedCategories") private var collapsedCategoriesData: Data = Data()
    
    @State private var collapsedCategories: Set<String> = []

    private var usesGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar
                .frame(width: 250)
            
            Divider()
            
            // Detail Panel
            detailPanel
                .frame(maxWidth: .infinity)
        }
        .onAppear {
            loadCollapsedCategories()
            // Auto-select first weapon if none selected
            if selectedWeapon == nil, let first = viewModel.weaponStats.first {
                selectedWeapon = first
            }
        }
    }

    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "scope")
                        .font(.title3)
                        .foregroundColor(accentColor)
                    
                    Text("Weapons")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Theme.overlayColor)
                .cornerRadius(6)
            }
            .padding()
            
            Divider()
            
            // Weapon List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(WeaponCategory.allCases) { category in
                        categorySection(category: category)
                    }
                }
            }
        }
        .background(Theme.backgroundSecondary)
    }
    
    private func categorySection(category: WeaponCategory) -> some View {
        let weapons = weaponsInCategory(category)
        let isCollapsed = collapsedCategories.contains(category.rawValue)
        
        return VStack(spacing: 0) {
            // Category Header
            Button(action: {
                toggleCategory(category)
            }) {
                HStack {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Text("\(weapons.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.overlayColor.opacity(0.5))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.overlayColor.opacity(0.3))
            }
            .buttonStyle(.plain)
            
            // Weapon Items
            if !isCollapsed {
                ForEach(weapons) { weapon in
                    weaponListItem(weapon: weapon)
                }
            }
        }
    }
    
    private func weaponListItem(weapon: WeaponStats) -> some View {
        let isSelected = selectedWeapon?.weaponId == weapon.weaponId
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedWeapon = weapon
            }
        }) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weapon.weaponName)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? accentColor : Theme.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(weapon.kills) kills")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(accentColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 6)
            .background(isSelected ? accentColor.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    private func weaponsInCategory(_ category: WeaponCategory) -> [WeaponStats] {
        let categoryWeapons = viewModel.weaponStats.filter { matchesCategory($0, category: category) }
        
        if searchText.isEmpty {
            return categoryWeapons.sorted { $0.kills > $1.kills }
        } else {
            return categoryWeapons
                .filter { $0.weaponName.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.kills > $1.kills }
        }
    }
    
    private func toggleCategory(_ category: WeaponCategory) {
        if collapsedCategories.contains(category.rawValue) {
            collapsedCategories.remove(category.rawValue)
        } else {
            collapsedCategories.insert(category.rawValue)
        }
        saveCollapsedCategories()
    }
    
    private func loadCollapsedCategories() {
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: collapsedCategoriesData) {
            collapsedCategories = decoded
        }
    }
    
    private func saveCollapsedCategories() {
        if let encoded = try? JSONEncoder().encode(collapsedCategories) {
            collapsedCategoriesData = encoded
        }
    }
    
    // MARK: - Detail Panel
    
    private var detailPanel: some View {
        ScrollView {
            if let weapon = selectedWeapon {
                VStack(spacing: 20) {
                    // Weapon Header
                    weaponHeader(weapon: weapon)
                    
                    // Playstyle Analysis
                    playstyleAnalysis(weapon: weapon)
                    
                    // Kill Distribution
                    killDistribution(weapon: weapon)
                    
                    // Efficiency Metrics
                    efficiencyMetrics(weapon: weapon)
                    
                    // Complete Stats Table
                    completeStatsTable(weapon: weapon)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "scope")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("Select a weapon")
                        .font(.title3)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("Choose a weapon from the sidebar to view detailed statistics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func weaponHeader(weapon: WeaponStats) -> some View {
        HStack(spacing: 16) {
            AsyncGameImage(
                url: URL(string: weapon.image),
                placeholder: Image(systemName: "scope")
            )
            .frame(width: 100, height: 70)
            .background(Theme.overlayColor)
            .cornerRadius(12)
            .id(weapon.weaponId)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(weapon.weaponName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                
                Text(displayTypeName(weapon.type))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Label("\(weapon.kills)", systemImage: "target")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Label(String(format: "%.1f%%", weapon.accuracy), systemImage: "scope")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Label(String(format: "%.2f", weapon.killsPerMinute), systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(12)
    }
    
    /// Flexible category matching that handles various API response formats
    private func matchesCategory(_ weapon: WeaponStats, category: WeaponCategory) -> Bool {
        let type = weapon.type.lowercased()

        switch category {
        case .assaultRifles:
            return type.contains("assault")
        case .carbines:
            return type.contains("carbine")
        case .smgs:
            return type.contains("smg") || type.contains("submachine") || type.contains("pdw")
        case .lmgs:
            return type.contains("lmg") || type.contains("light machine") || type.contains("machine gun")
        case .dmrs:
            return type.contains("dmr") || type.contains("marksman")
        case .sniperRifles:
            return type == "rifles" || type.contains("sniper")
        case .shotguns:
            return type.contains("shotgun")
        case .pistols:
            return type.contains("pistol") || type.contains("sidearm")
        }
    }

    // MARK: - Playstyle Analysis

    private func playstyleAnalysis(weapon: WeaponStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playstyle Analysis")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 16) {
                // Hipfire vs Scoped
                VStack(spacing: 8) {
                    Text("Combat Style")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(weapon.hipfireKills)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.info)

                            Text("Hipfire")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)

                            if weapon.kills > 0 {
                                Text("\(Int(Double(weapon.hipfireKills) / Double(weapon.kills) * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }

                        Image(systemName: "arrow.left.and.right")
                            .foregroundColor(Theme.textSecondary)

                        VStack(spacing: 4) {
                            Text("\(weapon.scopedKills)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.bf6Purple)

                            Text("Scoped")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)

                            if weapon.kills > 0 {
                                Text("\(Int(Double(weapon.scopedKills) / Double(weapon.kills) * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }

                    // Playstyle indicator
                    let hipfireRatio = weapon.kills > 0 ? Double(weapon.hipfireKills) / Double(weapon.kills) : 0
                    Text(getPlaystyleLabel(hipfireRatio: hipfireRatio))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(getPlaystyleColor(hipfireRatio: hipfireRatio))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(getPlaystyleColor(hipfireRatio: hipfireRatio).opacity(0.2))
                        .cornerRadius(6)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)

                // Accuracy Analysis
                VStack(spacing: 8) {
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text(String(format: "%.1f%%", weapon.accuracy))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(getAccuracyColor(weapon.accuracy))

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(weapon.shotsHit)")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("Hits")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(weapon.shotsFired)")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("Fired")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    Text(getAccuracyRating(weapon.accuracy))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(getAccuracyColor(weapon.accuracy))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Kill Distribution

    private func killDistribution(weapon: WeaponStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kill Distribution")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 16) {
                // Body vs Headshot
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "scope")
                            .foregroundColor(Theme.error)

                        Text("Headshots")
                            .font(.subheadline)

                        Spacer()

                        Text("\(weapon.headshotKills)")
                            .font(.subheadline)
                            .fontWeight(.bold)

                        Text("(\(Int(weapon.headshotPercentage))%)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    ProgressView(value: weapon.headshotPercentage, total: 100)
                        .tint(Theme.error)

                    HStack {
                        Image(systemName: "figure.stand")
                            .foregroundColor(Theme.info)

                        Text("Body Shots")
                            .font(.subheadline)

                        Spacer()

                        Text("\(weapon.bodyKills)")
                            .font(.subheadline)
                            .fontWeight(.bold)

                        let bodyPercent = weapon.kills > 0 ? Double(weapon.bodyKills) / Double(weapon.kills) * 100 : 0
                        Text("(\(Int(bodyPercent))%)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    ProgressView(value: bodyPercent(weapon: weapon), total: 100)
                        .tint(Theme.info)
                }

                Divider()

                // Multi-kills
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundColor(Theme.warning)

                    Text("\(weapon.multiKills)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    Text("Multi-Kills")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    if weapon.kills > 0 {
                        Text("\(Int(Double(weapon.multiKills) / Double(weapon.kills) * 100))% of kills")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Theme.backgroundSecondary)
            .cornerRadius(8)
        }
    }

    // MARK: - Efficiency Metrics

    private func efficiencyMetrics(weapon: WeaponStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Efficiency Metrics")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                efficiencyCard(
                    title: "Hits per Kill",
                    value: String(format: "%.1f", weapon.hitVKills),
                    icon: "target",
                    color: .green,
                    description: "Lower is better"
                )

                efficiencyCard(
                    title: "Damage/Min",
                    value: String(format: "%.0f", weapon.damagePerMinute),
                    icon: "flame.fill",
                    color: .orange,
                    description: "Damage output rate"
                )

                efficiencyCard(
                    title: "Kills/Min",
                    value: String(format: "%.2f", weapon.killsPerMinute),
                    icon: "bolt.fill",
                    color: .yellow,
                    description: "Kill rate"
                )

                efficiencyCard(
                    title: "Assist Damage",
                    value: "\(weapon.assistsDamage)",
                    icon: "hand.thumbsup.fill",
                    color: .blue,
                    description: "Damage leading to assists"
                )

                efficiencyCard(
                    title: "Total Damage",
                    value: formatNumber(weapon.damage),
                    icon: "burst.fill",
                    color: .red,
                    description: "Total damage dealt"
                )

                efficiencyCard(
                    title: "Time Used",
                    value: formatPlaytime(weapon.timeEquipped),
                    icon: "clock.fill",
                    color: .purple,
                    description: "Time equipped"
                )
            }
        }
    }

    private func efficiencyCard(title: String, value: String, icon: String, color: Color, description: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            Text(description)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
    }

    // MARK: - Complete Stats Table
    
    private func completeStatsTable(weapon: WeaponStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Complete Statistics")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            VStack(spacing: 0) {
                // Kill Stats
                statTableSection(title: "Kill Statistics", rows: [
                    ("Total Kills", "\(weapon.kills)"),
                    ("Body Kills", "\(weapon.bodyKills)"),
                    ("Headshot Kills", "\(weapon.headshotKills)"),
                    ("Hipfire Kills", "\(weapon.hipfireKills)"),
                    ("Scoped Kills", "\(weapon.scopedKills)"),
                    ("Multi-Kills", "\(weapon.multiKills)")
                ])
                
                Divider()
                
                // Damage Stats
                statTableSection(title: "Damage Statistics", rows: [
                    ("Total Damage", formatNumber(weapon.damage)),
                    ("Assist Damage", "\(weapon.assistsDamage)"),
                    ("Damage Per Minute", String(format: "%.0f", weapon.damagePerMinute))
                ])
                
                Divider()
                
                // Accuracy Stats
                statTableSection(title: "Accuracy Statistics", rows: [
                    ("Accuracy", weapon.accuracyPercent),
                    ("Headshot %", weapon.headshotsPercent),
                    ("Shots Fired", "\(weapon.shotsFired)"),
                    ("Shots Hit", "\(weapon.shotsHit)"),
                    ("Hits per Kill", String(format: "%.1f", weapon.hitVKills))
                ])
                
                Divider()
                
                // Time Stats
                statTableSection(title: "Time Statistics", rows: [
                    ("Time Equipped", formatPlaytime(weapon.timeEquipped)),
                    ("Spawns", "\(weapon.spawns)"),
                    ("Kills Per Minute", String(format: "%.2f", weapon.killsPerMinute))
                ])
            }
            .background(Theme.backgroundSecondary)
            .cornerRadius(8)
        }
    }
    
    private func statTableSection(title: String, rows: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.overlayColor.opacity(0.3))
            
            // Rows
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text(row.0)
                        .font(.caption)
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Text(row.1)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(index % 2 == 0 ? Color.clear : Theme.overlayColor.opacity(0.2))
            }
        }
    }

    // MARK: - Helper Functions

    private func displayTypeName(_ apiType: String) -> String {
        // Map API type strings to user-friendly display names
        switch apiType {
        case "LMG": return "LMGs"
        case "DMR": return "DMRs"
        case "SMG-PDW": return "SMGs"
        case "Rifles": return "Sniper Rifles"
        case "Shotgun": return "Shotguns"
        default: return apiType  // For "Assault Rifles", "Carbines", "Pistols" which match
        }
    }

    private func bodyPercent(weapon: WeaponStats) -> Double {
        guard weapon.kills > 0 else { return 0 }
        return Double(weapon.bodyKills) / Double(weapon.kills) * 100
    }

    private func getPlaystyleLabel(hipfireRatio: Double) -> String {
        switch hipfireRatio {
        case 0.7...:
            return "Aggressive Rusher"
        case 0.4..<0.7:
            return "Versatile"
        case 0.1..<0.4:
            return "Tactical Marksman"
        default:
            return "Precision Sniper"
        }
    }

    private func getPlaystyleColor(hipfireRatio: Double) -> Color {
        switch hipfireRatio {
        case 0.7...:
            return .red
        case 0.4..<0.7:
            return .orange
        case 0.1..<0.4:
            return .blue
        default:
            return .purple
        }
    }

    private func getAccuracyColor(_ accuracy: Double) -> Color {
        switch accuracy {
        case 30...:
            return .purple
        case 20..<30:
            return .blue
        case 15..<20:
            return .green
        case 10..<15:
            return .yellow
        default:
            return .orange
        }
    }

    private func getAccuracyRating(_ accuracy: Double) -> String {
        switch accuracy {
        case 30...:
            return "Elite"
        case 20..<30:
            return "Excellent"
        case 15..<20:
            return "Good"
        case 10..<15:
            return "Average"
        default:
            return "Needs Practice"
        }
    }

    private func formatPlaytime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        } else {
            return "\(num)"
        }
    }
}

#Preview {
    WeaponMasteryView()
        .environmentObject(StatsViewModel())
        .frame(width: 1200, height: 900)
}
