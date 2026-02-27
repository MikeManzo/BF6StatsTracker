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
    @State private var isPerMatchAveragesExpanded = true
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

            // Unified Overall Match Performance Card (includes hero stats)
            if let stats = viewModel.playerStats, stats.matchesPlayed > 0 {
                overallMatchPerformanceCard(stats: stats)
            }

            // Last Completed Match - Computed from Snapshots (MRM: Legacy Snapshot Stats)
//            LastCompletedMatchView(
//                currentSnapshot: historyManager.getRecentSnapshots(limit: 1).first,
//                previousSnapshot: historyManager.getRecentSnapshots(limit: 2).dropFirst().first
//            )

            HStack(alignment: .top, spacing: 16) {
                // Enhanced Class Card
                if let topClass = viewModel.topClass, let stats = viewModel.playerStats {
                    EnhancedClassCard(
                        classStats: topClass,
                        overallKPM: stats.killsPerMinute,
                        overallWinRate: stats.wlRatio,
                        totalTimePlayed: stats.timePlayed
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Most Played Class", icon: "person.fill")
                        Text("No class data available")
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    .cardStyle()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                // Top Weapons
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Top Weapons", icon: "scope")

                    if viewModel.topWeapons.isEmpty {
                        Text("No weapon data available")
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        ForEach(viewModel.topWeapons.prefix(4), id: \.weaponName) { weapon in
                            HStack {
                                AsyncGameImage(
                                    url: URL(string: weapon.image),
                                    placeholder: Image(systemName: "scope")
                                )
                                .frame(width: 36, height: 36)
                                .cornerRadius(6)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(weapon.weaponName)
                                        .fontWeight(.medium)
                                        .foregroundColor(Theme.textPrimary)

                                    Text("\(weapon.type)")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(weapon.kills)")
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.bf6Red)

                                    Text("kills")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .cardStyle()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .fixedSize(horizontal: false, vertical: true)
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
            SectionHeader(title: "Overall Game Performance", icon: "gamecontroller.fill")

            // Hero Stats Row - Primary career metrics
            HStack(spacing: 16) {
                enhancedKillsCard(stats: stats)
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

                KDACard(stats: stats)
                    .frame(maxWidth: .infinity)
            }

            // Collapsible sub-sections
            VStack(alignment: .leading, spacing: 12) {
                // Per-Match Averages - Collapsible (full width)
                perMatchAveragesDisclosure(stats: stats)

                // Combat Stats & Team Support - side by side
                HStack(alignment: .top, spacing: 12) {
                    combatStatsDisclosure(stats: stats)
                    teamSupportDisclosure(stats: stats)
                }
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

    // MARK: - Per-Match Averages Disclosure

    private func perMatchAveragesDisclosure(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Disclosure header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPerMatchAveragesExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isPerMatchAveragesExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Image(systemName: "chart.bar.fill")
                        .font(.subheadline)
                        .foregroundStyle(accentColor)

                    Text("Per-Match Averages")
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
            if isPerMatchAveragesExpanded {
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
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        StatRow(label: "Headshots", value: stats.headshots.formatted())
                        StatRow(label: "HS %", value: "\(String(format: "%.1f", stats.headshotPercentage))%")
                        StatRow(label: "Accuracy", value: "\(String(format: "%.1f", stats.accuracy))%")
                        StatRow(label: "Savior Kills", value: stats.saviorKills.formatted())
                        StatRow(label: "Assists", value: stats.assists.formatted())
                        StatRow(label: "Revives", value: stats.revives.formatted())
                    }
                    
                    // Combat Style breakdown (if available)
                    if let extended = viewModel.extendedProfileStats,
                       (extended.adsKills + extended.hipfireKills) > 0 {
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Combat Style")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.textSecondary)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                // ADS Kills
                                HStack(spacing: 4) {
                                    Image(systemName: "scope")
                                        .font(.caption2)
                                        .foregroundColor(Theme.bf6Red)
                                    Text("ADS")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text("\(extended.adsKills)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Theme.textPrimary)
                                    Text("(\(String(format: "%.0f", extended.aimingPercentage))%)")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                // Hipfire Kills
                                HStack(spacing: 4) {
                                    Image(systemName: "dot.scope")
                                        .font(.caption2)
                                        .foregroundColor(Theme.bf6Blue)
                                    Text("Hipfire")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text("\(extended.hipfireKills)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                
                                // Melee Kills (if available)
                                if extended.meleeKills > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "figure.boxing")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Text("Melee")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                        Text("\(extended.meleeKills)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                }
                                
                                // Grenade Kills (if available)
                                if extended.grenadeKills > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "circle.dotted.circle")
                                            .font(.caption2)
                                            .foregroundColor(Theme.bf6Green)
                                        Text("Grenade")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                        Text("\(extended.grenadeKills)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                }
                                
                                // Headshot Kills (if available)
                                if extended.headshotKills > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "scope.circle")
                                            .font(.caption2)
                                            .foregroundColor(.yellow)
                                        Text("Headshot")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                        Text("\(extended.headshotKills)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Theme.textPrimary)
                                        Text("(\(String(format: "%.0f", extended.headshotPercentage))%)")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
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
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        StatRow(label: "Revives", value: stats.revives.formatted())
                        StatRow(label: "Resupplies", value: stats.resupplies.formatted())
                        StatRow(label: "Repairs", value: stats.repairs.formatted())
                        StatRow(label: "Heals", value: stats.heals.formatted())
                        StatRow(label: "Savior Kills", value: stats.saviorKills.formatted())
                        StatRow(label: "Enemies Spotted", value: stats.enemiesSpotted.formatted())
                    }
                    
                    // Assist Breakdown (if available)
                    if let extended = viewModel.extendedProfileStats {
                        let totalAssists = extended.spotAssists + extended.suppressAssists + 
                                          extended.smokeAssists + extended.flashAssists + 
                                          extended.concussAssists + extended.driverAssists + 
                                          extended.pilotAssists
                        
                        if totalAssists > 0 {
                            Divider()
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Assist Breakdown")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Theme.textSecondary)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    if extended.spotAssists > 0 {
                                        assistTypeRow(icon: "eye.fill", label: "Spot", value: extended.spotAssists, color: Theme.bf6Blue)
                                    }
                                    if extended.suppressAssists > 0 {
                                        assistTypeRow(icon: "exclamationmark.triangle.fill", label: "Suppress", value: extended.suppressAssists, color: .orange)
                                    }
                                    if extended.smokeAssists > 0 {
                                        assistTypeRow(icon: "cloud.fill", label: "Smoke", value: extended.smokeAssists, color: .gray)
                                    }
                                    if extended.flashAssists > 0 {
                                        assistTypeRow(icon: "sparkles", label: "Flash", value: extended.flashAssists, color: .yellow)
                                    }
                                    if extended.concussAssists > 0 {
                                        assistTypeRow(icon: "waveform", label: "Concuss", value: extended.concussAssists, color: .purple)
                                    }
                                    if extended.driverAssists > 0 {
                                        assistTypeRow(icon: "car.fill", label: "Driver", value: extended.driverAssists, color: Theme.bf6Green)
                                    }
                                    if extended.pilotAssists > 0 {
                                        assistTypeRow(icon: "airplane", label: "Pilot", value: extended.pilotAssists, color: Theme.bf6Red)
                                    }
                                }
                            }
                        }
                    }
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
    
    // MARK: - Assist Type Row Helper
    
    private func assistTypeRow(icon: String, label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text("\(value)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
        }
    }
    
    // MARK: - Enhanced Kills Card
    
    private func enhancedKillsCard(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.caption)
                    .foregroundStyle(Theme.bf6Red)

                Text("KILLS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textSecondary)

                Spacer()
            }
            
            // Value
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(stats.kills.formatted())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .fontDesign(.rounded)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()
            }
            
            // Subtitle with human vs bot breakdown on same line
            HStack(spacing: 0) {
                // Kills per minute
                Text("\(String(format: "%.1f", stats.killsPerMinute)) per min")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                
                // Human vs Bot (if available)
                if let extended = viewModel.extendedProfileStats,
                   extended.totalKills > 0 {
                    Text(" • ")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.bf6Blue)
                        Text("\(extended.humanKills)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Text(" / ")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        Text("\(extended.botKills)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
                
                Spacer()
            }
            
            // Trend
            if let trend = convertTrend(viewModel.killsTrend) {
                HStack(spacing: 4) {
                    Image(systemName: trend.value > 0 ? "arrow.up" : "arrow.down")
                        .font(.caption)
                    Text(trend.text)
                        .font(.caption)
                }
                .foregroundColor(trend.value > 0 ? Theme.bf6Green : Theme.error)
            } else {
                Color.clear
                    .frame(height: 16)
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
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


// MARK: - KDA Card with Decorative Icon

struct KDACard: View {
    @Environment(\.accentColor) private var accentColor
    @State private var isHovered = false

    let stats: PlayerStats

    var body: some View {
        ZStack(alignment: .trailing) {
            // Decorative chart icon in background
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 52.5))
                .foregroundStyle(accentColor.opacity(0.1))
                .offset(x: -10, y: 0)

            // Card content - matching StatCard structure
            VStack(alignment: .leading, spacing: 12) {
                // Header (matches StatCard headerView)
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                        .foregroundStyle(accentColor)

                    Text("K/D/A RATIO")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textSecondary)

                    Spacer()
                }

                // Value (matches StatCard valueView)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", stats.kdaRatio))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .fontDesign(.rounded)
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()
                }

                // Subtitle (matches StatCard subtitleView)
                Text("K: \(stats.kills.formatted()) / D: \(stats.deaths.formatted()) / A: \(stats.assists.formatted())")
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
                    accentColor.opacity(isHovered ? 0.4 : 0.2),
                    lineWidth: isHovered ? 2 : 1
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.smoothSpring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
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
