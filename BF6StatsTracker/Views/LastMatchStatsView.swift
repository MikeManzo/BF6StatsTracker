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
//  LastMatchStatsView.swift
//  BF6StatsTracker
//
//  Displays statistics from the player's last/current match
//

import SwiftUI

struct LastMatchStatsView: View {
    let lastMatch: LastMatchStats
    let lastUpdated: Date?
    let progressionMode: ProgressionMode?

    init(lastMatch: LastMatchStats, lastUpdated: Date?, progressionMode: ProgressionMode? = nil) {
        self.lastMatch = lastMatch
        self.lastUpdated = lastUpdated
        self.progressionMode = progressionMode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                    .font(.title3)

                Text("Last Match Performance")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                if lastMatch.hasData {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)

                            Text("Live Data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let lastUpdated = lastUpdated {
                            Text(formatLastUpdated(lastUpdated))
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                }
            }

            if !lastMatch.hasData {
                emptyStateView
            } else {
                statsContent
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.1), Theme.overlayColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        VStack(spacing: 16) {
            // Progression Type Badge (if available)
            if let mode = progressionMode {
                ProgressionBadge(progressionMode: mode)
            }

            // Quick Stats Summary Row (Always visible)
            quickStatsSummary

            // Combat Stats Row
            if let kills = lastMatch.kills {
                combatStatsSection(kills: kills)
            }

            // Team Support & Objectives
            HStack(spacing: 16) {
                // Team Support
                if let baseStats = lastMatch.baseStats {
                    teamSupportSection(baseStats: baseStats)
                }

                // Objectives
                if let objective = lastMatch.objective {
                    objectiveSection(objective: objective)
                }
            }
        }
    }

    // MARK: - Quick Stats Summary

    private var quickStatsSummary: some View {
        HStack(spacing: 12) {
            // Total Kills
            if let kills = lastMatch.kills {
                LastMatchStatCard(
                    title: "Kills",
                    value: "\(kills.total)",
                    icon: "target",
                    color: .red
                )
            }

            // Assists
            if let assists = lastMatch.assists {
                LastMatchStatCard(
                    title: "Assists",
                    value: "\(assists.total)",
                    icon: "person.2.fill",
                    color: .blue
                )
            }

            // Vehicle Damage
            if let damage = lastMatch.damage {
                LastMatchStatCard(
                    title: "Vehicle Damage",
                    value: "\(damage.vehicle)",
                    icon: "car.fill",
                    color: .purple
                )
            }

            // Objectives
            if let objective = lastMatch.objective {
                let totalObjectives = objective.captured + objective.neutralized + objective.armed
                LastMatchStatCard(
                    title: "Objectives",
                    value: "\(totalObjectives)",
                    icon: "flag.fill",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Combat Stats Section

    private func combatStatsSection(kills: InRoundKills) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.red)

                Text("Combat Performance")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                // Total Kills Badge
                HStack(spacing: 4) {
                    Text("\(kills.total)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    Text("kills")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .background(Theme.borderColor)

            // Weapon Breakdown
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if kills.headshots > 0 {
                    LastMatchStatItem(label: "Headshots", value: "\(kills.headshots)", color: .yellow)
                }

                if kills.multiKills > 0 {
                    LastMatchStatItem(label: "Multi-Kills", value: "\(kills.multiKills)", color: .orange)
                }

                if kills.melee > 0 {
                    LastMatchStatItem(label: "Melee", value: "\(kills.melee)", color: .red)
                }

                if kills.grenade > 0 {
                    LastMatchStatItem(label: "Grenades", value: "\(kills.grenade)", color: .red)
                }

                if kills.assaultRifles > 0 {
                    LastMatchStatItem(label: "AR Kills", value: "\(kills.assaultRifles)", color: .red)
                }

                if kills.dmrs > 0 {
                    LastMatchStatItem(label: "DMR Kills", value: "\(kills.dmrs)", color: .teal)
                }

                if kills.lmgs > 0 {
                    LastMatchStatItem(label: "LMG Kills", value: "\(kills.lmgs)", color: .green)
                }

                if kills.smgs > 0 {
                    LastMatchStatItem(label: "SMG Kills", value: "\(kills.smgs)", color: .yellow)
                }

                if kills.sniperRifles > 0 {
                    LastMatchStatItem(label: "Sniper Kills", value: "\(kills.sniperRifles)", color: .blue)
                }

                if kills.shotguns > 0 {
                    LastMatchStatItem(label: "Shotgun Kills", value: "\(kills.shotguns)", color: .purple)
                }
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - Team Support Section

    private func teamSupportSection(baseStats: InRoundStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.green)

                Text("Team Support")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Divider()
                .background(Theme.borderColor)

            VStack(spacing: 8) {
                LastMatchStatRow(label: "Revives", value: "\(baseStats.revives)", icon: "cross.case.fill")
                LastMatchStatRow(label: "Resupplies", value: "\(baseStats.resupplies)", icon: "shippingbox.fill")
                LastMatchStatRow(label: "Spot Assists", value: "\(baseStats.spotAssists)", icon: "eye.fill")
                LastMatchStatRow(label: "Takedowns", value: "\(baseStats.playerTakeDowns)", icon: "figure.wrestling")
                LastMatchStatRow(label: "Throwables", value: "\(baseStats.thrownThrowables)", icon: "circle.circle.fill")
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Objective Section

    private func objectiveSection(objective: InRoundObjective) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(.orange)

                Text("Objectives")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Divider()
                .background(Theme.borderColor)

            VStack(spacing: 8) {
                LastMatchStatRow(label: "Captured", value: "\(objective.captured)", icon: "flag.checkered")
                LastMatchStatRow(label: "Neutralized", value: "\(objective.neutralized)", icon: "flag.slash")
                LastMatchStatRow(label: "Armed", value: "\(objective.armed)", icon: "exclamationmark.triangle.fill")
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Functions

    private func formatLastUpdated(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Updated just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Updated \(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Updated \(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "Updated \(days)d ago"
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Active Match Data")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Start playing to see your current match stats")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

// MARK: - Last Match Stat Card

struct LastMatchStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }
}

// MARK: - Last Match Stat Item

struct LastMatchStatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Last Match Stat Row

struct LastMatchStatRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.orange)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.backgroundPrimary.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 20) {
                // Preview with comprehensive data
                LastMatchStatsView(
                    lastMatch: LastMatchStats(
                        baseStats: InRoundStats(revives: 19, resupplies: 130, spotAssists: 23, thrownThrowables: 12, playerTakeDowns: 10),
                        kills: InRoundKills(total: 102, grenade: 2, headshots: 13, melee: 1, multiKills: 22, assaultRifles: 19, dmrs: 13, lmgs: 24, smgs: 15, sniperRifles: 8, shotguns: 5),
                        damage: InRoundDamage(vehicle: 6075),
                        assists: InRoundAssists(total: 71),
                        objective: InRoundObjective(armed: 2, captured: 5, neutralized: 8)
                    ),
                    lastUpdated: Date().addingTimeInterval(-300) // 5 minutes ago
                )

                // Preview without data
                LastMatchStatsView(
                    lastMatch: LastMatchStats(
                        baseStats: nil,
                        kills: nil,
                        damage: nil,
                        assists: nil,
                        objective: nil
                    ),
                    lastUpdated: nil
                )
            }
            .padding()
        }
    }
}
