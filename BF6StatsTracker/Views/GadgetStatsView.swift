//
//  GadgetStatsView.swift
//  BF6StatsTracker
//
//  Displays all gadget statistics for the player
//

import SwiftUI

struct GadgetStatsView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var selectedClass: BF6Class?
    @State private var sortOption: GadgetSortOption = .kills
    @State private var searchText = ""
    
    private var filteredGadgets: [GadgetStats] {
        var gadgets = viewModel.gadgetStats
        
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
    
    // MARK: - Class Filter View
    
    private var classFilterView: some View {
        HStack(spacing: 12) {
            ClassFilterButton(
                title: "All Classes",
                icon: "square.grid.2x2.fill",
                isSelected: selectedClass == nil,
                color: Theme.bf6Orange
            ) {
                selectedClass = nil
            }
            
            ForEach(BF6Class.allCases) { bf6Class in
                ClassFilterButton(
                    title: bf6Class.rawValue,
                    icon: bf6Class.iconName,
                    isSelected: selectedClass == bf6Class,
                    color: bf6Class.color
                ) {
                    selectedClass = bf6Class
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
                ForEach(filteredGadgets, id: \.gadgetName) { gadget in
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

// MARK: - Class Filter Button

struct ClassFilterButton: View {
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Gadget Image
                AsyncGameImage(
                    url: URL(string: gadget.image),
                    placeholder: Image(systemName: "wrench.fill")
                )
                .frame(width: 60, height: 60)
                .background(Theme.overlayColor)
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(gadget.gadgetName)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(gadget.type)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                // Primary Stat
                VStack(alignment: .trailing, spacing: 2) {
                    if gadget.kills > 0 {
                        Text("\(gadget.kills)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                        Text("kills")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        Text("\(gadget.uses)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        Text("uses")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 12)
            
            // Stats Grid
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
                    value: gadget.damageDealt.formatted(.number.notation(.compactName)),
                    color: Theme.bf6Orange
                )
                
                GadgetStatItem(
                    icon: "car.fill",
                    label: "Vehicles",
                    value: "\(gadget.vehiclesDestroyed)",
                    color: Theme.bf6Green
                )
            }
            
            // Expand Button
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
            
            // Expanded Details
            if isExpanded {
                Divider()
                    .padding(.vertical, 8)
                
                VStack(spacing: 8) {
                    DetailRow(label: "Spawns from Gadget", value: "\(gadget.spawns)")
                    DetailRow(label: "Time Used", value: formatTime(gadget.timePlayed))
                    DetailRow(label: "Efficiency", value: calculateEfficiency())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.overlayColor, lineWidth: 1)
        )
    }
    
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
