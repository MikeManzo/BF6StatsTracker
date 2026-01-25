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
//  IntelligenceView.swift
//  BF6StatsTracker
//
//  Spotting & Intelligence Dashboard
//  Shows enemies spotted, human percent, spot assists correlation with win rate
//

import SwiftUI

struct IntelligenceView: View {
    @EnvironmentObject var viewModel: StatsViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "eye.fill")
                    .font(.title)
                    .foregroundColor(Theme.bf6Blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Spotting & Intelligence")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    Text("Battlefield awareness and reconnaissance")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if let stats = viewModel.playerStats {
                    intelRating(stats: stats)
                }
            }

            if let stats = viewModel.playerStats {
                // Spotting Performance
                spottingPerformance(stats: stats)

                // Combat Intelligence
                combatIntelligence(stats: stats)

                // Team Contribution
                teamContribution(stats: stats)

                // Last Match Spotting
                if let lastMatch = stats.lastMatch, let baseStats = lastMatch.baseStats {
                    lastMatchSpotting(baseStats: baseStats)
                }
            } else {
                Text("No intelligence stats available")
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding()
    }

    // MARK: - Intel Rating

    private func intelRating(stats: PlayerStats) -> some View {
        let rating = calculateIntelRating(stats: stats)

        return VStack(spacing: 8) {
            Text("\(Int(rating.score))")
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

    // MARK: - Spotting Performance

    private func spottingPerformance(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spotting Performance")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 16) {
                // Total Spots
                VStack(spacing: 12) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.info)

                    Text("\(stats.enemiesSpotted)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    Text("Enemies Spotted")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textSecondary)

                    Divider()

                    VStack(spacing: 4) {
                        let spotsPerMatch = Double(stats.enemiesSpotted) / Double(max(stats.matchesPlayed, 1))
                        Text(String(format: "%.1f", spotsPerMatch))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.info)

                        Text("per match")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)

                // Spotting Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    spottingBreakdownRow(
                        label: "Total Spotted",
                        value: stats.enemiesSpotted,
                        icon: "eye.fill",
                        color: .blue
                    )

                    spottingBreakdownRow(
                        label: "Per Match",
                        value: Int(Double(stats.enemiesSpotted) / Double(max(stats.matchesPlayed, 1))),
                        icon: "chart.bar.fill",
                        color: .purple
                    )

                    spottingBreakdownRow(
                        label: "Per Minute",
                        value: calculateSpotsPerMinute(stats: stats),
                        icon: "clock.fill",
                        color: .green,
                        isDecimal: true
                    )

                    // Spotting efficiency compared to kills
                    let spotToKillRatio = stats.kills > 0 ? Double(stats.enemiesSpotted) / Double(stats.kills) : 0
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(Theme.warning)
                            .frame(width: 24)

                        Text("Spot/Kill Ratio")
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary)

                        Spacer()

                        Text(String(format: "%.2f", spotToKillRatio))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.warning)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)
            }

            // Spotting Contribution Analysis
            spottingContributionAnalysis(stats: stats)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    private func spottingBreakdownRow(label: String, value: Int, icon: String, color: Color, isDecimal: Bool = false) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }

    private func spottingContributionAnalysis(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reconnaissance Contribution")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            let totalTeamActions = stats.kills + stats.enemiesSpotted + stats.killAssists
            if totalTeamActions > 0 {
                let spottingPercent = Double(stats.enemiesSpotted) / Double(totalTeamActions) * 100

                HStack {
                    Text("Spotting contribution to team actions")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Spacer()

                    Text("\(Int(spottingPercent))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.info)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))

                        Rectangle()
                            .fill(Theme.info)
                            .frame(width: geometry.size.width * (spottingPercent / 100))
                    }
                }
                .frame(height: 8)
                .cornerRadius(4)
            }
        }
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
    }

    // MARK: - Combat Intelligence

    private func combatIntelligence(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combat Intelligence")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 16) {
                // Human Percent Analysis
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundColor(Theme.bf6Purple)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Human Opponents")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)

                            Text("vs AI Targets")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }

                        Spacer()
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", stats.humanPercentage))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.bf6Purple)

                        Text("%")
                            .font(.title)
                            .foregroundColor(Theme.bf6Purple)
                    }

                    Text(getHumanPercentRating(stats.humanPercentage))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(getHumanPercentColor(stats.humanPercentage))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(getHumanPercentColor(stats.humanPercentage).opacity(0.2))
                        .cornerRadius(6)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("This represents the difficulty of your targets")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)

                        Text("Higher % = More PvP combat")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)

                // Target Priority Analysis
                VStack(spacing: 12) {
                    Text("Target Distribution")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)

                    // Human kills
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Human Kills")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)

                            Spacer()

                            let humanKills = Int(Double(stats.kills) * (stats.humanPercentage / 100.0))
                            Text("\(humanKills)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.bf6Purple)
                        }

                        ProgressView(value: stats.humanPercentage, total: 100)
                            .tint(Theme.bf6Purple)
                    }

                    // AI kills
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("AI Kills")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)

                            Spacer()

                            let aiKills = Int(Double(stats.kills) * (1.0 - stats.humanPercentage / 100.0))
                            Text("\(aiKills)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.info)
                        }

                        ProgressView(value: 100 - stats.humanPercentage, total: 100)
                            .tint(Theme.info)
                    }

                    Divider()

                    // Situational Awareness Score
                    VStack(spacing: 4) {
                        Text("Awareness Score")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        let awarenessScore = calculateAwarenessScore(stats: stats)
                        Text("\(Int(awarenessScore))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(getAwarenessColor(awarenessScore))

                        Text(getAwarenessRating(awarenessScore))
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - Team Contribution

    private func teamContribution(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team Intelligence Contribution")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                contributionCard(
                    title: "Intel Provider",
                    value: "\(stats.enemiesSpotted)",
                    subtitle: "enemies revealed",
                    icon: "binoculars.fill",
                    color: .blue
                )

                contributionCard(
                    title: "Assists",
                    value: "\(stats.killAssists)",
                    subtitle: "teammate assists",
                    icon: "hand.thumbsup.fill",
                    color: .green
                )

                contributionCard(
                    title: "Combined Intel",
                    value: "\(stats.enemiesSpotted + stats.killAssists)",
                    subtitle: "total team value",
                    icon: "star.fill",
                    color: .yellow
                )
            }

            // Win Rate Correlation
            winRateCorrelation(stats: stats)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    private func contributionCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
    }

    private func winRateCorrelation(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intelligence Impact on Win Rate")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Win Rate")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text(String(format: "%.1f%%", stats.wlRatio))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.success)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Spots per Win")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    let spotsPerWin = stats.wins > 0 ? Double(stats.enemiesSpotted) / Double(stats.wins) : 0
                    Text(String(format: "%.1f", spotsPerWin))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.info)
                }

                Spacer()

                // Correlation indicator
                VStack(spacing: 4) {
                    let correlation = getIntelWinCorrelation(stats: stats)
                    Image(systemName: correlation.icon)
                        .font(.title2)
                        .foregroundColor(correlation.color)

                    Text(correlation.label)
                        .font(.caption2)
                        .foregroundColor(correlation.color)
                }
            }
        }
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
    }

    // MARK: - Last Match Spotting

    private func lastMatchSpotting(baseStats: InRoundStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Match Intelligence")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 16) {
                lastMatchStatCard(
                    title: "Spot Assists",
                    value: "\(baseStats.spotAssists)",
                    icon: "eye.trianglebadge.exclamationmark.fill",
                    color: .blue
                )

                lastMatchStatCard(
                    title: "Throwables",
                    value: "\(baseStats.thrownThrowables)",
                    icon: "circlebadge.fill",
                    color: .orange
                )

                lastMatchStatCard(
                    title: "Takedowns",
                    value: "\(baseStats.playerTakeDowns)",
                    icon: "figure.martial.arts",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    private func lastMatchStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
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

    // MARK: - Helper Functions

    private func calculateIntelRating(stats: PlayerStats) -> (score: Double, label: String, color: Color) {
        let spotsPerMatch = Double(stats.enemiesSpotted) / Double(max(stats.matchesPlayed, 1))
        let awarenessScore = calculateAwarenessScore(stats: stats)

        let score = (spotsPerMatch * 10) + (awarenessScore / 2)

        switch score {
        case 100...:
            return (score, "Elite Scout", .purple)
        case 60..<100:
            return (score, "Expert Recon", .blue)
        case 30..<60:
            return (score, "Intel Specialist", .green)
        case 15..<30:
            return (score, "Team Player", .yellow)
        default:
            return (score, "Combat Focused", .orange)
        }
    }

    private func calculateSpotsPerMinute(stats: PlayerStats) -> Int {
        guard stats.secondsPlayed > 0 else { return 0 }
        let minutes = Double(stats.secondsPlayed) / 60.0
        return Int(Double(stats.enemiesSpotted) / minutes)
    }

    private func calculateAwarenessScore(stats: PlayerStats) -> Double {
        let spottingScore = Double(stats.enemiesSpotted) / Double(max(stats.matchesPlayed, 1))
        let humanPercent = stats.humanPercentage
        let assistRatio = stats.kills > 0 ? Double(stats.killAssists) / Double(stats.kills) : 0

        return min((spottingScore * 2) + humanPercent + (assistRatio * 20), 100)
    }

    private func getHumanPercentRating(_ percent: Double) -> String {
        switch percent {
        case 70...:
            return "Elite PvP"
        case 50..<70:
            return "Competitive"
        case 30..<50:
            return "Mixed Combat"
        default:
            return "PvE Focused"
        }
    }

    private func getHumanPercentColor(_ percent: Double) -> Color {
        switch percent {
        case 70...:
            return .purple
        case 50..<70:
            return .blue
        case 30..<50:
            return .green
        default:
            return .orange
        }
    }

    private func getAwarenessColor(_ score: Double) -> Color {
        switch score {
        case 75...:
            return .purple
        case 50..<75:
            return .blue
        case 30..<50:
            return .green
        default:
            return .yellow
        }
    }

    private func getAwarenessRating(_ score: Double) -> String {
        switch score {
        case 75...:
            return "Exceptional"
        case 50..<75:
            return "Excellent"
        case 30..<50:
            return "Good"
        default:
            return "Developing"
        }
    }

    private func getIntelWinCorrelation(stats: PlayerStats) -> (icon: String, label: String, color: Color) {
        let spotsPerMatch = Double(stats.enemiesSpotted) / Double(max(stats.matchesPlayed, 1))

        if spotsPerMatch > 10 && stats.wlRatio > 50 {
            return ("arrow.up.circle.fill", "High Impact", .green)
        } else if spotsPerMatch > 5 {
            return ("minus.circle.fill", "Moderate", .blue)
        } else {
            return ("arrow.down.circle.fill", "Low Impact", .orange)
        }
    }
}

#Preview {
    IntelligenceView()
        .environmentObject(StatsViewModel())
        .frame(width: 1200, height: 900)
}
