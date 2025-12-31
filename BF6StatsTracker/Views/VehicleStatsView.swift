//
//  VehicleStatsView.swift
//  BF6StatsTracker
//
//  Displays all vehicle statistics for the player
//

import SwiftUI

struct VehicleStatsView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var selectedCategory: VehicleCategory?
    @State private var sortOption: VehicleSortOption = .kills
    @State private var searchText = ""
    
    private var filteredVehicles: [VehicleStats] {
        var vehicles = viewModel.vehicleStats
        
        // Filter by category
        if let category = selectedCategory {
            vehicles = viewModel.vehiclesByCategory[category] ?? []
        }
        
        // Filter by search
        if !searchText.isEmpty {
            vehicles = vehicles.filter { $0.vehicleName.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Sort
        switch sortOption {
        case .kills:
            vehicles.sort { $0.kills > $1.kills }
        case .destroyed:
            vehicles.sort { $0.destroyed > $1.destroyed }
        case .time:
            vehicles.sort { $0.timePlayed > $1.timePlayed }
        case .kpm:
            vehicles.sort { $0.killsPerMinute > $1.killsPerMinute }
        case .name:
            vehicles.sort { $0.vehicleName < $1.vehicleName }
        }
        
        return vehicles
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView
            
            // Category Pills
            categoryPills
            
            // Vehicles Content
            if filteredVehicles.isEmpty {
                emptyStateView
            } else {
                vehiclesGrid
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
                
                TextField("Search vehicles...", text: $searchText)
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
            
            // Total Stats Summary
            if !viewModel.vehicleStats.isEmpty {
                HStack(spacing: 16) {
                    SummaryBadge(
                        icon: "target",
                        value: viewModel.vehicleStats.reduce(0) { $0 + $1.kills }.formatted(),
                        label: "Total Kills",
                        color: Theme.bf6Red
                    )
                    
                    SummaryBadge(
                        icon: "flame.fill",
                        value: viewModel.vehicleStats.reduce(0) { $0 + $1.destroyed }.formatted(),
                        label: "Destroyed",
                        color: Theme.bf6Orange
                    )
                }
            }
            
            // Sort
            HStack(spacing: 8) {
                Text("Sort:")
                    .foregroundColor(Theme.textSecondary)
                
                Picker("Sort", selection: $sortOption) {
                    ForEach(VehicleSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
        }
    }
    
    // MARK: - Category Pills
    
    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                VehicleCategoryPill(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    color: Theme.bf6Orange
                ) {
                    selectedCategory = nil
                }
                
                ForEach(VehicleCategory.allCases) { category in
                    VehicleCategoryPill(
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
    
    // MARK: - Vehicles Grid
    
    private var vehiclesGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 380, maximum: 500), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredVehicles) { vehicle in
                    VehicleCard(vehicle: vehicle)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Empty State

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "car.fill",
            title: "No Vehicles Found",
            message: (!searchText.isEmpty || selectedCategory != nil)
                ? "Try adjusting your search or filters"
                : "Vehicle data will appear after using vehicles in matches"
        )
    }
    
    // MARK: - Helpers
    
    private func categoryColor(for category: VehicleCategory) -> Color {
        switch category {
        case .mainBattleTank: return Theme.textSecondary
        case .lightArmor: return .green
        case .antiAircraft: return .blue
        case .attackHelicopter: return .red
        case .transportHelicopter: return .teal
        case .jet: return .purple
        case .transportVehicle: return .orange
        case .watercraft: return .cyan
        }
    }
}

// MARK: - Summary Badge

struct SummaryBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Vehicle Category Pill

struct VehicleCategoryPill: View {
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
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? Theme.selectedText : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Theme.overlayColor)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vehicle Card

struct VehicleCard: View {
    let vehicle: VehicleStats
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Image
            HStack(spacing: 16) {
                // Vehicle Image
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [vehicleColor.opacity(0.3), vehicleColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    AsyncGameImage(
                        url: URL(string: vehicle.image),
                        placeholder: Image(systemName: vehicleIcon)
                    )
                    .frame(width: 60, height: 60)
                }
                .frame(width: 80, height: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.vehicleName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Label(vehicle.type, systemImage: vehicleIcon)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Primary Stat
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(vehicle.kills)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                    
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
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                VehicleStatItem(
                    icon: "xmark.circle",
                    label: "Deaths",
                    value: "\(vehicle.deaths)",
                    color: Theme.textSecondary
                )
                
                VehicleStatItem(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "K/D",
                    value: String(format: "%.2f", vehicle.kdRatio),
                    color: vehicle.kdRatio >= 1 ? .green : .orange
                )
                
                VehicleStatItem(
                    icon: "flame.fill",
                    label: "Destroyed",
                    value: "\(vehicle.destroyed)",
                    color: Theme.bf6Orange
                )
                
                VehicleStatItem(
                    icon: "clock.fill",
                    label: "Time",
                    value: formatTime(vehicle.timePlayed),
                    color: Theme.bf6Blue
                )
            }
            
            // Additional Stats on Hover
            if isHovered {
                Divider()
                    .padding(.vertical, 8)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    VehicleStatItem(
                        icon: "speedometer",
                        label: "KPM",
                        value: String(format: "%.2f", vehicle.killsPerMinute),
                        color: Theme.bf6Red
                    )
                    
                    VehicleStatItem(
                        icon: "figure.walk",
                        label: "Roadkills",
                        value: "\(vehicle.roadKills)",
                        color: Theme.bf6Purple
                    )
                    
                    VehicleStatItem(
                        icon: "person.2.fill",
                        label: "Driver Assists",
                        value: "\(vehicle.driverAssists)",
                        color: .teal
                    )
                    
                    VehicleStatItem(
                        icon: "arrow.left.arrow.right",
                        label: "Distance",
                        value: formatDistance(Double(vehicle.distanceTraveled)),
                        color: .cyan
                    )
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
                .stroke(
                    LinearGradient(
                        colors: [vehicleColor.opacity(isHovered ? 0.5 : 0.2), vehicleColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHovered ? 2 : 1
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var vehicleIcon: String {
        switch vehicle.type.lowercased() {
        case let t where t.contains("tank"): return "shield.fill"
        case let t where t.contains("heli"): return "xmark"
        case let t where t.contains("jet") || t.contains("air"): return "airplane"
        case let t where t.contains("boat") || t.contains("water"): return "ferry.fill"
        default: return "car.fill"
        }
    }
    
    private var vehicleColor: Color {
        switch vehicle.type.lowercased() {
        case let t where t.contains("tank"): return Theme.textSecondary
        case let t where t.contains("attack") && t.contains("heli"): return .red
        case let t where t.contains("transport") && t.contains("heli"): return .teal
        case let t where t.contains("jet"): return .purple
        case let t where t.contains("aa") || t.contains("anti"): return .blue
        default: return .green
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        }
        return String(format: "%.0fm", meters)
    }
}

// MARK: - Vehicle Stat Item

struct VehicleStatItem: View {
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
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Sort Options

enum VehicleSortOption: String, CaseIterable, Identifiable {
    case kills = "Kills"
    case destroyed = "Destroyed"
    case time = "Time"
    case kpm = "KPM"
    case name = "Name"
    
    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    VehicleStatsView()
        .environmentObject(StatsViewModel())
        .frame(width: 1000, height: 700)
        .background(Theme.backgroundPrimary)
}
