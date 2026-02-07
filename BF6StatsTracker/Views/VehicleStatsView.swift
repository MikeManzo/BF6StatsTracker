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
//  VehicleStatsView.swift
//  BF6StatsTracker
//
//  Displays all vehicle statistics for the player
//

import SwiftUI

struct VehicleStatsView: View {
    @Environment(\.accentColor) private var accentColor
    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var selectedCategory: VehicleCategory?
    @State private var sortOption: VehicleSortOption = .kills
    @State private var searchText = ""

    private var usesGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }
    
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
                        color: accentColor
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
        GlassContainerWrapper(usesGlass: usesGlass) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    VehicleCategoryPill(
                        title: "All",
                        icon: "square.grid.2x2.fill",
                        isSelected: selectedCategory == nil,
                        color: accentColor
                    ) {
                        selectedCategory = nil
                    }
                    .id("all")

                    ForEach(VehicleCategory.allCases) { category in
                        VehicleCategoryPill(
                            title: category.rawValue,
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
        category.color
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
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? Theme.selectedText : Theme.textSecondary)
            .padding(.horizontal, 12)
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

// MARK: - Vehicle Card

struct VehicleCard: View {
    let vehicle: VehicleStats
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with vehicle info and primary metric
            cardHeader
                .padding(16)
            
            // Separator
            Divider()
                .background(Theme.borderColor.opacity(0.3))
            
            // Key performance metrics
            mainStatsSection
                .padding(16)
            
            // Additional details footer
            Divider()
                .background(Theme.borderColor.opacity(0.3))
            
            additionalStatsFooter
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(cardBackgroundView)
        .overlay(cardBorderView)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
    
    // MARK: - Subviews
    
    private var cardHeader: some View {
        HStack(spacing: 12) {
            vehicleImageView
            
            VStack(alignment: .leading, spacing: 3) {
                Text(vehicle.vehicleName)
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                
                Label(vehicle.type, systemImage: vehicleIcon)
                    .font(.system(.caption, design: .default))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            primaryStatView
        }
    }
    
    private var vehicleImageView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(vehicleGradient)
            
            AsyncGameImage(
                url: URL(string: vehicle.image),
                placeholder: Image(systemName: vehicleIcon)
            )
            .frame(width: 70, height: 56)
        }
        .frame(width: 80, height: 56)
    }
    
    private var vehicleGradient: LinearGradient {
        LinearGradient(
            colors: [vehicleColor.opacity(0.3), vehicleColor.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var primaryStatView: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(vehicle.kills)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Theme.bf6Red)
            
            Text("KILLS")
                .font(.system(.caption2, design: .default, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .tracking(0.5)
        }
    }
    
    private var mainStatsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VehicleMetricCard(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "K/D Ratio",
                    value: String(format: "%.2f", vehicle.kdRatio),
                    color: kdColor
                )
                
                VehicleMetricCard(
                    icon: "flame.fill",
                    label: "Destroyed",
                    value: "\(vehicle.destroyed)",
                    color: .orange
                )
            }
            
            HStack(spacing: 12) {
                VehicleMetricCard(
                    icon: "speedometer",
                    label: "KPM",
                    value: String(format: "%.2f", vehicle.killsPerMinute),
                    color: Theme.bf6Red
                )
                
                VehicleMetricCard(
                    icon: "clock",
                    label: "Time Played",
                    value: formatTime(vehicle.timePlayed),
                    color: Theme.bf6Blue
                )
            }
        }
    }
    
    private var additionalStatsFooter: some View {
        HStack(spacing: 0) {
            VehicleFooterStat(label: "Deaths", value: "\(vehicle.deaths)")
            
            Divider()
                .frame(height: 24)
                .background(Theme.borderColor.opacity(0.3))
            
            VehicleFooterStat(label: "Roadkills", value: "\(vehicle.roadKills)")
            
            Divider()
                .frame(height: 24)
                .background(Theme.borderColor.opacity(0.3))
            
            VehicleFooterStat(label: "Driver Assists", value: "\(vehicle.driverAssists)")
            
            Divider()
                .frame(height: 24)
                .background(Theme.borderColor.opacity(0.3))
            
            VehicleFooterStat(label: "Distance", value: formatDistance(Double(vehicle.distanceTraveled)))
        }
    }
    
    private var cardBackgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Theme.cardBackground)
    }
    
    private var cardBorderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Theme.borderColor.opacity(0.5), lineWidth: 1)
    }
    
    private var kdColor: Color {
        vehicle.kdRatio >= 1 ? .green : .orange
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

// MARK: - Vehicle Metric Card Component

struct VehicleMetricCard: View {
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

// MARK: - Vehicle Footer Stat Component

struct VehicleFooterStat: View {
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
