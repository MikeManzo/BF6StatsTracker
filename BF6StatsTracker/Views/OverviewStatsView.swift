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
    @Environment(\.accentColor) private var accentColor
    @EnvironmentObject var viewModel: StatsViewModel
    @EnvironmentObject var historyManager: HistoryManager

    // State for collapsible sections
    @State private var isCombatStatsExpanded = true
    @State private var isTeamSupportExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Daily Performance (Today's stats) - Always show enhanced view
            TodayVsYesterdayView()
                .environmentObject(historyManager)
                .frame(alignment: .leading)

            // Data Completeness Warning Banner
            if viewModel.hasPlayerData && !viewModel.hasCompleteData {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Incomplete Data")
                            .font(.headline)
                            .foregroundColor(accentColor)

                        Text("Missing: \(viewModel.missingDataSections.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(viewModel.dataCompletenessPercentage))%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(accentColor)

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
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accentColor.opacity(0.2))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                .background(accentColor.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
            }
            // Top Stats Cards - Always in single row
            if let stats = viewModel.playerStats {
                HStack(spacing: 16) {
                    StatCard(
                        title: "Kills",
                        value: stats.kills.formatted(),
                        icon: "target",
                        color: Theme.bf6Red,
                        subtitle: "\(String(format: "%.1f", stats.killsPerMinute)) per min",
                        trend: convertTrend(viewModel.killsTrend)
                    )
                    .frame(maxWidth: .infinity)

                    StatCard(
                        title: "Deaths",
                        value: stats.deaths.formatted(),
                        icon: "xmark.circle.fill",
                        color: Theme.textSecondary,
                        subtitle: "K/D: \(String(format: "%.2f", stats.kdRatio))",
                        trend: convertTrend(viewModel.kdTrend)
                    )
                    .frame(maxWidth: .infinity)

                    StatCard(
                        title: "Score",
                        value: stats.totalScore.formatted(),
                        icon: "star.fill",
                        color: .yellow,
                        subtitle: "\(String(format: "%.0f", stats.scorePerMinute)) per min"
                    )
                    .frame(maxWidth: .infinity)

                    StatCard(
                        title: "Wins",
                        value: stats.wins.formatted(),
                        icon: "trophy.fill",
                        color: Theme.bf6Green,
                        subtitle: "W/L: \(String(format: "%.1f%%", stats.wlRatio))",
                        trend: convertTrend(viewModel.wlTrend)
                    )
                    .frame(maxWidth: .infinity)

                    RankCard(stats: stats)
                        .frame(maxWidth: .infinity)
                }
            }

            // Last Completed Match - Computed from Snapshots
            LastCompletedMatchView(
                currentSnapshot: historyManager.getRecentSnapshots(limit: 1).first,
                previousSnapshot: historyManager.getRecentSnapshots(limit: 2).dropFirst().first
            )

            // Unified Overall Match Performance Card
            if let stats = viewModel.playerStats, stats.matchesPlayed > 0 {
                overallMatchPerformanceCard(stats: stats)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Overall Match Performance Card (Unified Container)

    private func overallMatchPerformanceCard(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            SectionHeader(title: "Overall Match Performance", icon: "gamecontroller.fill")

            // Primary stats row
            HStack(spacing: 24) {
                CompactStatItem(
                    label: "Matches",
                    value: stats.matchesPlayed.formatted(),
                    icon: "flag.checkered",
                    color: Theme.bf6Purple,
                    detail: "\(stats.wins) wins"
                )

                CompactStatItem(
                    label: "Kills/Match",
                    value: String(format: "%.1f", stats.killsPerMatch),
                    icon: "target",
                    color: Theme.bf6Red,
                    detail: "Humans + Bots"
                )

                CompactStatItem(
                    label: "Human %",
                    value: stats.humanPercent,
                    icon: "person.fill",
                    color: Theme.bf6Blue,
                    detail: "Player kills"
                )

                if stats.damagePerMatch > 0 {
                    CompactStatItem(
                        label: "Damage/Match",
                        value: String(format: "%.0f", stats.damagePerMatch),
                        icon: "bolt.fill",
                        color: accentColor,
                        detail: "Avg per game"
                    )
                }

                Spacer()
            }

            // Collapsible sub-sections side by side
            HStack(alignment: .top, spacing: 12) {
                // Combat Stats - Collapsible
                combatStatsDisclosure(stats: stats)

                // Team Support - Collapsible
                teamSupportDisclosure(stats: stats)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Combat Stats Disclosure

    private func combatStatsDisclosure(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Disclosure header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCombatStatsExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isCombatStatsExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Image(systemName: "scope")
                        .font(.subheadline)
                        .foregroundStyle(accentColor)

                    Text("Combat Stats")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable content
            if isCombatStatsExpanded {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatRow(label: "Headshots", value: stats.headshots.formatted())
                    StatRow(label: "HS %", value: "\(String(format: "%.1f", stats.headshotPercentage))%")
                    StatRow(label: "Accuracy", value: "\(String(format: "%.1f", stats.accuracy))%")
                    StatRow(label: "Longest HS", value: "\(String(format: "%.0f", stats.longestHeadshot))m")
                    StatRow(label: "Assists", value: stats.assists.formatted())
                    StatRow(label: "Revives", value: stats.revives.formatted())
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(accentColor.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Team Support Disclosure

    private func teamSupportDisclosure(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Disclosure header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTeamSupportExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isTeamSupportExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Image(systemName: "person.3.fill")
                        .font(.subheadline)
                        .foregroundStyle(accentColor)

                    Text("Team Support")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable content
            if isTeamSupportExpanded {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatRow(label: "Revives", value: stats.revives.formatted())
                    StatRow(label: "Resupplies", value: stats.resupplies.formatted())
                    StatRow(label: "Repairs", value: stats.repairs.formatted())
                    StatRow(label: "Heals", value: stats.heals.formatted())
                    StatRow(label: "Savior Kills", value: stats.saviorKills.formatted())
                    StatRow(label: "Enemies Spotted", value: stats.enemiesSpotted.formatted())
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(accentColor.opacity(0.1), lineWidth: 1)
        )
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
    @Environment(\.accentColor) private var accentColor

    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(accentColor)

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


// MARK: - Rank Card with Decorative Icon

struct RankCard: View {
    @Environment(\.accentColor) private var accentColor

    let stats: PlayerStats

    var body: some View {
        ZStack(alignment: .trailing) {
            // Decorative rank icon in background
            Image(systemName: stats.isSRank ? "crown.fill" : "shield.fill")
                .font(.system(size: 70))
                .foregroundStyle(stats.isSRank ? accentColor.opacity(0.12) : accentColor.opacity(0.1))
                .offset(x: -10, y: 0)

            // Card content - matching StatCard structure
            VStack(alignment: .leading, spacing: 12) {
                // Header (matches StatCard headerView)
                HStack(spacing: 6) {
                    Image(systemName: stats.isSRank ? "crown.fill" : "chevron.up.circle.fill")
                        .font(.caption)
                        .foregroundStyle(accentColor)

                    Text("RANK (Estimated)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textSecondary)

                    // Info icon with tooltip
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                        .help("Rank is estimated from XP. Accurate for S001-S050 range. High S-ranks (S150+) may be less accurate due to season XP resets.")

                    Spacer()
                }

                // Value (matches StatCard valueView)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(stats.rankString)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .fontDesign(.rounded)
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()
                }

                // Subtitle (matches StatCard subtitleView)
                Text("XP: \((stats.xpData?.first?.total ?? 0).formatted())")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)

                // Spacer for trend (matches StatCard padding when no trend)
                Color.clear
                    .frame(height: 16)
            }
            .padding(16)
        }
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    accentColor.opacity(0.2),
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
