//
//  TeamSupportView.swift
//  BF6StatsTracker
//
//  Team Support Specialist Dashboard
//  Displays team support stats: repairs, heals, revives, resupplies
//

import SwiftUI

struct TeamSupportView: View {
    @EnvironmentObject var viewModel: StatsViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title)
                    .foregroundColor(Theme.bf6Green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Team Support Specialist")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    Text("Your contribution to team success")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let stats = viewModel.playerStats {
                    supportEffectivenessScore(stats: stats)
                }
            }

            if let stats = viewModel.playerStats {
                // Main Support Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    supportStatCard(
                        title: "Revives",
                        value: stats.revives,
                        perMatch: Double(stats.revives) / Double(max(stats.matchesPlayed, 1)),
                        icon: "cross.case.fill",
                        color: .red,
                        description: "Total teammate revives"
                    )

                    supportStatCard(
                        title: "Squad Revives",
                        value: stats.squadmateRevive,
                        perMatch: Double(stats.squadmateRevive) / Double(max(stats.matchesPlayed, 1)),
                        icon: "person.2.fill",
                        color: .orange,
                        description: "Revives on squad members"
                    )

                    supportStatCard(
                        title: "Resupplies",
                        value: stats.resupplies,
                        perMatch: Double(stats.resupplies) / Double(max(stats.matchesPlayed, 1)),
                        icon: "shippingbox.fill",
                        color: .blue,
                        description: "Ammo resupplies given"
                    )

                    supportStatCard(
                        title: "Repairs",
                        value: stats.repairs,
                        perMatch: Double(stats.repairs) / Double(max(stats.matchesPlayed, 1)),
                        icon: "wrench.and.screwdriver.fill",
                        color: .yellow,
                        description: "Vehicle repairs performed"
                    )

                    supportStatCard(
                        title: "Heals",
                        value: stats.heals,
                        perMatch: Double(stats.heals) / Double(max(stats.matchesPlayed, 1)),
                        icon: "bandage.fill",
                        color: .green,
                        description: "Health restored to teammates"
                    )

                    supportStatCard(
                        title: "Savior Kills",
                        value: stats.saviorKills,
                        perMatch: Double(stats.saviorKills) / Double(max(stats.matchesPlayed, 1)),
                        icon: "shield.lefthalf.filled",
                        color: .purple,
                        description: "Kills saving teammates"
                    )
                }

                // Support Breakdown Section
                supportBreakdownSection(stats: stats)

                // Support Comparison by Class
                if let classes = stats.classes {
                    classSupportComparison(classes: classes)
                }
            } else {
                Text("No support stats available")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Support Effectiveness Score

    private func supportEffectivenessScore(stats: PlayerStats) -> some View {
        let score = calculateSupportScore(stats: stats)
        let rating = getSupportRating(score: score)

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

    // MARK: - Support Stat Card

    private func supportStatCard(
        title: String,
        value: Int,
        perMatch: Double,
        icon: String,
        color: Color,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()

                Text(title)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)

                Text("total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "arrow.down.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(String(format: "%.1f per match", perMatch))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.8))
                .lineLimit(1)
        }
        .padding()
        .frame(height: 160)
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - Support Breakdown Section

    private func supportBreakdownSection(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Support Breakdown")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            VStack(spacing: 8) {
                // Total Support Actions
                let totalSupport = stats.revives + stats.resupplies + stats.repairs + stats.heals

                supportBreakdownRow(
                    label: "Total Support Actions",
                    value: totalSupport,
                    percentage: 100,
                    color: Theme.bf6Green
                )

                if totalSupport > 0 {
                    supportBreakdownRow(
                        label: "Revives",
                        value: stats.revives,
                        percentage: Double(stats.revives) / Double(totalSupport) * 100,
                        color: .red
                    )

                    supportBreakdownRow(
                        label: "Resupplies",
                        value: stats.resupplies,
                        percentage: Double(stats.resupplies) / Double(totalSupport) * 100,
                        color: .blue
                    )

                    supportBreakdownRow(
                        label: "Repairs",
                        value: stats.repairs,
                        percentage: Double(stats.repairs) / Double(totalSupport) * 100,
                        color: .yellow
                    )

                    supportBreakdownRow(
                        label: "Heals",
                        value: stats.heals,
                        percentage: Double(stats.heals) / Double(totalSupport) * 100,
                        color: .green
                    )
                }

                Divider()
                    .padding(.vertical, 4)

                // Squad vs Team Revives
                if stats.revives > 0 {
                    let squadPercent = Double(stats.squadmateRevive) / Double(stats.revives) * 100

                    HStack {
                        Text("Squad Focus")
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary)

                        Spacer()

                        Text("\(Int(squadPercent))% of revives on squad")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: squadPercent, total: 100)
                        .tint(.orange)
                }
            }
            .padding()
            .background(Theme.overlayColor)
            .cornerRadius(12)
        }
    }

    private func supportBreakdownRow(label: String, value: Int, percentage: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)

                Text("(\(Int(percentage))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (percentage / 100))
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
        }
    }

    // MARK: - Class Support Comparison

    private func classSupportComparison(classes: [ClassStats]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Support by Class")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            Text("Time played per class - Support class excels at team support")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(classes.sorted(by: { $0.timePlayed > $1.timePlayed })) { classStats in
                    classCard(classStats: classStats)
                }
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    private func classCard(classStats: ClassStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let bf6Class = BF6Class(rawValue: classStats.className) {
                    Image(systemName: bf6Class.iconName)
                        .foregroundColor(bf6Class.color)
                } else {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.gray)
                }

                Text(classStats.className)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Spacer()
            }

            HStack {
                Text(formatPlaytime(classStats.timePlayed))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(classStats.kills) kills")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
    }

    // MARK: - Helper Functions

    private func calculateSupportScore(stats: PlayerStats) -> Double {
        // Weight different support actions
        let reviveScore = Double(stats.revives) * 10
        let squadReviveScore = Double(stats.squadmateRevive) * 5 // Bonus for squad focus
        let resupplyScore = Double(stats.resupplies) * 2
        let repairScore = Double(stats.repairs) * 5
        let healScore = Double(stats.heals) * 3
        let saviorScore = Double(stats.saviorKills) * 15

        let totalScore = reviveScore + squadReviveScore + resupplyScore + repairScore + healScore + saviorScore
        let matchCount = Double(max(stats.matchesPlayed, 1))

        return totalScore / matchCount
    }

    private func getSupportRating(score: Double) -> (label: String, color: Color) {
        switch score {
        case 500...:
            return ("Elite Support", .purple)
        case 300..<500:
            return ("Expert Support", .blue)
        case 150..<300:
            return ("Dedicated Support", .green)
        case 75..<150:
            return ("Team Player", .yellow)
        case 25..<75:
            return ("Casual Support", .orange)
        default:
            return ("Combat Focused", .red)
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
    TeamSupportView()
        .environmentObject(StatsViewModel())
        .frame(width: 1000, height: 800)
}
