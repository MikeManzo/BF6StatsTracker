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
//  LastCompletedMatchView.swift
//  BF6StatsTracker
//
//  Displays computed statistics from the last completed match using snapshot deltas
//

import SwiftUI

struct LastCompletedMatchView: View {
    let currentSnapshot: StatsSnapshot?
    let previousSnapshot: StatsSnapshot?

    // Computed match stats from snapshot deltas
    private var matchStats: MatchDeltaStats? {
        guard let current = currentSnapshot,
              let previous = previousSnapshot else {
            return nil
        }
        return MatchDeltaStats(current: current, previous: previous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(.green)
                    .font(.title3)

                Text("Last Completed Match")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                if let stats = matchStats {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)

                            Text("Computed Data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(formatTimestamp(stats.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }

            if matchStats == nil {
                emptyStateView
            } else {
                statsContent
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.1), Theme.overlayColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        VStack(spacing: 16) {
            if let stats = matchStats {
                // Quick Stats Summary Row
                quickStatsSummary(stats: stats)

                // Combat Performance
                combatStatsSection(stats: stats)

                // Team Support & Match Results
                HStack(spacing: 16) {
                    teamSupportSection(stats: stats)
                    matchResultsSection(stats: stats)
                }
            }
        }
    }

    // MARK: - Quick Stats Summary

    private func quickStatsSummary(stats: MatchDeltaStats) -> some View {
        HStack(spacing: 12) {
            // Kills
            LastMatchStatCard(
                title: "Kills",
                value: "\(stats.kills)",
                icon: "target",
                color: .green
            )

            // Deaths
            LastMatchStatCard(
                title: "Deaths",
                value: "\(stats.deaths)",
                icon: "xmark.circle",
                color: .red
            )

            // K/D Ratio
            LastMatchStatCard(
                title: "K/D",
                value: String(format: "%.2f", stats.kdRatio),
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )

            // Score
            LastMatchStatCard(
                title: "Score",
                value: formatScore(stats.score),
                icon: "star.fill",
                color: .yellow
            )
        }
    }

    // MARK: - Combat Stats Section

    private func combatStatsSection(stats: MatchDeltaStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.green)

                Text("Combat Performance")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                // K/D Badge
                HStack(spacing: 4) {
                    Text(String(format: "%.2f", stats.kdRatio))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(stats.kdRatio >= 1.0 ? .green : .red)

                    Text("K/D")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .background(Theme.borderColor)

            // Combat Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                LastMatchStatItem(
                    label: "Kills",
                    value: "\(stats.kills)",
                    color: .green
                )

                LastMatchStatItem(
                    label: "Deaths",
                    value: "\(stats.deaths)",
                    color: .red
                )

                LastMatchStatItem(
                    label: "Assists",
                    value: "\(stats.assists)",
                    color: .blue
                )

                LastMatchStatItem(
                    label: "Headshots",
                    value: "\(stats.headshots)",
                    color: .yellow
                )

                if stats.headshots > 0 && stats.kills > 0 {
                    LastMatchStatItem(
                        label: "HS %",
                        value: String(format: "%.0f%%", stats.headshotPercent),
                        color: .yellow
                    )
                }

                LastMatchStatItem(
                    label: "KPM",
                    value: String(format: "%.1f", stats.killsPerMinute),
                    color: .orange
                )
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - Team Support Section

    private func teamSupportSection(stats: MatchDeltaStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)

                Text("Team Support")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Divider()
                .background(Theme.borderColor)

            VStack(spacing: 8) {
                LastMatchStatRow(
                    label: "Revives",
                    value: "\(stats.revives)",
                    icon: "cross.case.fill"
                )

                LastMatchStatRow(
                    label: "Resupplies",
                    value: "\(stats.resupplies)",
                    icon: "shippingbox.fill"
                )
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Match Results Section

    private func matchResultsSection(stats: MatchDeltaStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)

                Text("Match Result")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Divider()
                .background(Theme.borderColor)

            VStack(spacing: 8) {
                // Win/Loss indicator
                if stats.wins > 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .frame(width: 20)

                        Text("Victory")
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)

                        Spacer()
                    }
                } else if stats.losses > 0 {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(width: 20)

                        Text("Defeat")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)

                        Spacer()
                    }
                }

                LastMatchStatRow(
                    label: "Time Played",
                    value: formatDuration(stats.timePlayed),
                    icon: "clock.fill"
                )

                LastMatchStatRow(
                    label: "Score/Min",
                    value: String(format: "%.0f", stats.scorePerMinute),
                    icon: "speedometer"
                )
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Functions

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatScore(_ score: Int) -> String {
        if score >= 10000 {
            return String(format: "%.1fk", Double(score) / 1000.0)
        }
        return "\(score)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Completed Match Data")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Complete a match to see your last game stats")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

// MARK: - Match Delta Stats

/// Represents stats computed from the delta between two snapshots (last completed match)
struct MatchDeltaStats {
    let kills: Int
    let deaths: Int
    let assists: Int
    let revives: Int
    let resupplies: Int
    let headshots: Int
    let score: Int
    let timePlayed: Int
    let wins: Int
    let losses: Int
    let timestamp: Date

    var kdRatio: Double {
        deaths > 0 ? Double(kills) / Double(deaths) : Double(kills)
    }

    var killsPerMinute: Double {
        let minutes = Double(timePlayed) / 60.0
        return minutes > 0 ? Double(kills) / minutes : 0
    }

    var scorePerMinute: Double {
        let minutes = Double(timePlayed) / 60.0
        return minutes > 0 ? Double(score) / minutes : 0
    }

    var headshotPercent: Double {
        kills > 0 ? (Double(headshots) / Double(kills)) * 100.0 : 0
    }

    init(current: StatsSnapshot, previous: StatsSnapshot) {
        self.kills = max(0, current.kills - previous.kills)
        self.deaths = max(0, current.deaths - previous.deaths)
        self.assists = max(0, current.assists - previous.assists)
        self.revives = max(0, current.revives - previous.revives)
        self.resupplies = max(0, current.resupplies - previous.resupplies)
        self.headshots = max(0, current.headshots - previous.headshots)
        self.score = max(0, current.totalScore - previous.totalScore)
        self.timePlayed = max(0, current.timePlayed - previous.timePlayed)
        self.wins = max(0, current.wins - previous.wins)
        self.losses = max(0, current.losses - previous.losses)
        self.timestamp = current.timestamp
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.backgroundPrimary.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 20) {
                // Preview with match data
                LastCompletedMatchView(
                    currentSnapshot: createSampleSnapshot(
                        kills: 125,
                        deaths: 78,
                        assists: 42,
                        revives: 8,
                        resupplies: 15,
                        headshots: 23,
                        score: 25000,
                        timePlayed: 1800,
                        wins: 11,
                        losses: 5
                    ),
                    previousSnapshot: createSampleSnapshot(
                        kills: 100,
                        deaths: 65,
                        assists: 30,
                        revives: 5,
                        resupplies: 10,
                        headshots: 15,
                        score: 18500,
                        timePlayed: 600,
                        wins: 10,
                        losses: 5
                    )
                )

                // Preview without data
                LastCompletedMatchView(
                    currentSnapshot: nil,
                    previousSnapshot: nil
                )
            }
            .padding()
        }
    }
}

// Helper for preview
private func createSampleSnapshot(
    kills: Int,
    deaths: Int,
    assists: Int,
    revives: Int,
    resupplies: Int,
    headshots: Int,
    score: Int,
    timePlayed: Int,
    wins: Int,
    losses: Int
) -> StatsSnapshot {
    StatsSnapshot(
        playerName: "TestPlayer",
        platform: "pc",
        eaId: "test123",
        kills: kills,
        deaths: deaths,
        wins: wins,
        losses: losses,
        matchesPlayed: wins + losses,
        totalScore: score,
        timePlayed: timePlayed,
        headshots: headshots,
        assists: assists,
        revives: revives,
        resupplies: resupplies
    )
}
