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
    @State private var selectedCategory: WeaponCategory?

    private var usesGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "scope")
                        .font(.title)
                        .foregroundColor(accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weapon Mastery Analytics")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)

                        Text("Deep dive into weapon performance and playstyle")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()
                }

                if !viewModel.weaponStats.isEmpty {
                    // Category Filter
                    categoryFilterView

                    // Weapons Grid
                    weaponsGridView(weapons: filteredWeapons)

                    // Detailed Stats for Selected Weapon
                    if let weapon = selectedWeapon {
                        weaponDetailView(weapon: weapon)
                    }
                } else {
                    Text("No weapon stats available")
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding()
        }
    }

    // MARK: - Category Filter

    private var categoryFilterView: some View {
        GlassContainerWrapper(usesGlass: usesGlass) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    categoryButton(category: nil, label: "All Weapons")

                    ForEach(WeaponCategory.allCases) { category in
                        categoryButton(category: category, label: category.displayName)
                    }
                }
            }
        }
    }

    private func categoryButton(category: WeaponCategory?, label: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation {
                selectedCategory = category
            }
        } label: {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? Theme.selectedText : Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected && !usesGlass ? accentColor : (!isSelected && !usesGlass ? Theme.overlayColor : Color.clear))
                .cornerRadius(8)
                .modifier(SubTabGlassModifier(
                    isSelected: isSelected,
                    accentColor: accentColor,
                    usesGlass: usesGlass
                ))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filtered Weapons

    private var filteredWeapons: [WeaponStats] {
        let weapons = viewModel.weaponStats

        let filtered = selectedCategory == nil
            ? weapons
            : weapons.filter { matchesCategory($0, category: selectedCategory!) }

        return filtered.sorted { $0.kills > $1.kills }
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

    // MARK: - Weapons Grid

    private func weaponsGridView(weapons: [WeaponStats]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(weapons) { weapon in
                weaponCard(weapon: weapon)
            }
        }
    }

    private func weaponCard(weapon: WeaponStats) -> some View {
        Button {
            withAnimation {
                selectedWeapon = weapon
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(weapon.weaponName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if selectedWeapon?.weaponId == weapon.weaponId {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.success)
                    }
                }

                Text(displayTypeName(weapon.type))
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(weapon.kills)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(accentColor)

                        Text("kills")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f%%", weapon.headshotPercentage))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.error)

                        Text("headshot")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding()
            .background(selectedWeapon?.weaponId == weapon.weaponId ? accentColor.opacity(0.2) : Theme.overlayColor)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weapon Detail View

    private func weaponDetailView(weapon: WeaponStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(weapon.weaponName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    Text(displayTypeName(weapon.type))
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation {
                        selectedWeapon = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Playstyle Analysis
            playstyleAnalysis(weapon: weapon)

            // Kill Distribution
            killDistribution(weapon: weapon)

            // Efficiency Metrics
            efficiencyMetrics(weapon: weapon)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
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
