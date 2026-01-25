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
//  ModeEfficiencyView.swift
//  BF6StatsTracker
//
//  Compare progression modes for XP efficiency
//

import SwiftUI

struct ModeEfficiencyView: View {
    @EnvironmentObject var viewModel: StatsViewModel

    // Sort options
    @State private var sortBy: EfficiencySortOption = .xpEfficiency
    @State private var showOnlyRanked: Bool = false

    // Cached filtered modes to avoid recalculating on every view update
    @State private var cachedFilteredModes: [ProgressionMode] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                header

                // Filters
                filterSection

                // Mode Comparison Cards
                if !viewModel.progressionModes.isEmpty {
                    modeComparisonGrid
                } else {
                    loadingView
                }

                // XP Efficiency Explanation
                xpEfficiencyExplanation
            }
            .padding()
        }
        .background(Theme.backgroundPrimary.ignoresSafeArea())
        .onAppear {
            updateFilteredModes()
        }
        .onChange(of: sortBy) { _, _ in
            updateFilteredModes()
        }
        .onChange(of: showOnlyRanked) { _, _ in
            updateFilteredModes()
        }
        .onChange(of: viewModel.progressionModes.count) { _, _ in
            updateFilteredModes()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title)
                    .foregroundColor(Theme.bf6Blue)

                Text("Mode Efficiency")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                Spacer()
            }

            Text("Compare progression modes to find the most efficient XP gain")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        HStack(spacing: 16) {
            // Sort Options
            Picker("Sort By", selection: $sortBy) {
                Text("XP Efficiency").tag(EfficiencySortOption.xpEfficiency)
                Text("AI Penalty").tag(EfficiencySortOption.aiPenalty)
                Text("Match Bonus").tag(EfficiencySortOption.matchBonus)
                Text("Alphabetical").tag(EfficiencySortOption.alphabetical)
            }
            .pickerStyle(.menu)
            .padding(8)
            .background(Theme.backgroundSecondary)
            .cornerRadius(8)

            // Show Only Ranked Toggle
            Toggle(isOn: $showOnlyRanked) {
                Text("Ranked Only")
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
            }
            .toggleStyle(.switch)
            .padding(8)
            .background(Theme.backgroundSecondary)
            .cornerRadius(8)

            Spacer()
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - Mode Comparison Grid

    private var modeComparisonGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(filteredModes) { mode in
                ModeEfficiencyCard(mode: mode)
            }
        }
        .id(showOnlyRanked)
    }

    // MARK: - Filtered Modes

    private var filteredModes: [ProgressionMode] {
        cachedFilteredModes
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading progression modes...")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - XP Efficiency Explanation

    private var xpEfficiencyExplanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Understanding XP Efficiency")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                explanationRow(
                    icon: "star.fill",
                    title: "Best for XP",
                    description: "Official matches and Gauntlet provide full or high AI XP rates"
                )

                explanationRow(
                    icon: "bolt.fill",
                    title: "AI XP Factor",
                    description: "Lower percentage means more XP reduction for AI kills"
                )

                explanationRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Match & Win Bonuses",
                    description: "Multipliers applied to base XP at match completion"
                )

                explanationRow(
                    icon: "xmark.shield",
                    title: "Unranked Modes",
                    description: "Stats and XP are not tracked in Portal Unranked or Fallback modes"
                )
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    private func explanationRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.bf6Blue)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    // MARK: - Sorting

    private func sortComparator(lhs: ProgressionMode, rhs: ProgressionMode) -> Bool {
        switch sortBy {
        case .xpEfficiency:
            // Higher AI XP factor = better efficiency
            return lhs.aiXpFactor > rhs.aiXpFactor
        case .aiPenalty:
            // Lower AI penalty = better
            return lhs.aiXpFactor > rhs.aiXpFactor
        case .matchBonus:
            return lhs.matchBonusXpFactor > rhs.matchBonusXpFactor
        case .alphabetical:
            return lhs.displayName < rhs.displayName
        }
    }

    // MARK: - Cache Update

    private func updateFilteredModes() {
        cachedFilteredModes = viewModel.progressionModes
            .filter { !showOnlyRanked || $0.persistStats }
            .sorted(by: sortComparator)
    }
}

// MARK: - Mode Efficiency Card

struct ModeEfficiencyCard: View {
    let mode: ProgressionMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: iconForMode)
                    .foregroundColor(colorForMode)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    Text(mode.progressionMode)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                // Efficiency Badge
                efficiencyBadge
            }

            Divider()
                .background(Theme.borderColor)

            // Stats
            VStack(spacing: 8) {
                statRow(
                    label: "AI XP Factor",
                    value: "\(Int(mode.aiXpFactor * 100))%",
                    color: colorForXPFactor(mode.aiXpFactor),
                    icon: "cpu"
                )

                statRow(
                    label: "Match Bonus",
                    value: "\(Int(mode.matchBonusXpFactor * 100))%",
                    color: .blue,
                    icon: "gamecontroller.fill"
                )

                statRow(
                    label: "Win Bonus",
                    value: "\(Int(mode.winBonusXpFactor * 100))%",
                    color: .green,
                    icon: "flag.checkered"
                )

                statRow(
                    label: "Stats Tracked",
                    value: mode.persistStats ? "Yes" : "No",
                    color: mode.persistStats ? .green : .red,
                    icon: "chart.bar.fill"
                )
            }

            // Description
            Text(mode.xpDescription)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 4)
        }
        .padding()
        .background(backgroundForMode)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForMode.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Efficiency Badge

    private var efficiencyBadge: some View {
        let efficiency = calculateEfficiency(mode: mode)

        return VStack(spacing: 2) {
            Text("\(Int(efficiency))%")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(colorForEfficiency(efficiency))

            Text("Efficiency")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(8)
        .background(colorForEfficiency(efficiency).opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - Stat Row

    private func statRow(label: String, value: String, color: Color, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }

    // MARK: - Helpers

    private var iconForMode: String {
        if !mode.persistStats {
            return "xmark.shield"
        } else if mode.aiXpFactor >= 0.25 {
            return "star.fill"
        } else if mode.aiXpFactor >= 0.15 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }

    private var colorForMode: Color {
        if !mode.persistStats {
            return .gray
        } else if mode.aiXpFactor >= 0.25 {
            return .green
        } else if mode.aiXpFactor >= 0.15 {
            return .orange
        } else {
            return .red
        }
    }

    private var backgroundForMode: Color {
        colorForMode.opacity(0.1)
    }

    private func colorForXPFactor(_ factor: Double) -> Color {
        if factor == 0 {
            return .red
        } else if factor >= 0.25 {
            return .green
        } else if factor >= 0.15 {
            return .orange
        } else {
            return .red
        }
    }

    private func calculateEfficiency(mode: ProgressionMode) -> Double {
        if !mode.persistStats {
            return 0
        }

        // Weighted efficiency score based on XP factors
        let aiScore = mode.aiXpFactor * 60.0 // AI kills are 60% of score
        let matchScore = mode.matchBonusXpFactor * 25.0 // Match bonus is 25%
        let winScore = mode.winBonusXpFactor * 15.0 // Win bonus is 15%

        return min((aiScore + matchScore + winScore) * 100, 100)
    }

    private func colorForEfficiency(_ efficiency: Double) -> Color {
        if efficiency >= 80 {
            return .green
        } else if efficiency >= 50 {
            return .blue
        } else if efficiency >= 25 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Sort Options

enum EfficiencySortOption {
    case xpEfficiency
    case aiPenalty
    case matchBonus
    case alphabetical
}

// MARK: - Preview

#Preview {
    ModeEfficiencyView()
        .environmentObject(StatsViewModel())
        .frame(width: 1000, height: 800)
}
