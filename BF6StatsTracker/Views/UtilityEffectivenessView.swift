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
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var selectedGadget: GadgetStats?
    @State private var sortBy: GadgetSortOption = .kills

    enum GadgetSortOption: String, CaseIterable {
        case kills = "Kills"
        case efficiency = "Efficiency"
        case uses = "Uses"
        case damage = "Damage"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title)
                    .foregroundColor(Theme.bf6Blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Utility & Gadget Effectiveness")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    Text("Tactical equipment performance analysis")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()
            }

            if let stats = viewModel.playerStats {
                // Overall Utility Stats
                overallUtilityStats(stats: stats)

                // Gadgets Section
                if let gadgets = stats.gadgets, !gadgets.isEmpty {
                    gadgetsSection(gadgets: gadgets)

                    if let selected = selectedGadget {
                        gadgetDetailView(gadget: selected)
                    }
                }
            } else {
                Text("No utility stats available")
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding()
    }

    // MARK: - Overall Utility Stats

    private func overallUtilityStats(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tactical Utility Performance")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                utilityStatCard(
                    title: "Throwables Used",
                    value: "\(stats.thrownThrowables)",
                    icon: "circlebadge.fill",
                    color: .red,
                    description: "Grenades & equipment thrown"
                )

                utilityStatCard(
                    title: "Gadgets Destroyed",
                    value: "\(stats.gadgetsDestoyed)",
                    icon: "xmark.circle.fill",
                    color: .orange,
                    description: "Enemy gadgets destroyed"
                )

                utilityStatCard(
                    title: "Takedowns",
                    value: "\(stats.playerTakeDowns)",
                    icon: "figure.martial.arts",
                    color: .purple,
                    description: "Player takedowns"
                )

                utilityStatCard(
                    title: "Throwables/Match",
                    value: String(format: "%.1f", Double(stats.thrownThrowables) / Double(max(stats.matchesPlayed, 1))),
                    icon: "chart.bar.fill",
                    color: .blue,
                    description: "Average per match"
                )
            }

            // Utility Effectiveness Rating
            utilityEffectivenessRating(stats: stats)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    private func utilityStatCard(title: String, value: String, icon: String, color: Color, description: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
    }

    private func utilityEffectivenessRating(stats: PlayerStats) -> some View {
        let rating = calculateUtilityRating(stats: stats)

        return VStack(spacing: 8) {
            HStack {
                Text("Utility Effectiveness")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text(rating.label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(rating.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(rating.color.opacity(0.2))
                    .cornerRadius(6)
            }

            ProgressView(value: rating.score, total: 100)
                .tint(rating.color)
        }
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
    }

    // MARK: - Gadgets Section

    private func gadgetsSection(gadgets: [GadgetStats]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Gadget Performance")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                // Sort picker
                Menu {
                    ForEach(GadgetSortOption.allCases, id: \.self) { option in
                        Button {
                            sortBy = option
                        } label: {
                            HStack {
                                Text("Sort by \(option.rawValue)")
                                if sortBy == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sortBy.rawValue)
                            .font(.caption)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption2)
                    }
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.overlayColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(sortedGadgets(gadgets)) { gadget in
                    gadgetCard(gadget: gadget)
                }
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    private func sortedGadgets(_ gadgets: [GadgetStats]) -> [GadgetStats] {
        switch sortBy {
        case .kills:
            return gadgets.sorted { $0.kills > $1.kills }
        case .efficiency:
            return gadgets.sorted { getEfficiency($0) > getEfficiency($1) }
        case .uses:
            return gadgets.sorted { $0.uses > $1.uses }
        case .damage:
            return gadgets.sorted { $0.damage > $1.damage }
        }
    }

    private func getEfficiency(_ gadget: GadgetStats) -> Double {
        guard gadget.uses > 0 else { return 0 }
        return Double(gadget.kills) / Double(gadget.uses)
    }

    private func gadgetCard(gadget: GadgetStats) -> some View {
        Button {
            withAnimation {
                selectedGadget = gadget
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(gadget.gadgetName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    if selectedGadget?.gadgetId == gadget.gadgetId {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.success)
                    }
                }

                Text(gadget.type)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(gadget.kills)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.bf6Orange)

                        Text("kills")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f", getEfficiency(gadget)))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(getEfficiencyColor(getEfficiency(gadget)))

                        Text("K/Use")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding()
            .background(selectedGadget?.gadgetId == gadget.gadgetId ? Theme.bf6Blue.opacity(0.2) : Theme.backgroundSecondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gadget Detail View

    private func gadgetDetailView(gadget: GadgetStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(gadget.gadgetName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    Text(gadget.type)
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation {
                        selectedGadget = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Usage & Efficiency
            usageAndEfficiency(gadget: gadget)

            // Combat Stats
            gadgetCombatStats(gadget: gadget)

            // Damage Analysis
            gadgetDamageAnalysis(gadget: gadget)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
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

    // MARK: - Helper Functions

    private func calculateUtilityRating(stats: PlayerStats) -> (score: Double, label: String, color: Color) {
        let throwablesScore = Double(stats.thrownThrowables) * 2
        let gadgetsDestroyedScore = Double(stats.gadgetsDestoyed) * 5
        let takedownsScore = Double(stats.playerTakeDowns) * 10

        let totalScore = throwablesScore + gadgetsDestroyedScore + takedownsScore
        let matchCount = Double(max(stats.matchesPlayed, 1))
        let scorePerMatch = totalScore / matchCount

        let normalizedScore = min(scorePerMatch / 5.0, 100.0) // Normalize to 0-100

        switch normalizedScore {
        case 75...:
            return (normalizedScore, "Elite Tactician", .purple)
        case 50..<75:
            return (normalizedScore, "Expert", .blue)
        case 30..<50:
            return (normalizedScore, "Proficient", .green)
        case 15..<30:
            return (normalizedScore, "Competent", .yellow)
        default:
            return (normalizedScore, "Developing", .orange)
        }
    }

    private func getEfficiencyColor(_ efficiency: Double) -> Color {
        switch efficiency {
        case 0.5...:
            return .purple
        case 0.3..<0.5:
            return .blue
        case 0.15..<0.3:
            return .green
        case 0.05..<0.15:
            return .yellow
        default:
            return .orange
        }
    }

    private func getEfficiencyRating(_ efficiency: Double) -> String {
        switch efficiency {
        case 0.5...:
            return "Exceptional"
        case 0.3..<0.5:
            return "Excellent"
        case 0.15..<0.3:
            return "Good"
        case 0.05..<0.15:
            return "Average"
        default:
            return "Low"
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
    UtilityEffectivenessView()
        .environmentObject(StatsViewModel())
        .frame(width: 1200, height: 900)
}
