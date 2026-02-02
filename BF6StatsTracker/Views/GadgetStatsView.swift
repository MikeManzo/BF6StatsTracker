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
//  GadgetStatsView.swift
//  BF6StatsTracker
//
//  Displays all gadget statistics for the player
//

import SwiftUI

struct GadgetStatsView: View {
    @Environment(\.accentColor) private var accentColor
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var selectedGadgetType: GadgetType?
    @State private var sortOption: GadgetSortOption = .kills
    @State private var searchText = ""

    private var filteredGadgets: [GadgetStats] {
        var gadgets = viewModel.gadgetStats

        // Filter by gadget type
        if let selectedGadgetType = selectedGadgetType {
            gadgets = gadgets.filter { selectedGadgetType.matches($0) }
        }

        // Filter by search
        if !searchText.isEmpty {
            gadgets = gadgets.filter { $0.gadgetName.localizedCaseInsensitiveContains(searchText) }
        }

        // Sort
        switch sortOption {
        case .kills:
            gadgets.sort { $0.kills > $1.kills }
        case .uses:
            gadgets.sort { $0.uses > $1.uses }
        case .damage:
            gadgets.sort { $0.damageDealt > $1.damageDealt }
        case .vehicles:
            gadgets.sort { $0.vehiclesDestroyed > $1.vehiclesDestroyed }
        case .name:
            gadgets.sort { $0.gadgetName < $1.gadgetName }
        }

        return gadgets
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView
            
            // Class Filter
            classFilterView
            
            // Gadgets Content
            if filteredGadgets.isEmpty {
                emptyStateView
            } else {
                gadgetsList
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textSecondary)
                
                TextField("Search gadgets...", text: $searchText)
                    .textFieldStyle(.plain)
                
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
            
            // Sort
            HStack(spacing: 8) {
                Text("Sort by:")
                    .foregroundColor(Theme.textSecondary)
                
                Picker("Sort", selection: $sortOption) {
                    ForEach(GadgetSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
            }
            
            // Count
            Text("\(filteredGadgets.count) gadgets")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(6)
        }
    }
    
    // MARK: - Gadget Type Filter View

    private var classFilterView: some View {
        HStack(spacing: 12) {
            GadgetTypeFilterButton(
                title: "All Types",
                icon: "square.grid.2x2.fill",
                isSelected: selectedGadgetType == nil,
                color: accentColor
            ) {
                selectedGadgetType = nil
            }

            ForEach(GadgetType.allCases) { gadgetType in
                GadgetTypeFilterButton(
                    title: gadgetType.displayName,
                    icon: gadgetType.iconName,
                    isSelected: selectedGadgetType == gadgetType,
                    color: gadgetType.color
                ) {
                    selectedGadgetType = gadgetType
                }
            }
        }
    }
    
    // MARK: - Gadgets List
    
    private var gadgetsList: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 350, maximum: 450), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredGadgets) { gadget in
                    GadgetCard(gadget: gadget)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Empty State

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "wrench.and.screwdriver.fill",
            title: "No Gadgets Found",
            message: "Gadget data will appear after using gadgets in matches"
        )
    }
}

// MARK: - Gadget Type Filter Button

struct GadgetTypeFilterButton: View {
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

// MARK: - Gadget Card

struct GadgetCard: View {
    let gadget: GadgetStats
    @State private var isExpanded = false
    @Environment(\.accentColor) private var accentColor
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            Divider()
                .padding(.vertical, 12)
            
            statsGrid
            
            expandButton
            
            if isExpanded {
                expandedDetails
            }
        }
        .padding()
        .background(cardBackground)
        .overlay(cardBorder)
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            gadgetImage
            gadgetInfo
            Spacer()
            primaryStat
        }
    }
    
    private var gadgetImage: some View {
        AsyncGameImage(
            url: URL(string: gadget.image),
            placeholder: Image(systemName: placeholderIcon)
        )
        .frame(width: 60, height: 60)
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    /// Returns an appropriate SF Symbol based on gadget ID for gadgets without images
    private var placeholderIcon: String {
        switch gadget.gadgetId {
        // Repair & Support
        case "repair": return "wrench.and.screwdriver.fill"
        case "sup_bag", "vehsupcra": return "shippingbox.fill"
        case "adren": return "syringe.fill"

        // Recon & Sensors
        case "recondrone": return "airplane"
        case "laserdes": return "scope"
        case "tugs", "msensor": return "sensor.fill"
        case "decoy": return "person.fill.questionmark"

        // Deployables
        case "ladder": return "ladder.fill"
        case "deplocover", "deployable": return "shield.fill"
        case "deploymortar": return "burst.fill"
        case "deploybeacon": return "antenna.radiowaves.left.and.right"

        // Explosives & Mines
        case "mine_ap", "mine_tws", "mine_mosen": return "exclamationmark.triangle.fill"
        case "eodbot": return "ant.fill"

        // Launchers
        case "rl_longra", "rl_surtoair": return "arrow.up.right.circle.fill"
        case "il_airburst": return "cloud.bolt.fill"

        // Grenade Launchers
        case "gl_breach", "gl_smoke": return "circle.circle.fill"

        // Throwables
        case "tknife": return "scissors"
        case "gren_stun", "gren_flash": return "bolt.circle.fill"
        case "gren_smoke": return "smoke.fill"
        case "gren_mfrag": return "circle.fill"

        default: return "wrench.fill"
        }
    }
    
    private var gadgetInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(gadget.gadgetName)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(gadget.type)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }
    
    private var primaryStat: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if gadget.kills > 0 {
                Text("\(gadget.kills)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.error)
                Text("kills")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            } else {
                Text("\(gadget.uses)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.info)
                Text("uses")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            GadgetStatItem(
                icon: "target",
                label: "Kills",
                value: "\(gadget.kills)",
                color: Theme.bf6Red
            )
            
            GadgetStatItem(
                icon: "hand.tap.fill",
                label: "Uses",
                value: "\(gadget.uses)",
                color: Theme.bf6Blue
            )
            
            GadgetStatItem(
                icon: "flame.fill",
                label: "Damage",
                value: damageValue,
                color: accentColor
            )
            
            GadgetStatItem(
                icon: "car.fill",
                label: "Vehicles",
                value: "\(gadget.vehiclesDestroyed)",
                color: Theme.bf6Green
            )
        }
    }
    
    private var damageValue: String {
        gadget.damageDealt.formatted(.number.notation(.compactName))
    }
    
    private var expandButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }
    
    private var expandedDetails: some View {
        Group {
            Divider()
                .padding(.vertical, 8)
            
            VStack(spacing: 8) {
                DetailRow(label: "Spawns from Gadget", value: "\(gadget.spawns)")
                DetailRow(label: "Time Used", value: formatTime(gadget.timePlayed))
                DetailRow(label: "Efficiency", value: calculateEfficiency())
            }
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Theme.cardBackground)
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Theme.overlayColor, lineWidth: 1)
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func calculateEfficiency() -> String {
        guard gadget.uses > 0 else { return "N/A" }
        let killsPerUse = Double(gadget.kills) / Double(gadget.uses)
        return String(format: "%.2f kills/use", killsPerUse)
    }
}

// MARK: - Gadget Stat Item

struct GadgetStatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Gadget Type Enum

enum GadgetType: String, CaseIterable, Identifiable {
    case equipment = ""                      // 28 gadgets - no type in API
    case deployable = "Deployable Gadgets"   // 2 gadgets
    case explosives = "Explosives"           // 2 gadgets
    case grenade = "Grenade"                 // 2 gadgets
    case grenadeLaunchers = "Grenade Launchers"  // 2 gadgets
    case launchers = "Launchers"             // 2 gadgets
    case strikePackages = "Strike Packages"  // 1 gadget

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .equipment: return "Equipment"
        case .deployable: return "Deployable"
        case .explosives: return "Explosives"
        case .grenade: return "Grenades"
        case .grenadeLaunchers: return "GL"
        case .launchers: return "Launchers"
        case .strikePackages: return "Strikes"
        }
    }

    var iconName: String {
        switch self {
        case .equipment: return "wrench.and.screwdriver.fill"
        case .deployable: return "cube.box.fill"
        case .explosives: return "flame.fill"
        case .grenade: return "circle.fill"
        case .grenadeLaunchers: return "scope"
        case .launchers: return "arrow.up.right"
        case .strikePackages: return "airplane"
        }
    }

    var color: Color {
        switch self {
        case .equipment: return Theme.bf6Orange
        case .deployable: return Theme.bf6Green
        case .explosives: return Theme.bf6Red
        case .grenade: return Theme.warning
        case .grenadeLaunchers: return Theme.info
        case .launchers: return Theme.bf6Blue
        case .strikePackages: return Theme.success
        }
    }

    /// Determines if a gadget matches this category
    /// Uses smart matching to handle API inconsistencies (e.g., grenades with empty type)
    func matches(_ gadget: GadgetStats) -> Bool {
        // First check exact type match
        if gadget.type == self.rawValue {
            return true
        }

        // Smart matching for categories where API is inconsistent
        switch self {
        case .grenade:
            // Include gadgets with "Grenade" in name (Stun, Smoke, Flash, Mini grenades have empty type)
            return gadget.gadgetName.localizedCaseInsensitiveContains("Grenade")
        case .equipment:
            // Equipment is empty type, but exclude items that belong to other smart-matched categories
            if gadget.type.isEmpty {
                // Exclude grenades (they belong in .grenade category)
                return !gadget.gadgetName.localizedCaseInsensitiveContains("Grenade")
            }
            return false
        default:
            return false
        }
    }
}

// MARK: - Sort Options

enum GadgetSortOption: String, CaseIterable, Identifiable {
    case kills = "Kills"
    case uses = "Uses"
    case damage = "Damage"
    case vehicles = "Vehicles Destroyed"
    case name = "Name"

    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    GadgetStatsView()
        .environmentObject(StatsViewModel())
        .frame(width: 1000, height: 700)
        .background(Theme.backgroundPrimary)
}
