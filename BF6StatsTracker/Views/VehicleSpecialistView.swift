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
//  VehicleSpecialistView.swift
//  BF6StatsTracker
//
//  Vehicle Specialist Dashboard
//  Shows road kills, damage taken, driver vs passenger performance, distance traveled
//

import SwiftUI

struct VehicleSpecialistView: View {
    @Environment(\.accentColor) private var accentColor
    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var selectedVehicle: VehicleStats?
    @State private var searchText = ""
    @AppStorage("vehicleSpecialist_collapsedCategories") private var collapsedCategoriesData: Data = Data()
    
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
            // Auto-select first vehicle if none selected
            if selectedVehicle == nil, let first = viewModel.vehicleStats.first {
                selectedVehicle = first
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "car.fill")
                        .font(.title3)
                        .foregroundColor(accentColor)
                    
                    Text("Vehicles")
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
            
            // Vehicle List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(VehicleCategory.allCases) { category in
                        categorySection(category: category)
                    }
                }
            }
        }
        .background(Theme.backgroundSecondary)
    }
    
    private func categorySection(category: VehicleCategory) -> some View {
        let vehicles = vehiclesInCategory(category)
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
                    
                    Text("\(vehicles.count)")
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
            
            // Vehicle Items
            if !isCollapsed {
                ForEach(vehicles) { vehicle in
                    vehicleSidebarItem(vehicle: vehicle)
                }
            }
        }
    }
    
    private func vehicleSidebarItem(vehicle: VehicleStats) -> some View {
        let isSelected = selectedVehicle?.vehicleId == vehicle.vehicleId
        
        return Button(action: {
            withAnimation {
                selectedVehicle = vehicle
            }
        }) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.vehicleName)
                        .font(.caption)
                        .foregroundColor(isSelected ? Theme.selectedText : Theme.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(vehicle.kills) kills")
                        .font(.caption2)
                        .foregroundColor(isSelected ? Theme.selectedText.opacity(0.8) : Theme.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundColor(Theme.selectedText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? accentColor : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func vehiclesInCategory(_ category: VehicleCategory) -> [VehicleStats] {
        let vehicles = viewModel.vehicleStats.filter { $0.type == category.rawValue }
        
        if searchText.isEmpty {
            return vehicles.sorted { $0.kills > $1.kills }
        }
        
        return vehicles.filter {
            $0.vehicleName.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.kills > $1.kills }
    }
    
    private func toggleCategory(_ category: VehicleCategory) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsedCategories.contains(category.rawValue) {
                collapsedCategories.remove(category.rawValue)
            } else {
                collapsedCategories.insert(category.rawValue)
            }
            saveCollapsedCategories()
        }
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
            if let vehicle = selectedVehicle {
                VStack(spacing: 20) {
                    // Vehicle Header with Spec Score
                    vehicleHeader(vehicle: vehicle)
                    
                    // Combat Performance
                    combatPerformance(vehicle: vehicle)
                    
                    // Driver vs Passenger Analysis
                    driverVsPassengerAnalysis(vehicle: vehicle)
                    
                    // Efficiency & Distance
                    efficiencyAndDistance(vehicle: vehicle)
                }
                .padding()
            } else {
                emptyDetailView
            }
        }
        .background(Theme.backgroundPrimary)
    }
    
    private func vehicleHeader(vehicle: VehicleStats) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.vehicleName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                
                Text(vehicle.type)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            vehicleSpecScore(vehicle: vehicle)
        }
    }
    
    private func vehicleSpecScore(vehicle: VehicleStats) -> some View {
        let score = calculateVehicleScoreSingle(vehicle: vehicle)
        let rating = getVehicleRating(score: score)
        
        return VStack(spacing: 8) {
            Text("\(Int(score))")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(rating.color)
            
            Text(rating.label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(rating.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(rating.color.opacity(0.2))
                .cornerRadius(8)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }
    
    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Select a Vehicle")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
            
            Text("Choose a vehicle from the sidebar to view detailed statistics")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }







    // MARK: - Combat Performance

    private func combatPerformance(vehicle: VehicleStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combat Performance")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 16) {
                // Kills & Road Kills
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(vehicle.kills)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.error)

                            Text("Total Kills")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(vehicle.roadKills)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.warning)

                            Text("Road Kills")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    if vehicle.kills > 0 {
                        let roadKillPercent = Double(vehicle.roadKills) / Double(vehicle.kills) * 100
                        HStack {
                            Text("\(Int(roadKillPercent))% of kills are road kills")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)

                            Spacer()

                            if roadKillPercent > 20 {
                                Text("Aggressive Driver")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Theme.warning)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Theme.warning.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)

                // Damage Analysis
                VStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Image(systemName: "burst.fill")
                            .font(.title2)
                            .foregroundColor(Theme.error)

                        Text(formatNumber(vehicle.damage))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)

                        Text("Damage Dealt")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Divider()

                    VStack(spacing: 4) {
                        Image(systemName: "shield.slash.fill")
                            .font(.title2)
                            .foregroundColor(Theme.warning)

                        Text(formatNumber(vehicle.damageTo))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)

                        Text("Damage Taken")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    // Survivability rating
                    let survivability = calculateSurvivability(damage: vehicle.damage, damageTaken: vehicle.damageTo)
                    Text(String(format: "%.0f%% Survivability", survivability))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(getSurvivabilityColor(survivability))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(getSurvivabilityColor(survivability).opacity(0.2))
                        .cornerRadius(6)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Driver vs Passenger Analysis

    private func driverVsPassengerAnalysis(vehicle: VehicleStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Role Performance")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 20) {
                // Driver
                VStack(spacing: 8) {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.bf6Purple)

                    Text("\(vehicle.driverAssists)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    Text("Driver Assists")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    let totalAssists = vehicle.driverAssists + vehicle.passengerAssists
                    if totalAssists > 0 {
                        let driverPercent = Double(vehicle.driverAssists) / Double(totalAssists) * 100
                        Text("\(Int(driverPercent))% of assists")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)

                Image(systemName: "arrow.left.and.right")
                    .foregroundColor(Theme.textSecondary)

                // Passenger
                VStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.warning)

                    Text("\(vehicle.passengerAssists)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    Text("Passenger Assists")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    let totalAssists = vehicle.driverAssists + vehicle.passengerAssists
                    if totalAssists > 0 {
                        let passengerPercent = Double(vehicle.passengerAssists) / Double(totalAssists) * 100
                        Text("\(Int(passengerPercent))% of assists")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)
            }

            // Role preference
            let totalAssists = vehicle.driverAssists + vehicle.passengerAssists
            if totalAssists > 0 {
                let driverRatio = Double(vehicle.driverAssists) / Double(totalAssists)
                HStack {
                    Spacer()
                    Text(getRolePreference(driverRatio: driverRatio))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(getRoleColor(driverRatio: driverRatio))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(getRoleColor(driverRatio: driverRatio).opacity(0.2))
                        .cornerRadius(6)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Efficiency & Distance

    private func efficiencyAndDistance(vehicle: VehicleStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Efficiency & Usage")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                efficiencyCard(
                    title: "Distance",
                    value: formatDistance(vehicle.distanceTraveled),
                    icon: "speedometer",
                    color: .blue
                )

                efficiencyCard(
                    title: "KPM",
                    value: String(format: "%.2f", vehicle.killsPerMinute),
                    icon: "bolt.fill",
                    color: .yellow
                )

                efficiencyCard(
                    title: "Time In Vehicle",
                    value: formatPlaytime(vehicle.timeIn),
                    icon: "clock.fill",
                    color: .purple
                )

                efficiencyCard(
                    title: "Spawns",
                    value: "\(vehicle.spawns)",
                    icon: "arrow.uturn.down.circle.fill",
                    color: .green
                )

                efficiencyCard(
                    title: "Vehicles Destroyed",
                    value: "\(vehicle.vehiclesDestroyedWith)",
                    icon: "flame.fill",
                    color: .red
                )

                efficiencyCard(
                    title: "Multi-Kills",
                    value: "\(vehicle.multiKills)",
                    icon: "bolt.fill",
                    color: .orange
                )
            }
        }
    }

    private func efficiencyCard(title: String, value: String, icon: String, color: Color) -> some View {
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
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
    }

    // MARK: - Helper Functions

    private func calculateVehicleScore(vehicles: [VehicleStats]) -> Double {
        let totalKills = Double(vehicles.reduce(0) { $0 + $1.kills })
        let totalRoadKills = Double(vehicles.reduce(0) { $0 + $1.roadKills })
        let totalDamage = Double(vehicles.reduce(0) { $0 + $1.damage })
        let totalDistance = Double(vehicles.reduce(0) { $0 + $1.distanceTraveled }) / 1000.0 // Convert to km

        return (totalKills * 10) + (totalRoadKills * 5) + (totalDamage / 1000) + (totalDistance / 10)
    }
    
    private func calculateVehicleScoreSingle(vehicle: VehicleStats) -> Double {
        let kills = Double(vehicle.kills)
        let roadKills = Double(vehicle.roadKills)
        let damage = Double(vehicle.damage)
        let distance = Double(vehicle.distanceTraveled) / 1000.0 // Convert to km

        return (kills * 10) + (roadKills * 5) + (damage / 1000) + (distance / 10)
    }

    private func getVehicleRating(score: Double) -> (label: String, color: Color) {
        switch score {
        case 10000...:
            return ("Tank Ace", .purple)
        case 5000..<10000:
            return ("Vehicle Expert", .blue)
        case 2000..<5000:
            return ("Mechanized Warrior", .green)
        case 500..<2000:
            return ("Vehicle User", .yellow)
        default:
            return ("Infantry Main", .orange)
        }
    }

    private func calculateSurvivability(damage: Int, damageTaken: Int) -> Double {
        let total = damage + damageTaken
        guard total > 0 else { return 0 }
        return Double(damage) / Double(total) * 100
    }

    private func getSurvivabilityColor(_ survivability: Double) -> Color {
        switch survivability {
        case 70...:
            return .purple
        case 60..<70:
            return .blue
        case 50..<60:
            return .green
        case 40..<50:
            return .yellow
        default:
            return .orange
        }
    }

    private func getRolePreference(driverRatio: Double) -> String {
        switch driverRatio {
        case 0.7...:
            return "Dedicated Driver"
        case 0.5..<0.7:
            return "Balanced Role"
        case 0.3..<0.5:
            return "Flexible"
        default:
            return "Gunner Preference"
        }
    }

    private func getRoleColor(driverRatio: Double) -> Color {
        switch driverRatio {
        case 0.7...:
            return .purple
        case 0.5..<0.7:
            return .blue
        case 0.3..<0.5:
            return .green
        default:
            return .yellow
        }
    }

    private func formatDistance(_ meters: Int) -> String {
        let km = Double(meters) / 1000.0
        if km >= 1 {
            return String(format: "%.1f km", km)
        } else {
            return "\(meters) m"
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

#Preview {
    VehicleSpecialistView()
        .environmentObject(StatsViewModel())
        .frame(width: 1200, height: 900)
}
