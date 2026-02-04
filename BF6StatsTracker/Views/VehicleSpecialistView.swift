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
    @State private var selectedCategory: VehicleCategory?

    private var usesGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "car.fill")
                        .font(.title)
                        .foregroundColor(accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vehicle Specialist Dashboard")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)

                        Text("Master of mechanized warfare")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    if !viewModel.vehicleStats.isEmpty {
                        vehicleSpecScore(vehicles: viewModel.vehicleStats)
                    }
                }

                if !viewModel.vehicleStats.isEmpty {
                    // Overall Vehicle Stats
                    overallVehicleStats(vehicles: viewModel.vehicleStats)

                    // Category Filter
                    categoryFilterView

                    // Vehicles Grid
                    vehiclesGridView(vehicles: filteredVehicles)

                    // Detailed Stats for Selected Vehicle
                    if let vehicle = selectedVehicle {
                        vehicleDetailView(vehicle: vehicle)
                    }
                } else {
                    Text("No vehicle stats available")
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding()
        }
    }

    // MARK: - Vehicle Specialist Score

    private func vehicleSpecScore(vehicles: [VehicleStats]) -> some View {
        let score = calculateVehicleScore(vehicles: vehicles)
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

    // MARK: - Overall Vehicle Stats

    private func overallVehicleStats(vehicles: [VehicleStats]) -> some View {
        let totalKills = vehicles.reduce(0) { $0 + $1.kills }
        let totalRoadKills = vehicles.reduce(0) { $0 + $1.roadKills }
        let totalDamage = vehicles.reduce(0) { $0 + $1.damage }
        let totalDamageTaken = vehicles.reduce(0) { $0 + $1.damageTo }
        let totalDistance = vehicles.reduce(0) { $0 + $1.distanceTraveled }
        let totalDriverAssists = vehicles.reduce(0) { $0 + $1.driverAssists }
        let totalPassengerAssists = vehicles.reduce(0) { $0 + $1.passengerAssists }

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            quickStatCard(
                title: "Total Kills",
                value: "\(totalKills)",
                icon: "target",
                color: .red
            )

            quickStatCard(
                title: "Road Kills",
                value: "\(totalRoadKills)",
                icon: "figure.run",
                color: .orange
            )

            quickStatCard(
                title: "Distance",
                value: formatDistance(totalDistance),
                icon: "speedometer",
                color: .blue
            )

            quickStatCard(
                title: "Survivability",
                value: String(format: "%.1f%%", calculateSurvivability(damage: totalDamage, damageTaken: totalDamageTaken)),
                icon: "shield.fill",
                color: .green
            )

            quickStatCard(
                title: "Driver Assists",
                value: "\(totalDriverAssists)",
                icon: "steeringwheel",
                color: .purple
            )

            quickStatCard(
                title: "Passenger Assists",
                value: "\(totalPassengerAssists)",
                icon: "person.2.fill",
                color: .yellow
            )

            quickStatCard(
                title: "Vehicles Destroyed",
                value: "\(vehicles.reduce(0) { $0 + $1.vehiclesDestroyedWith })",
                icon: "flame.fill",
                color: .red
            )

            quickStatCard(
                title: "Total Damage",
                value: formatNumber(totalDamage),
                icon: "burst.fill",
                color: .orange
            )
        }
    }

    private func quickStatCard(title: String, value: String, icon: String, color: Color) -> some View {
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
                .multilineTextAlignment(.center)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(8)
    }

    // MARK: - Category Filter

    private var categoryFilterView: some View {
        GlassContainerWrapper(usesGlass: usesGlass) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    categoryButton(category: nil, label: "All Vehicles")

                    ForEach(VehicleCategory.allCases) { category in
                        categoryButton(category: category, label: category.rawValue)
                    }
                }
            }
        }
    }

    private func categoryButton(category: VehicleCategory?, label: String) -> some View {
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

    // MARK: - Filtered Vehicles

    private var filteredVehicles: [VehicleStats] {
        let vehicles = viewModel.vehicleStats

        // Debug: Print all vehicle types
        if selectedCategory != nil {
            logInfo("All vehicle types available:", category: .general)
            for vehicle in vehicles {
                logInfo("  - \(vehicle.vehicleName): '\(vehicle.type)'", category: .general)
            }
        }

        let filtered = selectedCategory == nil
            ? vehicles
            : vehicles.filter { matchesCategory($0, category: selectedCategory!) }

        logSuccess("Filtered \(filtered.count) vehicles for category: \(selectedCategory?.rawValue ?? "All")", category: .success)

        return filtered.sorted { $0.kills > $1.kills }
    }

    /// Match vehicle to category using exact API type
    private func matchesCategory(_ vehicle: VehicleStats, category: VehicleCategory) -> Bool {
        return vehicle.type == category.rawValue
    }

    // MARK: - Vehicles Grid

    private func vehiclesGridView(vehicles: [VehicleStats]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(vehicles) { vehicle in
                vehicleCard(vehicle: vehicle)
            }
        }
    }

    private func vehicleCard(vehicle: VehicleStats) -> some View {
        Button {
            withAnimation {
                selectedVehicle = vehicle
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(vehicle.vehicleName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if selectedVehicle?.vehicleId == vehicle.vehicleId {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.success)
                    }
                }

                Text(vehicle.type)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(vehicle.kills)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(accentColor)

                        Text("kills")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatDistance(vehicle.distanceTraveled))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.info)

                        Text("distance")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding()
            .background(selectedVehicle?.vehicleId == vehicle.vehicleId ? accentColor.opacity(0.2) : Theme.overlayColor)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vehicle Detail View

    private func vehicleDetailView(vehicle: VehicleStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
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

                Button {
                    withAnimation {
                        selectedVehicle = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Combat Performance
            combatPerformance(vehicle: vehicle)

            // Driver vs Passenger Analysis
            driverVsPassengerAnalysis(vehicle: vehicle)

            // Efficiency & Distance
            efficiencyAndDistance(vehicle: vehicle)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
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
