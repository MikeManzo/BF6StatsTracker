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
//  OverviewStatsView.swift
//  BF6StatsTracker
//
//  Overview of all player statistics
//

import SwiftUI

struct OverviewStatsView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @EnvironmentObject var historyManager: HistoryManager

    var body: some View {
        VStack(spacing: 20) {
            // Daily Performance (Today's stats) - Always show enhanced view
            TodayVsYesterdayView()
                .environmentObject(historyManager)

            // Data Completeness Warning Banner
            if viewModel.hasPlayerData && !viewModel.hasCompleteData {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.bf6Orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Incomplete Data")
                            .font(.headline)
                            .foregroundColor(Theme.bf6Orange)

                        Text("Missing: \(viewModel.missingDataSections.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(viewModel.dataCompletenessPercentage))%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.bf6Orange)

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
                            .foregroundColor(Theme.bf6Orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.bf6Orange.opacity(0.2))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                .background(Theme.bf6Orange.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.bf6Orange.opacity(0.3), lineWidth: 1)
                )
            }
            // Top Stats Cards - Responsive Grid
            GeometryReader { geometry in
                let breakpoint = ResponsiveBreakpoint(width: geometry.size.width)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: breakpoint.columns), spacing: breakpoint.spacing) {
                    if let stats = viewModel.playerStats {
                        StatCard(
                            title: "Kills",
                            value: stats.kills.formatted(),
                            icon: "target",
                            color: Theme.bf6Red,
                            subtitle: "\(String(format: "%.1f", stats.killsPerMinute)) per min",
                            trend: convertTrend(viewModel.killsTrend)
                        )

                        StatCard(
                            title: "Deaths",
                            value: stats.deaths.formatted(),
                            icon: "xmark.circle.fill",
                            color: Theme.textSecondary,
                            subtitle: "K/D: \(String(format: "%.2f", stats.kdRatio))",
                            trend: convertTrend(viewModel.kdTrend)
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
                            color: Theme.bf6Green,
                            subtitle: "W/L: \(String(format: "%.1f%%", stats.wlRatio))",
                            trend: convertTrend(viewModel.wlTrend)
                        )

                        RankCard(stats: stats)
                    }
                }
            }
            .frame(height: 160)

            // Last Completed Match - Computed from Snapshots
            LastCompletedMatchView(
                currentSnapshot: historyManager.getRecentSnapshots(limit: 1).first,
                previousSnapshot: historyManager.getRecentSnapshots(limit: 2).dropFirst().first
            )

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
                .cardStyle()

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
                .cardStyle()
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
                            color: Theme.bf6Purple,
                            subtitle: "\(stats.wins) wins"
                        )

                        StatCard(
                            title: "Kills/Match",
                            value: String(format: "%.1f", stats.killsPerMatch),
                            icon: "target",
                            color: Theme.bf6Red,
                            subtitle: "Avg per game"
                        )

                        if stats.damagePerMatch > 0 {
                            StatCard(
                                title: "Damage/Match",
                                value: String(format: "%.0f", stats.damagePerMatch),
                                icon: "bolt.fill",
                                color: Theme.bf6Orange,
                                subtitle: "Avg per game"
                            )
                        }

                        StatCard(
                            title: "Human Kills",
                            value: String(format: "%.1f%%", stats.humanPercentage),
                            icon: "person.2.fill",
                            color: Theme.bf6Blue,
                            subtitle: "vs AI kills"
                        )
                    }
                }
                .cardStyle()
            }

            HStack(spacing: 16) {
                // Enhanced Class Card
                if let topClass = viewModel.topClass, let stats = viewModel.playerStats {
                    EnhancedClassCard(
                        classStats: topClass,
                        overallSPM: stats.scorePerMinute,
                        overallWinRate: stats.wlRatio,
                        totalTimePlayed: stats.timePlayed
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Most Played Class", icon: "person.fill")
                        Text("No class data available")
                            .foregroundColor(Theme.textSecondary)
                    }
                    .cardStyle()
                    .frame(maxWidth: .infinity)
                }

                // Top Weapons
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Top Weapons", icon: "scope")

                    if viewModel.topWeapons.isEmpty {
                        Text("No weapon data available")
                            .foregroundColor(Theme.textSecondary)
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
                                        .foregroundColor(Theme.textPrimary)

                                    Text("\(weapon.type)")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text("\(weapon.kills)")
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.bf6Red)

                                    Text("kills")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .cardStyle()
                .frame(maxWidth: .infinity)
            }

            // All Classes Preview
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Class Performance", icon: "person.3.sequence.fill")

                if viewModel.classStats.isEmpty {
                    Text("No class data available")
                        .foregroundColor(Theme.textSecondary)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(Array(viewModel.classStats.enumerated()), id: \.element.id) { index, classStats in
                            AnimatedClassPreviewCard(
                                classStats: classStats,
                                delay: Double(index) * 0.1
                            )
                        }
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Helper Methods

    private func convertTrend(_ trendDirection: TrendDirection) -> TrendInfo? {
        switch trendDirection {
        case .improving:
            return TrendInfo(value: 1.0, text: "Improving", secondaryText: nil)
        case .declining:
            return TrendInfo(value: -1.0, text: "Declining", secondaryText: nil)
        case .stable:
            return nil // Don't show trend for stable
        }
    }
}

// MARK: - Trend Arrow

struct TrendArrow: View {
    let trend: TrendDirection

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
                .font(.caption)
                .foregroundColor(trend.color)
        }
    }
}

// Note: StatCard is now defined in UnifiedStatCard.swift as a legacy wrapper

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Theme.bf6Orange)

            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

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
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
        }
        .font(.subheadline)
    }
}

// MARK: - Animated Class Preview Card Wrapper

struct AnimatedClassPreviewCard: View {
    let classStats: ClassStats
    let delay: Double

    @State private var isVisible = false

    var body: some View {
        ClassPreviewCard(classStats: classStats)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                    isVisible = true
                }
            }
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
                .foregroundColor(Theme.textPrimary)

            VStack(spacing: 4) {
                HStack {
                    Text("Kills")
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(classStats.kills)")
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                }

                HStack {
                    Text("K/D")
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(String(format: "%.2f", classStats.kdRatio))
                        .fontWeight(.semibold)
                        .foregroundColor(classStats.kdRatio >= 1.0 ? Theme.bf6Green : Theme.bf6Red)
                }

                HStack {
                    Text("Time")
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(classStats.timePlayed / 3600)h")
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
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

// MARK: - Rank Card with Decorative Icon

struct RankCard: View {
    let stats: PlayerStats

    var body: some View {
        ZStack(alignment: .trailing) {
            // Decorative rank icon in background
            Image(systemName: stats.isSRank ? "crown.fill" : "shield.fill")
                .font(.system(size: 70))
                .foregroundStyle(stats.isSRank ? Theme.bf6Orange.opacity(0.12) : Theme.bf6Orange.opacity(0.1))
                .offset(x: -10, y: 0)

            // Card content
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: stats.isSRank ? "crown.fill" : "chevron.up.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.bf6Orange)

                        Text("RANK (Approx)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.textSecondary)

                        Spacer()
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(stats.rankString)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)

                        Spacer()
                    }

                    Text("XP: \((stats.xpData?.first?.total ?? 0).formatted())")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()
            }
            .padding(16)
        }
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    Theme.bf6Orange.opacity(0.2),
                    lineWidth: 1
                )
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
    .background(Theme.backgroundPrimary)
}
