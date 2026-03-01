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
//  HeaderSection.swift
//  BF6StatsTracker
//
//  Header components: player identity, quick stats, and actions toolbar
//

import SwiftUI

struct HeaderSection: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @StateObject private var accountStore = EAAccountStore.shared
    @Binding var showingSearch: Bool
    @Binding var showingSettings: Bool
    @Binding var showingAccountSelection: Bool
    @Binding var showingXPBreakdown: Bool
    @Binding var showingRankDetail: Bool
    let usesLiquidGlass: Bool
    
    // State for percentile popovers
    @State private var showingKDPercentile = false
    @State private var showingKillsPercentile = false
    @State private var showingAssistsPercentile = false
    @State private var showingWinRatePercentile = false
    
    var body: some View {
        HStack(spacing: 20) {
            // LEADING SECTION: Player Identity
            playerIdentitySection

            Spacer()

            // CENTER SECTION: Quick Stats
            if let stats = viewModel.playerStats {
                quickStatsSection(stats: stats)
            }

            Spacer()

            // TRAILING SECTION: Actions Toolbar
            actionsToolbarSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(height: 76)
        .conditionalBackground(apply: !usesLiquidGlass)
        .overlay(alignment: .bottom) {
            if !usesLiquidGlass {
                Divider()
            }
        }
    }
    
    // MARK: - Player Identity Section

    private var playerIdentitySection: some View {
        HStack(spacing: 12) {
            if let stats = viewModel.playerStats {
                // Avatar with EA badge overlay
                ZStack(alignment: .bottomTrailing) {
                    PlayerAvatarView(
                        avatarUrl: EAAccountStore.shared.mostRecentAccount?.avatarUrl,
                        size: 44
                    )

                    if viewModel.isEAAuthenticated {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.success)
                            .background(
                                Circle()
                                    .fill(Theme.selectedText)
                                    .frame(width: 16, height: 16)
                            )
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Name and platform
                    HStack(spacing: 6) {
                        Text(stats.userName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        PlatformIconView(platform: nil, size: 14)
                    }

                    // Total XP - clickable to show XP breakdown, with rank badge to the right
                    if let xpArray = stats.xpData, let xp = xpArray.first {
                        HStack(spacing: 6) {
                            Button {
                                showingXPBreakdown.toggle()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(Theme.warning)

                                    Text("\(formatXP(xp.total)) XP")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Click to view XP breakdown")
                            .popover(isPresented: $showingXPBreakdown) {
                                xpBreakdownPopover
                            }
                            
                            // Rank badge to the right of XP button
                            if let profileData = viewModel.profileData, let rank = profileData.rank {
                                Button {
                                    showingRankDetail.toggle()
                                } label: {
                                    HStack(spacing: 4) {
                                        // Rank image from profile data if available
                                        if let rankImgUrl = profileData.rankImg,
                                           let url = URL(string: rankImgUrl) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                case .failure(_):
                                                    Image(systemName: "star.circle.fill")
                                                        .foregroundColor(Theme.warning)
                                                case .empty:
                                                    ProgressView()
                                                        .scaleEffect(0.5)
                                                @unknown default:
                                                    Image(systemName: "star.circle.fill")
                                                        .foregroundColor(Theme.warning)
                                                }
                                            }
                                            .frame(width: 16, height: 16)
                                        } else {
                                            // Fallback to icon if no image available
                                            Image(systemName: "star.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(Theme.warning)
                                        }
                                        
                                        Text("Rank \(rank)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.cardBackground.opacity(0.5))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                .help("Click to view rank details")
                                .popover(isPresented: $showingRankDetail) {
                                    rankDetailPopover
                                }
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Player information")
    }

    // MARK: - XP Breakdown Popover

    private var xpBreakdownPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let stats = viewModel.playerStats,
               let xpArray = stats.xpData,
               let xp = xpArray.first {

                Text("Experience Breakdown")
                    .font(.headline)
                    .foregroundColor(.primary)

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Theme.warning)
                    Text("\(formatXP(xp.total)) Total XP")
                        .font(.body)
                        .foregroundColor(Theme.textPrimary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .foregroundColor(Theme.info)
                    Text("\(formatXP(xp.performance)) Performance")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(Theme.warning)
                    Text("\(formatXP(xp.accolades)) Accolades")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Divider()
                
                // Badges count from profile data
                if let profileData = viewModel.profileData, let badges = profileData.badges {
                    HStack(spacing: 8) {
                        Image(systemName: "medal.fill")
                            .foregroundColor(Theme.success)
                        Text("\(badges) Badges")
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 220)
    }
    
    // MARK: - Rank Detail Popover
    
    private var rankDetailPopover: some View {
        VStack(spacing: 12) {
            if let profileData = viewModel.profileData, 
               let rank = profileData.rank,
               let largeRankImgUrl = profileData.playerCard?.rankImage?.large,
               let url = URL(string: largeRankImgUrl) {
                
                Text("Rank \(rank)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Divider()
                
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 150, height: 150)
                    case .failure(_):
                        VStack {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(Theme.warning)
                            Text("Unable to load rank image")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    case .empty:
                        ProgressView()
                            .frame(width: 150, height: 150)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 220, height: 250)
    }

    // MARK: - Quick Stats Section

    private func quickStatsSection(stats: PlayerStats) -> some View {
        HStack(spacing: 20) {
            Button {
                showingKDPercentile.toggle()
            } label: {
                CleanStatCard(
                    value: String(format: "%.2f", stats.kdRatio),
                    label: "KILLS / DEATH",
                    color: .green,
                    trend: viewModel.kdTrend
                )
            }
            .buttonStyle(.plain)
            .help("All-Time Kills / Death Ratio - Click to see community ranking")
            .popover(isPresented: $showingKDPercentile) {
                PercentilePopoverView(
                    statName: "K/D Ratio",
                    statValue: String(format: "%.2f", stats.kdRatio),
                    tier: stats.kdPerformanceTier
                )
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1, height: 40)

            Button {
                showingKillsPercentile.toggle()
            } label: {
                CleanStatCard(
                    value: formatKills(stats.kills),
                    label: "KILLS",
                    color: .orange,
                    trend: viewModel.killsTrend
                )
            }
            .buttonStyle(.plain)
            .help("All-Time Kills - Click to see community ranking")
            .popover(isPresented: $showingKillsPercentile) {
                PercentilePopoverView(
                    statName: "Kills per Minute",
                    statValue: String(format: "%.2f", stats.killsPerMinute),
                    tier: stats.killsPerformanceTier
                )
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1, height: 40)

            Button {
                showingAssistsPercentile.toggle()
            } label: {
                CleanStatCard(
                    value: formatKills(stats.assists),
                    label: "ASSISTS",
                    color: .purple,
                    trend: viewModel.assistsTrend
                )
            }
            .buttonStyle(.plain)
            .help("All-Time Assists - Click to see community ranking")
            .popover(isPresented: $showingAssistsPercentile) {
                PercentilePopoverView(
                    statName: "Assists",
                    statValue: formatKills(stats.assists),
                    tier: stats.assistsPerformanceTier
                )
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1, height: 40)

            Button {
                showingWinRatePercentile.toggle()
            } label: {
                CleanStatCard(
                    value: String(format: "%.1f%%", stats.wlRatio),
                    label: "WIN RATE",
                    color: .blue,
                    trend: viewModel.wlTrend
                )
            }
            .buttonStyle(.plain)
            .help("All-Time Win Rate - Click to see community ranking")
            .popover(isPresented: $showingWinRatePercentile) {
                PercentilePopoverView(
                    statName: "Win Rate",
                    statValue: String(format: "%.1f%%", stats.wlRatio),
                    tier: stats.winRatePerformanceTier
                )
            }
        }
        .layoutPriority(1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick statistics")
    }

    // MARK: - Actions Toolbar Section

    private var actionsToolbarSection: some View {
        HStack(spacing: 12) {
            // Primary action group - toolbar style
            HStack(spacing: 8) {
                ToolbarButton(
                    icon: "arrow.clockwise",
                    tooltip: "Refresh stats (⌘R)",
                    isLoading: viewModel.isLoading,
                    shouldPulsate: viewModel.shouldPulsateRefreshButton
                ) {
                    Task {
                        await viewModel.forceRefreshStats()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(viewModel.isLoading)

                Divider()
                    .frame(height: 20)

                ToolbarButton(
                    icon: "magnifyingglass",
                    tooltip: "Search player (⌘F)"
                ) {
                    showingSearch = true
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()
                    .frame(height: 20)

                ToolbarButton(
                    icon: "gearshape",
                    tooltip: "Settings (⌘,)"
                ) {
                    showingSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            .padding(4)
            .background(usesLiquidGlass ? .clear : Color.secondary.opacity(0.08))
            .cornerRadius(7)
            .modifier(ToolbarGroupGlassModifier(usesGlass: usesLiquidGlass))

            // Secondary actions menu
            Menu {
                if accountStore.accounts.count > 1 {
                    Button {
                        showingAccountSelection = true
                    } label: {
                        Label("Switch Account", systemImage: "person.2.fill")
                    }

                    Divider()
                }

                Button(role: .destructive) {
                    viewModel.logout()
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .help("More options")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Action buttons")
    }
}
