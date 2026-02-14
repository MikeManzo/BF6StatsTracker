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
//  UtilityEffectivenessView.swift
//  BF6StatsTracker
//
//  Utility & Gadget Effectiveness Dashboard
//  Shows gadget uses, kills per use, throwables, destroyed gadgets, takedowns
//

import SwiftUI

struct UtilityEffectivenessView: View {
    @Environment(\.accentColor) private var accentColor
    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var selectedGadget: GadgetStats?
    @State private var searchText = ""
    @AppStorage("utilityEffectiveness_collapsedCategories") private var collapsedCategoriesData: Data = Data()
    
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
            // Auto-select first gadget if none selected
            if selectedGadget == nil, let first = viewModel.gadgetStats.first {
                selectedGadget = first
            }
        }
    }

    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.title3)
                        .foregroundColor(accentColor)
                    
                    Text("Gadgets")
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
            
            // Gadget List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(GadgetCategory.allCases) { category in
                        categorySection(category: category)
                    }
                }
            }
        }
        .background(Theme.backgroundSecondary)
    }
    
    private func categorySection(category: GadgetCategory) -> some View {
        let gadgets = gadgetsInCategory(category)
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
                    
                    Text("\(gadgets.count)")
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
            
            // Gadget Items
            if !isCollapsed {
                ForEach(gadgets) { gadget in
                    gadgetListItem(gadget: gadget)
                }
            }
        }
    }
    
    private func gadgetListItem(gadget: GadgetStats) -> some View {
        let isSelected = selectedGadget?.gadgetId == gadget.gadgetId
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedGadget = gadget
            }
        }) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gadget.gadgetName)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? accentColor : Theme.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(gadget.kills) kills")
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func gadgetsInCategory(_ category: GadgetCategory) -> [GadgetStats] {
        let categoryGadgets = viewModel.gadgetStats.filter { matchesCategory($0, category: category) }
        
        if searchText.isEmpty {
            return categoryGadgets.sorted { $0.kills > $1.kills }
        } else {
            return categoryGadgets
                .filter { $0.gadgetName.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.kills > $1.kills }
        }
    }
    
    private func toggleCategory(_ category: GadgetCategory) {
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
            if let gadget = selectedGadget {
                VStack(spacing: 20) {
                    // Gadget Header
                    gadgetHeader(gadget: gadget)
                    
                    // Usage & Efficiency
                    usageAndEfficiency(gadget: gadget)
                    
                    // Combat Performance
                    gadgetCombatStats(gadget: gadget)
                    
                    // Damage Analysis
                    gadgetDamageAnalysis(gadget: gadget)
                    
                    // Complete Stats Table
                    completeStatsTable(gadget: gadget)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("Select a gadget")
                        .font(.title3)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("Choose a gadget from the sidebar to view detailed statistics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func gadgetHeader(gadget: GadgetStats) -> some View {
        HStack(spacing: 16) {
            AsyncGameImage(
                url: URL(string: gadget.image),
                placeholder: Image(systemName: "wrench.and.screwdriver.fill")
            )
            .frame(width: 100, height: 70)
            .background(Theme.overlayColor)
            .cornerRadius(12)
            .id(gadget.gadgetId)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(gadget.gadgetName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                
                Text(gadget.type)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Label("\(gadget.kills)", systemImage: "target")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Label(String(format: "%.2f K/Use", getEfficiency(gadget)), systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Label(String(format: "%.2f KPM", gadget.kpm), systemImage: "timer")
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
    private func matchesCategory(_ gadget: GadgetStats, category: GadgetCategory) -> Bool {
        let type = gadget.type.lowercased()

        switch category {
        case .lethal:
            return type.contains("grenade") || type.contains("explosive") || type.contains("c5") || type.contains("mine")
        case .tactical:
            return type.contains("smoke") || type.contains("flash") || type.contains("emp") || type.contains("stun")
        case .equipment:
            return type.contains("sensor") || type.contains("spawn") || type.contains("ammo") || type.contains("medic") || type.contains("repair")
        case .launcher:
            return type.contains("launcher") || type.contains("rocket") || type.contains("missile")
        }
    }

    // MARK: - Usage & Efficiency

    private func usageAndEfficiency(gadget: GadgetStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage & Efficiency")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 16) {
                // Uses
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title)
                        .foregroundColor(Theme.info)

                    Text("\(gadget.uses)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    Text("Total Uses")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text("\(gadget.spawns) spawns")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)

                // Efficiency
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.title)
                        .foregroundColor(Theme.success)

                    let efficiency = getEfficiency(gadget)
                    Text(String(format: "%.3f", efficiency))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    Text("Kills per Use")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text(getEfficiencyRating(efficiency))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(getEfficiencyColor(efficiency))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(getEfficiencyColor(efficiency).opacity(0.2))
                        .cornerRadius(4)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Combat Stats

    private func gadgetCombatStats(gadget: GadgetStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combat Performance")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                combatStatCard(
                    title: "Kills",
                    value: "\(gadget.kills)",
                    icon: "target",
                    color: .red
                )

                combatStatCard(
                    title: "Multi-Kills",
                    value: "\(gadget.multiKills)",
                    icon: "bolt.fill",
                    color: .orange
                )

                combatStatCard(
                    title: "Assists",
                    value: "\(gadget.assists)",
                    icon: "hand.thumbsup.fill",
                    color: .blue
                )

                combatStatCard(
                    title: "KPM",
                    value: String(format: "%.3f", gadget.kpm),
                    icon: "speedometer",
                    color: .purple
                )

                combatStatCard(
                    title: "Time Used",
                    value: formatPlaytime(gadget.secondsPlayed),
                    icon: "clock.fill",
                    color: .green
                )

                combatStatCard(
                    title: "Vehicles Destroyed",
                    value: "\(gadget.vehiclesDestroyedWith)",
                    icon: "flame.fill",
                    color: .yellow
                )
            }
        }
    }

    private func combatStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
    }

    // MARK: - Damage Analysis

    private func gadgetDamageAnalysis(gadget: GadgetStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Damage Analysis")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 16) {
                // Total Damage
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "burst.fill")
                            .foregroundColor(Theme.error)

                        Text("Total Damage")
                            .font(.subheadline)

                        Spacer()

                        Text(formatNumber(gadget.damage))
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }

                    ProgressView(value: Double(gadget.damage), total: Double(max(gadget.damage, gadget.assistsDamage)))
                        .tint(Theme.error)

                    HStack {
                        Image(systemName: "hand.thumbsup.fill")
                            .foregroundColor(Theme.info)

                        Text("Assist Damage")
                            .font(.subheadline)

                        Spacer()

                        Text(formatNumber(gadget.assistsDamage))
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }

                    ProgressView(value: Double(gadget.assistsDamage), total: Double(max(gadget.damage, gadget.assistsDamage)))
                        .tint(Theme.info)
                }
                .frame(maxWidth: .infinity)

                Divider()

                // DPM
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundColor(Theme.warning)

                    Text(String(format: "%.1f", gadget.dpm))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    Text("Damage per Minute")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Theme.backgroundSecondary)
            .cornerRadius(8)
        }
    }
    
    // MARK: - Complete Stats Table
    
    private func completeStatsTable(gadget: GadgetStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Complete Statistics")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            VStack(spacing: 0) {
                statRow(label: "Kills", value: "\(gadget.kills)")
                statRow(label: "Multi-Kills", value: "\(gadget.multiKills)")
                statRow(label: "Assists", value: "\(gadget.assists)")
                statRow(label: "Uses", value: "\(gadget.uses)")
                statRow(label: "Spawns", value: "\(gadget.spawns)")
                statRow(label: "Damage", value: formatNumber(gadget.damage))
                statRow(label: "Assist Damage", value: formatNumber(gadget.assistsDamage))
                statRow(label: "Vehicles Destroyed", value: "\(gadget.vehiclesDestroyedWith)")
                statRow(label: "Kills per Minute", value: String(format: "%.3f", gadget.kpm))
                statRow(label: "Damage per Minute", value: String(format: "%.1f", gadget.dpm))
                statRow(label: "Efficiency (K/Use)", value: String(format: "%.3f", getEfficiency(gadget)))
                statRow(label: "Time Equipped", value: formatPlaytime(gadget.secondsPlayed))
            }
            .background(Theme.backgroundSecondary)
            .cornerRadius(8)
        }
    }
    
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.backgroundSecondary)
    }

    // MARK: - Helper Functions

    private func getEfficiency(_ gadget: GadgetStats) -> Double {
        guard gadget.uses > 0 else { return 0 }
        return Double(gadget.kills) / Double(gadget.uses)
    }

    private func getEfficiencyRating(_ efficiency: Double) -> String {
        switch efficiency {
        case 1...:
            return "Exceptional"
        case 0.5..<1:
            return "Very Good"
        case 0.25..<0.5:
            return "Good"
        case 0.1..<0.25:
            return "Average"
        default:
            return "Low"
        }
    }

    private func getEfficiencyColor(_ efficiency: Double) -> Color {
        switch efficiency {
        case 1...:
            return .purple
        case 0.5..<1:
            return .green
        case 0.25..<0.5:
            return .blue
        case 0.1..<0.25:
            return .orange
        default:
            return .red
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
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
}

// MARK: - Gadget Categories

enum GadgetCategory: String, CaseIterable, Identifiable {
    case lethal = "Lethal"
    case tactical = "Tactical"
    case equipment = "Equipment"
    case launcher = "Launcher"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue
    }
}


