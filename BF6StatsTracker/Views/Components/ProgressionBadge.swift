//
//  ProgressionBadge.swift
//  BF6StatsTracker
//
//  Badge component displaying match progression type and XP multipliers
//

import SwiftUI

struct ProgressionBadge: View {
    let progressionMode: ProgressionMode?
    let compact: Bool

    init(progressionMode: ProgressionMode?, compact: Bool = false) {
        self.progressionMode = progressionMode
        self.compact = compact
    }

    var body: some View {
        if let mode = progressionMode {
            if compact {
                compactBadge(mode: mode)
            } else {
                fullBadge(mode: mode)
            }
        } else {
            unknownBadge
        }
    }

    // MARK: - Full Badge

    private func fullBadge(mode: ProgressionMode) -> some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: iconForMode(mode))
                .font(.caption)
                .foregroundColor(colorForMode(mode))

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text(mode.xpDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // XP Factor Badge
            if mode.persistStats {
                xpFactorPill(aiXpFactor: mode.aiXpFactor)
            } else {
                unrankedPill
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundForMode(mode))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorForMode(mode).opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Compact Badge

    private func compactBadge(mode: ProgressionMode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: iconForMode(mode))
                .font(.caption2)
                .foregroundColor(colorForMode(mode))

            Text(mode.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundForMode(mode))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(colorForMode(mode).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Unknown Badge

    private var unknownBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "questionmark.circle")
                .font(.caption2)
                .foregroundColor(.gray)

            Text("Unknown Mode")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - XP Factor Pills

    private func xpFactorPill(aiXpFactor: Double) -> some View {
        let percentage = Int(aiXpFactor * 100)
        let displayText = aiXpFactor == 0 ? "0%" : "\(percentage)%"

        return Text(displayText)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(pillColorForXP(aiXpFactor))
            .cornerRadius(4)
    }

    private var unrankedPill: some View {
        Text("UNRANKED")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.gray)
            .cornerRadius(4)
    }

    // MARK: - Helpers

    private func iconForMode(_ mode: ProgressionMode) -> String {
        if !mode.persistStats {
            return "xmark.shield"
        } else if mode.aiXpFactor >= 0.25 {
            return "checkmark.shield.fill"
        } else if mode.aiXpFactor >= 0.15 {
            return "exclamationmark.shield"
        } else {
            return "xmark.shield"
        }
    }

    private func colorForMode(_ mode: ProgressionMode) -> Color {
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

    private func backgroundForMode(_ mode: ProgressionMode) -> Color {
        colorForMode(mode).opacity(0.15)
    }

    private func pillColorForXP(_ xpFactor: Double) -> Color {
        if xpFactor == 0 {
            return .red
        } else if xpFactor >= 0.25 {
            return .green
        } else if xpFactor >= 0.15 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Progression Info Popover

struct ProgressionInfoPopover: View {
    let progressionMode: ProgressionMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                Text("Match Type Information")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Divider()

            // Mode Name
            HStack {
                Text("Mode:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(progressionMode.displayName)
                    .fontWeight(.semibold)
            }

            // Stats Tracking
            HStack {
                Text("Stats Tracked:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(progressionMode.persistStats ? "Yes" : "No")
                    .fontWeight(.semibold)
                    .foregroundColor(progressionMode.persistStats ? .green : .red)
            }

            // AI XP Factor
            HStack {
                Text("AI Kill XP:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progressionMode.aiXpFactor * 100))%")
                    .fontWeight(.semibold)
            }

            // Match Bonus
            HStack {
                Text("Match Bonus:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progressionMode.matchBonusXpFactor * 100))%")
                    .fontWeight(.semibold)
            }

            // Win Bonus
            HStack {
                Text("Win Bonus:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progressionMode.winBonusXpFactor * 100))%")
                    .fontWeight(.semibold)
            }

            Divider()

            // Description
            Text(progressionMode.xpDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
        .frame(width: 280)
    }
}

// MARK: - Preview

#Preview("Full Badge") {
    VStack(spacing: 16) {
        // Official mode
        ProgressionBadge(
            progressionMode: ProgressionMode(
                progressionMode: "official-progression",
                progressibles: [
                    Progressible(
                        name: "AiXpFactor",
                        category: "Persistence",
                        kind: ProgressibleKind(
                            mutatorFloat: MutatorFloat(value: 0.25),
                            mutatorBoolean: nil,
                            mutatorSparseBoolean: nil
                        ),
                        id: "test"
                    )
                ]
            )
        )

        // Unranked mode
        ProgressionBadge(
            progressionMode: ProgressionMode(
                progressionMode: "portal-unranked",
                progressibles: [
                    Progressible(
                        name: "PersistStats",
                        category: "Persistence",
                        kind: ProgressibleKind(
                            mutatorFloat: nil,
                            mutatorBoolean: MutatorBoolean(value: false),
                            mutatorSparseBoolean: nil
                        ),
                        id: "test"
                    )
                ]
            )
        )

        // Compact badges
        HStack {
            ProgressionBadge(
                progressionMode: ProgressionMode(
                    progressionMode: "official-gauntlet-progression",
                    progressibles: []
                ),
                compact: true
            )

            ProgressionBadge(
                progressionMode: ProgressionMode(
                    progressionMode: "casual-AI-Progression",
                    progressibles: []
                ),
                compact: true
            )
        }
    }
    .padding()
    .background(Theme.backgroundPrimary)
}
