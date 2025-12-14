//
//  OverviewStatsView.swift
//  BF6StatsTracker
//
//  Overview of all player statistics
//

import SwiftUI

struct OverviewStatsView: View {
    @EnvironmentObject var viewModel: StatsViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Last Match Stats (if available)
            if let lastMatch = viewModel.playerStats?.lastMatch, lastMatch.hasData {
                LastMatchStatsView(lastMatch: lastMatch, lastUpdated: viewModel.lastUpdated)
            } else {
                Text("Last match data unavailable")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            // Data Completeness Warning Banner
            if viewModel.hasPlayerData && !viewModel.hasCompleteData {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Incomplete Data")
                            .font(.headline)
                            .foregroundColor(.yellow)

                        Text("Missing: \(viewModel.missingDataSections.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(viewModel.dataCompletenessPercentage))%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)

                        Button(action: {
                            Task {
                                await viewModel.retryMissingData()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry")
                            }
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
            }
            // Top Stats Cards
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                if let stats = viewModel.playerStats {
                    StatCard(
                        title: "Kills",
                        value: stats.kills.formatted(),
                        icon: "target",
                        color: .red,
                        subtitle: "\(String(format: "%.1f", stats.killsPerMinute)) per min"
                    )
                    
                    StatCard(
                        title: "Deaths",
                        value: stats.deaths.formatted(),
                        icon: "xmark.circle.fill",
                        color: .gray,
                        subtitle: "K/D: \(String(format: "%.2f", stats.kdRatio))"
                    )
                    
                    StatCard(
                        title: "Score",
                        value: stats.totalScore.formatted(),
                        icon: "star.fill",
                        color: .yellow,
                        subtitle: "\(String(format: "%.0f", stats.scorePerMinute)) per min"
                    )
                    
                    StatCard(
                        title: "Wins",
                        value: stats.wins.formatted(),
                        icon: "trophy.fill",
                        color: .green,
                        subtitle: "W/L: \(String(format: "%.1f%%", stats.wlRatio))"
                    )
                }
            }
            
            HStack(spacing: 16) {
                // Combat Stats
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Combat Stats", icon: "scope")
                    
                    if let stats = viewModel.playerStats {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatRow(label: "Headshots", value: stats.headshots.formatted())
                            StatRow(label: "HS %", value: "\(String(format: "%.1f", stats.headshotPercentage))%")
                            StatRow(label: "Accuracy", value: "\(String(format: "%.1f", stats.accuracy))%")
                            StatRow(label: "Longest HS", value: "\(String(format: "%.0f", stats.longestHeadshot))m")
                            StatRow(label: "Assists", value: stats.assists.formatted())
                            StatRow(label: "Revives", value: stats.revives.formatted())
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                
                // Team Stats
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Team Support", icon: "person.3.fill")
                    
                    if let stats = viewModel.playerStats {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatRow(label: "Revives", value: stats.revives.formatted())
                            StatRow(label: "Resupplies", value: stats.resupplies.formatted())
                            StatRow(label: "Repairs", value: stats.repairs.formatted())
                            StatRow(label: "Heals", value: stats.heals.formatted())
                            StatRow(label: "Savior Kills", value: stats.saviorKills.formatted())
                            StatRow(label: "Enemies Spotted", value: stats.enemiesSpotted.formatted())
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
            }

            // Match Performance Section
            if let stats = viewModel.playerStats, stats.matchesPlayed > 0 {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Match Performance", icon: "gamecontroller.fill")

                    HStack(spacing: 16) {
                        StatCard(
                            title: "Matches Played",
                            value: stats.matchesPlayed.formatted(),
                            icon: "flag.checkered",
                            color: .purple,
                            subtitle: "\(stats.wins) wins"
                        )

                        StatCard(
                            title: "Kills/Match",
                            value: String(format: "%.1f", stats.killsPerMatch),
                            icon: "target",
                            color: .red,
                            subtitle: "Avg per game"
                        )

                        if stats.damagePerMatch > 0 {
                            StatCard(
                                title: "Damage/Match",
                                value: String(format: "%.0f", stats.damagePerMatch),
                                icon: "bolt.fill",
                                color: .orange,
                                subtitle: "Avg per game"
                            )
                        }

                        StatCard(
                            title: "Human Kills",
                            value: String(format: "%.1f%%", stats.humanPercentage),
                            icon: "person.2.fill",
                            color: .blue,
                            subtitle: "vs AI kills"
                        )
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
            }

            HStack(spacing: 16) {
                // Top Class
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Most Played Class", icon: "person.fill")
                    
                    if let topClass = viewModel.topClass {
                        HStack(spacing: 16) {
                            // Class Icon
                            ClassIconView(
                                className: BF6Class(rawValue: topClass.className) ?? .assault,
                                size: 60,
                                imageURL: topClass.image
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(topClass.className)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                HStack(spacing: 16) {
                                    Label("\(topClass.kills) kills", systemImage: "target")
                                    Label("\(topClass.timePlayed / 3600)h played", systemImage: "clock.fill")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text(String(format: "%.2f", topClass.kdRatio))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                
                                Text("K/D Ratio")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("No class data available")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .frame(maxWidth: .infinity)
                
                // Top Weapons
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Top Weapons", icon: "scope")
                    
                    if viewModel.topWeapons.isEmpty {
                        Text("No weapon data available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.topWeapons.prefix(3), id: \.weaponName) { weapon in
                            HStack {
                                AsyncGameImage(
                                    url: URL(string: weapon.image),
                                    placeholder: Image(systemName: "scope")
                                )
                                .frame(width: 40, height: 40)
                                .cornerRadius(8)
                                
                                VStack(alignment: .leading) {
                                    Text(weapon.weaponName)
                                        .fontWeight(.medium)
                                    
                                    Text("\(weapon.type)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("\(weapon.kills)")
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    
                                    Text("kills")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .frame(maxWidth: .infinity)
            }
            
            // All Classes Preview
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Class Performance", icon: "person.3.sequence.fill")
                
                if viewModel.classStats.isEmpty {
                    Text("No class data available")
                        .foregroundColor(.secondary)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(viewModel.classStats) { classStats in
                            ClassPreviewCard(classStats: classStats)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [color.opacity(0.2), color.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
            
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

// MARK: - Class Preview Card

struct ClassPreviewCard: View {
    let classStats: ClassStats
    
    private var bf6Class: BF6Class {
        BF6Class(rawValue: classStats.className) ?? .assault
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ClassIconView(className: bf6Class, size: 50, imageURL: classStats.image)
            
            Text(classStats.className)
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 4) {
                HStack {
                    Text("Kills")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(classStats.kills)")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("K/D")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f", classStats.kdRatio))
                        .fontWeight(.semibold)
                        .foregroundColor(classStats.kdRatio >= 1.0 ? .green : .red)
                }
                
                HStack {
                    Text("Time")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(classStats.timePlayed / 3600)h")
                        .fontWeight(.semibold)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(bf6Class.color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(bf6Class.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        OverviewStatsView()
            .padding()
    }
    .environmentObject(StatsViewModel())
    .background(Color(red: 0.05, green: 0.05, blue: 0.1))
}
