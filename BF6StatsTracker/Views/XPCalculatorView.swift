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
//  XPCalculatorView.swift
//  BF6StatsTracker
//
//  XP Calculator tool to estimate XP gain based on match performance
//

import SwiftUI

struct XPCalculatorView: View {
    @EnvironmentObject var viewModel: StatsViewModel

    // Input fields
    @State private var kills: String = "20"
    @State private var assists: String = "10"
    @State private var aiKills: String = "5"
    @State private var accolades: String = "3"
    @State private var matchTime: String = "15"
    @State private var didWin: Bool = true
    @State private var selectedMode: ProgressionMode?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                header

                // Mode Selector
                if !viewModel.progressionModes.isEmpty {
                    modeSelector
                }

                // Input Section
                inputSection

                // Calculation Results
                calculationResults

                // Breakdown Section
                xpBreakdown
            }
            .padding()
        }
        .background(Theme.backgroundPrimary.ignoresSafeArea())
        .onAppear {
            // Set default mode if available
            if selectedMode == nil, let officialMode = viewModel.progressionModes.first(where: { $0.progressionMode == "official-progression" }) {
                selectedMode = officialMode
            } else if selectedMode == nil {
                selectedMode = viewModel.progressionModes.first
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title)
                    .foregroundColor(Theme.bf6Orange)

                Text("XP Calculator")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                Spacer()
            }

            Text("Estimate your XP gain based on match performance and progression mode")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match Type")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.progressionModes) { mode in
                        ModeSelectorCard(
                            mode: mode,
                            isSelected: selectedMode?.id == mode.id,
                            action: { selectedMode = mode }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overall Match Performance")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                XPInputField(label: "Total Kills", value: $kills, icon: "target")
                XPInputField(label: "Assists", value: $assists, icon: "person.2.fill")
                XPInputField(label: "AI Kills", value: $aiKills, icon: "cpu")
                XPInputField(label: "Accolades", value: $accolades, icon: "star.fill")
                XPInputField(label: "Match Time (min)", value: $matchTime, icon: "clock.fill")

                // Win Toggle
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "flag.checkered")
                            .foregroundColor(Theme.warning)
                            .font(.caption)

                        Text("Match Result")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Toggle(isOn: $didWin) {
                        Text(didWin ? "Victory" : "Defeat")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(didWin ? .green : .red)
                    }
                    .toggleStyle(.switch)
                }
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - Calculation Results

    private var calculationResults: some View {
        let result = calculateXP()

        return VStack(spacing: 16) {
            // Total XP Display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated XP")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text("\(Int(result.totalXP))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.bf6Orange)

                    Text("Total Experience Points")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    rankProgressIndicator(xp: result.totalXP)

                    Text("≈ \(result.matchesForNextRank) more matches for next rank")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Theme.bf6Orange.opacity(0.2), Theme.backgroundSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - XP Breakdown

    private var xpBreakdown: some View {
        let result = calculateXP()

        return VStack(alignment: .leading, spacing: 16) {
            Text("XP Breakdown")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            VStack(spacing: 12) {
                XPBreakdownRow(
                    label: "Base XP (Kills)",
                    value: result.baseKillXP,
                    icon: "target",
                    color: .red
                )

                XPBreakdownRow(
                    label: "AI Kill Penalty",
                    value: -result.aiPenalty,
                    icon: "cpu",
                    color: .orange,
                    isNegative: true
                )

                XPBreakdownRow(
                    label: "Assist Bonus",
                    value: result.assistXP,
                    icon: "person.2.fill",
                    color: .blue
                )

                XPBreakdownRow(
                    label: "Accolade Bonus",
                    value: result.accoladeXP,
                    icon: "star.fill",
                    color: .yellow
                )

                XPBreakdownRow(
                    label: "Time Bonus",
                    value: result.timeXP,
                    icon: "clock.fill",
                    color: .green
                )

                if didWin {
                    XPBreakdownRow(
                        label: "Win Bonus",
                        value: result.winBonus,
                        icon: "flag.checkered.2.crossed",
                        color: .green
                    )
                }

                Divider()

                HStack {
                    HStack {
                        Image(systemName: "sum")
                            .foregroundColor(Theme.bf6Orange)

                        Text("Total XP")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Spacer()

                    Text("\(Int(result.totalXP))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.bf6Orange)
                }
            }

            // Multiplier Info
            if let mode = selectedMode {
                multiplierInfo(mode: mode)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    // MARK: - Multiplier Info

    private func multiplierInfo(mode: ProgressionMode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Multipliers")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            VStack(spacing: 6) {
                HStack {
                    Text("AI XP Factor:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Spacer()

                    Text("\(Int(mode.aiXpFactor * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(mode.aiXpFactor >= 0.25 ? .green : .orange)
                }

                HStack {
                    Text("Match Bonus:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Spacer()

                    Text("\(Int(mode.matchBonusXpFactor * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.success)
                }

                HStack {
                    Text("Win Bonus:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Spacer()

                    Text("\(Int(mode.winBonusXpFactor * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.success)
                }
            }
        }
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
    }

    // MARK: - Helpers

    private func rankProgressIndicator(xp: Double) -> some View {
        let currentRank = Int(xp / 59_346)
        let nextRank = currentRank + 1
        let xpInCurrentRank = xp.truncatingRemainder(dividingBy: 59_346)
        let progress = xpInCurrentRank / 59_346

        return VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Text("Rank \(currentRank)")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)

                Text("Rank \(nextRank)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
            }

            ProgressView(value: progress, total: 1.0)
                .tint(Theme.bf6Orange)
                .frame(width: 120)
        }
    }

    private func calculateXP() -> XPCalculation {
        let killCount = Double(kills) ?? 0
        let assistCount = Double(assists) ?? 0
        let aiKillCount = Double(aiKills) ?? 0
        let accoladeCount = Double(accolades) ?? 0
        let matchTimeMin = Double(matchTime) ?? 0

        let mode = selectedMode ?? viewModel.progressionModes.first

        // Base XP calculations (simplified estimate)
        let baseKillXP = killCount * 100 // ~100 XP per kill
        let aiPenalty = aiKillCount * 100 * (1.0 - (mode?.aiXpFactor ?? 0.25))
        let assistXP = assistCount * 50 // ~50 XP per assist
        let accoladeXP = accoladeCount * 200 // ~200 XP per accolade
        let timeXP = matchTimeMin * 10 // ~10 XP per minute

        let baseTotal = baseKillXP + assistXP + accoladeXP + timeXP - aiPenalty

        // Apply multipliers
        let matchBonus = baseTotal * (mode?.matchBonusXpFactor ?? 1.0)
        let winBonus = didWin ? (baseTotal * (mode?.winBonusXpFactor ?? 1.0) * 0.1) : 0

        let totalXP = baseTotal + matchBonus + winBonus

        // Calculate matches needed for next rank
        let matchesForNextRank = totalXP > 0 ? Int(ceil(59_346 / totalXP)) : 0

        return XPCalculation(
            baseKillXP: baseKillXP,
            aiPenalty: aiPenalty,
            assistXP: assistXP,
            accoladeXP: accoladeXP,
            timeXP: timeXP,
            winBonus: winBonus,
            totalXP: totalXP,
            matchesForNextRank: matchesForNextRank
        )
    }
}

// MARK: - Supporting Types

struct XPCalculation {
    let baseKillXP: Double
    let aiPenalty: Double
    let assistXP: Double
    let accoladeXP: Double
    let timeXP: Double
    let winBonus: Double
    let totalXP: Double
    let matchesForNextRank: Int
}

// MARK: - Mode Selector Card

struct ModeSelectorCard: View {
    let mode: ProgressionMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: mode.persistStats ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(mode.persistStats ? .green : .gray)
                        .font(.caption)

                    Text(mode.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                }

                Text(mode.xpDescription)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
            .padding()
            .frame(width: 160, height: 80)
            .background(isSelected ? Theme.bf6Orange.opacity(0.2) : Theme.backgroundSecondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Theme.bf6Orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Input Field

struct XPInputField: View {
    let label: String
    @Binding var value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Theme.warning)
                    .font(.caption)

                Text(label)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            TextField("0", text: $value)
                .textFieldStyle(.plain)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
                .padding(8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
        }
        .padding()
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
    }
}

// MARK: - Breakdown Row

struct XPBreakdownRow: View {
    let label: String
    let value: Double
    let icon: String
    let color: Color
    var isNegative: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text("\(isNegative ? "-" : "+")\(Int(abs(value)))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isNegative ? .red : color)
        }
    }
}

// MARK: - Preview

#Preview {
    XPCalculatorView()
        .environmentObject(StatsViewModel())
        .frame(width: 800, height: 1000)
}
